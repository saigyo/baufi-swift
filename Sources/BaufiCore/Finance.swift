// Finanzmathematik: Annuitäten, Darlehensphasen, Modell-Berechnung.
// Portiert aus src/lib/finance.js, jedoch mit Festkomma-Geld (Int-Cents):
//
//  - Alle Geldgrößen sind Cents. Zinssätze/Quoten bleiben Double (Faktoren).
//  - Der Monatszins wird je Periode auf den Cent gerundet (round(rest · r)),
//    die Monatsrate einmal je Phase aus der Annuitätsformel berechnet und auf
//    ganze Cents gerundet – wie eine Bank eine feste Rate stellt. Dadurch ist
//    die Tilgung driftfrei; die Ziel-Restschuld wird auf wenige Euro genau
//    getroffen (nicht exakt). Tests verwenden entsprechend eine Cent-Toleranz.

import Foundation

/// Unendliche Phasenlänge (Anschlussfinanzierung bis Laufzeitende).
public let INF_MONTHS = Int.max

public struct Phase: Sendable {
    public let rate: Double      // Sollzins in Prozent p. a.
    public let months: Int       // Länge in Monaten (INF_MONTHS = bis Laufzeitende)
    public init(rate: Double, months: Int) {
        self.rate = rate
        self.months = months
    }
}

public struct Loan: Sendable {
    public var restArr: [Cents]   // Restschuld je Monat, Länge n+1
    public var payArr: [Cents]    // Monatsrate je Monat, Länge n
    public var interest: Cents    // Gesamtzinskosten
}

/// Annuität mit optionaler Ballon-Restschuld: Rate (Cents) so, dass nach `months`
/// genau `residual` Cents verbleiben. Liefert 0 bei ungültigen Eingaben.
public func annuityPayment(_ K: Cents, _ rateAnnual: Double, _ months: Int, residual: Cents = 0) -> Cents {
    if months <= 0 || K <= 0 { return 0 }
    let r = rateAnnual / 100 / 12
    let kd = Double(K), rd = Double(residual)
    let payD: Double
    if r == 0 {
        payD = max(0, (kd - rd) / Double(months))
    } else {
        let v = pow(1 + r, Double(-months))
        payD = max(0, ((kd - rd * v) * r) / (1 - v))
    }
    return max(0, Cents(payD.rounded()))
}

/// Annuitätendarlehen in Phasen; die Rate wird je Phase so kalibriert, dass am
/// Ende der Gesamtlaufzeit n genau die Ziel-Restschuld `ziel` verbleibt.
/// `sonderJahr` wird jeweils zum Jahresende getilgt, höchstens bis auf `ziel`.
public func annuLoan(_ K: Cents, _ n: Int, _ phases: [Phase], ziel: Cents = 0, sonderJahr: Cents = 0) -> Loan {
    var rest = K
    var interest: Cents = 0
    var done = 0
    var restArr: [Cents] = [K]
    var payArr: [Cents] = []

    for ph in phases {
        let m = min(ph.months, n - done)
        if m <= 0 { break }
        let pay = annuityPayment(rest, ph.rate, n - done, residual: ziel)
        let r = ph.rate / 100 / 12
        var broke = false
        for i in 0..<m {
            let z = Cents((Double(rest) * r).rounded())
            interest += z
            rest = max(0, rest + z - pay)
            if sonderJahr > 0 && (done + i + 1) % 12 == 0 {
                rest = max(rest - sonderJahr, min(rest, ziel))
            }
            restArr.append(rest)
            payArr.append(pay)
            if rest <= 0 { broke = true; break }
        }
        done += m
        if broke { break }
    }

    let tail = restArr.last ?? K
    while restArr.count < n + 1 { restArr.append(tail) }
    while payArr.count < n { payArr.append(0) }
    return Loan(restArr: restArr, payArr: payArr, interest: interest)
}

/// Addiert Restschulden, Raten und Zinsen zweier Darlehen (für die KfW-Kombi).
public func addLoans(_ a: Loan, _ b: Loan) -> Loan {
    let n = max(a.restArr.count, b.restArr.count)
    var restArr: [Cents] = []
    var payArr: [Cents] = []
    for i in 0..<n {
        restArr.append((i < a.restArr.count ? a.restArr[i] : 0) + (i < b.restArr.count ? b.restArr[i] : 0))
    }
    for i in 0..<(n - 1) {
        payArr.append((i < a.payArr.count ? a.payArr[i] : 0) + (i < b.payArr.count ? b.payArr[i] : 0))
    }
    return Loan(restArr: restArr, payArr: payArr, interest: a.interest + b.interest)
}

/// Zinsannahmen (Prozent p. a.).
public struct Zinsen: Sendable, Codable, Equatable {
    public var z10, z15, z20, volltilger, kfw, anschluss: Double
    public init(z10: Double, z15: Double, z20: Double, volltilger: Double, kfw: Double, anschluss: Double) {
        self.z10 = z10; self.z15 = z15; self.z20 = z20
        self.volltilger = volltilger; self.kfw = kfw; self.anschluss = anschluss
    }
}

