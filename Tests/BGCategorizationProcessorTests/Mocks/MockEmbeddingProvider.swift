import Foundation
@testable import BGCategorizationProcessor

actor MockEmbeddingTracker {
    private(set) var currentConcurrentCalls = 0
    private(set) var maxConcurrentCalls = 0
    private(set) var inputs: [String] = []

    func begin(_ text: String) {
        currentConcurrentCalls += 1
        maxConcurrentCalls = max(maxConcurrentCalls, currentConcurrentCalls)
        inputs.append(text)
    }

    func end() {
        currentConcurrentCalls -= 1
    }
}

struct MockEmbeddingProvider: EmbeddingProvider {
    let dimensions: Int
    var vectors: [String: [Float]]
    var shouldThrow: Bool
    var errorTexts: Set<String>
    var delayNanoseconds: UInt64
    var tracker: MockEmbeddingTracker?

    init(
        dimensions: Int = 4,
        vectors: [String: [Float]] = [:],
        shouldThrow: Bool = false,
        errorTexts: Set<String> = [],
        delayNanoseconds: UInt64 = 0,
        tracker: MockEmbeddingTracker? = nil
    ) {
        self.dimensions = dimensions
        self.vectors = vectors
        self.shouldThrow = shouldThrow
        self.errorTexts = errorTexts
        self.delayNanoseconds = delayNanoseconds
        self.tracker = tracker
    }

    func embed(_ text: String) async throws -> [Float] {
        if let tracker {
            await tracker.begin(text)
        }

        do {
            if delayNanoseconds > 0 {
                try await Task.sleep(nanoseconds: delayNanoseconds)
            }
            if shouldThrow || errorTexts.contains(text) {
                throw CategorizationError.embeddingFailed(text: text)
            }
            let vector = vectors[text] ?? Array(repeating: 0.1, count: dimensions)
            if let tracker {
                await tracker.end()
            }
            return vector
        } catch {
            if let tracker {
                await tracker.end()
            }
            throw error
        }
    }
}
