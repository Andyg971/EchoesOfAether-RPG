import XCTest
@testable import EchoesOfAether

/// Tests de l'Arbre de l'Aether : économie de points, verrous de progression,
/// bonus dérivés, refonte et persistance.
@MainActor
final class SkillTreeTests: XCTestCase {

    private func maxedPlayer() -> PlayerState {
        let p = PlayerState()
        p.level = PlayerState.maxLevel
        return p
    }

    private func node(_ id: String) -> SkillNode {
        guard let n = SkillTree.node(id: id) else {
            fatalError("nœud inconnu dans le registre : \(id)")
        }
        return n
    }

    // MARK: - Économie de points

    func testPointsTotalIsOnePerLevelAfterTheFirst() {
        let p = PlayerState()
        XCTAssertEqual(p.skillPointsTotal, 0, "Au niveau 1, aucun point")
        p.level = 10
        XCTAssertEqual(p.skillPointsTotal, 9)
        p.level = PlayerState.maxLevel
        XCTAssertEqual(p.skillPointsTotal, PlayerState.maxLevel - 1)
    }

    /// L'invariant de design : l'arbre contient plus de contenu que de points
    /// gagnables, donc on ne peut pas tout prendre — c'est ce qui en fait un
    /// choix de build et non une check-list.
    func testTreeOffersMoreContentThanEarnablePoints() {
        let totalCost = SkillTree.allNodes.reduce(0) { $0 + $1.maxRank * $1.costPerRank }
        XCTAssertEqual(totalCost, 39)
        XCTAssertGreaterThan(totalCost, PlayerState.maxLevel - 1,
                             "Tout maxer doit rester impossible")
    }

    func testUnlockSpendsPoints() {
        let p = maxedPlayer()
        let before = p.skillPointsAvailable
        XCTAssertTrue(p.unlockSkill(node("blade.attack")))
        XCTAssertEqual(p.skillRank("blade.attack"), 1)
        XCTAssertEqual(p.skillPointsAvailable, before - 1)
    }

    func testUnlockRespectsMaxRank() {
        let p = maxedPlayer()
        let n = node("blade.attack")
        for _ in 0..<n.maxRank { XCTAssertTrue(p.unlockSkill(n)) }
        XCTAssertEqual(p.skillRank(n.id), n.maxRank)
        XCTAssertFalse(p.unlockSkill(n), "Au rang max, plus d'investissement")
        XCTAssertEqual(p.skillLock(for: n), .maxed)
    }

    func testCannotSpendMorePointsThanEarned() {
        let p = PlayerState()
        p.level = 2                       // 1 seul point
        XCTAssertTrue(p.unlockSkill(node("blade.attack")))
        XCTAssertEqual(p.skillPointsAvailable, 0)
        XCTAssertFalse(p.unlockSkill(node("blade.attack")))
        XCTAssertEqual(p.skillLock(for: node("blade.attack")), .notEnoughPoints)
    }

    // MARK: - Verrous de voie

    func testTierGatingRequiresPointsInSameBranch() {
        let p = maxedPlayer()
        let crit = node("blade.crit")          // tier 1 → exige 2 dans la voie
        XCTAssertEqual(p.skillLock(for: crit), .needsBranchPoints(2))

        p.unlockSkill(node("blade.attack"))
        XCTAssertEqual(p.skillLock(for: crit), .needsBranchPoints(1))
        p.unlockSkill(node("blade.attack"))
        XCTAssertNil(p.skillLock(for: crit), "2 points investis → tier 1 ouvert")
    }

    /// Investir dans une AUTRE voie n'ouvre pas les tiers de celle-ci.
    func testBranchGatingIsPerBranch() {
        let p = maxedPlayer()
        for _ in 0..<3 { p.unlockSkill(node("aether.mp")) }
        XCTAssertEqual(p.skillPointsSpent(in: .aether), 3)
        XCTAssertEqual(p.skillPointsSpent(in: .blade), 0)
        XCTAssertEqual(p.skillLock(for: node("blade.crit")), .needsBranchPoints(2))
    }

