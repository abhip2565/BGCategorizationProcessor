import XCTest
@testable import BGCategorizationProcessor

final class TextChunkerTests: XCTestCase {
    func testShortTextReturnsSingleChunk() {
        let chunks = TextChunker.chunk("One sentence. Two sentence.", sentencesPerChunk: 5)
        XCTAssertEqual(chunks, ["One sentence. Two sentence."])
    }

    func testExactMultipleReturnsFullChunks() {
        let text = "One. Two. Three. Four."
        let chunks = TextChunker.chunk(text, sentencesPerChunk: 2)
        XCTAssertEqual(chunks, ["One. Two.", "Three. Four."])
    }

    func testNonExactMultipleReturnsSmallerLastChunk() {
        let text = "One. Two. Three."
        let chunks = TextChunker.chunk(text, sentencesPerChunk: 2)
        XCTAssertEqual(chunks, ["One. Two.", "Three."])
    }

    func testEmptyTextReturnsNoChunks() {
        XCTAssertEqual(TextChunker.chunk("", sentencesPerChunk: 2), [])
    }

    func testNoSentenceBoundariesReturnsSingleChunk() {
        let text = "this has no clear sentence boundary"
        XCTAssertEqual(TextChunker.chunk(text, sentencesPerChunk: 2), [text])
    }
}
