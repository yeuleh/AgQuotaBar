import Foundation

private func log(_ message: String) {
    let logFile = "/tmp/agquotabar_debug.log"
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let line = "[\(timestamp)] [LocalQuotaService] \(message)\n"
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

struct LocalQuotaService {
    func fetchQuota() async throws -> QuotaSnapshot {
        log("fetchQuota: starting")
        let detection = try detectPorts()
        log("fetchQuota: detected port=\(detection.connectPort ?? -1)")
        let responseData = try await performRequest(
            port: detection.connectPort ?? detection.httpPort,
            httpFallbackPort: detection.httpPort,
            csrfToken: detection.csrfToken
        )
        log("fetchQuota: received \(responseData.count) bytes")
        let decoded = try JSONDecoder().decode(UserStatusResponse.self, from: responseData)
        let snapshot = mapSnapshot(from: decoded)
        log("fetchQuota: parsed \(snapshot.models.count) models")
        return snapshot
    }

    private func detectPorts() throws -> PortDetectionResult {
        log("detectPorts: running ps")
        let psOutput = try runProcessOutput(
            executable: "/bin/ps",
            arguments: ["-ax", "-o", "pid=,command="]
        )
        let lines = psOutput.split(separator: "\n")
        guard let match = lines.first(where: {
            $0.contains("language_server") && $0.contains("--app_data_dir antigravity")
        }) else {
            log("detectPorts: language_server not found")
            throw LocalQuotaError.languageServerNotRunning
        }
        let line = String(match)
        log("detectPorts: found process")
        
        let components = line.trimmingCharacters(in: .whitespaces).split(separator: " ", maxSplits: 1)
        guard let pidString = components.first, let pid = Int(pidString) else {
            log("detectPorts: failed to parse PID")
            throw LocalQuotaError.languageServerNotRunning
        }
        log("detectPorts: PID=\(pid)")
        
        guard let csrfToken = matchValue(for: "--csrf_token(?:=|\\s+)([A-Za-z0-9-]+)", in: line) else {
            log("detectPorts: missing CSRF token")
            throw LocalQuotaError.missingCsrfToken
        }
        
        log("detectPorts: running lsof")
        let lsofOutput = try runProcessOutput(
            executable: "/usr/sbin/lsof",
            arguments: ["-nP", "-iTCP", "-sTCP:LISTEN", "-p", String(pid)]
        )
        log("detectPorts: lsof returned \(lsofOutput.count) chars")
        
        let portPattern = ":([0-9]+)\\s+\\(LISTEN\\)"
        var ports: [Int] = []
        var lineCount = 0
        for lsofLine in lsofOutput.split(separator: "\n") {
            lineCount += 1
            let lineStr = String(lsofLine)
            if !lineStr.contains("language_") {
                continue
            }
            if let portString = matchValue(for: portPattern, in: lineStr),
               let port = Int(portString) {
                ports.append(port)
                log("detectPorts: found port \(port) on line \(lineCount)")
            }
        }
        
        log("detectPorts: scanned \(lineCount) lines, found \(ports.count) ports")
        
        guard !ports.isEmpty else {
            log("detectPorts: no ports found")
            throw LocalQuotaError.missingPort
        }
        
        ports.sort()
        let httpPort = ports.count > 1 ? ports[1] : ports.first!
        log("detectPorts: using httpPort=\(httpPort)")
        
        return PortDetectionResult(connectPort: httpPort, httpPort: httpPort, csrfToken: csrfToken)
    }

    private func performRequest(port: Int, httpFallbackPort: Int, csrfToken: String) async throws -> Data {
        let body = GetUserStatusRequest(metadata: Metadata())
        let encoder = JSONEncoder()
        let payload = try encoder.encode(body)

        if port == httpFallbackPort {
            do {
                return try await request(
                    scheme: "http",
                    port: httpFallbackPort,
                    csrfToken: csrfToken,
                    payload: payload
                )
            } catch {
                if shouldFallbackToHTTP(error) == false {
                    throw error
                }
            }
        }

        do {
            return try await request(
                scheme: "https",
                port: port,
                csrfToken: csrfToken,
                payload: payload
            )
        } catch {
            if shouldFallbackToHTTP(error) {
                return try await request(
                    scheme: "http",
                    port: httpFallbackPort,
                    csrfToken: csrfToken,
                    payload: payload
                )
            }
            throw error
        }
    }

    private func request(
        scheme: String,
        port: Int,
        csrfToken: String,
        payload: Data
    ) async throws -> Data {
        guard let url = URL(string: "\(scheme)://127.0.0.1:\(port)\(Constants.getUserStatusPath)") else {
            throw LocalQuotaError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = payload
        request.timeoutInterval = Constants.timeoutSeconds
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(String(payload.count), forHTTPHeaderField: "Content-Length")
        request.setValue(Constants.connectProtocolVersion, forHTTPHeaderField: "Connect-Protocol-Version")
        request.setValue(csrfToken, forHTTPHeaderField: "X-Codeium-Csrf-Token")

        let configuration = URLSessionConfiguration.ephemeral
        let session = URLSession(configuration: configuration)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LocalQuotaError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw LocalQuotaError.httpError(httpResponse.statusCode)
        }
        return data
    }

    private func mapSnapshot(from response: UserStatusResponse) -> QuotaSnapshot {
        let formatter = ISO8601DateFormatter()
        let configs = response.userStatus.cascadeModelConfigData?.clientModelConfigs ?? []
        let models = configs.map { model in
            let fraction = model.quotaInfo?.remainingFraction
            let percentage = fraction.map { Int(($0 * 100).rounded()) }
            let resetTime = model.quotaInfo?.resetTime.flatMap { formatter.date(from: $0) }
            let isExhausted = (fraction ?? 0) <= 0
            return QuotaModel(
                id: model.modelOrAlias.model,
                name: model.label,
                remainingPercentage: percentage,
                resetTime: resetTime,
                isExhausted: isExhausted
            )
        }

        let planName = response.userStatus.userTier?.name ?? response.userStatus.planStatus?.planInfo.planName
        return QuotaSnapshot(
            timestamp: Date(),
            models: models,
            userEmail: response.userStatus.email,
            planName: planName,
            isStale: false
        )
    }

    private func shouldFallbackToHTTP(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else {
            return false
        }
        switch urlError.code {
        case .secureConnectionFailed,
             .serverCertificateUntrusted,
             .serverCertificateHasBadDate,
             .serverCertificateNotYetValid,
             .serverCertificateHasUnknownRoot,
             .cannotConnectToHost,
             .networkConnectionLost:
            return true
        default:
            return false
        }
    }

    private func matchValue(for pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let valueRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[valueRange])
    }

    private func runProcessOutput(executable: String, arguments: [String]) throws -> String {
        log("runProcessOutput: \(executable) \(arguments.joined(separator: " "))")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        log("runProcessOutput: exit=\(process.terminationStatus), bytes=\(data.count)")
        guard process.terminationStatus == 0 else {
            throw LocalQuotaError.processListingFailed
        }
        return String(decoding: data, as: UTF8.self)
    }
}

