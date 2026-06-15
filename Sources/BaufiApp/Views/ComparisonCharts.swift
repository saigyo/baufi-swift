// Vergleichsdiagramme: Restschuldverlauf + Belastungsquote mit Fokus-Modus.
// Entspricht components/ComparisonCharts.jsx (Recharts → Swift Charts).

import SwiftUI
import Charts
import BaufiCore

struct ComparisonCharts: View {
    let calc: CalcResult
    let rente: Int
    let fokusKey: String?
    let onToggle: (String) -> Void
    let onReset: () -> Void

    @State private var hoverRest: Int?
    @State private var hoverBel: Int?

    private var modelle: [Model] { calc.models.filter { !$0.infeasible } }

    var body: some View {
        VStack(spacing: 14) {
            restschuldCard
            belastungCard
        }
    }

    // MARK: Restschuld

    private var restschuldCard: some View {
        Card(title: "Restschuld bis zur Rente") {
            Chart {
                ForEach(modelle) { m in
                    ForEach(calc.restschuldPoints.filter { $0.key == m.key }) { p in
                        LineMark(
                            x: .value("Alter", p.alter),
                            y: .value("Restschuld", p.value),
                            series: .value("Modell", m.key)
                        )
                    }
                    .foregroundStyle(color(m.key))
                    .lineStyle(StrokeStyle(lineWidth: fokusKey == m.key ? 3 : 2))
                    .opacity(opacity(m.key))
                }
                RuleMark(x: .value("Rente", rente))
                    .foregroundStyle(.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .annotation(position: .top, alignment: .trailing) { tag("Rente") }
                if calc.zielRest > 0 {
                    RuleMark(y: .value("Ablösung", Double(calc.zielRest) / 100))
                        .foregroundStyle(Theme.red)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                        .annotation(position: .top, alignment: .trailing) { tag("Ablösung (z. B. KLV)").foregroundStyle(Theme.red) }
                }
            }
            .chartXAxisLabel("Alter")
            .chartXScale(domain: xDomain(calc.restschuldPoints))
            .chartYScale(domain: 0...restschuldYMax)
            .chartXAxis { jahrAxis() }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: gridDash).foregroundStyle(gridColor)
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text("\(Int(v / 1000))k").font(.system(size: 10, design: .monospaced))
                        }
                    }
                }
            }
            .frame(height: 300)
            .chartLegend(.hidden)
            .chartOverlay { proxy in
                hoverLayer(proxy, alter: $hoverRest, points: calc.restschuldPoints,
                           width: 220) { eur(Cents(($0 * 100).rounded())) }
            }

            legend
            note("Klick auf einen Eintrag in der Legende oder eine Zeile im Modellvergleich hebt das Modell hervor; Klick ins Diagramm setzt zurück.")
        }
    }

    // MARK: Belastungsquote

    private var belastungCard: some View {
        Card(title: "Belastungsquote über die Laufzeit") {
            Chart {
                ForEach(modelle) { m in
                    ForEach(calc.belastungPoints.filter { $0.key == m.key }) { p in
                        LineMark(
                            x: .value("Alter", p.alter),
                            y: .value("Belastung", p.value),
                            series: .value("Modell", m.key)
                        )
                    }
                    .foregroundStyle(color(m.key))
                    .lineStyle(StrokeStyle(lineWidth: fokusKey == m.key ? 3 : 2))
                    .opacity(opacity(m.key))
                }
                RuleMark(y: .value("40 %", 40))
                    .foregroundStyle(Theme.red)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .annotation(position: .trailing) { tag("40 %").foregroundStyle(Theme.red) }
                RuleMark(y: .value("35 %", 35))
                    .foregroundStyle(Theme.amber)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .annotation(position: .trailing) { tag("35 %").foregroundStyle(Theme.amber) }
            }
            .chartXAxisLabel("Alter")
            .chartXScale(domain: xDomain(calc.belastungPoints))
            .chartXAxis { jahrAxis() }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: gridDash).foregroundStyle(gridColor)
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text("\(Int(v)) %").font(.system(size: 10, design: .monospaced))
                        }
                    }
                }
            }
            .chartYScale(domain: 0...max(45, belastungMax))
            .frame(height: 260)
            .chartLegend(.hidden)
            .chartOverlay { proxy in
                hoverLayer(proxy, alter: $hoverBel, points: calc.belastungPoints,
                           width: 200) { pct($0, 1) }
            }

            legend
            note("Monatsrate\(calc.klv > 0 ? " + KLV-Beitrag" : "") ÷ Nettoeinkommen des jeweiligen Jahres bei \(pct(calc.g * 100, 1)) Steigerung p. a. Sprünge durch Anschlussfinanzierung bzw. Bauspar-Zuteilung.")
        }
    }

    private var belastungMax: Double {
        let m = calc.belastungPoints.map(\.value).max() ?? 0
        return (m / 5).rounded(.up) * 5
    }

    /// Obergrenze der Restschuld-Y-Achse = Startschuld, damit die Kurve den Bereich füllt (wie in der Vorlage).
    private var restschuldYMax: Double {
        max(1, calc.restschuldPoints.map(\.value).max() ?? 1)
    }

    // MARK: Legende & Helfer

    private var legend: some View {
        FlowLegend(models: modelle, fokusKey: fokusKey, onToggle: onToggle)
    }

    /// X-Achsen-Bereich aus den Datenpunkten (Alter), damit die Achse nicht bei 0 beginnt.
    private func xDomain(_ pts: [ChartPoint]) -> ClosedRange<Int> {
        let xs = pts.map(\.alter)
        let lo = xs.min() ?? 0
        let hi = xs.max() ?? 1
        return lo...max(hi, lo + 1)
    }

    /// X-Achse mit einem Tick je Lebensjahr (wie in der Vorlage).
    @AxisContentBuilder
    private func jahrAxis() -> some AxisContent {
        AxisMarks(values: .stride(by: 1)) { value in
            AxisGridLine(stroke: gridDash).foregroundStyle(gridColor)
            AxisTick(stroke: gridDash).foregroundStyle(gridColor)
            AxisValueLabel {
                if let y = value.as(Int.self) {
                    Text(verbatim: "\(y)").font(.system(size: 9, design: .monospaced))
                } else if let d = value.as(Double.self) {
                    Text(verbatim: "\(Int(d))").font(.system(size: 9, design: .monospaced))
                }
            }
        }
    }

    private var gridDash: StrokeStyle { StrokeStyle(lineWidth: 0.5, dash: [2, 3]) }
    private var gridColor: Color { Color.secondary.opacity(0.35) }

    private func color(_ key: String) -> Color { Theme.color(forModel: key) }

    private func opacity(_ key: String) -> Double {
        guard let f = fokusKey else { return 1 }
        return f == key ? 1 : 0.18
    }

    private func tag(_ t: String) -> some View {
        Text(t).font(Theme.mono(10)).foregroundStyle(Theme.muted)
    }

    private func note(_ t: String) -> some View {
        NoteText(t)
    }

    // MARK: Mouse-Over (Crosshair + Werte-Tooltip)

    /// Interaktive Ebene über einem Linien-Diagramm: folgt dem Cursor, zeigt eine
    /// senkrechte Hilfslinie, Punkte je Modell und eine Werte-Box (wie in der Web-App).
    @ViewBuilder
    private func hoverLayer(
        _ proxy: ChartProxy,
        alter: Binding<Int?>,
        points: [ChartPoint],
        width: CGFloat,
        format: @escaping (Double) -> String
    ) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let loc):
                            guard let plot = proxy.plotFrame else { return }
                            let rect = geo[plot]
                            if let a = proxy.value(atX: loc.x - rect.minX, as: Int.self) {
                                alter.wrappedValue = snap(a, in: points)
                            }
                        case .ended:
                            alter.wrappedValue = nil
                        }
                    }
                    .onTapGesture { onReset() }

                if let a = alter.wrappedValue, let plot = proxy.plotFrame {
                    let rect = geo[plot]
                    let absX = rect.minX + (proxy.position(forX: a) ?? 0)
                    let rows = hoverRows(points, alter: a, format: format)

                    Group {
                        Rectangle().fill(Theme.muted.opacity(0.45))
                            .frame(width: 1, height: rect.height)
                            .position(x: absX, y: rect.midY)
                        ForEach(rows) { r in
                            if let yrel = proxy.position(forY: r.raw) {
                                Circle().fill(r.color).frame(width: 7, height: 7)
                                    .overlay(Circle().stroke(.white, lineWidth: 1.5))
                                    .position(x: absX, y: rect.minY + yrel)
                            }
                        }
                        ChartTooltip(title: "Alter \(a)",
                                     rows: rows.map { ($0.label, $0.text, $0.color) })
                            .frame(width: width, alignment: .leading)
                            .offset(x: tooltipX(absX, width: width, total: geo.size.width),
                                    y: rect.minY + 6)
                    }
                    .allowsHitTesting(false)
                }
            }
        }
    }

    private func hoverRows(_ points: [ChartPoint], alter: Int,
                           format: (Double) -> String) -> [HoverRow] {
        modelle.compactMap { m in
            guard let p = points.first(where: { $0.key == m.key && $0.alter == alter }) else { return nil }
            return HoverRow(id: m.key, label: m.short, text: format(p.value),
                            color: color(m.key), raw: p.value)
        }
    }

    private func snap(_ a: Int, in points: [ChartPoint]) -> Int {
        let xs = points.map(\.alter)
        guard let lo = xs.min(), let hi = xs.max() else { return a }
        return min(max(a, lo), hi)
    }

    private func tooltipX(_ x: CGFloat, width: CGFloat, total: CGFloat) -> CGFloat {
        let gap: CGFloat = 14
        return x + gap + width <= total ? x + gap : max(0, x - gap - width)
    }
}

