// Eingabe-Datenmodell und Defaults. Portiert aus den DEFAULTS in
// src/lib/persistence.js. Geldfelder sind Cents.

import Foundation

public enum Modus: String, Codable, Sendable {
    case vergleich
    case max
}

/// Objekt-, Personen- und Zielangaben.
public struct Inputs: Codable, Equatable, Sendable {
    public var kaufpreis: Cents
    public var eigenkapital: Cents
    public var netto: Cents            // Nettoeinkommen pro Monat
    public var einkommenPlus: Double   // jährliche Steigerung in %
    public var alter: Int
    public var rente: Int
    public var bundesland: String
    public var makler: Bool
    public var maklerProzent: Double
    public var zielRest: Cents
    public var klvBeitrag: Cents       // monatlicher KLV-Beitrag
    public var sonderTilgung: Cents    // pro Jahr

    public init(kaufpreis: Cents, eigenkapital: Cents, netto: Cents, einkommenPlus: Double,
                alter: Int, rente: Int, bundesland: String, makler: Bool, maklerProzent: Double,
                zielRest: Cents, klvBeitrag: Cents, sonderTilgung: Cents) {
        self.kaufpreis = kaufpreis; self.eigenkapital = eigenkapital; self.netto = netto
        self.einkommenPlus = einkommenPlus; self.alter = alter; self.rente = rente
        self.bundesland = bundesland; self.makler = makler; self.maklerProzent = maklerProzent
        self.zielRest = zielRest; self.klvBeitrag = klvBeitrag; self.sonderTilgung = sonderTilgung
    }
}

/// Vollständiger, persistierbarer App-Zustand (alle Eingaben).
public struct AppStateData: Codable, Equatable, Sendable {
    public var inp: Inputs
    public var z: Zinsen
    public var bsp: BausparCfg
    public var modus: Modus
    public var limits: [Double]
    public var stress: Double

    public init(inp: Inputs, z: Zinsen, bsp: BausparCfg, modus: Modus, limits: [Double], stress: Double) {
        self.inp = inp; self.z = z; self.bsp = bsp
        self.modus = modus; self.limits = limits; self.stress = stress
    }
}

public enum Defaults {
    public static let inp = Inputs(
        kaufpreis: 50_000_000, eigenkapital: 12_000_000, netto: 450_000, einkommenPlus: 3,
        alter: 38, rente: 67, bundesland: "Berlin",
        makler: true, maklerProzent: 3.57, zielRest: 0, klvBeitrag: 0, sonderTilgung: 0
    )
    public static let z = Zinsen(z10: 3.5, z15: 3.7, z20: 3.85, volltilger: 3.8, kfw: 3.4, anschluss: 4.2)
    public static let bsp = BausparCfg(vorausZins: 3.9, bausparZins: 2.75, ansparJahre: 10, ansparQuote: 40)
    public static let modus: Modus = .vergleich
    public static let limits: [Double] = [30, 35, 40]
    public static let stress: Double = 0

    public static var state: AppStateData {
        AppStateData(inp: inp, z: z, bsp: bsp, modus: modus, limits: limits, stress: stress)
    }
}
