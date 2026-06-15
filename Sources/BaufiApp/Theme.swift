// Design-System (Bauplan-Stil), portiert aus src/styles.js: Farbpalette,
// Schrift-Helfer und Modell-/Limit-Farben.

import SwiftUI

extension Color {
    init(hex: String) {
        let h = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

enum Theme {
    // MARK: Palette (entspricht den CSS-Variablen)
    static let bg = Color(hex: "E9ECEA")        // --bg
    static let panel = Color(hex: "FFFFFF")     // --panel
    static let ink = Color(hex: "1C2826")       // --ink
    static let muted = Color(hex: "5C6B66")     // --muted
    static let line = Color(hex: "CBD4CF")      // --line
    static let accent = Color(hex: "2E7D5B")    // --accent
    static let warn = Color(hex: "A5524B")      // --warn
    static let amber = Color(hex: "B0762B")     // --amber
    static let fieldBg = Color(hex: "FBFCFB")
    static let bestBg = ink
    static let bestText = Color(hex: "C9D4CE")
    static let bestTag = Color(hex: "9FD9BD")
    static let bestTagBorder = Color(hex: "6E8A7F")
    static let bestRow = Color(hex: "EFF6F2")
    static let fokusRow = Color(hex: "DCEBE3")

    // Aliasse für bestehende Aufrufe
    static var green: Color { accent }
    static var red: Color { warn }

    // MARK: Schriften (Archivo → kondensierte System-Schrift, Zahlen → Monospace)
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight).width(.condensed)
    }
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    // MARK: Modell-/Limit-Farben
    static let modelColors: [String: Color] = [
        "a10": Color(hex: "8FB3D9"), "a15": Color(hex: "4F81B3"), "a20": Color(hex: "1F4E79"),
        "vt": Color(hex: "2E7D5B"), "kfw": Color(hex: "C07A2E"), "bsp": Color(hex: "A5524B"),
    ]
    static let limitColors: [Color] = [Color(hex: "9DBBAA"), Color(hex: "5F8F77"), Color(hex: "2E5C46")]

    static func color(forModel key: String) -> Color { modelColors[key] ?? .gray }

    /// Ampelfarbe für eine Belastungsquote (Schwellen 35 % / 40 %).
    static func belastungColor(_ v: Double) -> Color {
        v > 40 ? warn : (v > 35 ? amber : accent)
    }
}
