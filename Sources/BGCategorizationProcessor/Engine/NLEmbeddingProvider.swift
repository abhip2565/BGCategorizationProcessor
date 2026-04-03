import Foundation
import NaturalLanguage

public struct NLEmbeddingProvider: EmbeddingProvider {
    public let dimensions: Int = 512

    public init() {}

    public func embed(_ text: String) async throws -> [Float] {
        let detectedLanguage = NLLanguageRecognizer.dominantLanguage(for: text)
        let candidates = [detectedLanguage, .english].compactMap { $0 }
        var didFindEmbedding = false

        for language in candidates {
            guard let embedding = NLEmbedding.sentenceEmbedding(for: language) else {
                continue
            }
            didFindEmbedding = true
            if let vector = embedding.vector(for: text) {
                return vector.map(Float.init)
            }
        }

        if didFindEmbedding {
            throw CategorizationError.embeddingFailed(text: String(text.prefix(50)))
        }

        throw CategorizationError.embeddingUnavailable
    }
}
