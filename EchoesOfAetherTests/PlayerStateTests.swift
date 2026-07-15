import XCTest
@testable import EchoesOfAether

/// Tests de la courbe d'XP et du système de niveau de `PlayerState`.
///
/// ⚠️ Cette cible de test n'est PAS encore référencée dans le projet Xcode.
/// Pour l'activer : Xcode → File → New → Target → Unit Testing Bundle
/// (« EchoesOfAetherTests »), puis ajouter ces fichiers à la cible. Le build
/// de l'app principale n'est pas affecté tant que la cible n'existe pas.
@MainActor
final class PlayerStateTests: XCTestCase {

    func testXPForLevelIsIncreasing() {
        var previous = 0
        for level in 1..<PlayerState.maxLevel {
            let need = PlayerState.xpForLevel(level)
            XCTAssertGreaterThan(need, 0)
            XCTAssertLessThan(need, Int.max)
            XCTAssertGreaterThan(need, previous,
                                 "La courbe d'XP doit croître à chaque niveau")
            previous = need
        }
    }

    func testXPForLevelFormula() {
        // 80 * n^1.5
        XCTAssertEqual(PlayerState.xpForLevel(1), Int(80.0 * pow(1.0, 1.5)))
        XCTAssertEqual(PlayerState.xpForLevel(4), Int(80.0 * pow(4.0, 1.5))) // 80*8 = 640
    }

    /// La réserve de Magie croît avec le niveau (L1 = 30, +4 par niveau).
    func testMaxMPScalesWithLevel() {
        let p = PlayerState()
        p.level = 1
        XCTAssertEqual(p.maxMP, 30)
        p.level = 10
        XCTAssertEqual(p.maxMP, 30 + 9 * 4)   // 66
        p.level = PlayerState.maxLevel
        XCTAssertEqual(p.maxMP, 30 + (PlayerState.maxLevel - 1) * 4)   // 146
    }

    func testXPForLevelOutOfBounds() {
        XCTAssertEqual(PlayerState.xpForLevel(0), Int.max)
        XCTAssertEqual(PlayerState.xpForLevel(PlayerState.maxLevel), Int.max)
        XCTAssertEqual(PlayerState.xpForLevel(PlayerState.maxLevel + 5), Int.max)
    }

    func testGainXPSingleLevelUp() {
        let player = PlayerState()
        XCTAssertEqual(player.level, 1)
        let gained = player.gainXP(PlayerState.xpForLevel(1))
        XCTAssertEqual(gained, 1)
        XCTAssertEqual(player.level, 2)
        XCTAssertEqual(player.xp, 0)
    }

    func testGainXPKeepsRemainder() {
        let player = PlayerState()
        let need = PlayerState.xpForLevel(1)
        let gained = player.gainXP(need + 10)
        XCTAssertEqual(gained, 1)
        XCTAssertEqual(player.level, 2)
        XCTAssertEqual(player.xp, 10)
    }

    func testGainXPMultiLevel() {
        let player = PlayerState()
        // Un gros paquet d'XP doit faire monter plusieurs niveaux d'un coup.
        let gained = player.gainXP(100_000)
        XCTAssertGreaterThan(gained, 1)
        XCTAssertGreaterThan(player.level, 2)
    }

    func testGainXPCapsAtMaxLevel() {
        let player = PlayerState()
        _ = player.gainXP(10_000_000)
        XCTAssertEqual(player.level, PlayerState.maxLevel)
        XCTAssertEqual(player.xp, 0, "XP remis à 0 au plafond pour un affichage propre")
        XCTAssertEqual(player.xpProgress, 1)

        // Plus aucun gain au plafond.
        let extra = player.gainXP(5_000)
        XCTAssertEqual(extra, 0)
        XCTAssertEqual(player.level, PlayerState.maxLevel)
    }

    func testGainXPIgnoresNonPositive() {
        let player = PlayerState()
        XCTAssertEqual(player.gainXP(0), 0)
        XCTAssertEqual(player.gainXP(-50), 0)
        XCTAssertEqual(player.level, 1)
        XCTAssertEqual(player.xp, 0)
    }

    func testDerivedStatsScaleWithLevel() {
        let player = PlayerState()
        let atkL1 = player.attackDamage
        let hpL1 = player.currentMaxHP
        _ = player.gainXP(100_000)
        XCTAssertGreaterThan(player.attackDamage, atkL1)
        XCTAssertGreaterThan(player.currentMaxHP, hpL1)
    }
}
