import XCTest
@testable import EchoesOfAether

/// Les formules du combat, testées sans scène.
///
/// Trois capstones de l'Arbre de l'Aether n'avaient jamais eu que des
/// captures d'écran pour preuve — et Tempête jumelle comme Dernier souffle
/// n'avaient même pas ça. Ici chaque branche est une assertion.
final class CombatMathTests: XCTestCase {

    // MARK: - Multiplicateurs

    func testActionMultiplierStacksBoostAndTimedStrike() {
        XCTAssertEqual(CombatMath.actionMultiplier(boost: 0, timedStrike: false), 1.0)
        XCTAssertEqual(CombatMath.actionMultiplier(boost: 1, timedStrike: false), 1.55, accuracy: 0.0001)
        XCTAssertEqual(CombatMath.actionMultiplier(boost: 3, timedStrike: false), 2.65, accuracy: 0.0001)
        XCTAssertEqual(CombatMath.actionMultiplier(boost: 0, timedStrike: true), 1.35, accuracy: 0.0001)
        // Les deux se cumulent : bien jouer les deux récompense vraiment.
        XCTAssertEqual(CombatMath.actionMultiplier(boost: 2, timedStrike: true),
                       2.10 * 1.35, accuracy: 0.0001)
    }

    func testComboMultiplierSteps() {
        XCTAssertEqual(CombatMath.comboMultiplierTenths(comboCount: 1), 10)
        XCTAssertEqual(CombatMath.comboMultiplierTenths(comboCount: 2), 10)
        XCTAssertEqual(CombatMath.comboMultiplierTenths(comboCount: 3), 12)
        XCTAssertEqual(CombatMath.comboMultiplierTenths(comboCount: 4), 12)
        XCTAssertEqual(CombatMath.comboMultiplierTenths(comboCount: 5), 14)
        XCTAssertEqual(CombatMath.comboMultiplierTenths(comboCount: 99), 14)
    }

    // MARK: - Attaque physique

    func testAttackDamageBaseline() {
        XCTAssertEqual(CombatMath.attackDamage(base: 100, comboCount: 1, multiplier: 1,
                                               isCrit: false, targetBroken: false), 100)
    }

    /// L'ordre des arrondis est celui du code d'origine : division entière
    /// du combo AVANT conversion. 42 × 12 / 10 = 50 (pas 50,4).
    func testAttackDamagePreservesOriginalRoundingOrder() {
        XCTAssertEqual(CombatMath.attackDamage(base: 42, comboCount: 3, multiplier: 1,
                                               isCrit: false, targetBroken: false), 50)
    }

    func testAttackDamageCritAndBreakStack() {
        let plain = CombatMath.attackDamage(base: 100, comboCount: 1, multiplier: 1,
                                            isCrit: false, targetBroken: false)
        let crit = CombatMath.attackDamage(base: 100, comboCount: 1, multiplier: 1,
                                           isCrit: true, targetBroken: false)
        let broken = CombatMath.attackDamage(base: 100, comboCount: 1, multiplier: 1,
                                             isCrit: false, targetBroken: true)
        let both = CombatMath.attackDamage(base: 100, comboCount: 1, multiplier: 1,
                                           isCrit: true, targetBroken: true)
        XCTAssertEqual(crit, 150)
        XCTAssertEqual(broken, 180)
        XCTAssertEqual(both, 270, "critique puis BREAK : 100 → 150 → 270")
        XCTAssertGreaterThan(both, max(crit, broken))
        XCTAssertEqual(plain, 100)
    }

    // MARK: - Entaille noire et ENTAILLE DOUBLE

    func testBlackSlashDamage() {
        XCTAssertEqual(CombatMath.blackSlashDamage(base: 200, multiplier: 1,
                                                   isCrit: false, targetBroken: false), 200)
        XCTAssertEqual(CombatMath.blackSlashDamage(base: 200, multiplier: 1.55,
                                                   isCrit: false, targetBroken: false), 310)
        XCTAssertEqual(CombatMath.blackSlashDamage(base: 200, multiplier: 1,
                                                   isCrit: true, targetBroken: true), 540)
    }

