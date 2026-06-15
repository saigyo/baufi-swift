// Portierung von src/lib/persistence.test.js, angepasst an Codable + Base64-Teilcode.

import XCTest
@testable import BaufiCore

final class PersistenceTests: XCTestCase {

    func testShareCodeRoundTrip() {
        var inp = Defaults.inp
        inp.kaufpreis = 65_000_000
        inp.bundesland = "Bayern"
        inp.makler = false
        inp.sonderTilgung = 500_000
        var z = Defaults.z
        z.anschluss = 5.1
        let state = AppStateData(inp: inp, z: z, bsp: Defaults.bsp, modus: .max, limits: [25, 35, 40], stress: 1.5)

        let code = Persistence.encodeShareCode(state)
        XCTAssertFalse(code.isEmpty)
        let decoded = Persistence.decodeShareCode(code)
        XCTAssertEqual(decoded, state)
    }

    func testShareCodeRejectsGarbage() {
        XCTAssertNil(Persistence.decodeShareCode("kein gültiger code !!!"))
        XCTAssertNil(Persistence.decodeShareCode(""))
        // gültiges Base64, aber kein passendes JSON
        XCTAssertNil(Persistence.decodeShareCode(Data("hallo".utf8).base64EncodedString()))
    }

    func testSanitizeFallsBackToDefaults() {
        var inp = Defaults.inp
        inp.bundesland = "Nirgendwo"
        let bad = AppStateData(inp: inp, z: Defaults.z, bsp: Defaults.bsp,
                               modus: .vergleich, limits: [1, 2], stress: -3)
        let code = Persistence.encodeShareCode(bad)
        let fixed = Persistence.decodeShareCode(code)!
        XCTAssertEqual(fixed.inp.bundesland, Defaults.inp.bundesland)
        XCTAssertEqual(fixed.limits, Defaults.limits)
        XCTAssertEqual(fixed.stress, 0)
    }

    func testLoadReturnsDefaultsWhenEmpty() {
        let store = UserDefaults(suiteName: "baufi.tests.\(UUID().uuidString)")!
        let loaded = Persistence.load(from: store)
        XCTAssertEqual(loaded, Defaults.state)
    }

    func testSaveLoadRoundTrip() {
        let store = UserDefaults(suiteName: "baufi.tests.\(UUID().uuidString)")!
        var state = Defaults.state
        state.inp.kaufpreis = 72_500_000
        state.stress = 2.0
        Persistence.save(state, to: store)
        XCTAssertEqual(Persistence.load(from: store), state)
    }
}
