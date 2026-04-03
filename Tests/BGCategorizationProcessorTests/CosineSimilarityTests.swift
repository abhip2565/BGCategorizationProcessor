import XCTest
@testable import BGCategorizationProcessor

final class CosineSimilarityTests: XCTestCase {
    func testIdenticalVectorsReturnOne() {
        XCTAssertEqual(cosineSimilarity([1, 2, 3], [1, 2, 3]), 1, accuracy: 0.0001)
    }

    func testOrthogonalVectorsReturnZero() {
        XCTAssertEqual(cosineSimilarity([1, 0], [0, 1]), 0, accuracy: 0.0001)
    }

    func testOppositeVectorsReturnNegativeOne() {
        XCTAssertEqual(cosineSimilarity([1, 0], [-1, 0]), -1, accuracy: 0.0001)
    }

    func testZeroMagnitudeVectorReturnsZero() {
        XCTAssertEqual(cosineSimilarity([0, 0], [1, 2]), 0, accuracy: 0.0001)
    }

    func testDifferentLengthVectorsReturnZero() {
        XCTAssertEqual(cosineSimilarity([1, 2], [1]), 0, accuracy: 0.0001)
    }
}
