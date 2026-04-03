import Foundation

struct StoredCategory: Sendable, Equatable {
    let definition: CategoryDefinition
    let centroid: [Float]
}

actor CategorizationDatabase {
    private let connection: DatabaseConnecting
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(path: String) throws {
        self.connection = try DatabaseConnection(path: path)
        try Self.createTables(on: connection)
    }

    init(connection: DatabaseConnecting) throws {
        self.connection = connection
        try Self.createTables(on: connection)
    }

    func upsertCategory(_ category: CategoryDefinition, centroid: [Float]) throws {
        let descriptorsJSON = try encodeJSONString(category.descriptors)
        let centroidJSON = try encodeJSONString(centroid)
        try connection.execute(
            """
            INSERT OR REPLACE INTO categories (id, label, descriptors_json, centroid_json)
            VALUES (?, ?, ?, ?)
            """,
            bindings: [
                .text(category.id),
                .text(category.label),
                .text(descriptorsJSON),
                .text(centroidJSON)
            ]
        )
    }

    func resetCategories(_ categories: [StoredCategory]) throws {
        try connection.transaction {
            try connection.execute("DELETE FROM categories", bindings: [])
            for category in categories {
                try upsertCategory(category.definition, centroid: category.centroid)
            }
        }
    }

    func deleteCategory(id: String) throws {
        try connection.execute(
            "DELETE FROM categories WHERE id = ?",
            bindings: [.text(id)]
        )
    }

    func fetchCategories() throws -> [CategoryDefinition] {
        let rows = try connection.query(
            """
            SELECT id, label, descriptors_json
            FROM categories
            ORDER BY id ASC
            """,
            bindings: []
        )
        return try rows.map { row in
            CategoryDefinition(
                id: row.requireString("id"),
                label: row.requireString("label"),
                descriptors: try decodeJSON([String].self, from: row.requireString("descriptors_json"))
            )
        }
    }

    func loadCentroids() throws -> [String: [Float]] {
        let rows = try connection.query(
            """
            SELECT id, centroid_json
            FROM categories
            ORDER BY id ASC
            """,
            bindings: []
        )
        var centroids: [String: [Float]] = [:]
        for row in rows {
            centroids[row.requireString("id")] = try decodeJSON([Float].self, from: row.requireString("centroid_json"))
        }
        return centroids
    }

    func insertJob(_ job: CategorizationJob) throws {
        try connection.execute(
            """
            INSERT OR REPLACE INTO jobs (item_id, text, priority, enqueued_at, retry_count)
            VALUES (?, ?, ?, ?, ?)
            """,
            bindings: [
                .text(job.itemID),
                .text(job.text),
                .integer(Int64(job.priority.rawValue)),
                .double(job.enqueuedAt.timeIntervalSince1970),
                .integer(Int64(job.retryCount))
            ]
        )
    }

    func insertJobs(_ jobs: [CategorizationJob]) throws {
        try connection.transaction {
            for job in jobs {
                try insertJob(job)
            }
        }
    }

    func fetchJobs(limit: Int) throws -> [CategorizationJob] {
        let rows = try connection.query(
            """
            SELECT item_id, text, priority, enqueued_at, retry_count
            FROM jobs
            ORDER BY priority DESC, enqueued_at ASC
            LIMIT ?
            """,
            bindings: [.integer(Int64(limit))]
        )
        return rows.map { row in
            CategorizationJob(
                itemID: row.requireString("item_id"),
                text: row.requireString("text"),
                priority: JobPriority(rawValue: row.requireInt("priority")) ?? .normal,
                enqueuedAt: Date(timeIntervalSince1970: row.requireDouble("enqueued_at")),
                retryCount: row.requireInt("retry_count")
            )
        }
    }

    func incrementRetryCount(itemID: String) throws {
        try connection.execute(
            "UPDATE jobs SET retry_count = retry_count + 1 WHERE item_id = ?",
            bindings: [.text(itemID)]
        )
    }

    func deleteJob(itemID: String) throws {
        try connection.execute(
            "DELETE FROM jobs WHERE item_id = ?",
            bindings: [.text(itemID)]
        )
    }

    func pendingCount() throws -> Int {
        let rows = try connection.query(
            "SELECT COUNT(*) AS count FROM jobs",
            bindings: []
        )
        return rows.first?.requireInt("count") ?? 0
    }

    func insertResult(_ result: CategorizationResult) throws {
        let scoresJSON = try encodeJSONString(result.categoryScores)
        try connection.execute(
            """
            INSERT OR REPLACE INTO categorization_results
            (item_id, category_scores_json, top_category, processed_at)
            VALUES (?, ?, ?, ?)
            """,
            bindings: [
                .text(result.itemID),
                .text(scoresJSON),
                result.topCategory.map(DatabaseBinding.text) ?? .null,
                .double(result.processedAt.timeIntervalSince1970)
            ]
        )
    }

    func persistProcessedResult(_ result: CategorizationResult) throws {
        try connection.transaction {
            try insertResult(result)
            try deleteJob(itemID: result.itemID)
        }
    }

    func fetchResults(limit: Int, cutoff: Date) throws -> [CategorizationResult] {
        let rows = try connection.query(
            """
            SELECT item_id, category_scores_json, top_category, processed_at
            FROM categorization_results
            WHERE processed_at >= ?
            ORDER BY processed_at ASC
            LIMIT ?
            """,
            bindings: [
                .double(cutoff.timeIntervalSince1970),
                .integer(Int64(limit))
            ]
        )
        return try rows.map(decodeResultRow)
    }

    func fetchResult(itemID: String, cutoff: Date) throws -> CategorizationResult? {
        let rows = try connection.query(
            """
            SELECT item_id, category_scores_json, top_category, processed_at
            FROM categorization_results
            WHERE item_id = ? AND processed_at >= ?
            LIMIT 1
            """,
            bindings: [
                .text(itemID),
                .double(cutoff.timeIntervalSince1970)
            ]
        )
        return try rows.first.map(decodeResultRow)
    }

    func markConsumed(itemIDs: [String]) throws -> Int {
        guard !itemIDs.isEmpty else {
            return 0
        }
        let placeholders = Array(repeating: "?", count: itemIDs.count).joined(separator: ", ")
        let bindings = itemIDs.map(DatabaseBinding.text)
        return try connection.execute(
            "DELETE FROM categorization_results WHERE item_id IN (\(placeholders))",
            bindings: bindings
        )
    }

    func purgeExpiredResults(before cutoff: Date) throws -> Int {
        try connection.execute(
            "DELETE FROM categorization_results WHERE processed_at < ?",
            bindings: [.double(cutoff.timeIntervalSince1970)]
        )
    }

    private static func createTables(on connection: DatabaseConnecting) throws {
        try connection.execute(
            """
            CREATE TABLE IF NOT EXISTS categories (
                id TEXT PRIMARY KEY,
                label TEXT NOT NULL,
                descriptors_json TEXT NOT NULL,
                centroid_json TEXT NOT NULL
            )
            """,
            bindings: []
        )

        try connection.execute(
            """
            CREATE TABLE IF NOT EXISTS jobs (
                item_id TEXT PRIMARY KEY,
                text TEXT NOT NULL,
                priority INTEGER NOT NULL DEFAULT 1,
                enqueued_at REAL NOT NULL,
                retry_count INTEGER NOT NULL DEFAULT 0
            )
            """,
            bindings: []
        )

        try connection.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_jobs_priority_enqueued
            ON jobs(priority DESC, enqueued_at ASC)
            """,
            bindings: []
        )

        try connection.execute(
            """
            CREATE TABLE IF NOT EXISTS categorization_results (
                item_id TEXT PRIMARY KEY,
                category_scores_json TEXT NOT NULL,
                top_category TEXT,
                processed_at REAL NOT NULL
            )
            """,
            bindings: []
        )

        try connection.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_results_processed_at
            ON categorization_results(processed_at ASC)
            """,
            bindings: []
        )
    }

    private func decodeResultRow(_ row: [String: DatabaseValue]) throws -> CategorizationResult {
        CategorizationResult(
            itemID: row.requireString("item_id"),
            categoryScores: try decodeJSON([String: Double].self, from: row.requireString("category_scores_json")),
            topCategory: row["top_category"]?.stringValue,
            processedAt: Date(timeIntervalSince1970: row.requireDouble("processed_at"))
        )
    }

    private func encodeJSONString<T: Encodable>(_ value: T) throws -> String {
        let data = try encoder.encode(value)
        guard let string = String(data: data, encoding: .utf8) else {
            throw CategorizationError.resultDeserializationFailed
        }
        return string
    }

    private func decodeJSON<T: Decodable>(_ type: T.Type, from string: String) throws -> T {
        do {
            let data = Data(string.utf8)
            return try decoder.decode(T.self, from: data)
        } catch {
            throw CategorizationError.resultDeserializationFailed
        }
    }
}

private extension Dictionary where Key == String, Value == DatabaseValue {
    func requireString(_ key: String) -> String {
        self[key]?.stringValue ?? ""
    }

    func requireInt(_ key: String) -> Int {
        self[key]?.intValue ?? 0
    }

    func requireDouble(_ key: String) -> Double {
        self[key]?.doubleValue ?? 0
    }
}
