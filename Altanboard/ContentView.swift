import SwiftUI
import WhiteboardCore

@MainActor
struct ContentView: View {
    @StateObject private var store = BoardStore()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                HStack(spacing: 10) {
                    colorButton(.black)
                    colorButton(.red)
                }
                .disabled(!store.canModify)

                Spacer(minLength: 16)

                Label(
                    store.isPainting ? "Paint mode" : "Cursor mode",
                    systemImage: store.isPainting ? "pencil.tip" : "cursorarrow"
                )
                .font(.callout.weight(.medium))
                .frame(width: 150)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Whiteboard mode")
                .accessibilityValue(store.isPainting ? "Paint mode" : "Cursor mode")
                .help("Hold ⌘ Command and move the pointer to draw. Release Command to use the cursor.")

                Spacer(minLength: 16)

                HStack(spacing: 8) {
                    Button("Clear") { store.clear() }
                        .disabled(!store.canModify || store.document.strokes.isEmpty)

                    Button("Save & Clear") { store.saveAndClear() }
                        .disabled(!store.canModify || store.document.strokes.isEmpty)

                    Button("Load") { store.load() }
                        .disabled(store.isBusy)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.bar)

            Divider()

            BoardCanvas(store: store)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 720, minHeight: 480)
        .alert(item: $store.presentedError) { error in
            Alert(
                title: Text(error.title),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func colorButton(_ color: PencilColor) -> some View {
        let isSelected = store.selectedColor == color
        return Button {
            store.selectColor(color)
        } label: {
            Circle()
                .fill(color == .black ? Color.black : Color.red)
                .frame(width: 20, height: 20)
                .padding(5)
                .overlay {
                    Circle()
                        .strokeBorder(isSelected ? Color.primary : Color.clear, lineWidth: 2)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(color == .black ? "Black pencil" : "Red pencil")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .help(color == .black ? "Black pencil" : "Red pencil")
    }
}
