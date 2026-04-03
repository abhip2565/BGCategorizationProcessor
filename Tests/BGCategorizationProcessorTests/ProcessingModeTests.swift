import XCTest
@testable import BGCategorizationProcessor

final class ProcessingModeTests: XCTestCase {
    private var tempDirectory: URL!
    private var databasePath: String!

    override func setUp() {
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        databasePath = tempDirectory.appendingPathComponent("processing.sqlite3").path
    }

    override func tearDown() {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }

    func testForegroundModeProcessesConcurrentlyAndRespectsLimit() async throws {
        let tracker = MockEmbeddingTracker()
        let provider = MockEmbeddingProvider(
            vectors: makeVectors(),
            delayNanoseconds: 200_000_000,
            tracker: tracker
        )
        let processor = try makeProcessor(provider: provider, concurrency: 2)
        try await addDefaultCategories(to: processor)
        try await processor.enqueue(batch: [
            ("invoice tax", "1"),
            ("invoice tax", "2"),
            ("invoice tax", "3"),
            ("invoice tax", "4")
        ])

        try await processor.processAvailableJobs(mode: .foreground)

        let fgResults = try await processor.results(limit: 10)
        XCTAssertEqual(fgResults.count, 4)
        let maxConcurrentCalls = await tracker.maxConcurrentCalls
        XCTAssertLessThanOrEqual(maxConcurrentCalls, 2)
        XCTAssertGreaterThan(maxConcurrentCalls, 1)
    }

    func testBackgroundModeProcessesSequentiallyInOrder() async throws {
        let tracker = MockEmbeddingTracker()
        let provider = MockEmbeddingProvider(
            vectors: makeVectors(),
            delayNanoseconds: 100_000_000,
            tracker: tracker
        )
        let processor = try makeProcessor(provider: provider, concurrency: 4)
        try await addDefaultCategories(to: processor)
        try await processor.enqueue(batch: [
            ("invoice tax", "1"),
            ("invoice tax", "2"),
            ("invoice tax", "3")
        ])

        try await processor.processAvailableJobs(mode: .background)

        let bgResults = try await processor.results(limit: 10)
        XCTAssertEqual(bgResults.map(\.itemID), ["1", "2", "3"])
        let maxConcurrentCalls = await tracker.maxConcurrentCalls
        XCTAssertEqual(maxConcurrentCalls, 1)
    }

    func testFailedJobsAreSkippedAndRemainPendingInForeground() async throws {
        let provider = MockEmbeddingProvider(
            vectors: makeVectors(),
            errorTexts: ["will fail"]
        )
        let processor = try makeProcessor(provider: provider, concurrency: 2)
        try await addDefaultCategories(to: processor)
        try await processor.enqueue(batch: [
            ("invoice tax", "success"),
            ("will fail", "failure")
        ])

        try await processor.processAvailableJobs(mode: .foreground)

        let fgFailResults = try await processor.results(limit: 10)
        XCTAssertEqual(fgFailResults.count, 1)
        let fgFailPending = try await processor.pendingCount()
        XCTAssertEqual(fgFailPending, 1)
    }

    func testFailedJobsAreSkippedAndRemainPendingInBackground() async throws {
        let provider = MockEmbeddingProvider(
            vectors: makeVectors(),
            errorTexts: ["will fail"]
        )
        let processor = try makeProcessor(provider: provider, concurrency: 2)
        try await addDefaultCategories(to: processor)
        try await processor.enqueue(batch: [
            ("invoice tax", "success"),
            ("will fail", "failure")
        ])

        try await processor.processAvailableJobs(mode: .background)

        let bgFailResults = try await processor.results(limit: 10)
        XCTAssertEqual(bgFailResults.count, 1)
        let bgFailPending = try await processor.pendingCount()
        XCTAssertEqual(bgFailPending, 1)
    }

    func testBothModesEmitToResultStream() async throws {
        let provider = MockEmbeddingProvider(vectors: makeVectors())
        let processor = try makeProcessor(provider: provider, concurrency: 2)
        try await addDefaultCategories(to: processor)
        try await processor.enqueue(batch: [
            ("invoice tax", "1"),
            ("invoice tax", "2")
        ])

        let expectation = expectation(description: "stream emits results")
        expectation.expectedFulfillmentCount = 2
        let streamTask = Task {
            for await _ in processor.resultStream {
                expectation.fulfill()
            }
        }

        try await processor.processAvailableJobs(mode: .foreground)
        await fulfillment(of: [expectation], timeout: 2)
        streamTask.cancel()
    }

    private func makeProcessor(provider: MockEmbeddingProvider, concurrency: Int) throws -> BGCategorizationProcessor {
        try BGCategorizationProcessor(
            configuration: CategorizationConfiguration(
                databasePath: databasePath,
                foregroundConcurrency: concurrency
            ),
            embeddingProvider: provider
        )
    }

    private func addDefaultCategories(to processor: BGCategorizationProcessor) async throws {
        try await processor.resetCategories(to: [
            CategoryDefinition(id: "finance", label: "finance", descriptors: ["tax", "invoice"]),
            CategoryDefinition(id: "health", label: "health", descriptors: ["doctor", "hospital"])
        ])
    }

    private func makeVectors() -> [String: [Float]] {
        [
            "finance": [1, 0, 0, 0],
            "tax": [1, 0, 0, 0],
            "invoice": [1, 0, 0, 0],
            "health": [0, 1, 0, 0],
            "doctor": [0, 1, 0, 0],
            "hospital": [0, 1, 0, 0],
            "invoice tax": [1, 0, 0, 0]
        ]
    }
}
