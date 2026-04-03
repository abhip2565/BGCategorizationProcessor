import Accelerate
import Foundation

func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Double {
    guard a.count == b.count else {
        return 0
    }
    guard !a.isEmpty else {
        return 0
    }

    let dotProduct = vDSP.dot(a, b)
    let magnitudeA = sqrt(vDSP.dot(a, a))
    let magnitudeB = sqrt(vDSP.dot(b, b))

    guard magnitudeA > 0, magnitudeB > 0 else {
        return 0
    }

    return Double(dotProduct / (magnitudeA * magnitudeB))
}
