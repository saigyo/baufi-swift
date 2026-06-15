// Orchestrator: Layout, Tabs, KPIs, Banner, Empfehlung. Entspricht
// BaufinanzierungsSimulator.jsx (ohne den dort lokalen Finanz-/State-Code).

import SwiftUI
import BaufiCore

struct ContentView: View {
    @Environment(AppState.self) private var state

    private let lightText = Color(hex: "F2F5F3")

    var body: some View {
        @Bindable var state = state
        let calc = computeCalc(state.inp, state.z, state.bsp, state.stress)
        let invers = computeInvers(state.inp, state.z, state.bsp, state.modus, state.limits)
        let fokusKey = calc.models.contains { !$0.infeasible && $0.key == state.fokus } ? state.fokus : nil

        ZStack(alignment: .top) {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 18) {
                TitleBlock(jahre: calc.jahre, rente: state.inp.rente, modelCount: calc.models.count)

                HStack(alignment: .top, spacing: 18) {
                    ScrollView {
                        InputPanel(state: state, calc: calc, nkQ: invers.nkQ)
                            .panelBox(18)
                    }
                    .frame(width: 366)

                    ScrollView {
                        results(calc: calc, invers: invers, fokusKey: fokusKey)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(20)
        }
        .onChange(of: state.data) { _, newValue in Persistence.save(newValue) }
    }

    // MARK: Ergebnisbereich

    @ViewBuilder
    private func results(calc: CalcResult, invers: InversResult, fokusKey: String?) -> some View {
        @Bindable var state = state
        VStack(alignment: .leading, spacing: 14) {
            if let msg = state.statusMeldung {
                Banner(msg)
            }

            tabs(state: state)

            if state.modus == .vergleich {
                vergleich(calc: calc, fokusKey: fokusKey)
            } else {
                MaxPriceSection(state: state, invers: invers, jahre: calc.jahre)
            }

            Footer()
        }
    }

    private func tabs(state: AppState) -> some View {
        HStack(spacing: 0) {
            tabButton("Modellvergleich", .vergleich, state: state)
            Rectangle().fill(Theme.ink).frame(width: 1.5)
            tabButton("Maximaler Kaufpreis", .max, state: state)
        }
        .fixedSize()
        .overlay(Rectangle().stroke(Theme.ink, lineWidth: 1.5))
    }

    private func tabButton(_ title: String, _ modus: Modus, state: AppState) -> some View {
        let on = state.modus == modus
        return Button {
            state.modus = modus
        } label: {
            Text(title)
                .font(Theme.display(13, weight: .bold))
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(on ? lightText : Theme.ink)
                .padding(.horizontal, 18).padding(.vertical, 8)
                .background(on ? Theme.ink : Theme.panel)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func vergleich(calc: CalcResult, fokusKey: String?) -> some View {
        let warnBLA = calc.bla > 100

        KPIRow {
            KPI("Darlehenssumme", eur(calc.darlehen))
            KPI("Nebenkosten", eur(calc.nk))
            KPI("Beleihungsauslauf", pct(calc.bla, 0), warn: warnBLA)
            KPI("Tilgungszeit", "\(calc.jahre) Jahre")
            if calc.zielRest > 0 { KPI("Restschuld bei Rente", eur(calc.zielRest)) }
            if calc.klv > 0 { KPI("KLV-Beitrag / Monat", eur(calc.klv)) }
            if calc.sonder > 0 { KPI("Sondertilgung / Jahr", eur(calc.sonder)) }
        }

        if calc.zielGekappt {
            Banner("Die gewünschte Restschuld übersteigt die Darlehenssumme und wurde auf \(eur(calc.zielRest)) begrenzt.")
        }
        if warnBLA {
            Banner("Das Eigenkapital deckt die Nebenkosten nicht vollständig (Beleihung > 100 %). Viele Banken finanzieren das nur mit deutlichen Zinsaufschlägen.", warn: true)
        }
        if calc.jahre <= 0 {
            Banner("Renteneintritt muss nach dem aktuellen Alter liegen.", warn: true)
        }
        if calc.darlehen <= 0 && calc.jahre > 0 {
            Banner("Das Eigenkapital deckt Kaufpreis und Nebenkosten vollständig – es wird kein Darlehen benötigt.")
        }

        if let beste = calc.beste {
            empfehlung(beste, calc: calc)
        } else if !calc.models.isEmpty {
            Banner("Kein Modell bleibt unter 40 % Einkommensbelastung. Mögliche Hebel: mehr Eigenkapital, günstigeres Objekt oder späterer Renteneintritt.", warn: true)
        }

        if !calc.models.isEmpty {
            ComparisonCharts(
                calc: calc, rente: state.inp.rente, fokusKey: fokusKey,
                onToggle: toggleFokus, onReset: { state.fokus = nil }
            )
            ModelTable(
                state: state, calc: calc, anschluss: state.z.anschluss,
                fokusKey: fokusKey, onToggle: toggleFokus
            )
        }
    }

    private func empfehlung(_ beste: Model, calc: CalcResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Empfehlung")
                .font(Theme.mono(11))
                .textCase(.uppercase)
                .tracking(1.0)
                .foregroundStyle(Theme.bestTag)
                .padding(.horizontal, 8).padding(.vertical, 2)
                .overlay(Rectangle().stroke(Theme.bestTagBorder, lineWidth: 1))
            Text(beste.name)
                .font(Theme.display(20, weight: .bold))
                .foregroundStyle(lightText)
            Text(empfehlungsText(beste, calc: calc))
                .font(.system(size: 13))
                .foregroundStyle(Theme.bestText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Theme.ink)
    }

    private func empfehlungsText(_ beste: Model, calc: CalcResult) -> String {
        let ziel = calc.zielRest > 0 ? "die Zielrestschuld von \(eur(calc.zielRest))" : "0 €"
        let klvTeil = calc.klv > 0 ? " + KLV-Beitrag" : ""
        return "Niedrigste Gesamtzinskosten (\(eur(beste.zinskosten))) unter allen Modellen, die bis zum Renteneintritt auf \(ziel) zurückgeführt sind und deren Belastungsquote (Rate\(klvTeil) ÷ Einkommen des jeweiligen Jahres) zu keinem Zeitpunkt 40 % überschreitet – Spitze: \(pct(beste.belastung, 0))."
    }

    private func toggleFokus(_ key: String) {
        state.fokus = (state.fokus == key) ? nil : key
    }
}
