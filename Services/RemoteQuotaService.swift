import Foundation

private func log(_ message: String) {
    let logFile = "/tmp/agquotabar_debug.log"
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let line = "[\(timestamp)] [RemoteQuotaService] \(message)\n"
    if let data = line.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: logFile) {
            if let handle = FileHandle(forWritingAtPath: logFile) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            FileManager.default.createFile(atPath: logFile, contents: data)
        }
    }
}

@MainActor
final class RemoteQuotaService {
    private let oauthService: OAuthService
    private let session: URLSession
    
    init(oauthService: OAuthService? = nil) {
        self.oauthService = oauthService ?? OAuthService.shared
        
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = OAuthConstants.apiTimeoutSeconds
        self.session = URLSession(configuration: config)
    }
    
    func fetchQuota() async throws -> RemoteQuotaSnapshot {
        let accessToken = try await oauthService.getValidAccessToken()
        
        let projectInfo = try await loadProjectInfo(accessToken: accessToken)
        
        let modelsQuota = try await fetchModelsQuota(accessToken: accessToken, projectId: projectInfo.projectId)
        
        let userEmail = oauthService.userEmail
        
        return RemoteQuotaSnapshot(
            timestamp: Date(),
            models: modelsQuota,
            userEmail: userEmail,
            tier: projectInfo.tier,
            projectId: projectInfo.projectId
        )
    }
    
    private func loadProjectInfo(accessToken: String) async throws -> (projectId: String, tier: String) {
        let requestBody: [String: Any] = [
            "metadata": [
                "ideType": "ANTIGRAVITY"
            ]
        ]
        
        let response: LoadCodeAssistResponse = try await performAPIRequest(
            path: CloudCodeAPIConstants.loadCodeAssistPath,
            accessToken: accessToken,
            body: requestBody
        )
        
        return (projectId: response.projectId, tier: response.tier)
    }
    
    private func fetchModelsQuota(accessToken: String, projectId: String) async throws -> [RemoteModelQuota] {
        let requestBody: [String: Any] = [
            "project": projectId
        ]
        
        let response: FetchAvailableModelsResponse = try await performAPIRequest(
            path: CloudCodeAPIConstants.fetchAvailableModelsPath,
            accessToken: accessToken,
            body: requestBody
        )
        
        guard let models = response.models else {
            return []
        }
        
        let allowedPatterns = try NSRegularExpression(pattern: "gemini|claude|gpt", options: .caseInsensitive)
        
        return models.compactMap { (modelName, modelInfo) -> RemoteModelQuota? in
            let range = NSRange(modelName.startIndex..<modelName.endIndex, in: modelName)
            guard allowedPatterns.firstMatch(in: modelName, range: range) != nil else {
                return nil
            }
            
            guard isModelVersionSupported(modelName) else {
                return nil
            }
            
            guard let quotaInfo = modelInfo.quotaInfo else {
                return nil
            }
            
            let remainingFraction = quotaInfo.remainingFraction ?? 0
            let displayName = formatModelDisplayName(modelName)
            
            return RemoteModelQuota(
                modelName: modelName,
                displayName: displayName,
                remainingFraction: remainingFraction,
                resetTimeString: quotaInfo.resetTime
            )
        }
    }
    
    private func performAPIRequest<T: Decodable>(path: String, accessToken: String, body: [String: Any]) async throws -> T {
        guard let url = URL(string: CloudCodeAPIConstants.baseURL + path) else {
            throw OAuthError.networkError("Invalid API URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("AntigravityQuotaWatcher/1.0", forHTTPHeaderField: "User-Agent")
        
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = bodyData
        
        log("API request: \(path)")
        log("Body: \(String(data: bodyData, encoding: .utf8) ?? "nil")")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OAuthError.networkError("Invalid response")
        }
        
        log("API response: HTTP \(httpResponse.statusCode)")
        
        guard (200..<300).contains(httpResponse.statusCode) else {
            let responseBody = String(data: data, encoding: .utf8) ?? "nil"
            log("API error body: \(responseBody)")
            
            if httpResponse.statusCode == 401 {
                throw OAuthError.apiError(401, "Unauthorized - token may be invalid")
            }
            
            var errorMessage = "HTTP \(httpResponse.statusCode)"
            if let errorBody = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = errorBody["message"] as? String ?? (errorBody["error"] as? [String: Any])?["message"] as? String {
                errorMessage = message
            }
            
            throw OAuthError.apiError(httpResponse.statusCode, errorMessage)
        }
        
        log("API success, parsing response...")
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    private func isModelVersionSupported(_ modelName: String) -> Bool {
        let lowerName = modelName.lowercased()
        
        guard lowerName.contains("gemini") else {
            return true
        }
        
        if let match = lowerName.range(of: #"gemini-(\d+(?:\.\d+)?)"#, options: .regularExpression) {
            let versionString = lowerName[match].replacingOccurrences(of: "gemini-", with: "")
            if let version = Double(versionString) {
                return version >= 2.0
            }
        }
        
        return false
    }
    
    private func formatModelDisplayName(_ modelName: String) -> String {
        let fixedName = modelName.replacingOccurrences(of: #"(\d+)-(\d+)"#, with: "$1.$2", options: .regularExpression)
        
        return fixedName
            .split(separator: "-")
            .map { part in
                let str = String(part)
                if str.first?.isNumber == true {
                    return str
                }
                return str.prefix(1).uppercased() + str.dropFirst()
            }
            .joined(separator: " ")
    }
}
