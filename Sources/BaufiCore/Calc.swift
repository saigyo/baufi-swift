// Abgeleitete Berechnungen für die App. Portiert aus src/lib/calc.js.
// Geld in Cents, Quoten/Prozente in Double.

import Foundation

/// Ein Punkt für die Verlaufsdiagramme (Long-Format für Swift Charts).
public struct ChartPoint: Identifiable, Sendable {
    public let alter: Int
    public let key: String
    public let value: Double   // Restschuld in Euro bzw. Belastung in %
    public var id: String { "\(key)-\(alter)" }
}

public struct CalcResult: Sendable {
    public var grest: Cents = 0
    public var notar: Cents = 0
    public var makler: Cents = 0
    public var nk: Cents = 0
    public var darlehen: Cents = 0
    public var bla: Double = 0
    public var jahre: Int = 0
    public var nMonths: Int = 0
    public var models: [Model] = []
    public var beste: Model? = nil
    public var restschuldPoints: [ChartPoint] = []
    public var belastungPoints: [ChartPoint] = []
    public var zielRest: Cents = 0
    public var zielGekappt: Bool = false
    public var klv: Cents = 0
    public var g: Double = 0
    public var sonder: Cents = 0
    public var stressDelta: Double = 0
}

public func computeCalc(_ inp: Inputs, _ z: Zinsen, _ bsp: BausparCfg, _ stress: Double) -> CalcResult {
    var out = CalcResult()
    let grestPct = GREST[inp.bundesland] ?? 0
    out.grest = Cents((grestPct / 100 * Double(inp.kaufpreis)).rounded())
    out.notar = Cents((NOTAR_PROZENT / 100 * Double(inp.kaufpreis)).rounded())
    out.makler = inp.makler ? Cents((inp.maklerProzent / 100 * Double(inp.kaufpreis)).rounded()) : 0
    out.nk = out.grest + out.notar + out.makler
    out.darlehen = max(0, inp.kaufpreis + out.nk - inp.eigenkapital)
    out.bla = inp.kaufpreis > 0 ? Double(out.darlehen) / Double(inp.kaufpreis) * 100 : 0
    out.jahre = max(0, inp.rente - inp.alter)
    out.nMonths = out.jahre * 12
    out.zielRest = min(max(0, inp.zielRest), out.darlehen)
    out.zielGekappt = inp.zielRest > out.darlehen && out.darlehen > 0
    out.sonder = max(0, inp.sonderTilgung)

    let nMonths = out.nMonths
    var models = (nMonths > 0 && out.darlehen > 0)
        ? buildModels(out.darlehen, nMonths, z, bsp, ziel: out.zielRest, sonder: out.sonder)
        : []

    out.klv = out.zielRest > 0 ? max(0, inp.klvBeitrag) : 0
    out.g = max(0, inp.einkommenPlus) / 100
    let klv = out.klv, g = out.g
    let einkommenImJahr = { (j: Int) -> Double in Double(inp.netto) * pow(1 + g, Double(j)) }
    func spitze(_ loan: Loan) -> Double {
        var maxB = 0.0
        for mo in 0..<nMonths {
            let ink = einkommenImJahr(mo / 12)
            guard ink > 0 else { continue }
            let pay = mo < loan.payArr.count ? loan.payArr[mo] : 0
            let b = Double(pay + klv) / ink * 100
            if b > maxB { maxB = b }
        }
        return maxB
    }

    // Stress-Szenario: Anschlusszins um `stress` %-Punkte höher.
    out.stressDelta = max(0, stress)
    var stressMap: [String: Model] = [:]
    if out.stressDelta > 0 && !models.isEmpty {
        var zStress = z
        zStress.anschluss = z.anschluss + out.stressDelta
        for m in buildModels(out.darlehen, nMonths, zStress, bsp, ziel: out.zielRest, sonder: out.sonder) {
            stressMap[m.key] = m
        }
    }

    for i in models.indices {
        if models[i].infeasible { continue }
        if inp.netto <= 0 {
            models[i].belastung = 999; models[i].belastungStart = 999; models[i].tragbar = false
            continue
        }
        if let loan = models[i].loan { models[i].belastung = spitze(loan) }
        models[i].belastungStart = Double(models[i].rate1 + klv) / Double(inp.netto) * 100
        models[i].tragbar = models[i].belastung <= 40
        if let ms = stressMap[models[i].key], !ms.infeasible, let loan = ms.loan {
            models[i].stressBelastung = spitze(loan)
            models[i].stressZinskosten = ms.zinskosten
        }
    }

    let kandidaten = models.filter { !$0.infeasible && $0.tragbar }
    out.beste = kandidaten.min(by: { $0.zinskosten < $1.zinskosten })
    out.models = models

    // Chart-Daten: Restschuld je Lebensjahr.
    if out.jahre > 0 {
        for j in 0...out.jahre {
            for m in models where !m.infeasible {
                guard let loan = m.loan else { continue }
                let idx = min(j * 12, nMonths)
                let rest = loan.restArr[min(idx, loan.restArr.count - 1)]
                out.restschuldPoints.append(ChartPoint(alter: inp.alter + j, key: m.key, value: Double(rest) / 100))
            }
        }
        // Chart-Daten: Belastungsquote je Lebensjahr.
        for j in 0..<out.jahre {
            let ink = einkommenImJahr(j)
            guard ink > 0 else { continue }
            for m in models where !m.infeasible {
                guard let loan = m.loan else { continue }
                let pay = loan.payArr[min(j * 12, nMonths - 1)]
                let v = Double(pay + klv) / ink * 100
                out.belastungPoints.append(ChartPoint(alter: inp.alter + j, key: m.key, value: (v * 10).rounded() / 10))
            }
        }
    }

    return out
}

