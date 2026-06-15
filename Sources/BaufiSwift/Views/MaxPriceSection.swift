// Umkehr-Modus: maximaler Kaufpreis je Modell und Belastungsgrenze.
// Entspricht components/MaxPriceSection.jsx.

import SwiftUI
import Charts
import BaufiCore

struct MaxPriceSection: View {
    @Bindable var state: AppState
    let invers: InversResult
    let jahre: Int

    private let CAP: Cents = 1_000_000_000

    @State private var hoverModel: String?

    var body: some View {
        VStack(spacing: 14) {
            kpis
            if jahre <= 0 {
                Banner("Renteneintritt muss nach dem aktuellen Alter liegen.", warn: true)
            }
            grenzenCard
            if !invers.rows.isEmpty {
                balkenCard
                tabelleCard
            }
        }
    }

    // MARK: KPIs

    private var kpis: some View {
        KPIRow {
            KPI("Eigenkapital", eur(state.inp.eigenkapital))
            KPI("Nettoeinkommen", eur(state.inp.netto))
            KPI("Nebenkostenquote", pct(invers.nkQ * 100, 1))
            KPI("Tilgungszeit", "\(jahre) Jahre")
            if state.inp.zielRest > 0 { KPI("Restschuld bei Rente", eur(state.inp.zielRest)) }
            if invers.klv > 0 { KPI("KLV-Beitrag / Monat", eur(invers.klv)) }
        }
    }

    // MARK: Belastungsgrenzen

    private var grenzenCard: some View {
        Card(title: "Belastungsgrenzen") {
            HStack(alignment: .top, spacing: 16) {
                ForEach(Array(state.limits.enumerated()), id: \.offset) { i, _ in
                    Field(label: "Grenze \(i + 1)", suffix: "%") {
                        DoubleField(value: $state.limits[i], step: 1, range: 10...60)
                    }
                }
            }
            note("Anteil des Nettoeinkommens im jeweiligen Jahr (Steigerung \(pct(max(0, state.inp.einkommenPlus), 1)) p. a.), den Monatsrate\(invers.klv > 0 ? " + KLV-Beitrag (\(eur(invers.klv)))" : "") zu keinem Zeitpunkt überschreiten dürfen. Sondertilgungen und Zins-Stresstest bleiben hier unberücksichtigt.")
        }
    }

    // MARK: Balkenchart

