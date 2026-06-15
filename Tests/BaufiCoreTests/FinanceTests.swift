// Portierung von src/lib/finance.test.js. Wegen der Festkomma-Rundung (Zins und
// Rate je Periode auf den Cent) wird die Ziel-Restschuld auf wenige Euro genau
// getroffen statt exakt – die Invarianten verwenden daher eine Cent-Toleranz.

import XCTest
@testable import BaufiCore

final class FinanceTests: XCTestCase {
    let Z = Defaults.z
    let BSP = Defaults.bsp
    let D: Cents = 40_000_000          // 400.000 €
    let N = 29 * 12                    // 348 Monate
    var PHASEN: [Phase] { [Phase(rate: 3.7, months: 180), Phase(rate: 4.2, months: INF_MONTHS)] }

    /// Toleranz für rundungsbedingte Abweichung der Ziel-Restschuld (in Cents).
    /// Cross-Check gegen das JS-Original: Drift liegt real bei ≤ ~2 €.
    let landeTol: Cents = 500          // 5 €

    func tilgungsMonat(_ loan: Loan) -> Int {
        loan.restArr.firstIndex(where: { $0 <= 0 }) ?? -1
    }

    // MARK: annuityPayment

    func testAnnuityKnownValue() {
        // 100.000 € zu 6 % über 120 Monate: Lehrbuchbeispiel 1110,21 €
        XCTAssertEqual(annuityPayment(10_000_000, 6, 120), 111_021, accuracy: 1)
    }

    func testAnnuityLinearAtZeroRate() {
        XCTAssertEqual(annuityPayment(12_000_000, 0, 120), 100_000)             // 1000 €
        XCTAssertEqual(annuityPayment(12_000_000, 0, 120, residual: 6_000_000), 50_000)  // 500 €
    }

    func testAnnuityInvalidInputs() {
        XCTAssertEqual(annuityPayment(0, 3.7, 120), 0)
        XCTAssertEqual(annuityPayment(-1, 3.7, 120), 0)
        XCTAssertEqual(annuityPayment(10_000_000, 3.7, 0), 0)
        XCTAssertEqual(annuityPayment(5_000_000, 3.7, 120, residual: 10_000_000), 0)  // Restschuld > Darlehen
    }

    // MARK: annuLoan

    func testAnnuLoanTwoPhasesAndLengths() {
        let loan = annuLoan(D, N, PHASEN)
        XCTAssertEqual(loan.restArr.count, N + 1)
        XCTAssertEqual(loan.payArr.count, N)
        XCTAssertEqual(loan.restArr[0], D)
        XCTAssertLessThan(abs(loan.restArr[N]), landeTol)
    }

    func testAnnuLoanRateConstantPerPhase() {
        let loan = annuLoan(D, N, PHASEN)
        XCTAssertEqual(loan.payArr[0], loan.payArr[179])
        XCTAssertEqual(loan.payArr[180], loan.payArr[N - 1])
        XCTAssertGreaterThan(loan.payArr[180], loan.payArr[179])   // Anschluss 4,2 % > 3,7 %
    }

    func testAnnuLoanSumBalance() {
        let loan = annuLoan(D, N, PHASEN)
        let summe = loan.payArr.reduce(0, +)
        XCTAssertLessThan(abs(summe - (D + loan.interest)), landeTol)
    }

    func testAnnuLoanEndsAtTarget() {
        let ziel: Cents = 8_000_000   // 80.000 €
        let loan = annuLoan(D, N, PHASEN, ziel: ziel)
        XCTAssertEqual(loan.restArr[N], ziel, accuracy: landeTol)
    }

    func testAnnuLoanMonotonicallyDecreasing() {
        let loan = annuLoan(D, N, PHASEN, ziel: 8_000_000)
        for i in 1..<loan.restArr.count {
            XCTAssertLessThanOrEqual(loan.restArr[i], loan.restArr[i - 1])
        }
    }

    // MARK: annuLoan – Sondertilgung

    func testSondertilgungKeepsStartRate() {
        let base = annuLoan(D, N, PHASEN)
        let sonder = annuLoan(D, N, PHASEN, ziel: 0, sonderJahr: 500_000)
        XCTAssertEqual(sonder.payArr[0], base.payArr[0])
    }

    func testSondertilgungAppliedAtYearEnd() {
        let base = annuLoan(D, N, PHASEN)
        let sonder = annuLoan(D, N, PHASEN, ziel: 0, sonderJahr: 500_000)   // 5.000 €
        XCTAssertEqual(sonder.restArr[12], base.restArr[12] - 500_000)
        XCTAssertEqual(sonder.restArr[11], base.restArr[11])
    }

    func testSondertilgungReducesCostsAndPayoff() {
        let base = annuLoan(D, N, PHASEN)
        let sonder = annuLoan(D, N, PHASEN, ziel: 0, sonderJahr: 500_000)
        XCTAssertLessThan(sonder.interest, base.interest)
        XCTAssertLessThan(sonder.payArr[180], base.payArr[180])
        XCTAssertLessThan(tilgungsMonat(sonder), tilgungsMonat(base) == -1 ? N + 1 : tilgungsMonat(base))
        XCTAssertEqual(tilgungsMonat(base), -1)   // Basis tilgt erst exakt am Laufzeitende (kein <=0 davor)
    }

