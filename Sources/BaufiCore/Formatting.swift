// Zahlenformatierung (de-DE). Portiert aus src/lib/format.js.
// Geld wird intern als Int-Cents geführt; eur(_:) erwartet daher Cents.

import Foundation

/// Festkomma-Geldbetrag in Cents (100 == 1,00 €).
public typealias Cents = Int

private let eurFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.currencyCode = "EUR"
    f.locale = Locale(identifier: "de_DE")
    f.maximumFractionDigits = 0
    f.minimumFractionDigits = 0
    return f
}()

/// Formatiert einen Cent-Betrag als ganzzahligen Euro-String, z. B. "120.000 €".
public func eur(_ cents: Cents) -> String {
    let euros = (Double(cents) / 100).rounded()
    return eurFormatter.string(from: NSNumber(value: euros)) ?? "\(Int(euros)) €"
}

private func pctFormatter(_ digits: Int) -> NumberFormatter {
    let f = NumberFormatter()
    f.locale = Locale(identifier: "de_DE")
    f.minimumFractionDigits = digits
    f.maximumFractionDigits = digits
    return f
}

/// Formatiert einen Prozentwert (bereits in Prozent, nicht als Anteil), z. B. pct(3.7) == "3,70 %".
public func pct(_ value: Double, _ digits: Int = 2) -> String {
    let s = pctFormatter(digits).string(from: NSNumber(value: value)) ?? "\(value)"
    return s + " %"
}