    /// Le capstone de la Lame : second coup à 55 %.
    func testDoubleSlashEchoFiresForKaelWithCapstone() {
        XCTAssertEqual(CombatMath.doubleSlashEcho(primaryDamage: 200, isKael: true,
                                                  hasCapstone: true, targetHPAfterPrimary: 500), 110)
    }

    /// Sans capstone, rien. C'est un choix de build, pas un acquis.
    func testDoubleSlashEchoNeedsCapstone() {
        XCTAssertEqual(CombatMath.doubleSlashEcho(primaryDamage: 200, isKael: true,
                                                  hasCapstone: false, targetHPAfterPrimary: 500), 0)
    }

    /// C'est l'arbre de KAEL : un allié qui porte l'Entaille n'en profite pas.
    func testDoubleSlashEchoIsKaelOnly() {
        XCTAssertEqual(CombatMath.doubleSlashEcho(primaryDamage: 200, isKael: false,
                                                  hasCapstone: true, targetHPAfterPrimary: 500), 0)
    }

    /// On ne frappe pas un cadavre : si le premier coup tue, pas de second.
    /// C'est ce qui s'est passé contre la bête de la forêt lors de l'audit.
    func testDoubleSlashEchoSkipsDeadTarget() {
        XCTAssertEqual(CombatMath.doubleSlashEcho(primaryDamage: 354, isKael: true,
                                                  hasCapstone: true, targetHPAfterPrimary: 0), 0)
    }

    /// Le second coup ne tombe jamais à 0 sur un tout petit premier coup.
    func testDoubleSlashEchoNeverZeroWhenItFires() {
        XCTAssertEqual(CombatMath.doubleSlashEcho(primaryDamage: 1, isKael: true,
                                                  hasCapstone: true, targetHPAfterPrimary: 10), 1)
    }

    // MARK: - Sorts

    func testSpellDamageWeaknessAndBreak() {
        XCTAssertEqual(CombatMath.spellDamage(power: 100, multiplier: 1, spellMultiplier: 1,
                                              hitsWeakness: false, targetBroken: false), 100)
        XCTAssertEqual(CombatMath.spellDamage(power: 100, multiplier: 1, spellMultiplier: 1,
                                              hitsWeakness: true, targetBroken: false), 135)
        XCTAssertEqual(CombatMath.spellDamage(power: 100, multiplier: 1, spellMultiplier: 1,
                                              hitsWeakness: true, targetBroken: true), 243)
    }

    /// La voie de l'Aether (Canalisation) multiplie les sorts de Kael.
    func testSpellDamageUsesSpellMultiplier() {
        let p = PlayerState()
        p.level = PlayerState.maxLevel
        for _ in 0..<3 { p.unlockSkill(SkillTree.node(id: "aether.mp")!) }
        for _ in 0..<3 { p.unlockSkill(SkillTree.node(id: "aether.power")!) }
        XCTAssertEqual(p.spellPowerMultiplier, 1.18, accuracy: 0.0001)
        XCTAssertEqual(CombatMath.spellDamage(power: 100, multiplier: 1,
                                              spellMultiplier: p.spellPowerMultiplier,
                                              hitsWeakness: false, targetBroken: false), 118)
    }

    // MARK: - Coups subis et ÉGIDE

    func testIncomingDamageBlockCutsTo35Percent() {
        XCTAssertEqual(CombatMath.incomingDamage(raw: 100, blocked: true, damageReduction: 0), 35)
        XCTAssertEqual(CombatMath.incomingDamage(raw: 100, blocked: false, damageReduction: 0), 100)
    }

    /// Une parade ne rend jamais invincible : au moins 1 point passe.
    func testIncomingDamageNeverBelowOne() {
        XCTAssertEqual(CombatMath.incomingDamage(raw: 1, blocked: true, damageReduction: 0), 1)
        XCTAssertEqual(CombatMath.incomingDamage(raw: 2, blocked: true, damageReduction: 0.08), 1)
    }

