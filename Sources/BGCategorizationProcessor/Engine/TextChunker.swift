import Foundation
import NaturalLanguage

struct TextChunker {
    static func chunk(_ text: String, sentencesPerChunk: Int) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return []
        }

        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = trimmed

        var sentences: [String] = []
        tokenizer.enumerateTokens(in: trimmed.startIndex..<trimmed.endIndex) { range, _ in
            let sentence = trimmed[range].trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                sentences.append(sentence)
            }
            return true
        }

        if sentences.isEmpty {
            return [trimmed]
        }

        let chunkSize = max(1, sentencesPerChunk)
        if sentences.count <= chunkSize {
            return [sentences.joined(separator: " ")]
        }

        var chunks: [String] = []
        var index = 0
        while index < sentences.count {
            let upperBound = min(index + chunkSize, sentences.count)
            chunks.append(sentences[index..<upperBound].joined(separator: " "))
            index = upperBound
        }
        return chunks
    }
}
