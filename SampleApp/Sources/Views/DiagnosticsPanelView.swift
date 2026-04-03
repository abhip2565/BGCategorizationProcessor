import SwiftUI

struct DiagnosticsPanelView: View {
    @ObservedObject var model: SampleAppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                statusGrid
                actionCard
                recentResultsCard
                validationCard
            }
            .padding(20)
            .padding(.bottom, 120)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .scrollIndicators(.hidden)
        .background(SampleBackgroundView())
        .navigationTitle("Diagnostics")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await model.refreshSnapshot()
        }
    }

    private var statusGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Runtime status")
                .font(.system(size: 24, weight: .bold, design: .serif))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                statusTile(title: "Lifecycle", value: model.lifecycleStateDescription)
                statusTile(title: "BG Refresh", value: model.backgroundRefreshDescription)
                statusTile(title: "BG Task", value: model.backgroundTaskReadinessDescription)
                statusTile(title: "Pending Jobs", value: "\(model.pendingCount)")
                statusTile(title: "Categories", value: "\(model.categories.count)")
                statusTile(title: "Last Processed", value: model.lastProcessedSummary)
            }
        }
        .padding(20)
        .background(cardBackground)
    }

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Debug actions")
                .font(.system(size: 22, weight: .bold, design: .rounded))

            actionButton(
                title: model.isRefreshing ? "Refreshing..." : "Refresh snapshot",
                tint: Color(red: 0.16, green: 0.46, blue: 0.46),
                isDisabled: model.isRefreshing
            ) {
                Task {
                    await model.refreshSnapshot()
                }
            }

            actionButton(
                title: model.isQueueingBackgroundSamples ? "Queueing..." : "Queue background sample jobs",
                tint: Color(red: 0.74, green: 0.42, blue: 0.20),
                isDisabled: model.isQueueingBackgroundSamples
            ) {
                Task {
                    await model.enqueueBackgroundSamples()
                }
            }

            actionButton(
                title: "Process pending in foreground",
                tint: Color(red: 0.12, green: 0.53, blue: 0.33)
            ) {
                Task {
                    await model.processPendingInForeground()
                }
            }

            actionButton(
                title: "Consume visible results",
                tint: Color(red: 0.61, green: 0.27, blue: 0.25)
            ) {
                Task {
                    await model.consumeVisibleResults()
                }
            }

            Text("Package source: \(SampleAppConfiguration.packageURL)")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding(20)
        .background(cardBackground)
    }

    private var recentResultsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recent results")
                .font(.system(size: 22, weight: .bold, design: .rounded))

            if model.recentResults.isEmpty {
                Text("No stored results yet.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.recentResults, id: \.itemID) { result in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(result.itemID)
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        Text(result.topCategory ?? "No confident category")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                        Text(result.processedAt.formatted(date: .omitted, time: .standard))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.7))
                    )
                }
            }
        }
        .padding(20)
        .background(cardBackground)
    }

    private var validationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Manual background validation")
                .font(.system(size: 22, weight: .bold, design: .rounded))

            ForEach(Array(model.manualValidationSteps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1).")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Text(step)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .background(cardBackground)
    }

    private func statusTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
    }

    private func actionButton(
        title: String,
        tint: Color,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
        .disabled(isDisabled)
    }

    private var cardBackground: some ShapeStyle {
        Color.white.opacity(0.56)
    }
}