// MARK: - Umkehr-Modus: maximaler Kaufpreis je Modell und Belastungsgrenze

public struct InversCell: Sendable {
    public var P: Cents          // max. Kaufpreis
    public var D: Cents?         // zugehörige Darlehenssumme
    public var capped: Bool      // an der Obergrenze (> 10 Mio €)
}

public struct InversRow: Identifiable, Sendable {
    public let key: String
    public let name: String
    public let short: String
    public let infeasible: Bool
    public let hinweis: String
    public var cells: [InversCell?]   // nil = kein Budget / nicht darstellbar
    public var id: String { key }
}

public struct InversResult: Sendable {
    public var nkQ: Double = 0       // Nebenkostenquote als Anteil (0…1)
    public var klv: Cents = 0
    public var rows: [InversRow] = []
    public var jahre: Int = 0
    public var g: Double = 0
}

public func computeInvers(_ inp: Inputs, _ z: Zinsen, _ bsp: BausparCfg, _ modus: Modus, _ limits: [Double]) -> InversResult {
    var out = InversResult()
    out.nkQ = ((GREST[inp.bundesland] ?? 0) + NOTAR_PROZENT + (inp.makler ? inp.maklerProzent : 0)) / 100
    out.jahre = max(0, inp.rente - inp.alter)
    let n = out.jahre * 12
    out.klv = inp.zielRest > 0 ? max(0, inp.klvBeitrag) : 0
    guard modus == .max, n > 0, inp.netto > 0 else { return out }

    out.g = max(0, inp.einkommenPlus) / 100
    let nkQ = out.nkQ, klv = out.klv, g = out.g
    let inkJahr = (0...out.jahre).map { Double(inp.netto) * pow(1 + g, Double($0)) }

    // Spitzen-Belastung in % über die Laufzeit für einen Kaufpreis P (Cents) und ein Modell.
    func peakFor(_ P: Cents, _ key: String) -> Double? {
        let D = max(0, Cents((Double(P) * (1 + nkQ)).rounded()) - inp.eigenkapital)
        if D <= 0 { return Double(klv) / Double(inp.netto) * 100 }
        let ziel = min(max(0, inp.zielRest), D)
        guard let m = buildModels(D, n, z, bsp, ziel: ziel).first(where: { $0.key == key }),
              !m.infeasible, let loan = m.loan else { return nil }
        var maxB = 0.0
        for mo in 0..<n {
            let pay = mo < loan.payArr.count ? loan.payArr[mo] : 0
            let b = Double(pay + klv) / inkJahr[mo / 12]
            if b > maxB { maxB = b }
        }
        return maxB * 100
    }

    let CAP: Cents = 1_000_000_000   // 10 Mio €
    let sample = buildModels(50_000_000, n, z, bsp)   // 500.000 € nur für Metadaten / infeasible
    for meta in sample {
        if meta.infeasible {
            out.rows.append(InversRow(key: meta.key, name: meta.name, short: meta.short,
                                      infeasible: true, hinweis: meta.hinweis, cells: limits.map { _ in nil }))
            continue
        }
        var cells: [InversCell?] = []
        for L in limits {
            if Double(klv) / Double(inp.netto) * 100 >= L {
                cells.append(InversCell(P: 0, D: nil, capped: false)); continue
            }
            if (peakFor(CAP, meta.key) ?? .infinity) <= L {
                cells.append(InversCell(P: CAP, D: nil, capped: true)); continue
            }
            var lo = Double(inp.eigenkapital) / (1 + nkQ)
            var hi = Double(CAP)
            for _ in 0..<40 {
                let mid = (lo + hi) / 2
                if let b = peakFor(Cents(mid.rounded()), meta.key), b <= L { lo = mid } else { hi = mid }
            }
            let P = Cents((lo / 100_000).rounded(.down)) * 100_000   // auf 1.000 € abrunden
            let D = max(0, Cents((Double(P) * (1 + nkQ)).rounded()) - inp.eigenkapital)
            cells.append(InversCell(P: P, D: D, capped: false))
        }
        out.rows.append(InversRow(key: meta.key, name: meta.name, short: meta.short,
                                  infeasible: false, hinweis: meta.hinweis, cells: cells))
    }
    return out
}
