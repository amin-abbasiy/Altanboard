import AppKit
import UniformTypeIdentifiers

@MainActor
enum BoardFileDialogs {
    static func saveURL(in window: NSWindow) async -> URL? {
        let panel = NSSavePanel()
        panel.title = "Save Drawing"
        panel.prompt = "Save & Clear"
        panel.message = "The canvas will be cleared only after your drawing is saved."
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        panel.nameFieldStringValue = "Altanboard-\(formatter.string(from: Date())).json"

        let response = await withCheckedContinuation { continuation in
            panel.beginSheetModal(for: window) { response in
                continuation.resume(returning: response)
            }
        }
        return response == .OK ? panel.url : nil
    }

    static func loadURL(in window: NSWindow) async -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Load Drawing"
        panel.prompt = "Load"
        panel.allowedContentTypes = [.json]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        let response = await withCheckedContinuation { continuation in
            panel.beginSheetModal(for: window) { response in
                continuation.resume(returning: response)
            }
        }
        return response == .OK ? panel.url : nil
    }
}
