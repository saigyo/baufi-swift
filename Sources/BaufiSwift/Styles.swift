// Wiederverwendbare Stil-Bausteine im Bauplan-Stil (eckige Rahmen, GROSSBUCHSTABEN
// mit Sperrung, Monospace-Zahlen). Entspricht den .bf-* Klassen aus src/styles.js.

import SwiftUI

extension View {
    /// Weißes Panel mit dünnem, eckigem Rahmen (--panel / --line).
    func panelBox(_ padding: CGFloat = 16) -> some View {
        self.padding(padding)
            .background(Theme.panel)
            .overlay(Rectangle().stroke(Theme.line, lineWidth: 1))
    }

    /// Eingabefeld-Optik: Monospace, heller Hintergrund, eckiger Rahmen.
    func blueprintField() -> some View {
        self.textFieldStyle(.plain)
            .font(Theme.mono(13))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Theme.fieldBg)
            .overlay(Rectangle().stroke(Theme.line, lineWidth: 1))
    }
}

/// Sektionsüberschrift (Archivo, fett, GROSSBUCHSTABEN, gesperrt).
struct SecTitle: View {
    let text: String
    var size: CGFloat = 13
    init(_ text: String, size: CGFloat = 13) { self.text = text; self.size = size }
    var body: some View {
        Text(text)
            .font(Theme.display(size, weight: .bold))
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(Theme.ink)
    }
}

/// Kleines Label (Feld-/KPI-Beschriftung), GROSSBUCHSTABEN, gedämpft.
struct MiniLabel: View {
    let text: String
    var size: CGFloat = 11
    init(_ text: String, size: CGFloat = 11) { self.text = text; self.size = size }
    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .regular))
            .textCase(.uppercase)
            .tracking(0.7)
            .foregroundStyle(Theme.muted)
    }
}

/// Erläuternder Hinweistext.
struct NoteText: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(Theme.muted)
            .fixedSize(horizontal: false, vertical: true)
    }
}
