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
            CommandGroup(replacing: .appInfo) {
                Button("Über BaufiSwift") { showAboutPanel() }
            }
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

    /// Standard-„Über"-Fenster mit Copyright, Kurzbeschreibung und Lizenzhinweis.
    private func showAboutPanel() {
        let para = NSMutableParagraphStyle()
        para.alignment = .center
        para.lineSpacing = 2

        let base: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: para,
        ]

        let credits = NSMutableAttributedString(
            string: """
            Vergleich von Baufinanzierungsmodellen – nativer macOS-Port des \
            Baufinanzierungs-Simulators.

            MIT-Lizenz – Open Source. Bereitgestellt „wie besehen“, ohne Gewähr. \
            Keine Finanz-, Anlage- oder Steuerberatung.


            """,
            attributes: base
        )

        func appendLink(_ label: String, _ url: String, trailingNewline: Bool = true) {
            let link = NSMutableAttributedString(string: label, attributes: base)
            link.addAttribute(.link, value: URL(string: url)!,
                              range: NSRange(location: 0, length: link.length))
            credits.append(link)
            if trailingNewline { credits.append(NSAttributedString(string: "\n", attributes: base)) }
        }

        appendLink("Projektseite auf GitHub", "https://github.com/saigyo/baufi-swift")
        appendLink("Basiert auf: baufinanzierungs-simulator",
                   "https://github.com/saigyo/baufinanzierungs-simulator", trailingNewline: false)

        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: credits,
            NSApplication.AboutPanelOptionKey(rawValue: "Copyright"): "© 2026 Markus Ackermann",
        ])
        NSApp.activate(ignoringOtherApps: true)
    }
}
