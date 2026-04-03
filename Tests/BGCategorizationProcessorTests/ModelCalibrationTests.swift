import Foundation
import XCTest
@testable import BGCategorizationProcessor
@testable import BGCategorizationProcessorCoreML

final class ModelCalibrationTests: XCTestCase {
    func testCalibrationFixtureReportsScoreDistributions() async throws {
        try skipIfSimulator()

        guard let fixturePath = ProcessInfo.processInfo.environment["BGCATEGORIZATION_CALIBRATION_FIXTURE"] else {
            throw XCTSkip("Set BGCATEGORIZATION_CALIBRATION_FIXTURE to a JSON fixture path to run calibration.")
        }

        let fixtureURL = URL(fileURLWithPath: fixturePath)
        let fixture = try loadFixture(from: fixtureURL)
        let provider = try CoreMLEmbeddingProvider()

        let positiveScores = try await scorePairs(fixture.positivePairs, provider: provider)
        let negativeScores = try await scorePairs(fixture.negativePairs, provider: provider)

        XCTAssertFalse(positiveScores.isEmpty)
        XCTAssertFalse(negativeScores.isEmpty)

        let thresholds = fixture.candidateThresholds.isEmpty
            ? [0.15, 0.20, 0.25, 0.30, 0.35, 0.40, 0.45]
            : fixture.candidateThresholds.sorted()

        let positiveSummary = summarize(positiveScores)
        let negativeSummary = summarize(negativeScores)
        let thresholdReport = thresholds.map { evaluate(threshold: $0, positiveScores: positiveScores, negativeScores: negativeScores) }

        print("Calibration fixture: \(fixtureURL.path)")
        print("Positive scores: \(format(summary: positiveSummary))")
        print("Negative scores: \(format(summary: negativeSummary))")
        for row in thresholdReport {
            print("threshold=\(row.threshold) precision=\(row.precision) recall=\(row.recall) falsePositiveRate=\(row.falsePositiveRate) balancedAccuracy=\(row.balancedAccuracy)")
        }

        if let best = thresholdReport.max(by: { $0.balancedAccuracy < $1.balancedAccuracy }) {
            print("recommended_threshold=\(best.threshold)")
        }

        XCTAssertGreaterThan(positiveSummary.mean, negativeSummary.mean)
    }

    private func loadFixture(from url: URL) throws -> CalibrationFixture {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(CalibrationFixture.self, from: data)
    }

    private func scorePairs(_ pairs: [CalibrationPair], provider: CoreMLEmbeddingProvider) async throws -> [Double] {
        var scores: [Double] = []
        scores.reserveCapacity(pairs.count)

        for pair in pairs {
            let left = try await provider.embed(pair.left)
            let right = try await provider.embed(pair.right)
            scores.append(cosineSimilarity(left, right))
        }

        return scores
    }

    private func summarize(_ scores: [Double]) -> ScoreSummary {
        let sorted = scores.sorted()
        let count = Double(sorted.count)
        let sum = sorted.reduce(0, +)
        let middle = sorted.count / 2
        let median = sorted.count.isMultiple(of: 2)
            ? (sorted[middle - 1] + sorted[middle]) / 2
            : sorted[middle]

        return ScoreSummary(
            min: sorted.first ?? 0,
            max: sorted.last ?? 0,
            mean: sum / count,
            median: median
        )
    }

    private func evaluate(threshold: Double, positiveScores: [Double], negativeScores: [Double]) -> ThresholdEvaluation {
        let truePositives = Double(positiveScores.filter { $0 >= threshold }.count)
        let falseNegatives = Double(positiveScores.count) - truePositives
        let falsePositives = Double(negativeScores.filter { $0 >= threshold }.count)
        let trueNegatives = Double(negativeScores.count) - falsePositives

        let precision = safeDivide(truePositives, truePositives + falsePositives)
        let recall = safeDivide(truePositives, truePositives + falseNegatives)
        let trueNegativeRate = safeDivide(trueNegatives, trueNegatives + falsePositives)
        let falsePositiveRate = safeDivide(falsePositives, falsePositives + trueNegatives)
        let balancedAccuracy = (recall + trueNegativeRate) / 2

        return ThresholdEvaluation(
            threshold: threshold,
            precision: precision,
            recall: recall,
            falsePositiveRate: falsePositiveRate,
            balancedAccuracy: balancedAccuracy
        )
    }

    private func safeDivide(_ numerator: Double, _ denominator: Double) -> Double {
        guard denominator > 0 else {
            return 0
        }
        return numerator / denominator
    }

    private func format(summary: ScoreSummary) -> String {
        "min=\(summary.min) mean=\(summary.mean) median=\(summary.median) max=\(summary.max)"
    }

    private func skipIfSimulator() throws {
        #if os(iOS) && targetEnvironment(simulator)
        throw XCTSkip("Calibration runs are device-only on iOS. The simulator backend collapses embeddings.")
        #endif
    }
}

private struct CalibrationFixture: Decodable {
    let positivePairs: [CalibrationPair]
    let negativePairs: [CalibrationPair]
    let candidateThresholds: [Double]
}

private struct CalibrationPair: Decodable {
    let left: String
    let right: String
}

private struct ScoreSummary {
    let min: Double
    let max: Double
    let mean: Double
    let median: Double
}

private struct ThresholdEvaluation {
    let threshold: Double
    let precision: Double
    let recall: Double
    let falsePositiveRate: Double
    let balancedAccuracy: Double
}
