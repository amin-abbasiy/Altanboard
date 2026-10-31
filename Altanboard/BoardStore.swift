import AppKit
import Combine
import Foundation
import WhiteboardCore

struct BoardAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

@MainActor
final class BoardStore: ObservableObject {
    @Published private(set) var session = BoardSession()
    @Published private(set) var isBusy = false
    @Published var presentedError: BoardAlert?

    var document: BoardDocument { session.document }
    var mode: BoardMode { session.mode }
    var selectedColor: PencilColor { session.selectedColor }
    var canModify: Bool { mode == .edit && !isBusy }

    func setMode(_ mode: BoardMode) {
        guard !isBusy else { return }
        session.mode = mode
    }

    func selectColor(_ color: PencilColor) {
        guard canModify else { return }
        session.selectedColor = color
    }

    func commit(_ stroke: Stroke) {
        guard canModify else { return }
        do {
            try session.append(stroke)
        } catch {
            present(error, title: "Couldn’t Add Stroke")
        }
    }

    func clear() {
        guard canModify else { return }
        do {
            try session.clear()
        } catch {
            present(error, title: "Couldn’t Clear Drawing")
        }
    }

    func saveAndClear() {
        guard canModify, !document.strokes.isEmpty,
              let window = NSApp.keyWindow ?? NSApp.mainWindow else { return }
        isBusy = true

        Task {
            defer { isBusy = false }
            guard let url = await BoardFileDialogs.saveURL(in: window) else { return }
            let snapshot = session
            do {
                let savedSession = try await Task.detached(priority: .userInitiated) {
                    let hasAccess = url.startAccessingSecurityScopedResource()
                    defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
                    var saved = snapshot
                    try saved.saveAndClear(to: url)
                    return saved
                }.value
                session = savedSession
            } catch {
                present(error, title: "Couldn’t Save Drawing", prefix: "Your drawing has not been cleared.")
            }
        }
    }

    func load() {
        guard !isBusy, let window = NSApp.keyWindow ?? NSApp.mainWindow else { return }
        isBusy = true

        Task {
            defer { isBusy = false }
            guard let url = await BoardFileDialogs.loadURL(in: window) else { return }
            do {
                let loaded = try await Task.detached(priority: .userInitiated) {
                    let hasAccess = url.startAccessingSecurityScopedResource()
                    defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
                    return try BoardFileStore.load(from: url)
                }.value
                try session.replaceDocument(loaded)
            } catch {
                present(error, title: "Couldn’t Load Drawing", prefix: "Your current drawing has not been changed.")
            }
        }
    }

    private func present(_ error: Error, title: String, prefix: String? = nil) {
        let message = [prefix, error.localizedDescription].compactMap { $0 }.joined(separator: "\n\n")
        presentedError = BoardAlert(title: title, message: message)
    }
}
