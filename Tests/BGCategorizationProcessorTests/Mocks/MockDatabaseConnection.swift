import Foundation
@testable import BGCategorizationProcessor

final class MockDatabaseConnection: DatabaseConnecting, @unchecked Sendable {
    var jobs: [String: CategorizationJob] = [:]
    var results: [String: CategorizationResult] = [:]
    var shouldFailDeleteJob = false

    @discardableResult
    func execute(_ sql: String, bindings: [DatabaseBinding]) throws -> Int {
        if sql.contains("CREATE TABLE") || sql.contains("CREATE INDEX") || sql.contains("PRAGMA") {
            return 0
        }

        if sql.contains("INSERT OR REPLACE INTO jobs") {
            let itemID = bindings[0].stringValue ?? ""
            let text = bindings[1].stringValue ?? ""
            let priority = JobPriority(rawValue: Int(bindings[2].int64Value ?? 1)) ?? .normal
            let enqueuedAt = Date(timeIntervalSince1970: bindings[3].doubleValue ?? 0)
            jobs[itemID] = CategorizationJob(
                itemID: itemID,
                text: text,
                priority: priority,
                enqueuedAt: enqueuedAt
            )
            return 1
        }

        if sql.contains("INSERT OR REPLACE INTO categorization_results") {
            let itemID = bindings[0].stringValue ?? ""
            let scoresData = Data((bindings[1].stringValue ?? "{}").utf8)
            let scores = try JSONDecoder().decode([String: Double].self, from: scoresData)
            let topCategory = bindings[2].stringValue
            let processedAt = Date(timeIntervalSince1970: bindings[3].doubleValue ?? 0)
            results[itemID] = CategorizationResult(
                itemID: itemID,
                categoryScores: scores,
                topCategory: topCategory,
                processedAt: processedAt
            )
            return 1
        }

        if sql.contains("DELETE FROM jobs WHERE item_id = ?") {
            if shouldFailDeleteJob {
                throw DatabaseError.executionFailed("Forced delete failure")
            }
            let itemID = bindings[0].stringValue ?? ""
            let existed = jobs.removeValue(forKey: itemID) != nil
            return existed ? 1 : 0
        }

        return 0
    }

    func query(_ sql: String, bindings: [DatabaseBinding]) throws -> [[String: DatabaseValue]] {
        if sql.contains("SELECT COUNT(*) AS count FROM jobs") {
            return [["count": .integer(Int64(jobs.count))]]
        }
        return []
    }

    func transaction(_ block: () throws -> Void) throws {
        let jobsSnapshot = jobs
        let resultsSnapshot = results
        do {
            try block()
        } catch {
            jobs = jobsSnapshot
            results = resultsSnapshot
            throw error
        }
    }
}

private extension DatabaseBinding {
    var stringValue: String? {
        if case .text(let value) = self {
            return value
        }
        return nil
    }

    var int64Value: Int64? {
        if case .integer(let value) = self {
            return value
        }
        return nil
    }

    var doubleValue: Double? {
        if case .double(let value) = self {
            return value
        }
        return nil
    }
}
