import Foundation

actor ProcessingGate {
    private var active = false

    func begin() -> Bool {
        guard !active else {
            return false
        }
        active = true
        return true
    }

    func end() {
        active = false
    }
}

actor AutomaticProcessingDriver {
    private var task: Task<Void, Never>?

    func startIfNeeded(operation: @escaping @Sendable () async -> Void) {
        guard task == nil else {
            return
        }

        task = Task {
            await operation()
            self.finish()
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }

    private func finish() {
        task = nil
    }
}

public final class BGCategorizationProcessor: Sendable {
    private static let maxRetryCount = 3

    private let configuration: CategorizationConfiguration
    private let embeddingProvider: EmbeddingProvider
    private let database: CategorizationDatabase
    private let engine: CategorizationEngine
    private let queue: JobQueue
    let appStateObserver: AppStateObserver
    private let bgTaskCoordinator: BGTaskCoordinator?
    private let processingGate = ProcessingGate()
    private let automaticProcessingDriver = AutomaticProcessingDriver()
    private let resultContinuation: AsyncStream<CategorizationResult>.Continuation
    public let resultStream: AsyncStream<CategorizationResult>

    public init(configuration: CategorizationConfiguration, embeddingProvider: EmbeddingProvider) throws {
        self.configuration = configuration
        self.embeddingProvider = embeddingProvider
        self.database = try CategorizationDatabase(path: configuration.databasePath)
        self.engine = CategorizationEngine(
            embeddingProvider: embeddingProvider,
            config: configuration.classification
        )
        self.queue = JobQueue(database: database)
        self.appStateObserver = AppStateObserver()
        self.bgTaskCoordinator = configuration.backgroundTaskIdentifier.map(BGTaskCoordinator.init(taskIdentifier:))
        let pair = AsyncStream<CategorizationResult>.makeStream()
        self.resultStream = pair.stream
        self.resultContinuation = pair.continuation

        if let bgTaskCoordinator {
            bgTaskCoordinator.register(processor: self)
            Task { await self.appStateObserver.startObserving() }
            Task { await self.observeAppStateChanges() }
            Task { await self.restoreAutomaticWorkIfNeeded() }
        }
    }

    public func shutdown() async {
        await automaticProcessingDriver.cancel()
        await appStateObserver.stopObserving()
        resultContinuation.finish()
    }

    public func addCategory(_ category: CategoryDefinition) async throws {
        let centroid = try await makeCentroid(for: category)
        do {
            try await database.upsertCategory(category, centroid: centroid)
        } catch {
            throw CategorizationError.databaseError(underlying: error)
        }
    }

    public func deleteCategory(id: String) async throws {
        do {
            try await database.deleteCategory(id: id)
        } catch let error as CategorizationError {
            throw error
        } catch {
            throw CategorizationError.databaseError(underlying: error)
        }
    }

    public func resetCategories(to categories: [CategoryDefinition]) async throws {
        var stored: [StoredCategory] = []
        for category in categories {
            let centroid = try await makeCentroid(for: category)
            stored.append(StoredCategory(definition: category, centroid: centroid))
        }

        do {
            try await database.resetCategories(stored)
        } catch {
            throw CategorizationError.databaseError(underlying: error)
        }
    }

    public func currentCategories() async throws -> [CategoryDefinition] {
        do {
            return try await database.fetchCategories()
        } catch let error as CategorizationError {
            throw error
        } catch {
            throw CategorizationError.databaseError(underlying: error)
        }
    }

    public func enqueue(text: String, itemID: String, priority: JobPriority = .normal) async throws {
        let job = CategorizationJob(itemID: itemID, text: text, priority: priority)
        try await queue.enqueue(job)
        await scheduleBackgroundProcessingIfNeeded()
        await triggerAutomaticProcessingIfForeground()
    }

    public func enqueue(batch: [(text: String, itemID: String)], priority: JobPriority = .normal) async throws {
        let jobs = batch.map { entry in
            CategorizationJob(itemID: entry.itemID, text: entry.text, priority: priority)
        }
        try await queue.enqueueBatch(jobs)
        await scheduleBackgroundProcessingIfNeeded()
        await triggerAutomaticProcessingIfForeground()
    }

    public func pendingCount() async throws -> Int {
        do {
            return try await database.pendingCount()
        } catch let error as CategorizationError {
            throw error
        } catch {
            throw CategorizationError.databaseError(underlying: error)
        }
    }

    public func results(limit: Int = 50) async throws -> [CategorizationResult] {
        let cutoff = resultCutoffDate()
        do {
            return try await database.fetchResults(limit: limit, cutoff: cutoff)
        } catch let error as CategorizationError {
            throw error
        } catch {
            throw CategorizationError.databaseError(underlying: error)
        }
    }

    public func result(for itemID: String) async throws -> CategorizationResult? {
        let cutoff = resultCutoffDate()
        do {
            return try await database.fetchResult(itemID: itemID, cutoff: cutoff)
        } catch let error as CategorizationError {
            throw error
        } catch {
            throw CategorizationError.databaseError(underlying: error)
        }
    }

    public func markConsumed(itemIDs: [String]) async throws -> Int {
        do {
            return try await database.markConsumed(itemIDs: itemIDs)
        } catch let error as CategorizationError {
            throw error
        } catch {
            throw CategorizationError.databaseError(underlying: error)
        }
    }

    @discardableResult
    public func processAvailableJobs(mode: ProcessingMode = .background) async throws -> Bool {
        guard await processingGate.begin() else {
            return false
        }

        do {
            _ = try await database.purgeExpiredResults(before: resultCutoffDate())
            let centroids = try await database.loadCentroids()
            let batchSize = mode == .foreground
                ? configuration.foregroundBatchSize
                : configuration.backgroundBatchSize
            let jobs = try await queue.dequeue(limit: batchSize)

            guard !jobs.isEmpty else {
                await processingGate.end()
                return true
            }

            if centroids.isEmpty {
                try await processJobsWithoutCategories(jobs)
                await processingGate.end()
                return true
            }

            switch mode {
            case .foreground:
                try await processParallel(jobs: jobs, centroids: centroids)
            case .background:
                try await processSequential(jobs: jobs, centroids: centroids)
            }
            await processingGate.end()
        } catch let error as CategorizationError {
            await processingGate.end()
            throw error
        } catch {
            await processingGate.end()
            throw CategorizationError.databaseError(underlying: error)
        }
        return true
    }

    private func processJobsWithoutCategories(_ jobs: [CategorizationJob]) async throws {
        for job in jobs {
            let result = CategorizationResult(
                itemID: job.itemID,
                categoryScores: [:],
                topCategory: nil
            )
            try await persistAndEmit(result)
        }
    }

    private enum JobOutcome: Sendable {
        case success(CategorizationResult)
        case failure(CategorizationJob)
        case cancelled
    }

    private func processParallel(
        jobs: [CategorizationJob],
        centroids: [String: [Float]]
    ) async throws {
        try await withThrowingTaskGroup(of: JobOutcome.self) { group in
            var inflight = 0
            var nextIndex = 0

            while nextIndex < jobs.count || inflight > 0 {
                while inflight < configuration.foregroundConcurrency, nextIndex < jobs.count {
                    let job = jobs[nextIndex]
                    nextIndex += 1
                    inflight += 1
                    group.addTask {
                        guard !Task.isCancelled else {
                            return .cancelled
                        }
                        do {
                            let result = try await self.engine.classify(
                                text: job.text,
                                itemID: job.itemID,
                                centroids: centroids
                            )
                            return .success(result)
                        } catch {
                            return .failure(job)
                        }
                    }
                }

                guard inflight > 0 else {
                    continue
                }

                try Task.checkCancellation()

                if let outcome = try await group.next() {
                    inflight -= 1
                    switch outcome {
                    case .success(let result):
                        try await persistAndEmit(result)
                    case .failure(let job):
                        await handleJobFailure(job)
                    case .cancelled:
                        break
                    }
                }
            }
        }
    }

    private func processSequential(
        jobs: [CategorizationJob],
        centroids: [String: [Float]]
    ) async throws {
        for job in jobs {
            try Task.checkCancellation()
            do {
                let result = try await engine.classify(
                    text: job.text,
                    itemID: job.itemID,
                    centroids: centroids
                )
                try await persistAndEmit(result)
            } catch {
                await handleJobFailure(job)
                continue
            }
        }
    }

    private func handleJobFailure(_ job: CategorizationJob) async {
        if job.retryCount + 1 >= Self.maxRetryCount {
            try? await database.deleteJob(itemID: job.itemID)
        } else {
            try? await database.incrementRetryCount(itemID: job.itemID)
        }
    }

    private func persistAndEmit(_ result: CategorizationResult) async throws {
        do {
            try await database.persistProcessedResult(result)
            resultContinuation.yield(result)
        } catch let error as CategorizationError {
            throw error
        } catch {
            throw CategorizationError.databaseError(underlying: error)
        }
    }

    private func makeCentroid(for category: CategoryDefinition) async throws -> [Float] {
        let texts = [category.label] + category.descriptors
        guard !texts.isEmpty else {
            throw CategorizationError.embeddingFailed(text: category.label)
        }

        var vectors: [[Float]] = []
        vectors.reserveCapacity(texts.count)

        for text in texts {
            let vector = try await embeddingProvider.embed(text)
            vectors.append(vector)
        }

        guard let first = vectors.first else {
            throw CategorizationError.embeddingFailed(text: category.label)
        }

        var centroid = Array(repeating: Float.zero, count: first.count)
        for vector in vectors {
            guard vector.count == first.count else {
                throw CategorizationError.modelLoadFailed(reason: "Inconsistent embedding dimensions")
            }
            for index in vector.indices {
                centroid[index] += vector[index]
            }
        }

        let divisor = Float(vectors.count)
        return centroid.map { $0 / divisor }
    }

    private func resultCutoffDate(now: Date = Date()) -> Date {
        now.addingTimeInterval(-configuration.resultTTL)
    }


    private func observeAppStateChanges() async {
        let stateChanges = appStateObserver.stateChanges
        for await state in stateChanges {
            switch state {
            case .foreground:
                await triggerAutomaticProcessingIfForeground()
            case .background:
                await scheduleBackgroundProcessingIfNeeded()
            case .backgroundTask:
                break
            }
        }
    }

    private func restoreAutomaticWorkIfNeeded() async {
        await scheduleBackgroundProcessingIfNeeded()
        await triggerAutomaticProcessingIfForeground()
    }

    private func scheduleBackgroundProcessingIfNeeded() async {
        guard let bgTaskCoordinator else {
            return
        }

        let pending = (try? await database.pendingCount()) ?? 0
        guard pending > 0 else {
            return
        }

        try? bgTaskCoordinator.scheduleIfNeeded()
    }

    private func triggerAutomaticProcessingIfForeground() async {
        guard bgTaskCoordinator != nil else {
            return
        }

        let currentState = await appStateObserver.currentState
        guard case .foreground = currentState else {
            return
        }

        await automaticProcessingDriver.startIfNeeded { [weak self] in
            await self?.drainAutomaticallyInForeground()
        }
    }

    private func drainAutomaticallyInForeground() async {
        while !Task.isCancelled {
            let currentState = await appStateObserver.currentState
            guard case .foreground = currentState else {
                return
            }

            let pending = (try? await database.pendingCount()) ?? 0
            guard pending > 0 else {
                return
            }

            do {
                try await processAvailableJobs(mode: .foreground)
            } catch {
                return
            }
        }
    }
}
