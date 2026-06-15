// Eingabe-Panel: Objekt & Kapital, Person & Ziel, Nebenkosten, Zinsannahmen.
// Entspricht components/InputPanel.jsx.

import SwiftUI
import BaufiCore

struct InputPanel: View {
    @Bindable var state: AppState
    let calc: CalcResult
    let nkQ: Double

    private var grestPct: Double { GREST[state.inp.bundesland] ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            objektSektion
            personSektion
            nebenkostenSektion
            zinsSektion
        }
    }

    // MARK: 01 · Objekt & Kapital

    private var objektSektion: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("01 · Objekt & Kapital")
            if state.modus == .vergleich {
                Field(label: "Kaufpreis", suffix: "€") { CentsField(cents: $state.inp.kaufpreis, step: 1_000_000) }
            } else {
                note("Der maximale Kaufpreis wird aus Einkommen, Belastungsgrenzen und Eigenkapital berechnet.")
            }
            Field(label: "Eigenkapital", suffix: "€") { CentsField(cents: $state.inp.eigenkapital, step: 500_000) }
            Field(label: "Nettoeinkommen / Monat", suffix: "€") { CentsField(cents: $state.inp.netto, step: 10_000) }
            Field(label: "Einkommenssteigerung p. a.", suffix: "%") {
                DoubleField(value: $state.inp.einkommenPlus, step: 0.5, range: 0...10)
            }
            note("Idealisierte jährliche Steigerung des Nettoeinkommens. 0 % = konstantes Einkommen.")
        }
    }

    // MARK: 02 · Person & Ziel

    private var personSektion: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("02 · Person & Ziel")
            HStack(alignment: .top, spacing: 12) {
                Field(label: "Alter heute") { IntField(value: $state.inp.alter, range: 18...80) }
                Field(label: "Renteneintritt") { IntField(value: $state.inp.rente, range: 50...75) }
            }
            Field(label: "Zulässige Restschuld bei Rente", suffix: "€") {
                CentsField(cents: $state.inp.zielRest, step: 1_000_000)
            }
            note("0 € = volle Tilgung bis zur Rente. Höher, wenn zum Renteneintritt eine Ablösesumme fällig wird (z. B. KLV).")
            if state.inp.zielRest > 0 {
                Field(label: "KLV-Beitrag / Monat", suffix: "€") { CentsField(cents: $state.inp.klvBeitrag, step: 2_500) }
                note("Beitrag zur Kapitallebensversicherung, die die Restschuld ablösen soll. Fließt in die Belastungsquote ein.")
            }
            Field(label: "Sondertilgung / Jahr", suffix: "€") { CentsField(cents: $state.inp.sonderTilgung, step: 100_000) }
            note("Jährliche Sondertilgung zum Jahresende. Senkt Restschuld und Zinskosten, zählt nicht zur Belastungsquote. Im Bauspar-Modell ignoriert.")
        }
    }

    // MARK: 03 · Nebenkosten

    private var nebenkostenSektion: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("03 · Nebenkosten")
            Field(label: "Bundesland") {
                Picker("", selection: $state.inp.bundesland) {
                    ForEach(BUNDESLAENDER, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                .frame(maxWidth: 220)
            }
            Toggle(isOn: $state.inp.makler) {
                Text("Maklerprovision (\(pct(state.inp.maklerProzent)))")
            }
            if state.modus == .vergleich {
                nkZeile("Grunderwerbsteuer (\(pct(grestPct, 1)))", eur(calc.grest))
                nkZeile("Notar & Grundbuch (\(pct(NOTAR_PROZENT, 1)))", eur(calc.notar))
                if state.inp.makler { nkZeile("Makler", eur(calc.makler)) }
                nkZeile("Nebenkosten gesamt", eur(calc.nk), bold: true)
            } else {
                nkZeile("Grunderwerbsteuer", pct(grestPct, 1))
                nkZeile("Notar & Grundbuch", pct(NOTAR_PROZENT, 1))
                if state.inp.makler { nkZeile("Makler", pct(state.inp.maklerProzent)) }
                nkZeile("Nebenkostenquote", pct(nkQ * 100, 1), bold: true)
            }
        }
    }

    // MARK: 04 · Zinsannahmen

    private var zinsSektion: some View {
        VStack(alignment: .leading, spacing: 10) {
            DisclosureGroup(isExpanded: $state.zinsOffen) {
                VStack(alignment: .leading, spacing: 10) {
                    grid([
                        ("Zinsbindung 10 J.", $state.z.z10),
                        ("Zinsbindung 15 J.", $state.z.z15),
                        ("Zinsbindung 20 J.", $state.z.z20),
                        ("Volltilger", $state.z.volltilger),
                        ("KfW (10 J.)", $state.z.kfw),
                        ("Anschlusszins", $state.z.anschluss),
                    ])
                    note("Anschlusszins = Annahme für die Zeit nach Ablauf einer Zinsbindung.")

                    sectionTitle("Stresstest Anschluss").padding(.top, 4)
                    Field(label: "Zinsaufschlag", suffix: "%-Pkt.") {
                        DoubleField(value: $state.stress, step: 0.5, range: 0...10)
                    }
                    note("0 = aus. Bei Aufschlag > 0 zeigt der Modellvergleich eine zusätzliche Stress-Spalte.")

                    sectionTitle("Bauspar-Kombi").padding(.top, 4)
                    HStack(alignment: .top, spacing: 12) {
                        Field(label: "Vorausdarlehen", suffix: "%") { DoubleField(value: $state.bsp.vorausZins, step: 0.05, range: 0...15) }
                        Field(label: "Bauspardarlehen", suffix: "%") { DoubleField(value: $state.bsp.bausparZins, step: 0.05, range: 0...15) }
                    }
                    HStack(alignment: .top, spacing: 12) {
                        Field(label: "Ansparphase", suffix: "J.") { IntField(value: $state.bsp.ansparJahre, range: 1...25) }
                        Field(label: "Ansparquote", suffix: "%") { DoubleField(value: $state.bsp.ansparQuote, step: 5, range: 20...50) }
                    }
                }
                .padding(.top, 6)
            } label: {
                SecTitle("04 · Zinsannahmen anpassen")
            }
        }
    }

    private func grid(_ items: [(String, Binding<Double>)]) -> some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                Field(label: item.0, suffix: "%") { DoubleField(value: item.1, step: 0.05, range: 0...15) }
            }
        }
    }

    // MARK: Bausteine

    private func sectionTitle(_ t: String) -> some View {
        SecTitle(t)
    }

    private func note(_ t: String) -> some View {
        NoteText(t)
    }

    private func nkZeile(_ label: String, _ value: String, bold: Bool = false) -> some View {
        HStack {
            Text(label).font(.system(size: 13, weight: bold ? .semibold : .regular)).foregroundStyle(Theme.ink)
            Spacer()
            Text(value).font(Theme.mono(13, weight: bold ? .medium : .regular)).foregroundStyle(Theme.ink)
        }
        .padding(.vertical, 1)
    }
}
