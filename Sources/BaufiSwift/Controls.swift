// Wiederverwendbare Eingabe-Bausteine (Bauplan-Stil). Entspricht components/controls.jsx.

import SwiftUI
import BaufiCore

/// Beschriftetes Feld mit optionalem Suffix (z. B. „€", „%").
struct Field<Content: View>: View {
    let label: String
    var suffix: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            MiniLabel(label)
            HStack(spacing: 6) {
                content
                if let suffix {
                    Text(suffix).font(Theme.mono(13)).foregroundStyle(Theme.muted)
                }
            }
        }
    }
}

/// Geldbetrag-Eingabe in Euro, intern als Cents geführt.
struct CentsField: View {
    @Binding var cents: Cents
    var step: Cents = 100

    var body: some View {
        let euros = Binding<Double>(
            get: { Double(cents) / 100 },
            set: { cents = Cents(($0 * 100).rounded()) }
        )
        HStack(spacing: 4) {
            TextField("", value: euros, format: .number.grouping(.automatic))
                .multilineTextAlignment(.trailing)
                .frame(width: 104)
                .blueprintField()
            Stepper("", value: euros, step: Double(step) / 100)
                .labelsHidden()
        }
    }
}

/// Dezimal-Eingabe (Zinssätze, Quoten, Prozentgrenzen).
struct DoubleField: View {
    @Binding var value: Double
    var step: Double = 1
    var range: ClosedRange<Double> = 0...1_000_000

    var body: some View {
        HStack(spacing: 4) {
            TextField("", value: $value, format: .number)
                .multilineTextAlignment(.trailing)
                .frame(width: 64)
                .blueprintField()
            Stepper("", value: $value, in: range, step: step)
                .labelsHidden()
        }
    }
}

/// Ganzzahl-Eingabe (Alter, Renteneintritt, Ansparjahre).
struct IntField: View {
    @Binding var value: Int
    var range: ClosedRange<Int> = 0...200

    var body: some View {
        HStack(spacing: 4) {
            TextField("", value: $value, format: .number)
                .multilineTextAlignment(.trailing)
                .frame(width: 54)
                .blueprintField()
            Stepper("", value: $value, in: range)
                .labelsHidden()
        }
    }
}
