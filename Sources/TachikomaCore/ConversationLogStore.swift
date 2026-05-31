import Foundation

public struct ConversationLogEntry: Codable, Equatable {
    public let createdAt: Date
    public let kind: String
    public let text: String

    public init(createdAt: Date = Date(), kind: String, text: String) {
        self.createdAt = createdAt
        self.kind = kind
        self.text = text
    }
}

public struct ConversationLogStore: Sendable {
    public let logDirectory: URL

    public init(
        logDirectory: URL = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("Tachikoma", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
    ) {
        self.logDirectory = logDirectory
    }

    public func append(_ entry: ConversationLogEntry) throws {
        try FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)

        let fileURL = logDirectory.appendingPathComponent(Self.fileName(for: entry.createdAt))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entry) + Data("\n".utf8)

        if FileManager.default.fileExists(atPath: fileURL.path) {
            let handle = try FileHandle(forWritingTo: fileURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } else {
            try data.write(to: fileURL, options: .atomic)
        }
    }

    private static func fileName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'.jsonl'"
        return formatter.string(from: date)
    }
}
