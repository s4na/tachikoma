import Foundation

public struct LaunchAgentManager {
    public static let defaultsSuiteName = "com.s4na.tachikoma"
    public static let label = "com.s4na.tachikoma"
    public static let startupOffDefaultsKey = "startupOff"

    public let label: String
    public let executablePath: String
    public let plistURL: URL

    private let fileManager: FileManager

    public init(
        label: String = LaunchAgentManager.label,
        executablePath: String = LaunchAgentManager.currentExecutablePath(),
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        fileManager: FileManager = .default
    ) {
        self.label = label
        self.executablePath = executablePath
        plistURL = homeDirectory
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(label).plist")
        self.fileManager = fileManager
    }

    public func sync(startupOff: Bool) throws {
        if startupOff {
            try remove()
        } else {
            try install()
        }
    }

    public func install() throws {
        try fileManager.createDirectory(
            at: plistURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let data = try PropertyListSerialization.data(
            fromPropertyList: Self.plist(label: label, executablePath: executablePath),
            format: .xml,
            options: 0
        )
        try data.write(to: plistURL, options: .atomic)
    }

    public func remove() throws {
        if fileManager.fileExists(atPath: plistURL.path) {
            try fileManager.removeItem(at: plistURL)
        }
    }

    public static func plist(label: String, executablePath: String) -> [String: Any] {
        [
            "Label": label,
            "ProgramArguments": [executablePath],
            "RunAtLoad": true
        ]
    }

    public static func startupDefaults() -> UserDefaults {
        UserDefaults(suiteName: defaultsSuiteName) ?? .standard
    }

    public static func currentExecutablePath() -> String {
        if let executablePath = Bundle.main.executablePath {
            return executablePath
        }

        return CommandLine.arguments.first ?? "tachikoma"
    }
}
