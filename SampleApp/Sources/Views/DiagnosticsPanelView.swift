import SwiftUI

struct DiagnosticsPanelView: View {
    @ObservedObject var model: SampleAppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                statusGrid
                actionCard
                stressTestCard
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
        .background(cardShape)
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
        .background(cardShape)
    }

    private var stressTestCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Stress test")
                .font(.system(size: 22, weight: .bold, design: .rounded))

            Text("Enqueue and process 500 large-text jobs in one shot to exercise background throughput.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            actionButton(
                title: model.isRunningStressTest ? "Enqueuing..." : "Queue 500 jobs for BG processing",
                tint: Color(red: 0.74, green: 0.30, blue: 0.18),
                isDisabled: model.isRunningStressTest
            ) {
                Task {
                    await model.enqueueStressTestForBackground()
                }
            }

            actionButton(
                title: model.isRunningStressTest ? "Running..." : "Run 500-job stress test (foreground)",
                tint: Color(red: 0.56, green: 0.22, blue: 0.52),
                isDisabled: model.isRunningStressTest
            ) {
                Task {
                    await model.runStressTest()
                }
            }

            if !model.stressTestProgress.isEmpty {
                Text(model.stressTestProgress)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(model.isRunningStressTest ? .orange : .green)
            }

            if !model.stressTestResults.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(model.stressTestResults, id: \.itemID) { result in
                            HStack(spacing: 10) {
                                Text(result.topCategory ?? "---")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .frame(width: 80, alignment: .leading)

                                Text(result.itemID.components(separatedBy: "-").last.map { "#\($0)" } ?? result.itemID)
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.secondary)

                                Spacer()

                                if let top = result.topCategory, let score = result.categoryScores[top] {
                                    Text(String(format: "%.2f", score))
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(.ultraThinMaterial)
                            )
                        }
                    }
                }
                .frame(maxHeight: 400)
            }
        }
        .padding(20)
        .background(cardShape)
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
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                }
            }
        }
        .padding(20)
        .background(cardShape)
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
        .background(cardShape)
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
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
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

    private var cardShape: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.regularMaterial)
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
    }
}
