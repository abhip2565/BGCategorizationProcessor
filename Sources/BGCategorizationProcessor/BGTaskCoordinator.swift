import Foundation
import os.log

#if os(iOS)
import BackgroundTasks
#endif

private let logger = Logger(subsystem: "BGCategorizationProcessor", category: "BGTaskCoordinator")

private final class BGProcessingTaskBox: @unchecked Sendable {
    #if os(iOS)
    let task: BGProcessingTask

    init(task: BGProcessingTask) {
        self.task = task
    }

    func complete(success: Bool) {
        task.setTaskCompleted(success: success)
    }
    #endif
}

public final class BGTaskCoordinator: Sendable {
    private let taskIdentifier: String
    private static let registrationLock = NSLock()
    private nonisolated(unsafe) static var registeredIdentifiers = Set<String>()

    public init(taskIdentifier: String) {
        self.taskIdentifier = taskIdentifier
    }

    public func register(processor: BGCategorizationProcessor) {
        #if os(iOS)
        guard Self.claimRegistration(for: taskIdentifier) else {
            logger.info("Registration skipped — already registered for \(self.taskIdentifier)")
            return
        }

        logger.info("Registering BGProcessingTask handler for \(self.taskIdentifier)")

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            guard let processingTask = task as? BGProcessingTask else {
                logger.error("Task launched but was not a BGProcessingTask — ignoring")
                return
            }
            let taskBox = BGProcessingTaskBox(task: processingTask)
            logger.info("BGProcessingTask launched by system for \(self.taskIdentifier)")

            let runner = Task {
                try? self.scheduleIfNeeded()
                let shouldReschedule = await self.handleBackgroundLaunch(processor: processor)
                if shouldReschedule {
                    logger.info("Background pass complete — work remains, task will reschedule")
                } else {
                    logger.info("Background pass complete — no pending work, cancelling future schedule")
                    BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: self.taskIdentifier)
                }
                taskBox.complete(success: true)
                logger.info("BGProcessingTask marked complete (success)")
            }

            processingTask.expirationHandler = {
                logger.warning("System expiration handler fired — cancelling background processing")
                runner.cancel()
            }
        }
        #endif
    }

    public func handleBackgroundLaunch(processor: BGCategorizationProcessor) async -> Bool {
        await processor.appStateObserver.overrideState(.backgroundTask)
        let initialPending = (try? await processor.pendingCount()) ?? 0
        logger.info("Background launch started — \(initialPending) jobs pending")

        var batchCount = 0
        while !Task.isCancelled {
            let pending = (try? await processor.pendingCount()) ?? 0
            guard pending > 0 else {
                logger.info("No more pending jobs — exiting background loop after \(batchCount) batches")
                break
            }

            do {
                try await processor.processAvailableJobs(mode: .background)
                batchCount += 1
                let remaining = (try? await processor.pendingCount()) ?? 0
                logger.debug("Batch \(batchCount) complete — \(remaining) jobs remaining")
            } catch {
                logger.error("Background processing error: \(error.localizedDescription)")
                break
            }
        }

        if Task.isCancelled {
            logger.warning("Background processing was cancelled (system expiration or task cancellation)")
        }

        let remaining = (try? await processor.pendingCount()) ?? 0
        logger.info("Background launch finished — processed \(initialPending - remaining) of \(initialPending) jobs, \(remaining) remaining")
        return remaining > 0
    }

    public func scheduleIfNeeded() throws {
        #if os(iOS)
        let request = BGProcessingTaskRequest(identifier: taskIdentifier)
        request.requiresExternalPower = false
        request.requiresNetworkConnectivity = false

        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("Scheduled BGProcessingTaskRequest for \(self.taskIdentifier)")
        } catch let error as BGTaskScheduler.Error where error.code == .unavailable {
            logger.debug("Schedule skipped — BGTaskScheduler unavailable (Simulator or restricted environment)")
        } catch {
            logger.error("Failed to schedule BGProcessingTaskRequest: \(error.localizedDescription)")
            throw error
        }
        #endif
    }

    private static func claimRegistration(for identifier: String) -> Bool {
        registrationLock.lock()
        defer { registrationLock.unlock() }

        if registeredIdentifiers.contains(identifier) {
            return false
        }

        registeredIdentifiers.insert(identifier)
        return true
    }
}