    private var balkenCard: some View {
        Card(title: "Maximaler Kaufpreis nach Modell") {
            Chart {
                ForEach(invers.rows.filter { !$0.infeasible }) { row in
                    ForEach(Array(row.cells.enumerated()), id: \.offset) { i, cell in
                        BarMark(
                            x: .value("Kaufpreis", balkenWert(cell)),
                            y: .value("Modell", row.short)
                        )
                        .foregroundStyle(Theme.limitColors[i % Theme.limitColors.count])
                        .position(by: .value("Grenze", limitLabel(i)))
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) { Text("\(Int(v / 1000))k") }
                    }
                }
            }
            .chartForegroundStyleScale(domain: limitLabels, range: limitColorRange)
            .frame(height: 300)
            .chartOverlay { proxy in hoverLayer(proxy) }
        }
    }

    // MARK: Mouse-Over (Zeilen-Highlight + Grenzen-Tooltip)

    private var feasibleRows: [InversRow] { invers.rows.filter { !$0.infeasible } }

    @ViewBuilder
    private func hoverLayer(_ proxy: ChartProxy) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let loc):
                            guard let plot = proxy.plotFrame else { return }
                            let rect = geo[plot]
                            hoverModel = proxy.value(atY: loc.y - rect.minY, as: String.self)
                        case .ended:
                            hoverModel = nil
                        }
                    }

                if let s = hoverModel, let plot = proxy.plotFrame,
                   let row = feasibleRows.first(where: { $0.short == s }),
                   let yrel = proxy.position(forY: s) {
                    let rect = geo[plot]
                    let bandH = rect.height / CGFloat(max(1, feasibleRows.count))
                    Group {
                        Rectangle().fill(Theme.muted.opacity(0.12))
                            .frame(width: rect.width, height: bandH)
                            .position(x: rect.midX, y: rect.minY + yrel)
                        ChartTooltip(title: row.short, rows: grenzenRows(row))
                            .frame(width: 230, alignment: .leading)
                            .position(x: min(rect.midX + 60, geo.size.width - 130),
                                      y: min(max(rect.minY + yrel, 70), geo.size.height - 70))
                    }
                    .allowsHitTesting(false)
                }
            }
        }
    }

    private func grenzenRows(_ row: InversRow) -> [(label: String, value: String, color: Color)] {
        state.limits.indices.map { i in
            let cell = i < row.cells.count ? row.cells[i] : nil
            let value: String
            if let c = cell, c.P > 0 {
                value = c.capped ? "> 10 Mio. €" : eur(c.P)
            } else {
                value = "—"
            }
            return ("Grenze \(limitLabel(i)) %", value, Theme.limitColors[i % Theme.limitColors.count])
        }
    }

    // MARK: Tabelle

    private var tabelleCard: some View {
        Card(title: "Was kann ich mir leisten?") {
            VStack(spacing: 0) {
                tabelleHeader
                ForEach(invers.rows) { row in
                    tabelleRow(row)
                    Rectangle().fill(Theme.line).frame(height: 1)
                }
            }
            note("Größter Kaufpreis (auf 1.000 € gerundet), bei dem die Belastungsquote des Modells (Monatsrate\(invers.klv > 0 ? " + KLV-Beitrag" : "") ÷ Einkommen des jeweiligen Jahres) zu keinem Zeitpunkt die jeweilige Grenze überschreitet – inkl. Nebenkosten, abzüglich Eigenkapital, Restschuld bei Rente wie eingestellt (\(state.inp.zielRest > 0 ? eur(state.inp.zielRest) : "0 €")). „—“ = das Budget reicht für kein Darlehen.")
        }
    }

    private var tabelleHeader: some View {
        HStack(spacing: 8) {
            cellHeader("Modell").frame(maxWidth: .infinity, alignment: .leading)
            ForEach(Array(state.limits.enumerated()), id: \.offset) { i, L in
                VStack(alignment: .trailing, spacing: 1) {
                    cellHeader("max. bei \(limitLabel(i)) %")
                    Text("Budget \(eur(startBudget(L)))/Mon.").font(Theme.mono(10)).foregroundStyle(Theme.muted)
                }
                .frame(width: 160, alignment: .trailing)
            }
        }
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.ink).frame(height: 1.5) }
    }

    private func cellHeader(_ t: String) -> some View {
        Text(t)
            .font(.system(size: 10, weight: .semibold))
            .textCase(.uppercase)
            .tracking(0.7)
            .foregroundStyle(Theme.muted)
    }

    @ViewBuilder
    private func tabelleRow(_ row: InversRow) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Rectangle().fill(Theme.color(forModel: row.key)).frame(width: 10, height: 10)
                Text(row.name).font(.system(size: 13)).foregroundStyle(Theme.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if row.infeasible {
                Text(row.hinweis).font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(Array(row.cells.enumerated()), id: \.offset) { _, cell in
                    zelleInhalt(cell).frame(width: 160, alignment: .trailing)
                }
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func zelleInhalt(_ cell: InversCell?) -> some View {
        if let c = cell, c.P > 0 {
            if c.capped {
                Text("> 10 Mio. €").font(Theme.mono(13)).foregroundStyle(Theme.ink)
            } else {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(eur(c.P)).font(Theme.mono(13, weight: .medium)).foregroundStyle(Theme.ink)
                    if let d = c.D { Text("Darlehen \(eur(d))").font(Theme.mono(11)).foregroundStyle(Theme.muted) }
                }
            }
        } else {
            Text("—").font(Theme.mono(13)).foregroundStyle(Theme.muted)
        }
    }

    // MARK: Helfer

    private func balkenWert(_ cell: InversCell?) -> Double {
        guard let c = cell else { return 0 }
        return Double(c.capped ? CAP : c.P) / 100
    }

    private func startBudget(_ L: Double) -> Cents {
        max(0, Cents((L / 100 * Double(state.inp.netto)).rounded()) - invers.klv)
    }

    private func limitLabel(_ i: Int) -> String {
        let v = state.limits[i]
        return v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }

    private var limitLabels: [String] { state.limits.indices.map(limitLabel) }
    private var limitColorRange: [Color] { state.limits.indices.map { Theme.limitColors[$0 % Theme.limitColors.count] } }

    private func note(_ t: String) -> some View {
        NoteText(t)
    }
}
