// Modellvergleich-Tabelle inkl. Fokus-Modus, optionaler Stress-Spalte,
// Empfehlungs-Markierung und aufklappbarer Info. Entspricht components/ModelTable.jsx.

import SwiftUI
import BaufiCore

struct ModelTable: View {
    @Bindable var state: AppState
    let calc: CalcResult
    let anschluss: Double
    let fokusKey: String?
    let onToggle: (String) -> Void

    private var stressDelta: Double { calc.stressDelta }
    private var hatStress: Bool { stressDelta > 0 }

    var body: some View {
        Card(title: "Modellvergleich") {
            VStack(spacing: 0) {
                header
                Rectangle().fill(Theme.ink).frame(height: 1.5)
                ForEach(calc.models) { m in
                    row(m)
                    Rectangle().fill(Theme.line).frame(height: 1)
                }
            }
            if let key = state.detail, let m = calc.models.first(where: { $0.key == key }) {
                Text(m.hinweis)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.muted)
                    .padding(.leading, 10).padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .leading) { Rectangle().fill(Theme.line).frame(width: 3) }
            }
            NoteText(erklaerung)
        }
    }

    // MARK: Kopfzeile

    private var header: some View {
        HStack(spacing: 8) {
            cell("Modell", width: nil, align: .leading, header: true)
            cell("Sollzins", width: 130, align: .leading, header: true)
            cell("Rate (Start)", width: 96, align: .trailing, header: true)
            cell("Rate (später)", width: 96, align: .trailing, header: true)
            cell("Belastung (Spitze)", width: 116, align: .trailing, header: true)
            if hatStress {
                cell("Stress +\(pct(stressDelta, 1))", width: 116, align: .trailing, header: true)
            }
            cell("Zinskosten gesamt", width: 120, align: .trailing, header: true)
            cell("", width: 56, align: .center, header: true)
        }
        .padding(.vertical, 6)
    }

    // MARK: Datenzeile

    @ViewBuilder
    private func row(_ m: Model) -> some View {
        let isBest = calc.beste?.key == m.key
        let isFokus = fokusKey == m.key
        let dimmed = fokusKey != nil && !isFokus

        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Rectangle().fill(Theme.color(forModel: m.key)).frame(width: 10, height: 10)
                Text(m.name)
                    .font(.system(size: 13, weight: isFokus || isBest ? .semibold : .regular))
                    .foregroundStyle(Theme.ink)
                if isBest { badge("Empfehlung") }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if m.infeasible {
                Text(m.hinweis)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                cell(m.zinsInfo, width: 130, align: .leading, mono: true)
                cell(eur(m.rate1), width: 96, align: .trailing, mono: true)
                cell(m.rate2 != nil ? eur(m.rate2!) : "—", width: 96, align: .trailing, mono: true)
                belastungCell(m.belastung, start: m.belastungStart, width: 116)
                if hatStress {
                    stressCell(m, width: 116)
                }
                cell(eur(m.zinskosten), width: 120, align: .trailing, mono: true)
                infoButton(m).frame(width: 56)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(isFokus ? Theme.fokusRow : (isBest ? Theme.bestRow : Color.clear))
        .opacity(dimmed ? 0.45 : 1)
        .contentShape(Rectangle())
        .onTapGesture { if !m.infeasible { onToggle(m.key) } }
    }

    private func belastungCell(_ v: Double, start: Double, width: CGFloat) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(pct(v, 0)).font(Theme.mono(13, weight: .medium)).foregroundStyle(Theme.belastungColor(v))
            if calc.g > 0 {
                Text("Start \(pct(start, 0))").font(.system(size: 11)).foregroundStyle(Theme.muted)
            }
        }
        .frame(width: width, alignment: .trailing)
    }

    private func stressCell(_ m: Model, width: CGFloat) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            if let b = m.stressBelastung {
                Text(pct(b, 0)).font(Theme.mono(13, weight: .medium)).foregroundStyle(Theme.belastungColor(b))
            } else {
                Text("—").font(Theme.mono(13))
            }
            if let zk = m.stressZinskosten {
                Text("Zinsen \(eur(zk))").font(.system(size: 11)).foregroundStyle(Theme.muted)
            }
        }
        .frame(width: width, alignment: .trailing)
    }

    private func infoButton(_ m: Model) -> some View {
        Button {
            state.detail = (state.detail == m.key) ? nil : m.key
        } label: {
            Text(state.detail == m.key ? "−" : "Info")
                .font(Theme.mono(11))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 8).padding(.vertical, 2)
                .background(Theme.fieldBg)
                .overlay(Rectangle().stroke(Theme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: Bausteine

    @ViewBuilder
    private func cell(_ text: String, width: CGFloat?, align: Alignment, header: Bool = false, mono: Bool = false) -> some View {
        Group {
            if header {
                Text(text)
                    .font(.system(size: 10, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(0.7)
                    .foregroundStyle(Theme.muted)
            } else if mono {
                Text(text).font(Theme.mono(13)).foregroundStyle(Theme.ink)
            } else {
                Text(text).font(.system(size: 13)).foregroundStyle(Theme.ink)
            }
        }
        .frame(width: width, alignment: align)
        .frame(maxWidth: width == nil ? .infinity : nil, alignment: align)
    }

    private func badge(_ t: String) -> some View {
        Text(t)
            .font(Theme.mono(10))
            .textCase(.uppercase)
            .tracking(0.7)
            .foregroundStyle(.white)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Theme.accent)
    }

    private var erklaerung: String {
        var s = "Belastung (Spitze) = höchster Wert von Monatsrate"
        if calc.klv > 0 { s += " + KLV-Beitrag (\(eur(calc.klv)))" }
        s += " ÷ Nettoeinkommen des jeweiligen Jahres (Steigerung \(pct(calc.g * 100, 1)) p. a.) über die gesamte Laufzeit. "
        s += "Faustregel: bis 35 % komfortabel, 35–40 % angespannt, über 40 % kritisch. "
        s += "Alle Modelle sind so gerechnet, dass die Restschuld zum Renteneintritt "
        s += calc.zielRest > 0 ? eur(calc.zielRest) : "0 €"
        s += " beträgt"
        s += calc.zielRest > 0 ? " – abzulösen z. B. durch eine fällige Kapitallebensversicherung." : "."
        if calc.sonder > 0 {
            s += " Sondertilgungen (\(eur(calc.sonder)) p. a.) senken Tilgungszeit bzw. Folge-Raten, zählen aber nicht zur Belastungsquote."
        }
        if stressDelta > 0 {
            s += " Stress-Spalte: Spitzen-Belastung und Zinskosten, falls der Anschlusszins um \(pct(stressDelta, 1))-Punkte höher ausfällt (\(pct(anschluss + stressDelta))). Die Empfehlung basiert auf dem Basisszenario."
        }
        return s
    }
}