    /// ÉGIDE (voie du Souffle) : 2 rangs = 8 % en moins, après la parade.
    func testIncomingDamageAppliesAegisAfterBlock() {
        XCTAssertEqual(CombatMath.incomingDamage(raw: 100, blocked: false, damageReduction: 0.08), 92)
        XCTAssertEqual(CombatMath.incomingDamage(raw: 100, blocked: true, damageReduction: 0.08), 32)
    }

    // MARK: - DERNIER SOUFFLE

    /// Le capstone du Souffle : le coup fatal laisse Kael à 1 PV.
    func testLastBreathSavesFromFatalHit() {
        let r = CombatMath.applyHitToKael(hp: 50, damage: 80, hasLastBreath: true, lastBreathUsed: false)
        XCTAssertEqual(r.hp, 1)
        XCTAssertTrue(r.lastBreathTriggered)
    }

    /// Sans le capstone, Kael meurt normalement.
    func testLastBreathNeedsCapstone() {
        let r = CombatMath.applyHitToKael(hp: 50, damage: 80, hasLastBreath: false, lastBreathUsed: false)
        XCTAssertEqual(r.hp, 0)
        XCTAssertFalse(r.lastBreathTriggered)
    }

    /// Une seule fois par combat : déjà consommé, il ne rejoue pas.
    func testLastBreathIsOncePerBattle() {
        let r = CombatMath.applyHitToKael(hp: 50, damage: 80, hasLastBreath: true, lastBreathUsed: true)
        XCTAssertEqual(r.hp, 0)
        XCTAssertFalse(r.lastBreathTriggered)
    }

    /// Un coup non fatal ne le consomme pas — sinon il partirait pour rien.
    func testLastBreathNotConsumedByNonFatalHit() {
        let r = CombatMath.applyHitToKael(hp: 100, damage: 30, hasLastBreath: true, lastBreathUsed: false)
        XCTAssertEqual(r.hp, 70)
        XCTAssertFalse(r.lastBreathTriggered)
    }

    /// À 1 PV exactement, un nouveau coup fatal tue : le sursis n'est pas
    /// infini. C'est la garde `hp > 1` du code d'origine.
    func testLastBreathDoesNotLoopAtOneHP() {
        let r = CombatMath.applyHitToKael(hp: 1, damage: 5, hasLastBreath: true, lastBreathUsed: false)
        XCTAssertEqual(r.hp, 0)
        XCTAssertFalse(r.lastBreathTriggered)
    }

    /// Le coup qui tombe pile à 0 est fatal lui aussi.
    func testLastBreathTreatsExactZeroAsFatal() {
        let r = CombatMath.applyHitToKael(hp: 40, damage: 40, hasLastBreath: true, lastBreathUsed: false)
        XCTAssertEqual(r.hp, 1)
        XCTAssertTrue(r.lastBreathTriggered)
    }

    // MARK: - TEMPÊTE JUMELLE

    /// Le capstone de l'Aether : deux Tempêtes par combat au lieu d'une.
    func testTwinTempestDoublesUses() {
        XCTAssertEqual(CombatMath.tempestMaxUses(hasTwinTempest: false), 1)
        XCTAssertEqual(CombatMath.tempestMaxUses(hasTwinTempest: true), 2)
    }

    /// Bout en bout depuis l'arbre : investir le capstone ouvre bien la
    /// seconde Tempête.
    func testTwinTempestFollowsSkillTree() {
        let p = PlayerState()
        p.level = PlayerState.maxLevel
        XCTAssertEqual(CombatMath.tempestMaxUses(hasTwinTempest: p.hasTwinTempest), 1)
        for _ in 0..<3 { p.unlockSkill(SkillTree.node(id: "aether.mp")!) }
        for _ in 0..<3 { p.unlockSkill(SkillTree.node(id: "aether.power")!) }
        for _ in 0..<2 { p.unlockSkill(SkillTree.node(id: "aether.regen")!) }
        XCTAssertTrue(p.unlockSkill(SkillTree.node(id: "aether.capstone")!))
        XCTAssertEqual(CombatMath.tempestMaxUses(hasTwinTempest: p.hasTwinTempest), 2)
    }
}
