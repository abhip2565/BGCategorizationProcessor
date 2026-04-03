import XCTest
@testable import BGCategorizationProcessor

final class BGCategorizationProcessorIntegrationTests: XCTestCase {
    private var tempDirectory: URL!
    private var databasePath: String!

    override func setUp() {
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        databasePath = tempDirectory.appendingPathComponent("integration.sqlite3").path
    }

    override func tearDown() {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }

    func testFullFlowFromCategoryToConsumption() async throws {
        let processor = try makeProcessor(provider: MockEmbeddingProvider(vectors: vectors))
        try await processor.addCategory(CategoryDefinition(id: "finance", label: "finance", descriptors: ["tax", "invoice"]))
        try await processor.enqueue(text: "invoice tax", itemID: "item-1")

        try await processor.processAvailableJobs(mode: .background)

        let fetched = try await processor.result(for: "item-1")
        let result = try XCTUnwrap(fetched)
        XCTAssertEqual(result.topCategory, "finance")
        let consumed = try await processor.markConsumed(itemIDs: ["item-1"])
        XCTAssertEqual(consumed, 1)
        let afterConsume = try await processor.result(for: "item-1")
        XCTAssertNil(afterConsume)
    }

    func testNoCategoriesProducesEmptyScoreResults() async throws {
        let processor = try makeProcessor(provider: MockEmbeddingProvider(vectors: vectors))
        try await processor.enqueue(text: "invoice tax", itemID: "item-1")
        try await processor.processAvailableJobs(mode: .background)

        let fetched = try await processor.result(for: "item-1")
        let result = try XCTUnwrap(fetched)
        XCTAssertTrue(result.categoryScores.isEmpty)
        XCTAssertNil(result.topCategory)
    }

    func testDeletingCategoryAffectsLaterProcessing() async throws {
        let processor = try makeProcessor(provider: MockEmbeddingProvider(vectors: vectors))
        try await processor.resetCategories(to: [
            CategoryDefinition(id: "finance", label: "finance", descriptors: ["tax", "invoice"]),
            CategoryDefinition(id: "health", label: "health", descriptors: ["doctor", "hospital"])
        ])

        try await processor.enqueue(text: "doctor hospital", itemID: "item-1")
        try await processor.deleteCategory(id: "health")
        try await processor.processAvailableJobs(mode: .background)

        let fetched2 = try await processor.result(for: "item-1")
        let result = try XCTUnwrap(fetched2)
        XCTAssertEqual(Set(result.categoryScores.keys), Set(["finance"]))
    }

    func testBatchEnqueueProcessesAllResults() async throws {
        let processor = try makeProcessor(provider: MockEmbeddingProvider(vectors: vectors))
        try await processor.addCategory(CategoryDefinition(id: "finance", label: "finance", descriptors: ["tax", "invoice"]))
        try await processor.enqueue(batch: [
            ("invoice tax", "1"),
            ("invoice tax", "2"),
            ("invoice tax", "3")
        ])

        try await processor.processAvailableJobs(mode: .background)
        let batchResults = try await processor.results(limit: 10)
        XCTAssertEqual(batchResults.count, 3)
    }

    func testResultStreamEmitsDuringProcessing() async throws {
        let provider = MockEmbeddingProvider(vectors: vectors, delayNanoseconds: 100_000_000)
        let processor = try makeProcessor(provider: provider)
        try await processor.addCategory(CategoryDefinition(id: "finance", label: "finance", descriptors: ["tax", "invoice"]))
        try await processor.enqueue(batch: [
            ("invoice tax", "1"),
            ("invoice tax", "2")
        ])

        let expectation = expectation(description: "stream emits")
        expectation.expectedFulfillmentCount = 2
        let task = Task {
            for await _ in processor.resultStream {
                expectation.fulfill()
            }
        }

        try await processor.processAvailableJobs(mode: .foreground)
        await fulfillment(of: [expectation], timeout: 2)
        task.cancel()
    }

    func testMarkConsumedRemovesResults() async throws {
        let processor = try makeProcessor(provider: MockEmbeddingProvider(vectors: vectors))
        try await processor.addCategory(CategoryDefinition(id: "finance", label: "finance", descriptors: ["tax", "invoice"]))
        try await processor.enqueue(text: "invoice tax", itemID: "consume")
        try await processor.processAvailableJobs(mode: .background)

        let consumed = try await processor.markConsumed(itemIDs: ["consume", "missing"])
        XCTAssertEqual(consumed, 1)
        let remaining = try await processor.results(limit: 10)
        XCTAssertTrue(remaining.isEmpty)
    }

    func testExpiredResultsAreInvisibleToFetch() async throws {
        let processor = try BGCategorizationProcessor(
            configuration: CategorizationConfiguration(
                databasePath: databasePath,
                resultTTL: 0.01
            ),
            embeddingProvider: MockEmbeddingProvider(vectors: vectors)
        )
        try await processor.addCategory(CategoryDefinition(id: "finance", label: "finance", descriptors: ["tax", "invoice"]))
        try await processor.enqueue(text: "invoice tax", itemID: "expire")
        try await processor.processAvailableJobs(mode: .background)
        try await Task.sleep(nanoseconds: 20_000_000)

        let expiredResults = try await processor.results(limit: 10)
        XCTAssertTrue(expiredResults.isEmpty)
    }