/// Bauspar-Parameter.
public struct BausparCfg: Sendable, Codable, Equatable {
    public var vorausZins: Double      // Vorausdarlehen, % p. a.
    public var bausparZins: Double     // Bauspardarlehen, % p. a.
    public var ansparJahre: Int        // Länge der Ansparphase in Jahren
    public var ansparQuote: Double     // angesparter Anteil der Bausparsumme in %
    public init(vorausZins: Double, bausparZins: Double, ansparJahre: Int, ansparQuote: Double) {
        self.vorausZins = vorausZins; self.bausparZins = bausparZins
        self.ansparJahre = ansparJahre; self.ansparQuote = ansparQuote
    }
}

/// Ein Finanzierungsmodell inkl. abgeleiteter Kennzahlen. Die belastungs- und
/// stressbezogenen Felder werden erst in computeCalc gefüllt.
public struct Model: Sendable, Identifiable {
    public let key: String
    public let name: String
    public let short: String
    public var zinsInfo: String = "—"
    public var hinweis: String = ""
    public var loan: Loan? = nil

    public var rate1: Cents = 0
    public var rate2: Cents? = nil
    public var rateMax: Cents = 0
    public var zinskosten: Cents = 0
    public var payoffMonth: Int = 0
    public var restRente: Cents = 0
    public var infeasible: Bool = false

    // In computeCalc gefüllt:
    public var belastung: Double = 0       // Spitzen-Belastungsquote in %
    public var belastungStart: Double = 0
    public var tragbar: Bool = false
    public var stressBelastung: Double? = nil
    public var stressZinskosten: Cents? = nil

    public var id: String { key }
}

