import XCTest
@testable import BGCategorizationProcessor

final class DatabaseTests: XCTestCase {
    private var tempDirectory: URL!
    private var databasePath: String!
    private var database: CategorizationDatabase!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        databasePath = tempDirectory.appendingPathComponent("database.sqlite3").path
        database = try CategorizationDatabase(path: databasePath)
    }

    override func tearDown() {
        database = nil
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }

    func testEnqueueSingleJobPersists() async throws {
        try await database.insertJob(CategorizationJob(itemID: "1", text: "hello", priority: .normal))
        let count = try await database.pendingCount()
        XCTAssertEqual(count, 1)
    }

    func testEnqueueBatchPersistsAll() async throws {
        try await database.insertJobs([
            CategorizationJob(itemID: "1", text: "a", priority: .normal),
            CategorizationJob(itemID: "2", text: "b", priority: .high)
        ])
        let count = try await database.pendingCount()
        XCTAssertEqual(count, 2)
    }

    func testDequeueReturnsPriorityThenAgeOrder() async throws {
        try await database.insertJobs([
            CategorizationJob(itemID: "older", text: "a", priority: .normal, enqueuedAt: Date(timeIntervalSince1970: 1)),
            CategorizationJob(itemID: "highest", text: "b", priority: .high, enqueuedAt: Date(timeIntervalSince1970: 3)),
            CategorizationJob(itemID: "newer", text: "c", priority: .normal, enqueuedAt: Date(timeIntervalSince1970: 2))
        ])

        let jobs = try await database.fetchJobs(limit: 3)
        XCTAssertEqual(jobs.map(\.itemID), ["highest", "older", "newer"])
    }

    func testDequeueWithLimitReturnsCorrectCount() async throws {
        try await database.insertJobs((0..<5).map {
            CategorizationJob(itemID: "\($0)", text: "text", priority: .normal)
        })
        let jobs = try await database.fetchJobs(limit: 2)
        XCTAssertEqual(jobs.count, 2)
    }

    func testRemoveJobDeletesIt() async throws {
        try await database.insertJob(CategorizationJob(itemID: "1", text: "hello", priority: .normal))
        try await database.deleteJob(itemID: "1")
        let count = try await database.pendingCount()
        XCTAssertEqual(count, 0)
    }

    func testPendingCountIsAccurate() async throws {
        try await database.insertJobs([
            CategorizationJob(itemID: "1", text: "a", priority: .normal),
            CategorizationJob(itemID: "2", text: "b", priority: .normal)
        ])
        let count = try await database.pendingCount()
        XCTAssertEqual(count, 2)
    }

    func testDuplicateItemIDReplacesExistingJob() async throws {
        try await database.insertJob(CategorizationJob(itemID: "1", text: "first", priority: .low))
        try await database.insertJob(CategorizationJob(itemID: "1", text: "second", priority: .high))
        let jobs = try await database.fetchJobs(limit: 10)
        XCTAssertEqual(jobs.count, 1)
        XCTAssertEqual(jobs.first?.text, "second")
        XCTAssertEqual(jobs.first?.priority, .high)
    }

    func testInsertResultPersistsCorrectly() async throws {
        let result = CategorizationResult(itemID: "1", categoryScores: ["finance": 0.9], topCategory: "finance", processedAt: Date(timeIntervalSince1970: 10))
        try await database.insertResult(result)
        let fetched = try await database.fetchResult(itemID: "1", cutoff: .distantPast)
        XCTAssertEqual(fetched, result)
    }

    func testFetchByItemIDReturnsCorrectResult() async throws {
        let result = CategorizationResult(itemID: "2", categoryScores: ["finance": 0.7], topCategory: nil, processedAt: Date(timeIntervalSince1970: 12))
        try await database.insertResult(result)
        let fetched = try await database.fetchResult(itemID: "2", cutoff: .distantPast)
        XCTAssertEqual(fetched?.itemID, "2")
    }

    func testFetchWithLimitReturnsOldestFirst() async throws {
        try await database.insertResult(CategorizationResult(itemID: "1", categoryScores: [:], topCategory: nil, processedAt: Date(timeIntervalSince1970: 1)))
        try await database.insertResult(CategorizationResult(itemID: "2", categoryScores: [:], topCategory: nil, processedAt: Date(timeIntervalSince1970: 2)))
        try await database.insertResult(CategorizationResult(itemID: "3", categoryScores: [:], topCategory: nil, processedAt: Date(timeIntervalSince1970: 3)))

        let results = try await database.fetchResults(limit: 2, cutoff: .distantPast)
        XCTAssertEqual(results.map(\.itemID), ["1", "2"])
    }

    func testMarkConsumedDeletesMatchingResults() async throws {
        try await database.insertResult(CategorizationResult(itemID: "1", categoryScores: [:], topCategory: nil))
        try await database.insertResult(CategorizationResult(itemID: "2", categoryScores: [:], topCategory: nil))
        let deleted = try await database.markConsumed(itemIDs: ["1"])
        let fetched = try await database.fetchResult(itemID: "1", cutoff: .distantPast)
        XCTAssertEqual(deleted, 1)
        XCTAssertNil(fetched)
    }

    func testMarkConsumedWithNonexistentIDsReturnsZero() async throws {
        let deleted = try await database.markConsumed(itemIDs: ["missing"])
        XCTAssertEqual(deleted, 0)
    }

    func testPurgeExpiredRemovesOldResults() async throws {
        try await database.insertResult(CategorizationResult(itemID: "1", categoryScores: [:], topCategory: nil, processedAt: Date(timeIntervalSince1970: 1)))
        let purged = try await database.purgeExpiredResults(before: Date(timeIntervalSince1970: 2))
        XCTAssertEqual(purged, 1)
    }

    func testNilTopCategoryRoundTrips() async throws {
        let result = CategorizationResult(itemID: "nil", categoryScores: ["finance": 0.1], topCategory: nil)
        try await database.insertResult(result)
        let fetched = try await database.fetchResult(itemID: "nil", cutoff: .distantPast)
        XCTAssertNil(fetched?.topCategory)
    }

    func testCorruptedScoresJSONThrowsDeserializationError() async throws {
        let connection = try DatabaseConnection(path: databasePath)
        try connection.execute(
            """
            INSERT OR REPLACE INTO categorization_results (item_id, category_scores_json, top_category, processed_at)
            VALUES (?, ?, ?, ?)
            """,
            bindings: [
                .text("broken"),
                .text("{bad json"),
                .null,
                .double(1)
            ]
        )

        do {
            _ = try await database.fetchResults(limit: 10, cutoff: .distantPast)
            XCTFail("Expected deserialization failure")
        } catch {
            guard case CategorizationError.resultDeserializationFailed = error else {
                return XCTFail("Unexpected error \(error)")
            }
        }
    }

    func testPersistProcessedResultIsAtomic() async throws {
        let mock = MockDatabaseConnection()
        mock.jobs["1"] = CategorizationJob(itemID: "1", text: "hello", priority: .normal)
        mock.shouldFailDeleteJob = true
        let database = try CategorizationDatabase(connection: mock)

        do {
            try await database.persistProcessedResult(
                CategorizationResult(itemID: "1", categoryScores: ["finance": 0.9], topCategory: "finance")
            )
            XCTFail("Expected transaction to fail")
        } catch {}
        XCTAssertEqual(mock.jobs.count, 1)
        XCTAssertEqual(mock.results.count, 0)
    }
}