    func testCapstoneRequiresDeepInvestment() {
        let p = maxedPlayer()
        let capstone = node("blade.capstone")
        XCTAssertEqual(capstone.branchRequirement, 8)
        XCTAssertEqual(p.skillLock(for: capstone), .needsBranchPoints(8))

        for _ in 0..<3 { p.unlockSkill(node("blade.attack")) }   // 3
        for _ in 0..<3 { p.unlockSkill(node("blade.crit")) }     // 6
        XCTAssertEqual(p.skillLock(for: capstone), .needsBranchPoints(2))
        p.unlockSkill(node("blade.slash"))                       // 8
        XCTAssertNil(p.skillLock(for: capstone))
        XCTAssertTrue(p.unlockSkill(capstone))
        XCTAssertTrue(p.hasDoubleSlash)
    }

    // MARK: - Bonus dérivés

    func testBladeBonusesFeedDerivedStats() {
        let p = maxedPlayer()
        let atk = p.attackDamage, crit = p.critChance, slash = p.blackSlashDamage
        for _ in 0..<3 { p.unlockSkill(node("blade.attack")) }
        for _ in 0..<3 { p.unlockSkill(node("blade.crit")) }
        p.unlockSkill(node("blade.slash"))
        XCTAssertEqual(p.attackDamage, atk + 9)
        XCTAssertEqual(p.critChance, crit + 0.09, accuracy: 0.0001)
        XCTAssertEqual(p.blackSlashDamage, slash + 14)
    }

    func testAetherAndBreathBonusesFeedDerivedStats() {
        let p = maxedPlayer()
        let mp = p.maxMP, hp = p.currentMaxHP
        let dodge = p.dodgeChance, regen = p.attackMPRegen

        for _ in 0..<3 { p.unlockSkill(node("aether.mp")) }
        for _ in 0..<3 { p.unlockSkill(node("aether.power")) }
        p.unlockSkill(node("aether.regen"))
        for _ in 0..<3 { p.unlockSkill(node("breath.hp")) }
        for _ in 0..<3 { p.unlockSkill(node("breath.dodge")) }
        p.unlockSkill(node("breath.ward"))

        XCTAssertEqual(p.maxMP, mp + 24)
        XCTAssertEqual(p.currentMaxHP, hp + 54)
        XCTAssertEqual(p.attackMPRegen, regen + 4)
        XCTAssertEqual(p.dodgeChance, dodge + 0.09, accuracy: 0.0001)
        XCTAssertEqual(p.spellPowerMultiplier, 1.18, accuracy: 0.0001)
        XCTAssertEqual(p.skillDamageReduction, 0.04, accuracy: 0.0001)
    }

    /// Un rang de PV doit se ressentir tout de suite, pas au prochain repos.
    func testHPNodeCreditsCurrentHP() {
        let p = maxedPlayer()
        p.currentHP = 100
        p.unlockSkill(node("breath.hp"))
        XCTAssertEqual(p.currentHP, 118)
    }

    func testCapstonesAreOffByDefault() {
        let p = maxedPlayer()
        XCTAssertFalse(p.hasDoubleSlash)
        XCTAssertFalse(p.hasTwinTempest)
        XCTAssertFalse(p.hasLastBreath)
    }

    // MARK: - Refonte

    func testRespecRefundsEveryPoint() {
        let p = maxedPlayer()
        for _ in 0..<3 { p.unlockSkill(node("blade.attack")) }
        for _ in 0..<3 { p.unlockSkill(node("blade.crit")) }
        XCTAssertEqual(p.skillPointsSpent, 6)

        p.respecSkills()
        XCTAssertEqual(p.skillPointsSpent, 0)
        XCTAssertEqual(p.skillPointsAvailable, p.skillPointsTotal)
        XCTAssertEqual(p.skillRank("blade.attack"), 0)
        XCTAssertEqual(p.attackDamage, PlayerState().attackDamage
                       + (PlayerState.maxLevel - 1) * 2)
    }

