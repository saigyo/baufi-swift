// Geteilte UI-Bausteine im Bauplan-Stil: KPI-Kacheln, Banner, Titelblock (Schriftfeld).

import SwiftUI
import BaufiCore

/// Einzelne Kennzahl-Kachel (eckiger Rahmen, GROSSBUCHSTABEN-Label, Monospace-Wert).
struct KPI: View {
    let label: String
    let value: String
    var warn: Bool = false

    init(_ label: String, _ value: String, warn: Bool = false) {
        self.label = label; self.value = value; self.warn = warn
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            MiniLabel(label, size: 10)
            Text(value)
                .font(Theme.mono(20, weight: .medium))
                .foregroundStyle(warn ? Theme.warn : Theme.ink)
        }
        .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(Theme.panel)
        .overlay(Rectangle().stroke(warn ? Theme.warn : Theme.line, lineWidth: 1))
    }
}

/// Adaptive Reihe von KPI-Kacheln.
struct KPIRow<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        let columns = [GridItem(.adaptive(minimum: 160), spacing: 12)]
        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) { content }
    }
}

/// Hinweis-/Warnbanner mit farbigem Balken links.
struct Banner: View {
    let text: String
    var warn: Bool = false
    init(_ text: String, warn: Bool = false) { self.text = text; self.warn = warn }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle().fill(warn ? Theme.warn : Theme.accent).frame(width: 4)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.panel)
        .overlay(Rectangle().stroke(Theme.line, lineWidth: 1))
    }
}

/// Kopfzeile im Stil eines Schriftfelds (gerahmt, mit Trennlinien).
struct TitleBlock: View {
    let jahre: Int
    let rente: Int
    let modelCount: Int

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Baufinanzierungs-Simulator")
                    .font(Theme.display(28, weight: .heavy))
                    .textCase(.uppercase)
                    .tracking(-0.3)
                    .foregroundStyle(Theme.ink)
                Text("Modellvergleich · schuldenfrei bis zur Rente")
                    .font(Theme.mono(12))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 18).padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .trailing) { Rectangle().fill(Theme.ink).frame(width: 1.5) }

            metaItem("Laufzeit", "\(jahre) Jahre")
            metaItem("Bis Alter", "\(rente)")
            metaItem("Modelle", modelCount > 0 ? "\(modelCount)" : "—")
        }
        .background(Theme.panel)
        .overlay(Rectangle().stroke(Theme.ink, lineWidth: 1.5))
    }

    private func metaItem(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            MiniLabel(label, size: 10)
            Text(value).font(Theme.mono(18))
                .foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .frame(minWidth: 92, alignment: .leading)
        .overlay(alignment: .leading) { Rectangle().fill(Theme.line).frame(width: 1) }
    }
}
