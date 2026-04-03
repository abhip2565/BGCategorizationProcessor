import Foundation

struct RankedCategoryPresentation: Identifiable, Equatable {
    let id: String
    let label: String
    let score: Double
    let isTopCategory: Bool
    let intensity: Double

    var scoreText: String {
        String(format: "%.3f", score)
    }

    var similarityPercentText: String {
        String(format: "%.0f%%", max(0, min(1, score)) * 100)
    }
}
