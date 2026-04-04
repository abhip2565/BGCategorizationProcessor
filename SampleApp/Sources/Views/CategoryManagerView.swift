import SwiftUI
import BGCategorizationProcessor

struct CategoryManagerView: View {
    @ObservedObject var model: SampleAppModel

    @State private var editorDraft = CategoryDraft()
    @State private var editingCategoryID: String?
    @State private var isPresentingEditor = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Persisted category catalog")
                        .font(.system(size: 22, weight: .bold, design: .serif))

                    Text("Categories are stored by the library and survive relaunch or app kill until you change them.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }

            if model.categories.isEmpty {
                Section {
                    Text("No categories yet. Add one manually or seed the starter set.")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.regularMaterial)
                )
            } else {
                Section("Categories") {
                    ForEach(model.categories, id: \.id) { category in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(category.label)
                                        .font(.system(size: 17, weight: .bold, design: .rounded))
                                    Text(category.id)
                                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button {
                                    editingCategoryID = category.id
                                    editorDraft = CategoryDraft(category: category)
                                    isPresentingEditor = true
                                } label: {
                                    Image(systemName: "pencil")
                                        .foregroundStyle(Color(red: 0.78, green: 0.36, blue: 0.23))
                                }
                                .buttonStyle(.borderless)
                            }

                            if category.descriptors.isEmpty {
                                Text("No descriptors. The label embedding is used as the centroid.")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                            } else {
                                descriptorFlow(category.descriptors)
                            }
                        }
                        .padding(.vertical, 6)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Task {
                                    await model.deleteCategory(id: category.id)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                editingCategoryID = category.id
                                editorDraft = CategoryDraft(category: category)
                                isPresentingEditor = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(Color(red: 0.78, green: 0.36, blue: 0.23))
                        }
                    }
                }
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.regularMaterial)
                )
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(SampleBackgroundView())
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Seed") {
                    Task {
                        await model.seedStarterCategories()
                    }
                }

                Button {
                    editingCategoryID = nil
                    editorDraft = CategoryDraft()
                    isPresentingEditor = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 96)
        }
        .sheet(isPresented: $isPresentingEditor) {
            NavigationStack {
                CategoryEditorView(
                    draft: $editorDraft,
                    isEditingIDLocked: editingCategoryID != nil
                ) {
                    isPresentingEditor = false
                    let draft = editorDraft
                    let originalID = editingCategoryID
                    editingCategoryID = nil
                    editorDraft = CategoryDraft()
                    Task {
                        await model.saveCategory(draft, originalID: originalID)
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .task {
            await model.refreshSnapshot()
        }
    }

    private func descriptorFlow(_ descriptors: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(descriptors, id: \.self) { descriptor in
                Text(descriptor)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.78, green: 0.36, blue: 0.23).opacity(0.12))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color(red: 0.78, green: 0.36, blue: 0.23).opacity(0.2), lineWidth: 1)
                    )
            }
        }
    }
}
