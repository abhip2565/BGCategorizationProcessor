import SwiftUI

@main
struct SampleAppApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = SampleAppModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .task {
                    await model.bootIfNeeded()
                    model.handleScenePhase(scenePhase)
                }
                .onChange(of: scenePhase) { newPhase in
                    model.handleScenePhase(newPhase)
                }
        }
    }
}
