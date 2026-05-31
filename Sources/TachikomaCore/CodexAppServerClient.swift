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
        var collectedLines: [String] = []

        let isEventStream = (response as? HTTPURLResponse)?
            .value(forHTTPHeaderField: "Content-Type")?
            .localizedCaseInsensitiveContains("text/event-stream") == true

        if let httpResponse = response as? HTTPURLResponse, !(200 ..< 300).contains(httpResponse.statusCode) {
            for try await line in bytes.lines {
                collectedLines.append(line)
            }
            throw CodexAppServerError.httpStatus(httpResponse.statusCode, collectedLines.joined(separator: "\n"))
        }

        for try await line in bytes.lines {
            if isEventStream, let payload = Self.ssePayload(from: line) {
                guard payload != "[DONE]" else { continue }
                collectedLines.append(payload)
                onDelta(payload)
            } else if isEventStream, Self.isSSEControlLine(line) {
                continue
            } else {
                collectedLines.append(line)
                onDelta(line)
            }
        }

        let collected = collectedLines.joined(separator: "\n")
        guard !collected.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CodexAppServerError.emptyResponse
        }

        let data = Data(collected.utf8)
        if let decoded = try? JSONDecoder().decode(CodexConversationResponse.self, from: data) {
            return decoded
        }

        return CodexConversationResponse(message: collected)
    }

    private static func ssePayload(from line: String) -> String? {
        guard line.hasPrefix("data:") else { return nil }

        let payload = line.dropFirst("data:".count)
        if payload.first == " " {
            return String(payload.dropFirst())
        }
        return String(payload)
    }

    private static func isSSEControlLine(_ line: String) -> Bool {
        line.isEmpty ||
            line.hasPrefix(":") ||
            line.hasPrefix("event:") ||
            line.hasPrefix("id:") ||
            line.hasPrefix("retry:")
    }
}
