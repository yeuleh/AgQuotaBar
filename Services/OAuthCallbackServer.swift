import Foundation
import Network

struct OAuthCallbackResult {
    let code: String
    let state: String
}

final class OAuthCallbackServer {
    private var listener: NWListener?
    private var port: UInt16 = 0
    private var expectedState: String?
    private var continuation: CheckedContinuation<OAuthCallbackResult, Error>?
    
    var redirectUri: String {
        "http://\(OAuthConstants.callbackHost):\(port)\(OAuthConstants.callbackPath)"
    }
    
    func start() async throws -> UInt16 {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        
        listener = try NWListener(using: parameters, on: .any)
        
        return try await withCheckedThrowingContinuation { continuation in
            listener?.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    if let port = self?.listener?.port?.rawValue {
                        self?.port = port
                        continuation.resume(returning: port)
                    }
                case .failed(let error):
                    continuation.resume(throwing: OAuthError.callbackServerFailed(error.localizedDescription))
                default:
                    break
                }
            }
            
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            
            listener?.start(queue: .global(qos: .userInitiated))
        }
    }
    
    func waitForCallback(expectedState: String) async throws -> OAuthCallbackResult {
        self.expectedState = expectedState
        
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            
            Task {
                try await Task.sleep(nanoseconds: UInt64(OAuthConstants.authTimeoutSeconds * 1_000_000_000))
                if self.continuation != nil {
                    self.continuation?.resume(throwing: OAuthError.authorizationTimeout)
                    self.continuation = nil
                    self.stop()
                }
            }
        }
    }
    
    func stop() {
        listener?.cancel()
        listener = nil
        continuation = nil
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            guard let self = self, let data = data, error == nil else {
                connection.cancel()
                return
            }
            
            let request = String(decoding: data, as: UTF8.self)
            self.processRequest(request, connection: connection)
        }
    }
    
    private func processRequest(_ request: String, connection: NWConnection) {
        guard let firstLine = request.split(separator: "\r\n").first,
              let urlPart = firstLine.split(separator: " ").dropFirst().first,
              let components = URLComponents(string: String(urlPart)) else {
            sendErrorResponse(connection: connection, error: "invalid_request", message: "Invalid request format")
            return
        }
        
        guard components.path == OAuthConstants.callbackPath else {
            sendErrorResponse(connection: connection, error: "not_found", message: "Not found")
            return
        }
        
        let queryItems = components.queryItems ?? []
        let params = Dictionary(uniqueKeysWithValues: queryItems.compactMap { item -> (String, String)? in
            guard let value = item.value else { return nil }
            return (item.name, value)
        })
        
        if let error = params["error"] {
            let description = params["error_description"] ?? error
            sendErrorResponse(connection: connection, error: error, message: description)
            continuation?.resume(throwing: OAuthError.authorizationDenied(description))
            continuation = nil
            stop()
            return
        }
        
        guard let code = params["code"], let state = params["state"] else {
            sendErrorResponse(connection: connection, error: "missing_params", message: "Missing code or state")
            continuation?.resume(throwing: OAuthError.authorizationDenied("Missing authorization code"))
            continuation = nil
            stop()
            return
        }
        
        guard state == expectedState else {
            sendErrorResponse(connection: connection, error: "invalid_state", message: "State mismatch (CSRF protection)")
            continuation?.resume(throwing: OAuthError.invalidState)
            continuation = nil
            stop()
            return
        }
        
        sendSuccessResponse(connection: connection)
        continuation?.resume(returning: OAuthCallbackResult(code: code, state: state))
        continuation = nil
        
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.stop()
        }
    }
    
    private func sendSuccessResponse(connection: NWConnection) {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <title>授权成功</title>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    height: 100vh;
                    margin: 0;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    color: white;
                }
                .container {
                    text-align: center;
                    padding: 40px;
                    background: rgba(255,255,255,0.1);
                    border-radius: 20px;
                    backdrop-filter: blur(10px);
                }
                .icon { font-size: 64px; margin-bottom: 20px; }
                h1 { margin: 0 0 10px 0; font-weight: 600; }
                p { margin: 0; opacity: 0.9; }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="icon">✓</div>
                <h1>授权成功</h1>
                <p>您可以关闭此窗口并返回 AgQuotaBar</p>
            </div>
        </body>
        </html>
        """
        sendHTTPResponse(connection: connection, status: "200 OK", body: html)
    }
    
    private func sendErrorResponse(connection: NWConnection, error: String, message: String) {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <title>授权失败</title>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    height: 100vh;
                    margin: 0;
                    background: linear-gradient(135deg, #e74c3c 0%, #c0392b 100%);
                    color: white;
                }
                .container {
                    text-align: center;
                    padding: 40px;
                    background: rgba(255,255,255,0.1);
                    border-radius: 20px;
                    backdrop-filter: blur(10px);
                }
                .icon { font-size: 64px; margin-bottom: 20px; }
                h1 { margin: 0 0 10px 0; font-weight: 600; }
                p { margin: 0; opacity: 0.9; }
                .error-code { font-size: 12px; opacity: 0.7; margin-top: 15px; }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="icon">✕</div>
                <h1>授权失败</h1>
                <p>\(message)</p>
                <p class="error-code">错误代码: \(error)</p>
            </div>
        </body>
        </html>
        """
        sendHTTPResponse(connection: connection, status: "200 OK", body: html)
    }
    
    private func sendHTTPResponse(connection: NWConnection, status: String, body: String) {
        let response = """
        HTTP/1.1 \(status)\r
        Content-Type: text/html; charset=utf-8\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        \r
        \(body)
        """
        
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
