import Foundation

#if canImport(UIKit)
import UIKit
#endif

public enum CategorizationAppState: Sendable {
    case foreground
    case background
    case backgroundTask
}

public actor AppStateObserver {
    public private(set) var currentState: CategorizationAppState = .foreground

    private var continuation: AsyncStream<CategorizationAppState>.Continuation?
    private var observingTask: Task<Void, Never>?
    public let stateChanges: AsyncStream<CategorizationAppState>

    public init() {
        let pair = AsyncStream<CategorizationAppState>.makeStream()
        self.stateChanges = pair.stream
        self.continuation = pair.continuation
    }

    public func startObserving() {
        guard observingTask == nil else {
            return
        }

        #if canImport(UIKit)
        observingTask = Task { [weak self] in
            await self?.observeNotifications()
        }
        #endif
    }

    public func stopObserving() {
        observingTask?.cancel()
        observingTask = nil
        continuation?.finish()
        continuation = nil
    }

    public func overrideState(_ state: CategorizationAppState) {
        currentState = state
        continuation?.yield(state)
    }
    #if canImport(UIKit)
    private func observeNotifications() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                let center = NotificationCenter.default
                for await _ in center.notifications(named: UIApplication.didBecomeActiveNotification) {
                    await self?.setState(.foreground)
                }
            }

            group.addTask { [weak self] in
                let center = NotificationCenter.default
                for await _ in center.notifications(named: UIApplication.didEnterBackgroundNotification) {
                    await self?.setState(.background)
                }
            }
        }
    }
    #endif

    private func setState(_ state: CategorizationAppState) {
        currentState = state
        continuation?.yield(state)
    }
}