    func testProviderFailuresSkipOnlyFailingJobs() async throws {
        let processor = try makeProcessor(provider: MockEmbeddingProvider(vectors: vectors, errorTexts: ["will fail"]))
        try await processor.addCategory(CategoryDefinition(id: "finance", label: "finance", descriptors: ["tax", "invoice"]))
        try await processor.enqueue(batch: [
            ("invoice tax", "ok"),
            ("will fail", "bad")
        ])

        try await processor.processAvailableJobs(mode: .background)
        let okResult = try await processor.result(for: "ok")
        XCTAssertNotNil(okResult)
        let badResult = try await processor.result(for: "bad")
        XCTAssertNil(badResult)
        let pending = try await processor.pendingCount()
        XCTAssertEqual(pending, 1)
    }

    func testForegroundProcessingIsFasterThanBackground() async throws {
        let delayedProvider = MockEmbeddingProvider(vectors: vectors, delayNanoseconds: 200_000_000)
        let foregroundProcessor = try BGCategorizationProcessor(
            configuration: CategorizationConfiguration(
                databasePath: tempDirectory.appendingPathComponent("foreground.sqlite3").path,
                foregroundConcurrency: 3
            ),
            embeddingProvider: delayedProvider
        )
        let backgroundProcessor = try BGCategorizationProcessor(
            configuration: CategorizationConfiguration(
                databasePath: tempDirectory.appendingPathComponent("background.sqlite3").path,
                foregroundConcurrency: 3
            ),
            embeddingProvider: delayedProvider
        )

        try await foregroundProcessor.addCategory(CategoryDefinition(id: "finance", label: "finance", descriptors: ["tax", "invoice"]))
        try await backgroundProcessor.addCategory(CategoryDefinition(id: "finance", label: "finance", descriptors: ["tax", "invoice"]))
        let jobs = (0..<6).map { ("invoice tax", "\($0)") }
        try await foregroundProcessor.enqueue(batch: jobs)
        try await backgroundProcessor.enqueue(batch: jobs)

        let foregroundStart = Date()
        try await foregroundProcessor.processAvailableJobs(mode: .foreground)
        let foregroundDuration = Date().timeIntervalSince(foregroundStart)

        let backgroundStart = Date()
        try await backgroundProcessor.processAvailableJobs(mode: .background)
        let backgroundDuration = Date().timeIntervalSince(backgroundStart)

        XCTAssertLessThan(foregroundDuration, backgroundDuration)
    }

    func testConfiguredBackgroundTaskIdentifierTriggersAutomaticForegroundProcessing() async throws {
        let processor = try BGCategorizationProcessor(
            configuration: CategorizationConfiguration(
                databasePath: databasePath,
                foregroundConcurrency: 2,
                backgroundTaskIdentifier: "com.example.bgcategorization.processing"
            ),
            embeddingProvider: MockEmbeddingProvider(
                vectors: vectors,
                delayNanoseconds: 50_000_000
            )
        )
        try await processor.addCategory(CategoryDefinition(id: "finance", label: "finance", descriptors: ["tax", "invoice"]))
        try await processor.enqueue(text: "invoice tax", itemID: "auto-foreground")

        let result = try await waitForResult(itemID: "auto-foreground", processor: processor)
        XCTAssertEqual(result.topCategory, "finance")
        let pendingAfter = try await processor.pendingCount()
        XCTAssertEqual(pendingAfter, 0)
    }

    func testConfiguredBackgroundTaskIdentifierDoesNotAutoProcessWhileBackgrounded() async throws {
        let processor = try BGCategorizationProcessor(
            configuration: CategorizationConfiguration(
                databasePath: databasePath,
                foregroundConcurrency: 2,
                backgroundTaskIdentifier: "com.example.bgcategorization.processing"
            ),
            embeddingProvider: MockEmbeddingProvider(
                vectors: vectors,
                delayNanoseconds: 50_000_000
            )
        )
        try await processor.addCategory(CategoryDefinition(id: "finance", label: "finance", descriptors: ["tax", "invoice"]))
        await processor.appStateObserver.overrideState(.background)
        try await processor.enqueue(text: "invoice tax", itemID: "background-hold")

        try await Task.sleep(nanoseconds: 150_000_000)
        let bgPending = try await processor.pendingCount()
        XCTAssertEqual(bgPending, 1)
        let bgResult = try await processor.result(for: "background-hold")
        XCTAssertNil(bgResult)

        await processor.appStateObserver.overrideState(.foreground)
        let result = try await waitForResult(itemID: "background-hold", processor: processor)
        XCTAssertEqual(result.topCategory, "finance")
    }

    private func makeProcessor(provider: MockEmbeddingProvider) throws -> BGCategorizationProcessor {
        try BGCategorizationProcessor(
            configuration: CategorizationConfiguration(
                databasePath: databasePath,
                foregroundConcurrency: 3
            ),
            embeddingProvider: provider
        )
    }

    private var vectors: [String: [Float]] {
        [
            "finance": [1, 0, 0, 0],
            "tax": [1, 0, 0, 0],
            "invoice": [1, 0, 0, 0],
            "health": [0, 1, 0, 0],
            "doctor": [0, 1, 0, 0],
            "hospital": [0, 1, 0, 0],
            "invoice tax": [1, 0, 0, 0],
            "doctor hospital": [0, 1, 0, 0]
        ]
    }

    private func waitForResult(
        itemID: String,
        processor: BGCategorizationProcessor,
        timeoutNanoseconds: UInt64 = 2_000_000_000
    ) async throws -> CategorizationResult {
        let deadline = ContinuousClock.now + .nanoseconds(Int64(timeoutNanoseconds))

        while ContinuousClock.now < deadline {
            if let result = try await processor.result(for: itemID) {
                return result
            }
            try await Task.sleep(nanoseconds: 25_000_000)
        }

        XCTFail("Timed out waiting for result \(itemID)")
        throw CancellationError()
    }
}
