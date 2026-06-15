// App-Einstieg: Fenster, Menübefehle für Teil-Code (Cmd+Shift+C/V) und Reset.

import SwiftUI
import AppKit
import BaufiCore

/// Sorgt dafür, dass das Binary auch ohne .app-Bundle (z. B. via `swift run`) als
/// reguläre App mit Dock-Icon startet und das Fenster nach vorne kommt.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct BaufiSwiftApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var state = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(state)
                .frame(minWidth: 1040, minHeight: 720)
        }
        .defaultSize(width: 1400, height: 920)
        .commands {
            CommandGroup(after: .pasteboard) {
                Divider()
                Button("Szenario als Code kopieren") { state.copyShareCode() }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                Button("Szenario aus Code einfügen") { state.pasteShareCode() }
                    .keyboardShortcut("v", modifiers: [.command, .shift])
                Divider()
                Button("Auf Standardwerte zurücksetzen") { state.resetToDefaults() }
            }
        }
    }
}
