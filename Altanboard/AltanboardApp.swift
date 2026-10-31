import AppKit
import SwiftUI

@main
@MainActor
struct AltanboardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("Altanboard", id: "whiteboard") {
            ContentView()
        }
        .defaultSize(width: 1_000, height: 740)
        .commands {
            // This is a single whiteboard, not a multi-document editor.
            CommandGroup(replacing: .newItem) {}
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
