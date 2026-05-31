import Foundation

public enum CodexAppServerError: Error, LocalizedError {
    case invalidURL(String)
    case emptyResponse
    case httpStatus(Int, String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL(let value):
            return "Codex App Server URL is invalid: \(value)"
        case .emptyResponse:
            return "Codex App Server returned an empty response."
        case .httpStatus(let statusCode, let body):
            return "Codex App Server returned HTTP \(statusCode): \(body)"
        }
    }
}

public struct CodexConversationRequest: Codable, Equatable, Sendable {
    public let mode: ConversationMode
    public let message: String
    public let targetDirectory: String
    public let readonly: Bool

    public init(mode: ConversationMode, message: String, targetDirectory: String, readonly: Bool) {
        self.mode = mode
        self.message = message
        self.targetDirectory = targetDirectory
        self.readonly = readonly
    }
}

public struct CodexConversationResponse: Codable, Equatable, Sendable {
    public let message: String
    public let affectedFiles: [String]?
    public let workItems: [String]?
    public let impact: String?

    public init(
        message: String,
        affectedFiles: [String]? = nil,
        workItems: [String]? = nil,
        impact: String? = nil
    ) {
        self.message = message
        self.affectedFiles = affectedFiles
        self.workItems = workItems
        self.impact = impact
    }
}

public protocol CodexAppServerConnecting: Sendable {
    func send(
        _ request: CodexConversationRequest,
        endpoint: String,
        onDelta: @escaping @Sendable (String) -> Void
    ) async throws -> CodexConversationResponse
}

public struct CodexAppServerClient: CodexAppServerConnecting {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(
        _ request: CodexConversationRequest,
        endpoint: String,
        onDelta: @escaping @Sendable (String) -> Void
    ) async throws -> CodexConversationResponse {
        guard let url = URL(string: endpoint) else {
            throw CodexAppServerError.invalidURL(endpoint)
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("text/event-stream, application/json, text/plain", forHTTPHeaderField: "Accept")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (bytes, response) = try await session.bytes(for: urlRequest)
        var collected = ""

        if let httpResponse = response as? HTTPURLResponse, !(200 ..< 300).contains(httpResponse.statusCode) {
            for try await line in bytes.lines {
                collected += line + "\n"
            }
            throw CodexAppServerError.httpStatus(httpResponse.statusCode, collected)
        }

        var lines: [String] = []
        for try await line in bytes.lines {
            let chunk = Self.payload(from: line)
            guard !chunk.isEmpty else { continue }
            lines.append(chunk)
            collected = lines.joined(separator: "\n")
            onDelta(chunk)
        }

        guard !collected.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CodexAppServerError.emptyResponse
        }

        let data = Data(collected.utf8)
        if let decoded = try? JSONDecoder().decode(CodexConversationResponse.self, from: data) {
            return decoded
        }

        return CodexConversationResponse(message: collected.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func payload(from line: String) -> String {
        if line.hasPrefix("data:") {
            let value = line.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
            return value == "[DONE]" ? "" : value
        }

        return line
    }
}
