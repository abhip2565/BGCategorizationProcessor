import Foundation
import BGCategorizationProcessor

struct CategoryDraft: Equatable {
    var id: String = ""
    var label: String = ""
    var descriptorsText: String = ""

    init() {}

    init(category: CategoryDefinition) {
        id = category.id
        label = category.label
        descriptorsText = category.descriptors.joined(separator: "\n")
    }

    var descriptors: [String] {
        descriptorsText
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
