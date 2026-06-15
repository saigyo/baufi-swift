// Beobachtbarer App-Zustand: hält die Eingaben, Auto-Speichern, Teil-Code.
// Entspricht dem State-Teil von BaufinanzierungsSimulator.jsx + persistence.js.

import SwiftUI
import AppKit
import BaufiCore

@MainActor
@Observable
final class AppState {
    var inp: Inputs
    var z: Zinsen
    var bsp: BausparCfg
    var modus: Modus
    var limits: [Double]
    var stress: Double

    // UI-State (nicht persistiert)
    var fokus: String? = nil          // hervorgehobenes Modell in Diagrammen/Tabelle
    var detail: String? = nil         // aufgeklappte Info-Zeile
    var zinsOffen: Bool = false       // Sektion „04 · Zinsannahmen"
    var statusMeldung: String? = nil  // kurze Rückmeldung für Kopieren/Einfügen

    init() {
        let s = Persistence.load()
        inp = s.inp; z = s.z; bsp = s.bsp
        modus = s.modus; limits = s.limits; stress = s.stress
    }

    var data: AppStateData {
        AppStateData(inp: inp, z: z, bsp: bsp, modus: modus, limits: limits, stress: stress)
    }

    func apply(_ d: AppStateData) {
        inp = d.inp; z = d.z; bsp = d.bsp
        modus = d.modus; limits = d.limits; stress = d.stress
    }

    func persist() { Persistence.save(data) }

    // MARK: Teil-Code über die Zwischenablage

    func copyShareCode() {
        let code = Persistence.encodeShareCode(data)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(code, forType: .string)
        flash("Szenario als Code in die Zwischenablage kopiert.")
    }

    func pasteShareCode() {
        guard let s = NSPasteboard.general.string(forType: .string),
              let d = Persistence.decodeShareCode(s) else {
            flash("Kein gültiger Szenario-Code in der Zwischenablage.")
            return
        }
        apply(d)
        persist()
        flash("Szenario aus Code geladen.")
    }

    func resetToDefaults() {
        apply(Defaults.state)
        persist()
        flash("Auf Standardwerte zurückgesetzt.")
    }

    private func flash(_ message: String) {
        statusMeldung = message
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            if statusMeldung == message { statusMeldung = nil }
        }
    }
}
