// Persistenz: Auto-Speichern (UserDefaults) und Teil-Code (Base64-JSON).
// Ersetzt die URL-Persistenz der Web-App (src/lib/persistence.js).

import Foundation

public enum Persistence {
    static let defaultsKey = "baufi.appstate.v1"

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }()
    private static let decoder = JSONDecoder()

    /// Validiert/normalisiert geladene Daten (Fallback auf Defaults bei Unfug).
    static func sanitized(_ data: AppStateData) -> AppStateData {
        var d = data
        if GREST[d.inp.bundesland] == nil { d.inp.bundesland = Defaults.inp.bundesland }
        if d.stress < 0 { d.stress = 0 }
        if d.limits.count != Defaults.limits.count || d.limits.contains(where: { !$0.isFinite }) {
            d.limits = Defaults.limits
        }
        return d
    }

    // MARK: Teil-Code (Base64-JSON über die Zwischenablage)

    public static func encodeShareCode(_ state: AppStateData) -> String {
        guard let json = try? encoder.encode(state) else { return "" }
        return json.base64EncodedString()
    }

    public static func decodeShareCode(_ code: String) -> AppStateData? {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let json = Data(base64Encoded: trimmed),
              let state = try? decoder.decode(AppStateData.self, from: json)
        else { return nil }
        return sanitized(state)
    }

    // MARK: Auto-Speichern (UserDefaults)

    public static func save(_ state: AppStateData, to store: UserDefaults = .standard) {
        guard let json = try? encoder.encode(state) else { return }
        store.set(json, forKey: defaultsKey)
    }

    public static func load(from store: UserDefaults = .standard) -> AppStateData {
        guard let json = store.data(forKey: defaultsKey),
              let state = try? decoder.decode(AppStateData.self, from: json)
        else { return Defaults.state }
        return sanitized(state)
    }
}
