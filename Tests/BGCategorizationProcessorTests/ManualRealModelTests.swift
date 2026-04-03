import XCTest
@testable import BGCategorizationProcessor
@testable import BGCategorizationProcessorCoreML

final class ManualRealModelTests: XCTestCase {
    func testManualEmbeddingSmoke() async throws {
        try skipIfSimulator()
        let provider = try CoreMLEmbeddingProvider()
        let embedding = try await provider.embed("invoice tax payment")

        XCTAssertEqual(embedding.count, 384)
        XCTAssertTrue(embedding.contains { $0 != 0 })
    }

    func testManualSemanticOrdering() async throws {
        try skipIfSimulator()
        let provider = try CoreMLEmbeddingProvider()

        let financeA = try await provider.embed("invoice salary expense tax")
        let financeB = try await provider.embed("billing payroll reimbursement finance")
        let sports = try await provider.embed("soccer team stadium coach")
        XCTAssertGreaterThan(
            cosineSimilarity(financeA, financeB),
            cosineSimilarity(financeA, sports)
        )
    }

    func testManualSemanticDiagnostics() async throws {
        try skipIfSimulator()
        let provider = try CoreMLEmbeddingProvider()

        let anchor = try await provider.embed("invoice tax payment salary expense")
        let comparisons = [
            "billing payroll reimbursement finance",
            "doctor hospital appointment clinic",
            "soccer team stadium coach",
            "mountain hiking trail weather"
        ]

        var scores: [(String, Double)] = []
        for comparison in comparisons {
            let embedding = try await provider.embed(comparison)
            scores.append((comparison, cosineSimilarity(anchor, embedding)))
        }

        for (text, score) in scores {
            print("\(score) :: \(text)")
        }

        let ordered = scores.map(\.1)
        XCTAssertGreaterThan(ordered.max() ?? 0, ordered.min() ?? 0)
    }

    func testManualProcessorFlowWithRealModel() async throws {
        try skipIfSimulator()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let databasePath = directory.appendingPathComponent("manual.sqlite3").path
        let processor = try BGCategorizationProcessor(
            configuration: CategorizationConfiguration(databasePath: databasePath),
            embeddingProvider: CoreMLEmbeddingProvider()
        )

        try await processor.resetCategories(to: [
            CategoryDefinition(id: "finance", label: "finance", descriptors: ["invoice", "salary", "tax", "expense"]),
            CategoryDefinition(id: "health", label: "health", descriptors: ["doctor", "hospital", "prescription", "clinic"])
        ])

        try await processor.enqueue(text: "invoice salary tax reimbursement", itemID: "manual-item")
        try await processor.processAvailableJobs(mode: .background)

        let fetched = try await processor.result(for: "manual-item")
        let result = try XCTUnwrap(fetched)
        XCTAssertFalse(result.categoryScores.isEmpty)
    }

    private func skipIfSimulator() throws {
        #if os(iOS) && targetEnvironment(simulator)
        throw XCTSkip("Real MiniLM diagnostics are device-only on iOS. The simulator backend collapses embeddings.")
        #endif
    }
}
