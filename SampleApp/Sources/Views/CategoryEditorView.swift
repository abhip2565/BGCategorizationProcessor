import SwiftUI

struct CategoryEditorView: View {
    @Binding var draft: CategoryDraft
    let isEditingIDLocked: Bool
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Definition") {
                TextField("Category ID", text: $draft.id)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(isEditingIDLocked)

                TextField("Label", text: $draft.label)
            }

            Section("Descriptors") {
                Text("One descriptor per line. Leave it empty to use the label embedding only.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)

                TextEditor(text: $draft.descriptorsText)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .frame(minHeight: 160)
            }
        }
        .navigationTitle(isEditingIDLocked ? "Edit Category" : "New Category")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    onSave()
                    dismiss()
                }
                .disabled(
                    draft.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    draft.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
        }
    }
}
