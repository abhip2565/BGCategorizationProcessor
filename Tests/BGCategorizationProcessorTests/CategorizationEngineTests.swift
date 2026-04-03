import XCTest
@testable import BGCategorizationProcessor

final class CategorizationEngineTests: XCTestCase {
    func testSingleChunkScoresMultipleCategories() async throws {
        let provider = MockEmbeddingProvider(vectors: [
            "Invoice paid today.": [1, 0, 0, 0]
        ])
        let engine = CategorizationEngine(
            embeddingProvider: provider,
            config: ClassificationConfig(minimumConfidence: 0.2, sentencesPerChunk: 5, maxTextLength: 1_000)
        )

        let result = try await engine.classify(
            text: "Invoice paid today.",
            itemID: "1",
            centroids: [
                "finance": [1, 0, 0, 0],
                "health": [0, 1, 0, 0]
            ]
        )

        XCTAssertEqual(result.topCategory, "finance")
        XCTAssertGreaterThan(result.categoryScores["finance"] ?? -1, result.categoryScores["health"] ?? 1)
    }

    func testMultiChunkAveragesScores() async throws {
        let provider = MockEmbeddingProvider(vectors: [
            "Tax forms filed. Invoice paid.": [1, 0, 0, 0],
            "Doctor visit completed. Prescription collected.": [0, 1, 0, 0]
        ])
        let engine = CategorizationEngine(
            embeddingProvider: provider,
            config: ClassificationConfig(minimumConfidence: 0.6, sentencesPerChunk: 2, maxTextLength: 1_000)
        )

        let result = try await engine.classify(
            text: "Tax forms filed. Invoice paid. Doctor visit completed. Prescription collected.",
            itemID: "item",
            centroids: [
                "finance": [1, 0, 0, 0],
                "health": [0, 1, 0, 0]
            ]
        )

        XCTAssertEqual(result.categoryScores["finance"] ?? -1, 0.5, accuracy: 0.0001)
        XCTAssertEqual(result.categoryScores["health"] ?? -1, 0.5, accuracy: 0.0001)
        XCTAssertNil(result.topCategory)
    }

    func testBelowMinimumConfidenceReturnsNilTopCategory() async throws {
        let provider = MockEmbeddingProvider(vectors: [
            "Weakly related text.": [0.1, 0.1, 0, 0]
        ])
        let engine = CategorizationEngine(
            embeddingProvider: provider,
            config: ClassificationConfig(minimumConfidence: 0.9, sentencesPerChunk: 5, maxTextLength: 1_000)
        )

        let result = try await engine.classify(
            text: "Weakly related text.",
            itemID: "2",
            centroids: ["finance": [1, 0, 0, 0]]
        )

        XCTAssertNil(result.topCategory)
    }

    func testEmptyCentroidsReturnsEmptyScores() async throws {
        let provider = MockEmbeddingProvider()
        let engine = CategorizationEngine(
            embeddingProvider: provider,
            config: ClassificationConfig()
        )

        let result = try await engine.classify(text: "Anything", itemID: "3", centroids: [:])
        XCTAssertTrue(result.categoryScores.isEmpty)
        XCTAssertNil(result.topCategory)
    }

    func testLongTextIsTruncatedBeforeEmbedding() async throws {
        let tracker = MockEmbeddingTracker()
        let provider = MockEmbeddingProvider(
            vectors: ["abcdefghij": [1, 0, 0, 0]],
            tracker: tracker
        )
        let engine = CategorizationEngine(
            embeddingProvider: provider,
            config: ClassificationConfig(minimumConfidence: 0.1, sentencesPerChunk: 5, maxTextLength: 10)
        )

        _ = try await engine.classify(
            text: "abcdefghijklmno",
            itemID: "4",
            centroids: ["finance": [1, 0, 0, 0]]
        )

        let inputs = await tracker.inputs
        XCTAssertEqual(inputs, ["abcdefghij"])
    }

    func testSingleSentenceUsesOriginalTextAsChunk() async throws {
        let tracker = MockEmbeddingTracker()
        let provider = MockEmbeddingProvider(
            vectors: ["Single sentence only": [1, 0, 0, 0]],
            tracker: tracker
        )
        let engine = CategorizationEngine(
            embeddingProvider: provider,
            config: ClassificationConfig(minimumConfidence: 0.1, sentencesPerChunk: 2, maxTextLength: 1_000)
        )

        _ = try await engine.classify(
            text: "Single sentence only",
            itemID: "5",
            centroids: ["finance": [1, 0, 0, 0]]
        )

        let inputs = await tracker.inputs
        XCTAssertEqual(inputs, ["Single sentence only"])
    }

    func testEmbeddingFailurePropagates() async {
        let provider = MockEmbeddingProvider(shouldThrow: true)
        let engine = CategorizationEngine(
            embeddingProvider: provider,
            config: ClassificationConfig()
        )

        await XCTAssertThrowsErrorAsync {
            _ = try await engine.classify(
                text: "Text",
                itemID: "6",
                centroids: ["finance": [1, 0, 0, 0]]
            )
        }
    }
}