    func testSondertilgungDoesNotUndercutTarget() {
        let loan = annuLoan(D, N, PHASEN, ziel: 8_000_000, sonderJahr: 5_000_000)
        XCTAssertGreaterThanOrEqual(loan.restArr.min() ?? 0, 0)
        XCTAssertLessThanOrEqual(loan.restArr[N], 8_000_000 + landeTol)
    }

    func testSondertilgungStopsPaymentsAfterPayoff() {
        let loan = annuLoan(D, N, PHASEN, ziel: 0, sonderJahr: 10_000_000)
        let ende = tilgungsMonat(loan)
        XCTAssertGreaterThan(ende, 0)
        XCTAssertLessThan(ende, 60)
        XCTAssertTrue(loan.restArr.allSatisfy { $0 >= 0 })
        XCTAssertTrue(loan.payArr[ende...].allSatisfy { $0 == 0 })
        XCTAssertEqual(loan.restArr.count, N + 1)   // Padding bleibt erhalten
    }

    // MARK: addLoans

    func testAddLoans() {
        let a = annuLoan(10_000_000, N, [Phase(rate: 3.4, months: 120), Phase(rate: 4.2, months: INF_MONTHS)])
        let b = annuLoan(30_000_000, N, [Phase(rate: 3.7, months: 180), Phase(rate: 4.2, months: INF_MONTHS)])
        let sum = addLoans(a, b)
        XCTAssertEqual(sum.interest, a.interest + b.interest)
        XCTAssertEqual(sum.restArr[0], 40_000_000)
        XCTAssertEqual(sum.restArr[200], a.restArr[200] + b.restArr[200])
        XCTAssertEqual(sum.payArr[0], a.payArr[0] + b.payArr[0])
    }

    // MARK: buildModels

    func testBuildModelsOrder() {
        let keys = buildModels(D, N, Z, BSP).map { $0.key }
        XCTAssertEqual(keys, ["a10", "a15", "a20", "vt", "kfw", "bsp"])
    }

    func testBuildModelsAllReachTarget() {
        let ziel: Cents = 5_000_000
        for m in buildModels(D, N, Z, BSP, ziel: ziel) where !m.infeasible {
            XCTAssertEqual(m.loan!.restArr[N], ziel, accuracy: landeTol, m.key)
        }
    }

    func testVolltilger() {
        let vt = buildModels(D, N, Z, BSP).first { $0.key == "vt" }!
        XCTAssertNil(vt.rate2)
        XCTAssertEqual(vt.rate1, vt.rateMax)
    }

    func testKfWCombo() {
        let kfw = buildModels(D, N, Z, BSP).first { $0.key == "kfw" }!
        XCTAssertTrue(kfw.hinweis.contains("100.000"))
        XCTAssertLessThan(abs(kfw.loan!.restArr[N]), landeTol)
        let klein = buildModels(8_000_000, N, Z, BSP, ziel: 0, sonder: 200_000).first { $0.key == "kfw" }!
        XCTAssertLessThan(abs(klein.loan!.restArr[N]), landeTol)
    }

    func testBausparInfeasibleWhenSavingTooLong() {
        var bspCfg = BSP
        bspCfg.ansparJahre = 30
        let bsp = buildModels(D, N, Z, bspCfg).first { $0.key == "bsp" }!
        XCTAssertTrue(bsp.infeasible)
    }

    func testStressOnlyAffectsFollowUpFinancing() {
        let basis = buildModels(D, N, Z, BSP)
        var zStress = Z
        zStress.anschluss = Z.anschluss + 2
        let stress = buildModels(D, N, zStress, BSP)
        func zk(_ models: [Model], _ key: String) -> Cents { models.first { $0.key == key }!.zinskosten }
        XCTAssertGreaterThan(zk(stress, "a10"), zk(basis, "a10"))
        XCTAssertGreaterThan(zk(stress, "kfw"), zk(basis, "kfw"))
        XCTAssertEqual(zk(stress, "vt"), zk(basis, "vt"))
        XCTAssertEqual(zk(stress, "bsp"), zk(basis, "bsp"))
    }

    // MARK: summarize (über buildModels-Felder)

    func testSummaryFields() {
        let a15 = buildModels(D, N, Z, BSP).first { $0.key == "a15" }!
        XCTAssertEqual(a15.rate1, a15.loan!.payArr[0])
        XCTAssertEqual(a15.payoffMonth, N)
        XCTAssertLessThan(abs(a15.restRente), landeTol)
        XCTAssertFalse(a15.infeasible)
    }

    func testSummaryReachesTargetEarlyWithSonder() {
        let a15 = buildModels(D, N, Z, BSP, ziel: 8_000_000, sonder: 2_000_000).first { $0.key == "a15" }!
        XCTAssertLessThan(a15.payoffMonth, N)
        XCTAssertLessThanOrEqual(a15.restRente, 8_000_000 + landeTol)
    }
}
