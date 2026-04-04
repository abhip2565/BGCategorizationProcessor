import Foundation
import SwiftUI
import UIKit
import BGCategorizationProcessor
import BGCategorizationProcessorCoreML

@MainActor
final class SampleAppModel: ObservableObject {
    enum BootState: Equatable {
        case idle
        case booting
        case ready
        case failed(String)
    }

    @Published private(set) var bootState: BootState = .idle
    @Published var inputText: String = ""
    @Published private(set) var categories: [CategoryDefinition] = []
    @Published private(set) var rankedCategories: [RankedCategoryPresentation] = []
    @Published private(set) var latestResult: CategorizationResult?
    @Published private(set) var recentResults: [CategorizationResult] = []
    @Published private(set) var pendingCount: Int = 0
    @Published private(set) var statusMessage: String = "Create categories, then classify some text."
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var isClassifying = false
    @Published private(set) var isRefreshing = false
    @Published private(set) var isQueueingBackgroundSamples = false
    @Published private(set) var isRunningStressTest = false
    @Published private(set) var stressTestProgress: String = ""
    @Published private(set) var stressTestResults: [CategorizationResult] = []
    @Published private(set) var lifecycleStateDescription = "Launching"
    @Published private(set) var backgroundRefreshDescription = "Unknown"
    @Published private(set) var backgroundTaskReadinessDescription = "Checking configuration"
    @Published private(set) var lastProcessedSummary = "No classifications yet"

    private var processor: BGCategorizationProcessor?
    private var resultStreamTask: Task<Void, Never>?
    private var didBootstrap = false
    private let configuration: CategorizationConfiguration
    private let minimumConfidence: Double

    init() {
        let databasePath = (try? SampleAppConfiguration.databasePath()) ?? NSTemporaryDirectory().appending("sample.sqlite3")
        let configuration = CategorizationConfiguration(
            databasePath: databasePath,
            classification: SampleAppConfiguration.classification,
            foregroundBatchSize: 24,
            backgroundBatchSize: 5,
            foregroundConcurrency: 3,
            backgroundTaskIdentifier: SampleAppConfiguration.backgroundTaskIdentifier
        )
        self.configuration = configuration
        self.minimumConfidence = configuration.classification.minimumConfidence
        refreshEnvironmentStatus()
    }

    func bootIfNeeded() async {
        guard !didBootstrap else {
            await refreshSnapshot()
            return
        }

        didBootstrap = true
        bootState = .booting
        lastErrorMessage = nil
        refreshEnvironmentStatus()

        do {
            let provider = try CoreMLEmbeddingProvider()
            let processor = try BGCategorizationProcessor(
                configuration: configuration,
                embeddingProvider: provider
            )
            self.processor = processor
            startListeningForResults(from: processor)
            bootState = .ready
            statusMessage = "Processor ready. Categories persist at \(configuration.databasePath)."
            await refreshSnapshot()
        } catch {
            bootState = .failed(Self.describe(error))
            lastErrorMessage = Self.describe(error)
            statusMessage = "Failed to initialize the CoreML sample app."
        }
    }

    func retryBoot() async {
        resultStreamTask?.cancel()
        resultStreamTask = nil
        processor = nil
        didBootstrap = false
        latestResult = nil
        recentResults = []
        rankedCategories = []
        await bootIfNeeded()
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            lifecycleStateDescription = "Foreground active"
        case .inactive:
            lifecycleStateDescription = "Foreground inactive"
        case .background:
            lifecycleStateDescription = "App moved to background"
        @unknown default:
            lifecycleStateDescription = "Unknown lifecycle state"
        }

        refreshEnvironmentStatus()

