import SwiftUI

struct ContentView: View {
    @ObservedObject var model: SampleAppModel

    var body: some View {
        ZStack {
            SampleBackgroundView()
                .ignoresSafeArea()

            switch model.bootState {
            case .idle, .booting:
                loadingView
            case .failed(let message):
                failureView(message: message)
            case .ready:
                appShell
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingView: some View {
        VStack(spacing: 18) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.3)

            Text("Preparing CoreML sample app")
                .font(.system(size: 30, weight: .bold, design: .serif))

            Text("Loading the remote-package sample shell and the local categorization database.")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func failureView(message: String) -> some View {
        VStack(spacing: 16) {
            Text("Sample app failed to boot")
                .font(.system(size: 30, weight: .bold, design: .serif))

            Text(message)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)

            Button("Retry") {
                Task {
                    await model.retryBoot()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.78, green: 0.36, blue: 0.23))
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var appShell: some View {
        TabView {
            NavigationStack {
                CategorizationWorkspaceView(model: model)
                    .background(SampleBackgroundView().ignoresSafeArea())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .tabItem {
                Label("Classify", systemImage: "sparkles.rectangle.stack")
            }

            NavigationStack {
                CategoryManagerView(model: model)
                    .background(SampleBackgroundView().ignoresSafeArea())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .tabItem {
                Label("Categories", systemImage: "square.grid.2x2.fill")
            }

            NavigationStack {
                DiagnosticsPanelView(model: model)
                    .background(SampleBackgroundView().ignoresSafeArea())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .tabItem {
                Label("Diagnostics", systemImage: "gauge.with.dots.needle.67percent")
            }
        }
        .tint(Color(red: 0.78, green: 0.36, blue: 0.23))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbarBackground(.visible, for: .navigationBar, .tabBar)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar, .tabBar)
    }
}
