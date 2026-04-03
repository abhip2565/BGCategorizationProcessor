import Foundation
import BGCategorizationProcessor

enum SampleAppConfiguration {
    static let packageURL = "https://github.com/abhip2565/BGCategorizationProcessor.git"
    static let backgroundTaskIdentifier = "com.abhip2565.BGCategorizationProcessor.sample.processing"
    static let classification = ClassificationConfig(
        minimumConfidence: 0.35,
        sentencesPerChunk: 5,
        maxTextLength: 10_000
    )

    static let starterCategories: [CategoryDefinition] = [
        CategoryDefinition(
            id: "finance",
            label: "Finance",
            descriptors: ["invoice", "expense report", "tax filing", "budget review"]
        ),
        CategoryDefinition(
            id: "support",
            label: "Support",
            descriptors: ["bug report", "customer issue", "outage update", "ticket escalation"]
        ),
        CategoryDefinition(
            id: "travel",
            label: "Travel",
            descriptors: ["flight booking", "hotel reservation", "itinerary change", "trip approval"]
        ),
        CategoryDefinition(
            id: "legal",
            label: "Legal",
            descriptors: ["contract review", "compliance notice", "policy update", "nda request"]
        )
    ]

    static let sampleTexts: [String] = [
        "Customer reported a login failure after the outage window and needs a status update.",
        "Please review the new hotel reservation and flight change for next week's client trip.",
        "We need approval on the invoice and updated budget numbers before tax close.",
        "Legal requested a quick contract review before procurement signs the NDA."
    ]

    static let backgroundSampleTexts: [String] = [
        "Tax reconciliation is blocked until the invoice batch is approved.",
        "User account recovery ticket still needs escalation and status messaging.",
        "Travel desk needs a new itinerary after the flight cancellation."
    ]

    static func databasePath() throws -> String {
        let root = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!.appendingPathComponent("BGCategorizationProcessorSample", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root.appendingPathComponent("sample.sqlite3").path
    }
}