        if phase == .active {
            Task {
                await refreshSnapshot()
            }
        }
    }

    func classifyCurrentText() async {
        let trimmedText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            statusMessage = "Enter some text before classifying."
            return
        }

        guard let processor else {
            statusMessage = "Processor is not ready yet."
            return
        }

        isClassifying = true
        lastErrorMessage = nil
        let itemID = "manual-\(UUID().uuidString)"

        do {
            try await processor.enqueue(text: trimmedText, itemID: itemID, priority: .high)
            try await processUntilIdle(mode: .foreground)

            if let result = try await processor.result(for: itemID) {
                latestResult = result
                rebuildRankedCategories(for: result)
                statusMessage = result.topCategory == nil
                    ? "No category crossed the confidence threshold. Ranked similarities are still available."
                    : "Classified \(itemID) as \(result.topCategory ?? "unknown")."
            } else {
                statusMessage = "The text was queued, but no result was returned yet."
            }

            await refreshSnapshot()
        } catch {
            lastErrorMessage = Self.describe(error)
            statusMessage = "Classification failed."
        }

        isClassifying = false
    }

    func saveCategory(_ draft: CategoryDraft, originalID: String?) async {
        guard let processor else {
            statusMessage = "Processor is not ready yet."
            return
        }

        let sanitizedID = draft.id.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedLabel = draft.label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitizedID.isEmpty, !sanitizedLabel.isEmpty else {
            statusMessage = "Category ID and label are both required."
            return
        }

        let category = CategoryDefinition(
            id: sanitizedID,
            label: sanitizedLabel,
            descriptors: draft.descriptors
        )

        do {
            if let originalID, originalID != sanitizedID {
                try await processor.deleteCategory(id: originalID)
            }
            try await processor.addCategory(category)
            statusMessage = "Saved category \(sanitizedLabel)."
            await refreshSnapshot()
        } catch {
            lastErrorMessage = Self.describe(error)
            statusMessage = "Unable to save category \(sanitizedLabel)."
        }
    }

    func deleteCategory(id: String) async {
        guard let processor else {
            statusMessage = "Processor is not ready yet."
            return
        }

        do {
            try await processor.deleteCategory(id: id)
            statusMessage = "Deleted category \(id)."
            await refreshSnapshot()
        } catch {
            lastErrorMessage = Self.describe(error)
            statusMessage = "Unable to delete category \(id)."
        }
    }

    func seedStarterCategories() async {
        guard let processor else {
            statusMessage = "Processor is not ready yet."
            return
        }

        do {
            try await processor.resetCategories(to: SampleAppConfiguration.starterCategories)
            statusMessage = "Loaded \(SampleAppConfiguration.starterCategories.count) starter categories."
            await refreshSnapshot()
        } catch {
            lastErrorMessage = Self.describe(error)
            statusMessage = "Unable to load starter categories."
        }
    }

    func enqueueBackgroundSamples() async {
        guard let processor else {
            statusMessage = "Processor is not ready yet."
            return
        }

        isQueueingBackgroundSamples = true

        do {
            try await processor.enqueue(
                batch: SampleAppConfiguration.backgroundSampleTexts.enumerated().map { index, text in
                    (text, "bg-\(Int(Date().timeIntervalSince1970))-\(index)")
                },
                priority: .normal
            )
            statusMessage = "Queued background samples. Move the app to the background on a device and watch the diagnostics panel."
            await refreshSnapshot()
        } catch {
            lastErrorMessage = Self.describe(error)
            statusMessage = "Unable to queue background samples."
        }

        isQueueingBackgroundSamples = false
    }

    func processPendingInForeground() async {
        guard processor != nil else {
            statusMessage = "Processor is not ready yet."
            return
        }

        isRefreshing = true
        do {
            try await processUntilIdle(mode: .foreground)
            statusMessage = "Processed pending jobs in foreground mode."
            await refreshSnapshot()
        } catch {
            lastErrorMessage = Self.describe(error)
            statusMessage = "Unable to process pending jobs."
        }
        isRefreshing = false
    }

    func consumeVisibleResults() async {
        guard let processor else {
            statusMessage = "Processor is not ready yet."
            return
        }

        let visibleIDs = recentResults.map(\.itemID)
        guard !visibleIDs.isEmpty else {
            statusMessage = "No recent results to consume."
            return
        }

        do {
            _ = try await processor.markConsumed(itemIDs: visibleIDs)
            statusMessage = "Marked \(visibleIDs.count) recent results as consumed."
            latestResult = nil
            rankedCategories = []
            await refreshSnapshot()
        } catch {
            lastErrorMessage = Self.describe(error)
            statusMessage = "Unable to consume recent results."
        }
    }

    func enqueueStressTestForBackground() async {
        guard let processor else {
            statusMessage = "Processor is not ready yet."
            return
        }

        isRunningStressTest = true
        stressTestResults = []
        stressTestProgress = "Enqueuing 500 large jobs..."
        lastErrorMessage = nil

        let texts = SampleAppConfiguration.stressTestTexts
        let prefix = "stress-\(Int(Date().timeIntervalSince1970))"

        do {
            let batch = texts.enumerated().map { index, text in
                (text, "\(prefix)-\(index)")
            }
            try await processor.enqueue(batch: batch, priority: .normal)
            stressTestProgress = "Queued 500 jobs. Minimize app, then trigger BG task from debugger."
            statusMessage = "500 jobs queued for background processing. Minimize now."
            await refreshSnapshot()
        } catch {
            lastErrorMessage = Self.describe(error)
            stressTestProgress = "Failed to enqueue"
            statusMessage = "Stress test enqueue failed."
        }

        isRunningStressTest = false
    }

    func runStressTest() async {
        guard let processor else {
            statusMessage = "Processor is not ready yet."
            return
        }

        isRunningStressTest = true
        stressTestResults = []
        stressTestProgress = "Enqueuing 500 jobs..."
        lastErrorMessage = nil

        let texts = SampleAppConfiguration.stressTestTexts
        let prefix = "stress-\(Int(Date().timeIntervalSince1970))"

        do {
            let batch = texts.enumerated().map { index, text in
                (text, "\(prefix)-\(index)")
            }
            try await processor.enqueue(batch: batch, priority: .normal)
            stressTestProgress = "Enqueued 500. Processing..."

            let startTime = CFAbsoluteTimeGetCurrent()
            while try await processor.pendingCount() > 0 {
                _ = try await processor.processAvailableJobs(mode: .foreground)
                let remaining = try await processor.pendingCount()
                let done = 500 - remaining
                stressTestProgress = "Processed \(done)/500..."
            }
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime

            var results: [CategorizationResult] = []
            for i in 0..<500 {
                if let result = try await processor.result(for: "\(prefix)-\(i)") {
                    results.append(result)
                }
            }
            stressTestResults = results.sorted { $0.processedAt < $1.processedAt }
            stressTestProgress = "Done: 500 jobs in \(String(format: "%.1f", elapsed))s"
            statusMessage = "Stress test complete. \(results.count) results collected."
            await refreshSnapshot()
        } catch {
            lastErrorMessage = Self.describe(error)
            stressTestProgress = "Failed"
            statusMessage = "Stress test failed."
        }

        isRunningStressTest = false
    }

    func loadSampleText(_ text: String) {
        inputText = text
        statusMessage = "Loaded sample text. Tap Classify when ready."
    }

    func refreshSnapshot() async {
        guard let processor else {
            refreshEnvironmentStatus()
            return
        }

        isRefreshing = true
        defer { isRefreshing = false }

        refreshEnvironmentStatus()

        do {
            categories = try await processor.currentCategories().sorted {
                $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending
            }
            pendingCount = try await processor.pendingCount()
            recentResults = try await processor.results(limit: 12).sorted {
                $0.processedAt > $1.processedAt
            }

            if let activeResult = latestResult,
               let refreshed = recentResults.first(where: { $0.itemID == activeResult.itemID }) {
                latestResult = refreshed
            } else if latestResult == nil {
                latestResult = recentResults.first
            }

            if let latestResult {
                rebuildRankedCategories(for: latestResult)
                lastProcessedSummary = "\(latestResult.itemID) at \(Self.dateFormatter.string(from: latestResult.processedAt))"
            } else {
                rankedCategories = []
                lastProcessedSummary = "No classifications yet"
            }
        } catch {
            lastErrorMessage = Self.describe(error)
            statusMessage = "Unable to refresh the sample app state."
        }
    }

    var shortStatusMessage: String {
        if statusMessage.contains(configuration.databasePath) {
            return statusMessage.replacingOccurrences(of: configuration.databasePath, with: ".../<db>.sqlite3")
        }
        return statusMessage
    }

    var confidenceThresholdText: String {
        String(format: "%.2f", minimumConfidence)
    }

    var manualValidationSteps: [String] {
        [
            "Seed or add a few categories, then queue sample jobs from the Diagnostics tab.",
            "Run the sample on a real device with Background App Refresh enabled.",
            "Send the app to the background and wait for iOS to launch the background processing task.",
            "Reopen the app and confirm pending work dropped while recent results and categories persisted."
        ]
    }

    private func processUntilIdle(mode: ProcessingMode) async throws {
        guard let processor else {
            return
        }

        while try await processor.pendingCount() > 0 {
            _ = try await processor.processAvailableJobs(mode: mode)
        }
    }

    private func rebuildRankedCategories(for result: CategorizationResult) {
        let labelsByID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.label) })
        let scores = result.categoryScores
        let maxScore = scores.values.max() ?? 1
        let minScore = scores.values.min() ?? 0
        let range = max(maxScore - minScore, 0.0001)

        rankedCategories = scores
            .map { key, score in
                let normalized = (score - minScore) / range
                return RankedCategoryPresentation(
                    id: key,
                    label: labelsByID[key] ?? key,
                    score: score,
                    isTopCategory: key == result.topCategory,
                    intensity: max(0.18, normalized)
                )
            }
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
                }
                return lhs.score > rhs.score
            }
    }

    private func startListeningForResults(from processor: BGCategorizationProcessor) {
        resultStreamTask?.cancel()
        resultStreamTask = Task { [weak self] in
            for await result in processor.resultStream {
                await self?.handleIncomingResult(result)
            }
        }
    }

    private func handleIncomingResult(_ result: CategorizationResult) async {
        latestResult = result
        rebuildRankedCategories(for: result)
        lastProcessedSummary = "\(result.itemID) at \(Self.dateFormatter.string(from: result.processedAt))"
        statusMessage = result.topCategory == nil
            ? "Processed \(result.itemID) without a confident winner."
            : "Processed \(result.itemID) as \(result.topCategory ?? "unknown")."
        await refreshSnapshot()
    }

    private func refreshEnvironmentStatus() {
        let refreshStatus = UIApplication.shared.backgroundRefreshStatus
        switch refreshStatus {
        case .available:
            backgroundRefreshDescription = "Background App Refresh available"
        case .denied:
            backgroundRefreshDescription = "Background App Refresh denied"
        case .restricted:
            backgroundRefreshDescription = "Background App Refresh restricted"
        @unknown default:
            backgroundRefreshDescription = "Background App Refresh unknown"
        }

        let permittedIdentifiers = Bundle.main.object(
            forInfoDictionaryKey: "BGTaskSchedulerPermittedIdentifiers"
        ) as? [String] ?? []
        let backgroundModes = Bundle.main.object(
            forInfoDictionaryKey: "UIBackgroundModes"
        ) as? [String] ?? []

        if !backgroundModes.contains("processing") {
            backgroundTaskReadinessDescription = "Missing UIBackgroundModes=processing"
        } else if !permittedIdentifiers.contains(SampleAppConfiguration.backgroundTaskIdentifier) {
            backgroundTaskReadinessDescription = "Missing BGTaskScheduler identifier"
        } else {
            switch refreshStatus {
            case .available:
                backgroundTaskReadinessDescription = "Configured and ready for device validation"
            case .denied:
                backgroundTaskReadinessDescription = "Configured, but Background App Refresh is denied"
            case .restricted:
                backgroundTaskReadinessDescription = "Configured, but background execution is restricted"
            @unknown default:
                backgroundTaskReadinessDescription = "Configured with unknown system status"
            }
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()

    private static func describe(_ error: Error) -> String {
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            return description
        }
        return String(describing: error)
    }
}
