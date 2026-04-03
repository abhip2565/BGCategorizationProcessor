import XCTest
@testable import BGCategorizationProcessor
@testable import BGCategorizationProcessorCoreML

final class CoreMLEmbeddingProviderRuntimeTests: XCTestCase {
    func testBundledModelEmbedsToExpectedDimension() async throws {
        try skipIfSimulator()
        let provider = try CoreMLEmbeddingProvider()
        let embedding = try await provider.embed("invoice tax payment")

        XCTAssertEqual(embedding.count, 384)
        XCTAssertTrue(embedding.contains { $0 != 0 })
    }

    func testSimilarTextsScoreHigherThanUnrelatedTexts() async throws {
        try skipIfSimulator()
        let provider = try CoreMLEmbeddingProvider()

        let invoice = try await provider.embed("invoice tax payment salary expense")
        let finance = try await provider.embed("billing payroll expense reimbursement")
        let unrelated = try await provider.embed("football mountain weather hiking trail")

        let similarScore = cosineSimilarity(invoice, finance)
        let unrelatedScore = cosineSimilarity(invoice, unrelated)

        XCTAssertGreaterThan(similarScore, unrelatedScore)
    }

    func testRepeatedEmbeddingsStayNumericallyStable() async throws {
        try skipIfSimulator()
        let provider = try CoreMLEmbeddingProvider()

        let first = try await provider.embed("doctor hospital appointment prescription")
        let second = try await provider.embed("doctor hospital appointment prescription")

        XCTAssertEqual(first.count, second.count)

        for index in first.indices {
            XCTAssertEqual(first[index], second[index], accuracy: 0.0001)
        }
    }

    private func skipIfSimulator() throws {
        #if os(iOS) && targetEnvironment(simulator)
        throw XCTSkip("CoreML MiniLM runtime validation is device-only on iOS. The simulator backend collapses embeddings.")
        #endif
    }
}
