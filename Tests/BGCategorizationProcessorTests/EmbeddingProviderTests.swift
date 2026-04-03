import Foundation
import XCTest
@testable import BGCategorizationProcessor
@testable import BGCategorizationProcessorCoreML

final class EmbeddingProviderTests: XCTestCase {
    func testMockEmbeddingProviderReturnsDeterministicVectors() async throws {
        let provider = MockEmbeddingProvider(vectors: ["hello": [1, 2, 3, 4]])
        let embedding = try await provider.embed("hello")
        XCTAssertEqual(embedding, [1, 2, 3, 4])
    }

    func testMockEmbeddingProviderThrowsWhenConfigured() async {
        let provider = MockEmbeddingProvider(shouldThrow: true)
        await XCTAssertThrowsErrorAsync {
            _ = try await provider.embed("hello")
        }
    }

    func testWordPieceTokenizerPadsAndTruncates() throws {
        let vocabURL = try makeVocabularyFile(tokens: [
            "[PAD]", "[UNK]", "[CLS]", "[SEP]", "hello", "world", "##s", "!"
        ])
        let tokenizer = try WordPieceTokenizer(vocabURL: vocabURL)

        let shortEncoding = tokenizer.encode("hello worlds!", maxLength: 8)
        XCTAssertEqual(shortEncoding.ids.count, 8)
        XCTAssertEqual(shortEncoding.attentionMask, [1, 1, 1, 1, 1, 1, 0, 0])

        let truncatedEncoding = tokenizer.encode("hello hello hello hello hello", maxLength: 4)
        XCTAssertEqual(truncatedEncoding.ids.count, 4)
        XCTAssertEqual(truncatedEncoding.ids.last, 3)
    }

    func testWordPieceTokenizerFallsBackToUnknownToken() throws {
        let vocabURL = try makeVocabularyFile(tokens: ["[PAD]", "[UNK]", "[CLS]", "[SEP]", "known"])
        let tokenizer = try WordPieceTokenizer(vocabURL: vocabURL)
        let encoding = tokenizer.encode("mystery", maxLength: 5)
        XCTAssertEqual(encoding.ids[1], 1)
    }

    func testBundledCoreMLProviderInitializerFindsResources() throws {
        let provider = try CoreMLEmbeddingProvider()
        XCTAssertEqual(provider.dimensions, 384)
    }

    private func makeVocabularyFile(tokens: [String]) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try tokens.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
