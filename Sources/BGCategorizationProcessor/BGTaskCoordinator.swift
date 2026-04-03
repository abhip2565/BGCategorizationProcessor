import Foundation

#if os(iOS)
import BackgroundTasks
#endif

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
            return
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            guard let processingTask = task as? BGProcessingTask else {
                return
            }
            let taskBox = BGProcessingTaskBox(task: processingTask)

            let runner = Task {
                try? self.scheduleIfNeeded()
                let shouldReschedule = await self.handleBackgroundLaunch(processor: processor)
                if !shouldReschedule {
                    BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: self.taskIdentifier)
                }
                taskBox.complete(success: true)
            }

            processingTask.expirationHandler = {
                runner.cancel()
            }
        }
        #endif
    }

    public func handleBackgroundLaunch(processor: BGCategorizationProcessor) async -> Bool {
        await processor.appStateObserver.overrideState(.backgroundTask)

        while !Task.isCancelled {
            let pending = (try? await processor.pendingCount()) ?? 0
            guard pending > 0 else {
                break
            }

            do {
                try await processor.processAvailableJobs(mode: .background)
            } catch {
                break
            }
        }

        let remaining = (try? await processor.pendingCount()) ?? 0
        return remaining > 0
    }

    public func scheduleIfNeeded() throws {
        #if os(iOS)
        let request = BGProcessingTaskRequest(identifier: taskIdentifier)
        request.requiresExternalPower = false
        request.requiresNetworkConnectivity = false

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch let error as BGTaskScheduler.Error where error.code == .unavailable {
        } catch {
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
