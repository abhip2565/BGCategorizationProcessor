import SwiftUI

struct CategorizationWorkspaceView: View {
    @ObservedObject var model: SampleAppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerCard
                sampleTextCard
                inputCard
                resultCard

                if !model.rankedCategories.isEmpty {
                    rankedCategoriesCard
                }
            }
            .padding(20)
            .padding(.bottom, 120)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .scrollIndicators(.hidden)
        .background(SampleBackgroundView())
        .navigationTitle("Classify")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await model.refreshSnapshot()
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CoreML categorization preview")
                .font(.system(size: 24, weight: .bold, design: .serif))

            Text("Text is queued into the library, processed against persisted categories, and rendered as a ranked similarity stack.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            statusBadge(model.shortStatusMessage, tint: Color(red: 0.13, green: 0.45, blue: 0.39))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(cardShape)
    }

    private var sampleTextCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Quick sample texts")
                .font(.system(size: 18, weight: .bold, design: .rounded))

            ForEach(SampleAppConfiguration.sampleTexts, id: \.self) { sample in
                Button {
                    model.loadSampleText(sample)
                } label: {
                    Text(sample)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.ultraThinMaterial)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(cardShape)
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Input")
                .font(.system(size: 18, weight: .bold, design: .rounded))

            TextEditor(text: $model.inputText)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .frame(minHeight: 140)
                .padding(12)
                .scrollContentBackground(.hidden)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )

            Button {
                Task {
                    await model.classifyCurrentText()
                }
            } label: {
                HStack {
                    if model.isClassifying {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(model.isClassifying ? "Classifying..." : "Classify")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.78, green: 0.36, blue: 0.23))
            .disabled(model.isClassifying)
        }
        .padding(18)
        .background(cardShape)
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Top category")
                .font(.system(size: 18, weight: .bold, design: .rounded))

            if let result = model.latestResult {
                VStack(alignment: .leading, spacing: 10) {
                    Text(result.topCategory ?? "No confident category")
                        .font(.system(size: 26, weight: .bold, design: .serif))

                    Text("Threshold: \(model.confidenceThresholdText)")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)

                    Text("Item ID: \(result.itemID)")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.95, green: 0.71, blue: 0.52),
                                    Color(red: 0.96, green: 0.88, blue: 0.75)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
            } else {
                Text("No classification yet. Add categories in the next tab, then submit some text here.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(cardShape)
    }

    private var rankedCategoriesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Similarity map")
                .font(.system(size: 18, weight: .bold, design: .rounded))

            ForEach(model.rankedCategories) { category in
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(category.label)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                            if category.isTopCategory {
                                Text("Top")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.white.opacity(0.65), in: Capsule())
                            }
                        }

                        Text("score \(category.scoreText)")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(category.similarityPercentText)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(similarityColor(for: category))
                )
            }
        }
        .padding(18)
        .background(cardShape)
    }

    private var cardShape: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.regularMaterial)
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
    }

    private func similarityColor(for category: RankedCategoryPresentation) -> Color {
        let base = category.isTopCategory
            ? (red: 0.91, green: 0.49, blue: 0.28)
            : (red: 0.18, green: 0.58, blue: 0.52)
        return Color(
            red: min(1, base.red + (1 - category.intensity) * 0.18),
            green: min(1, base.green + (1 - category.intensity) * 0.18),
            blue: min(1, base.blue + (1 - category.intensity) * 0.18)
        )
        .opacity(0.32 + (category.intensity * 0.48))
    }

    private func statusBadge(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(tint.opacity(0.12), in: Capsule())
    }
}