    /// La refonte ne doit pas laisser Kael au-dessus de ses PV max.
    func testRespecClampsCurrentHP() {
        let p = maxedPlayer()
        for _ in 0..<3 { p.unlockSkill(node("breath.hp")) }
        p.currentHP = p.currentMaxHP
        p.respecSkills()
        XCTAssertLessThanOrEqual(p.currentHP, p.currentMaxHP)
    }

    func testRespecCostGrowsWithLevel() {
        XCTAssertLessThan(SkillTree.respecCost(level: 1),
                          SkillTree.respecCost(level: PlayerState.maxLevel))
    }

    // MARK: - Persistance

    func testSaveRoundTripPreservesRanks() throws {
        let p = maxedPlayer()
        for _ in 0..<2 { p.unlockSkill(node("blade.attack")) }
        p.unlockSkill(node("aether.mp"))

        let data = try JSONDecoder().decode(
            SaveData.self,
            from: try JSONEncoder().encode(p.toSaveData(phase: .act3, resonance: 0)))
        let loaded = PlayerState()
        loaded.load(from: data)

        XCTAssertEqual(loaded.skillRank("blade.attack"), 2)
        XCTAssertEqual(loaded.skillRank("aether.mp"), 1)
        XCTAssertEqual(loaded.skillPointsSpent, p.skillPointsSpent)
    }

    /// Save trafiquée ou nœud rééquilibré à la baisse : pas de bonus fantôme.
    func testLoadClampsBogusRanks() {
        let p = maxedPlayer()
        p.skillRanks = ["blade.attack": 99, "inconnu.node": 3, "aether.mp": -2]
        let loaded = PlayerState()
        loaded.load(from: p.toSaveData(phase: .village, resonance: 0))

        XCTAssertEqual(loaded.skillRank("blade.attack"), node("blade.attack").maxRank)
        XCTAssertEqual(loaded.skillRank("inconnu.node"), 0)
        XCTAssertEqual(loaded.skillRank("aether.mp"), 0)
    }

    /// Saves antérieures à l'arbre : la clé `skillRanks` est absente du JSON.
    /// Le décodage doit passer et laisser l'arbre vide, sans crash.
    func testLoadingLegacySaveLeavesTreeEmpty() throws {
        let legacy = PlayerState()
        legacy.level = 12
        for _ in 0..<2 { legacy.unlockSkill(node("blade.attack")) }

        // On retire la clé pour reproduire une sauvegarde d'avant l'arbre.
        let encoded = try JSONEncoder().encode(
            legacy.toSaveData(phase: .forest, resonance: 0))
        var json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertNotNil(json["skillRanks"], "La clé doit exister avant retrait")
        json.removeValue(forKey: "skillRanks")

        let data = try JSONDecoder().decode(
            SaveData.self,
            from: try JSONSerialization.data(withJSONObject: json))
        let loaded = PlayerState()
        loaded.load(from: data)

        XCTAssertTrue(loaded.skillRanks.isEmpty)
        XCTAssertEqual(loaded.skillPointsAvailable, 11)
    }

    /// New Game+ : le build fait partie des acquis, comme l'arme et l'armure.
    func testNewGamePlusSeedCarriesRanks() {
        let p = maxedPlayer()
        for _ in 0..<3 { p.unlockSkill(node("blade.attack")) }

        let seed = NewGamePlusSeed(from: p.toSaveData(phase: .act4, resonance: 0))
        let fresh = PlayerState()
        fresh.applyNewGamePlusSeed(seed)

        XCTAssertEqual(fresh.skillRank("blade.attack"), 3)
        XCTAssertEqual(fresh.newGamePlus, 1)
    }
}