/// Eine Zeile im Hover-Tooltip eines Linien-Diagramms.
private struct HoverRow: Identifiable {
    let id: String
    let label: String
    let text: String
    let color: Color
    let raw: Double
}

/// Werte-Box für Mouse-Over (weiß, dünner Rahmen, eckig – Bauplan-Stil).
struct ChartTooltip: View {
    let title: String
    let rows: [(label: String, value: String, color: Color)]

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.ink)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                Text("\(r.label) : \(r.value)")
                    .font(.system(size: 12))
                    .foregroundStyle(r.color)
            }
        }
        .padding(10)
        .background(Color.white)
        .overlay(Rectangle().stroke(Theme.line, lineWidth: 1))
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
    }
}

/// Klickbare Legende (ersetzt die klickbare Recharts-Legende).
struct FlowLegend: View {
    let models: [Model]
    let fokusKey: String?
    let onToggle: (String) -> Void

    var body: some View {
        let columns = [GridItem(.adaptive(minimum: 140), alignment: .leading)]
        LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
            ForEach(models) { m in
                Button { onToggle(m.key) } label: {
                    HStack(spacing: 6) {
                        Rectangle().fill(Theme.color(forModel: m.key)).frame(width: 10, height: 10)
                        Text(m.short).font(.system(size: 12)).foregroundStyle(Theme.ink)
                    }
                    .opacity(fokusKey == nil || fokusKey == m.key ? 1 : 0.4)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Wiederverwendbare Panel-Karte mit Titel (Bauplan-Stil).
struct Card<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SecTitle(title)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelBox(18)
    }
}