/// Erzeugt die sechs Modelle in fester Reihenfolge: a10, a15, a20, vt, kfw, bsp.
public func buildModels(_ D: Cents, _ nMonths: Int, _ z: Zinsen, _ bsp: BausparCfg,
                        ziel: Cents = 0, sonder: Cents = 0) -> [Model] {
    var models: [Model] = []

    // Annuitätendarlehen mit 10 / 15 / 20 Jahren Zinsbindung
    let annuVarianten: [(Int, Double, String)] = [(10, z.z10, "a10"), (15, z.z15, "a15"), (20, z.z20, "a20")]
    for (jahre, rate, key) in annuVarianten {
        let loan = annuLoan(D, nMonths, [
            Phase(rate: rate, months: jahre * 12),
            Phase(rate: z.anschluss, months: INF_MONTHS),
        ], ziel: ziel, sonderJahr: sonder)
        let hatAnschluss = nMonths > jahre * 12
        var m = Model(key: key, name: "Annuität · \(jahre) J. Zinsbindung", short: "Annuität \(jahre) J.")
        m.zinsInfo = hatAnschluss ? "\(pct(rate)) → \(pct(z.anschluss))" : pct(rate)
        m.hinweis = hatAnschluss
            ? "Nach \(jahre) Jahren Anschlussfinanzierung zum angenommenen Zins von \(pct(z.anschluss)) (Zinsänderungsrisiko)."
            : "Zinsbindung deckt die volle Laufzeit ab."
        applySummary(&m, loan, nMonths, ziel: ziel)
        models.append(m)
    }

    // Volltilgerdarlehen
    do {
        let loan = annuLoan(D, nMonths, [Phase(rate: z.volltilger, months: INF_MONTHS)], ziel: ziel, sonderJahr: sonder)
        var m = Model(key: "vt", name: "Volltilgerdarlehen", short: "Volltilger")
        m.zinsInfo = pct(z.volltilger)
        m.hinweis = "Zins über die gesamte Laufzeit festgeschrieben – volle Planungssicherheit, kein Anschlussrisiko."
        applySummary(&m, loan, nMonths, ziel: ziel)
        models.append(m)
    }

    // KfW-Kombination (KfW-Baustein max. 100.000 €, 10 J. Zinsbindung)
    do {
        let kfwTeil = min(10_000_000, D)
        let hauptTeil = D - kfwTeil
        let hauptZiel = min(ziel, hauptTeil)
        let kfwZiel = ziel - hauptZiel
        let kfw = annuLoan(kfwTeil, nMonths, [
            Phase(rate: z.kfw, months: 120),
            Phase(rate: z.anschluss, months: INF_MONTHS),
        ], ziel: kfwZiel, sonderJahr: hauptTeil > 0 ? 0 : sonder)
        let haupt = annuLoan(hauptTeil, nMonths, [
            Phase(rate: z.z15, months: 180),
            Phase(rate: z.anschluss, months: INF_MONTHS),
        ], ziel: hauptZiel, sonderJahr: hauptTeil > 0 ? sonder : 0)
        let loan = addLoans(kfw, haupt)
        var m = Model(key: "kfw", name: "Annuität 15 J. + KfW-Baustein", short: "KfW-Kombi")
        m.zinsInfo = "\(pct(z.z15)) + KfW \(pct(z.kfw))"
        m.hinweis = "KfW-Wohneigentumsprogramm (\(eur(kfwTeil)), 10 J. Zinsbindung) ergänzt ein Hauptdarlehen mit 15 J. Zinsbindung. Anschluss jeweils zu \(pct(z.anschluss))."
            + (sonder > 0 && hauptTeil > 0 ? " Sondertilgungen fließen in das Hauptdarlehen." : "")
        applySummary(&m, loan, nMonths, ziel: ziel)
        models.append(m)
    }

    // Bauspar-Kombimodell
    do {
        let ansparM = bsp.ansparJahre * 12
        if ansparM >= nMonths || ansparM <= 0 {
            var m = Model(key: "bsp", name: "Bauspar-Kombimodell", short: "Bauspar-Kombi")
            m.zinsInfo = "—"
            m.infeasible = true
            m.hinweis = "Ansparphase ist länger als die verbleibende Zeit bis zur Rente – Modell in dieser Konstellation nicht darstellbar."
            models.append(m)
        } else {
            let quote = bsp.ansparQuote / 100
            let monatsSparen = Double(D) * quote / Double(ansparM)   // Cents/Monat (fraktional)
            let zinsM = Double(D) * bsp.vorausZins / 100 / 12        // Cents/Monat
            var restArr: [Cents] = [D]
            var payArr: [Cents] = []
            var interestD: Double = 0
            for i in 1...ansparM {
                interestD += zinsM
                let guthaben = Cents((Double(D) * quote * Double(i) / Double(ansparM)).rounded())
                restArr.append(D - guthaben)   // Netto-Schuld = Vorausdarlehen − Bausparguthaben
                payArr.append(Cents((zinsM + monatsSparen).rounded()))
            }
            let subKapital = Cents((Double(D) * (1 - quote)).rounded())
            let sub = annuLoan(subKapital, nMonths - ansparM,
                               [Phase(rate: bsp.bausparZins, months: INF_MONTHS)],
                               ziel: min(ziel, subKapital))
            interestD += Double(sub.interest)
            for r in sub.restArr.dropFirst() { restArr.append(r) }
            for p in sub.payArr { payArr.append(p) }
            let fee = Cents((Double(D) * 0.01).rounded())   // Abschlussgebühr ~1 % der Bausparsumme
            let loan = Loan(restArr: restArr, payArr: payArr, interest: Cents(interestD.rounded()) + fee)
            var m = Model(key: "bsp", name: "Bauspar-Kombimodell", short: "Bauspar-Kombi")
            m.zinsInfo = "\(pct(bsp.vorausZins)) → \(pct(bsp.bausparZins))"
            m.hinweis = "Tilgungsfreies Vorausdarlehen (\(pct(bsp.vorausZins))) + paralleles Ansparen von \(formatGanz(bsp.ansparQuote)) % über \(bsp.ansparJahre) Jahre, danach Bauspardarlehen zu \(pct(bsp.bausparZins)). Inkl. ca. 1 % Abschlussgebühr; Guthabenverzinsung vereinfachend vernachlässigt."
                + (sonder > 0 ? " Sondertilgungen werden in diesem Modell nicht berücksichtigt." : "")
            applySummary(&m, loan, nMonths, ziel: ziel)
            models.append(m)
        }
    }

    return models
}

/// Füllt die Kennzahlen eines Modells aus dem berechneten Darlehen.
func applySummary(_ m: inout Model, _ loan: Loan, _ nMonths: Int, ziel: Cents) {
    m.loan = loan
    let rate1 = loan.payArr.first ?? 0
    m.rate1 = rate1
    m.rateMax = loan.payArr.max() ?? 0

    // letzte abweichende Rate (z. B. nach Anschluss / Zuteilung)
    var rate2: Cents? = nil
    for i in stride(from: loan.payArr.count - 1, through: 0, by: -1) {
        if loan.payArr[i] > 0 {
            if abs(loan.payArr[i] - rate1) > 50 { rate2 = loan.payArr[i] }   // > 0,50 €
            break
        }
    }
    m.rate2 = rate2

    var payoffMonth = nMonths
    for i in 0..<loan.restArr.count {
        if loan.restArr[i] <= ziel + 50 { payoffMonth = i; break }   // Toleranz 0,50 €
    }
    m.payoffMonth = payoffMonth
    m.restRente = loan.restArr[min(nMonths, loan.restArr.count - 1)]
    m.zinskosten = loan.interest
    m.infeasible = false
}

/// Formatiert eine Quote ohne Nachkommastellen, wenn sie ganzzahlig ist (z. B. "40").
func formatGanz(_ value: Double) -> String {
    if value == value.rounded() { return String(Int(value)) }
    return pct(value, 1).replacingOccurrences(of: " %", with: "")
}