private enum Constants {
    static let getUserStatusPath = "/exa.language_server_pb.LanguageServerService/GetUserStatus"
    static let connectProtocolVersion = "1"
    static let timeoutSeconds: TimeInterval = 5
}

private struct PortDetectionResult {
    let connectPort: Int?
    let httpPort: Int
    let csrfToken: String
}

private struct GetUserStatusRequest: Encodable {
    let metadata: Metadata
}

private struct Metadata: Encodable {
    let ideName: String = "antigravity"
    let extensionName: String = "antigravity"
    let ideVersion: String = "1.0"
    let locale: String = "en"
}

private struct UserStatusResponse: Decodable {
    let userStatus: UserStatus
}

private struct UserStatus: Decodable {
    let name: String?
    let email: String?
    let planStatus: PlanStatus?
    let cascadeModelConfigData: CascadeModelConfigData?
    let userTier: UserTier?
}

private struct UserTier: Decodable {
    let id: String?
    let name: String
    let description: String?
}

private struct PlanStatus: Decodable {
    let planInfo: PlanInfo
    let availablePromptCredits: Double?
    let availableFlowCredits: Double?
}

private struct PlanInfo: Decodable {
    let teamsTier: String?
    let planName: String
    let monthlyPromptCredits: Double?
    let monthlyFlowCredits: Double?
}

private struct CascadeModelConfigData: Decodable {
    let clientModelConfigs: [ModelConfig]
}

private struct ModelConfig: Decodable {
    let label: String
    let modelOrAlias: ModelAlias
    let quotaInfo: ModelQuotaInfo?
}

private struct ModelAlias: Decodable {
    let model: String
}

private struct ModelQuotaInfo: Decodable {
    let remainingFraction: Double?
    let resetTime: String?
}

enum LocalQuotaError: LocalizedError {
    case languageServerNotRunning
    case missingPort
    case missingCsrfToken
    case processListingFailed
    case invalidURL
    case invalidResponse
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .languageServerNotRunning:
            return "Language server not running"
        case .missingPort:
            return "Missing extension server port"
        case .missingCsrfToken:
            return "Missing CSRF token"
        case .processListingFailed:
            return "Failed to inspect processes"
        case .invalidURL:
            return "Invalid request URL"
        case .invalidResponse:
            return "Invalid response"
        case .httpError(let status):
            return "HTTP error \(status)"
        }
    }
}
