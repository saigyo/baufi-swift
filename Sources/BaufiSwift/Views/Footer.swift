// Footer: Annahmen, Vereinfachungen, Disclaimer. Entspricht components/Footer.jsx,
// der URL-Hinweis ist durch den Teil-Code-Hinweis ersetzt.

import SwiftUI

struct Footer: View {
    var body: some View {
        Text("""
        Vereinfachtes Rechenmodell (monatliche Annuitäten; optionale Sondertilgungen jeweils zum \
        Jahresende, im Bauspar-Modell und im Modus „Maximaler Kaufpreis" nicht berücksichtigt; ohne \
        Bereitstellungszinsen, Förder-Tilgungszuschüsse und Steuereffekte). Geldbeträge werden intern \
        centgenau (Festkomma) gerechnet; der Periodenzins wird auf den Cent gerundet. Der Zins-Stresstest \
        variiert ausschließlich den Anschlusszins. Die Einkommenssteigerung ist eine idealisierte, \
        gleichmäßige Annahme – reale Einkommen entwickeln sich in Sprüngen und können auch sinken; \
        Banken rechnen bei der Kreditvergabe in der Regel mit dem heutigen Einkommen. Eine zum \
        Renteneintritt verbleibende Restschuld muss durch die geplante Ablösesumme (z. B. Auszahlung \
        einer Kapitallebensversicherung) gedeckt sein – der KLV-Beitrag wird in der Belastungsquote \
        berücksichtigt, ob die Ablaufleistung die Restschuld tatsächlich deckt (Rendite-, Kosten- und \
        Auszahlungsrisiko), prüft die Simulation jedoch nicht. Zinsannahmen sind frei wählbare Szenarien, \
        keine aktuellen Konditionen. Eingaben werden automatisch gesichert und beim Start wiederhergestellt; \
        über „Szenario als Code kopieren/einfügen" lassen sich Szenarien teilen. Dies ist eine Simulation \
        und keine Finanz- oder Anlageberatung – für eine konkrete Finanzierung bitte Angebote von Banken \
        bzw. unabhängigen Vermittlern einholen.
        """)
        .font(.system(size: 11.5))
        .foregroundStyle(Theme.muted)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 10)
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
        .padding(.top, 4)
    }
}
