import Foundation

public struct CategorizationConfiguration: Sendable, Codable, Hashable {
    public let databasePath: String
    public let classification: ClassificationConfig
    public let resultTTL: TimeInterval
    public let foregroundBatchSize: Int
    public let backgroundBatchSize: Int
    public let foregroundConcurrency: Int
    public let backgroundTaskIdentifier: String?

    public init(
        databasePath: String? = nil,
        classification: ClassificationConfig = ClassificationConfig(),
        resultTTL: TimeInterval = 86_400,
        foregroundBatchSize: Int = 50,
        backgroundBatchSize: Int = 5,
        foregroundConcurrency: Int = 4,
        backgroundTaskIdentifier: String? = nil
    ) {
        self.databasePath = databasePath ?? Self.defaultDatabasePath
        self.classification = classification
        self.resultTTL = max(0, resultTTL)
        self.foregroundBatchSize = max(1, foregroundBatchSize)
        self.backgroundBatchSize = max(1, backgroundBatchSize)
        self.foregroundConcurrency = max(1, foregroundConcurrency)
        self.backgroundTaskIdentifier = backgroundTaskIdentifier
    }

    private static var defaultDatabasePath: String {
        let directory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!.appendingPathComponent("BGCategorizationProcessor", isDirectory: true)
        return directory.appendingPathComponent("categorization.sqlite3").path
    }
}
