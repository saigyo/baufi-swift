# BaufiSwift — native macOS-Port des Baufinanzierungs-Simulators

Datum: 2026-06-14

## Ziel

Native macOS-App (SwiftUI) mit voller Funktionsparität zum bestehenden
React/Vite-Projekt `baufinanzierung-simulator`: Vergleich von sechs
Baufinanzierungsmodellen mit dem Ziel, die Finanzierung bis zum Renteneintritt
auf 0 € bzw. eine definierte Ziel-Restschuld zurückzuführen.

## Funktionsumfang (voll)

- **Modellvergleich**: Annuität 10/15/20 J. (mit Anschlussfinanzierung),
  Volltilger, KfW-Kombi (≤ 100.000 €), Bauspar-Kombi.
- **Nebenkosten** je Bundesland (Grunderwerbsteuer, Notar/Grundbuch, optional Makler).
- **Belastungsquote** mit jährlicher Einkommenssteigerung; Spitze + Start; Schwellen 35/40 %.
- **Ziel-Restschuld bei Rente** + KLV-Monatsbeitrag in der Belastung.
- **Sondertilgung** (€/Jahr, jeweils Jahresende).
- **Zins-Stresstest** (Aufschlag auf Anschlusszins) als Zusatzspalte.
- **Umkehr-Modus**: max. Kaufpreis je Belastungsgrenze (Binärsuche).
- **Zwei Charts** (Restschuldverlauf, Belastungsquote) + Max-Kaufpreis-Balken, Fokus-Modus.
- **Persistenz**: Auto-Speichern (UserDefaults) + Teil-Code (Base64-JSON über die
  Zwischenablage) als Ersatz für die teilbare URL.

## Architektur

Swift Package mit getrennten Targets (Logik UI-frei und testbar, analog `src/lib/`):

- **`BaufiCore`** (library): `Finance`, `Calc`, `Constants`, `Formatting`,
  `AppState`, `Persistence` — keine UI-Abhängigkeit.
- **`BaufiSwift`** (executable, SwiftUI App): `ContentView` (Orchestrator),
  `Views/` (InputPanel, ModelTable, ComparisonCharts, MaxPriceSection, Footer),
  `Controls`, `Theme` (Farben).
- **`BaufiCoreTests`**: portierte Invarianten-Tests aus `finance.test.js` /
  `persistence.test.js`.

Charts: **Swift Charts** (`LineMark`, `BarMark`). Ziel-Plattform **macOS 14**.

## Geldrepräsentation (Festkomma)

- **Alle Geldbeträge als `Int` Cents** (`typealias Cents = Int`) — exakt, keine
  Float-Akkumulationsdrift über die Laufzeit.
- **Zinssätze, Quoten, %-Grenzen als `Double`** — Faktoren, kein „Geld".
- **Per-Periode-Rundung**: Monatszins `round(rest · r)` auf den Cent; Monatsrate
  einmal je Phase aus der Annuitätsformel berechnet und auf ganze Cents gerundet
  (wie eine reale Bank eine feste Rate stellt). Folge: Ziel-Restschuld wird auf
  wenige Euro genau getroffen statt exakt — Invarianten-Tests verwenden daher
  eine Cent-/Euro-Toleranz statt Festwerten.

## Finanzmathematik (1:1 portiert)

`annuityPayment`, `annuLoan` (Phasen, Ziel-Restschuld, Sondertilgung), `addLoans`,
`buildModels` (sechs Modelle), `summarize`, `computeCalc`, `computeInvers` —
gleiche Formeln, gleiche Schwellen, gleiche dokumentierte Vereinfachungen.

## Persistenz / Teilen

`AppStateData: Codable` (inp/z/bsp/modus/limits/stress). Auto-Save nach
UserDefaults bei jeder Änderung; Wiederherstellung beim Start. Menübefehle
„Szenario kopieren / einfügen" schreiben/lesen einen Base64-JSON-Code über
`NSPasteboard`. Ungültige Daten fallen auf `DEFAULTS` zurück.

## Sprache / Format

UI Deutsch; Zahlenformat de_DE über `NumberFormatter`. Disclaimer/Annahmen im
Footer beibehalten (URL-Hinweis durch Teil-Code-Hinweis ersetzt).
