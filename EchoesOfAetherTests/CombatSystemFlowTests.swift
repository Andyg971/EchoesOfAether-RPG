import XCTest
import SpriteKit
@testable import EchoesOfAether

/// L'ORCHESTRATION du combat, sur une vraie scène SpriteKit (non présentée).
///
/// `CombatMathTests` verrouille les formules ; ici c'est le câblage qui est
/// testé — ce que `perform`, `resolveEnemyHit` et `checkVictory` FONT de ces
/// formules : dépenser la Magie, refuser une action trop chère, casser un
/// bouclier au bon coup, laisser Kael à 1 PV, clore le combat.
///
/// Sans `SKView`, aucune `SKAction` ne s'exécute : chaque test appelle
/// donc UNE étape synchrone et observe l'état juste après. Les enchaînements
/// à délai (tour suivant, fermeture) restent du ressort du simulateur.
@MainActor
final class CombatSystemFlowTests: XCTestCase {

    private var scene: SKScene!
    private var player: PlayerState!
    private var sut: CombatSystem!
    private var difficultyBefore: Difficulty!

    /// PV de base de l'ennemi ; `attach` les relève (× robustesse × difficulté).
    private let baseEnemyHP = 2_000



    private var foe: CombatSystem.EnemyState { sut.enemies[0] }

    /// Le tour du joueur est relancé à la main entre deux actions (sans
    /// boucle de jeu, `endPlayerAction` ne le fait pas tout seul).
    private func nextPlayerTurn() {
        sut.phase = .playerTurn
    }

    // XCTest déclare setUp/tearDown non isolés et interdit de les isoler : l'état
    // @MainActor se prépare donc au début de chaque test (`prepare()` + `defer`).
    private func prepare() {
        difficultyBefore = Difficulty.current
        Difficulty.current = .normal
        scene = SKScene(size: CGSize(width: 844, height: 390))
        player = PlayerState()
        sut = CombatSystem()
        sut.attach(to: scene, enemyName: "Bête", enemyHP: baseEnemyHP,
                   goldReward: 30, player: player) { _, _ in }
        sut.startPlayerTurn()
    }

    private func cleanup() {
        Difficulty.current = difficultyBefore
        sut = nil; scene = nil; player = nil
    }

    // MARK: - Ouverture

    func test_attach_scalesEnemyAndOpensOnPlayerTurn() {
        prepare()
        defer { cleanup() }
        let expectedHP = Int((Double(baseEnemyHP) * Double(CombatSystem.enemyHPScale)).rounded())
        XCTAssertEqual(foe.combatant.maxHP, expectedHP, "robustesse de base appliquée")
        XCTAssertEqual(foe.combatant.hp, expectedHP)
        XCTAssertEqual(foe.shield, foe.shieldMax)
        XCTAssertEqual(sut.kael.hp, player.currentHP)
        XCTAssertEqual(sut.kael.mp, player.maxMP)
        XCTAssertEqual(sut.phase, .playerTurn)
        XCTAssertEqual(sut.playerBP, 1, "un point de Boost gagné à l'ouverture du tour")
        XCTAssertTrue(sut.isActive)
    }

    // MARK: - Attaque physique

    func test_performAttack_damagesTargetRegensMPAndStartsCombo() {
        prepare()
        defer { cleanup() }
        sut.kael.mp = 10
        let hpBefore = foe.combatant.hp

        sut.perform(.attack)

        let dealt = hpBefore - foe.combatant.hp
        let plain = CombatMath.attackDamage(base: player.attackDamage, comboCount: 1,
                                            multiplier: 1, isCrit: false, targetBroken: false)
        let crit = CombatMath.attackDamage(base: player.attackDamage, comboCount: 1,
                                           multiplier: 1, isCrit: true, targetBroken: false)
        XCTAssertTrue(dealt == plain || dealt == crit, "dégâts \(dealt) ∉ {\(plain), \(crit)}")
        XCTAssertEqual(sut.kael.mp, 10 + player.attackMPRegen, "l'attaque régénère la Magie")
        XCTAssertEqual(sut.comboCount, 1)
        XCTAssertEqual(sut.phase, .playerActing)
        XCTAssertEqual(foe.shield, foe.shieldMax, "le physique ne brise aucun bouclier")
    }

    // MARK: - Magie

    func test_performSpell_withoutEnoughMP_isRefusedAndKeepsTurn() {
        prepare()
        defer { cleanup() }
        sut.kael.mp = CombatSpell.ember.mpCost - 1
        let hpBefore = foe.combatant.hp

        sut.perform(.spell(.ember))

        XCTAssertEqual(foe.combatant.hp, hpBefore, "aucun dégât")
        XCTAssertEqual(sut.kael.mp, CombatSpell.ember.mpCost - 1, "rien dépensé")
        XCTAssertEqual(sut.phase, .playerTurn, "le joueur garde son tour")
    }

    func test_performSpell_spendsMPAndDamages() {
        prepare()
        defer { cleanup() }
        let mpBefore = sut.kael.mp
        let hpBefore = foe.combatant.hp

        sut.perform(.spell(.ember))

        XCTAssertEqual(sut.kael.mp, mpBefore - CombatSpell.ember.mpCost)
        XCTAssertLessThan(foe.combatant.hp, hpBefore)
        XCTAssertEqual(sut.comboCount, 0, "un sort casse le combo physique")
        XCTAssertEqual(sut.phase, .playerActing)
    }

    /// La Bête est faible au feu, bouclier 2 : le premier Brasier entame,
    /// le second BRISE (l'ennemi est à terre pour un tour).
    func test_spellOnWeakness_breaksShieldOnTheLastHit() {
        prepare()
        defer { cleanup() }
        XCTAssertTrue(foe.weaknesses.contains(.fire))
        XCTAssertEqual(foe.shieldMax, 2)
        sut.kael.mp = 100

        sut.perform(.spell(.ember))
        XCTAssertEqual(foe.shield, 1)
        XCTAssertEqual(foe.brokenTurns, 0, "pas encore cassé")

        nextPlayerTurn()
        sut.perform(.spell(.ember))
        XCTAssertEqual(foe.shield, 0)
        XCTAssertEqual(foe.brokenTurns, 1, "BREAK au dernier point de bouclier")
    }

    func test_spellOffWeakness_leavesShieldIntact() {
        prepare()
        defer { cleanup() }
        XCTAssertFalse(foe.weaknesses.contains(.ice))
        sut.kael.mp = 100

        sut.perform(.spell(.frost))

        XCTAssertEqual(foe.shield, foe.shieldMax)
        XCTAssertEqual(foe.brokenTurns, 0)
    }

    // MARK: - Entaille noire

    func test_blackSlash_buildsResonanceAndStunsAtThree() {
        prepare()
        defer { cleanup() }
        sut.kael.mp = 100

        sut.perform(.blackSlash)
        XCTAssertEqual(sut.resonance, 1)
        XCTAssertFalse(foe.combatant.stunned)

        nextPlayerTurn()
        sut.perform(.blackSlash)
        XCTAssertEqual(sut.resonance, 2)
        XCTAssertFalse(foe.combatant.stunned)

        nextPlayerTurn()
        sut.perform(.blackSlash)
        XCTAssertEqual(sut.resonance, 3)
        XCTAssertTrue(foe.combatant.stunned, "troisième Entaille : étourdissement")
        XCTAssertEqual(sut.kael.mp, 100 - 3 * 14, "14 PM par Entaille")
    }

    // MARK: - Soins

    func test_potion_healsFortyPercentAndConsumesOne() {
        prepare()
        defer { cleanup() }
        player.potions = 2
        sut.kael.hp = 100
        let expected = min(sut.kael.maxHP, 100 + Int(CGFloat(sut.kael.maxHP) * 0.40))

        sut.perform(.potion)

        XCTAssertEqual(sut.kael.hp, expected)
        XCTAssertEqual(player.potions, 1)
        XCTAssertEqual(sut.comboCount, 0)
    }

    func test_mend_healsKaelBySpellPower() {
        prepare()
        defer { cleanup() }
        sut.kael.hp = 50
        let mpBefore = sut.kael.mp
        let power = Int(CGFloat(CombatSpell.mend.power(at: player.level)) * player.spellPowerMultiplier)

        sut.perform(.spell(.mend))

        XCTAssertEqual(sut.kael.hp, min(sut.kael.maxHP, 50 + power))
        XCTAssertEqual(sut.kael.mp, mpBefore - CombatSpell.mend.mpCost)
    }

    // MARK: - Coups ennemis

    func test_enemyHit_unblocked_takesFullDamage() {
        prepare()
        defer { cleanup() }
        sut.phase = .enemyTurn
        let hpBefore = sut.kael.hp
        var proceeded = false

        sut.resolveEnemyHit(foe, rawDamage: 40, isSpecial: false, victim: nil,
                            victimHome: .zero, sparkColor: .white, shakeIntensity: 1) {
            proceeded = true
        }

        let expected = CombatMath.incomingDamage(raw: 40, blocked: false,
                                                 damageReduction: player.skillDamageReduction)
        XCTAssertEqual(sut.kael.hp, hpBefore - expected)
        XCTAssertTrue(proceeded, "le tour continue")
    }

    func test_enemyHit_blocked_isReducedAndClosesTheWindow() {
        prepare()
        defer { cleanup() }
        sut.phase = .enemyTurn
        sut.openBlockWindow()
        XCTAssertTrue(sut.attemptBlock(), "parade prise dans la fenêtre")
        let hpBefore = sut.kael.hp

        sut.resolveEnemyHit(foe, rawDamage: 40, isSpecial: false, victim: nil,
                            victimHome: .zero, sparkColor: .white, shakeIntensity: 1) {}

        let expected = CombatMath.incomingDamage(raw: 40, blocked: true,
                                                 damageReduction: player.skillDamageReduction)
        XCTAssertEqual(sut.kael.hp, hpBefore - expected)
        XCTAssertLessThan(expected, 40)
        XCTAssertFalse(sut.blockArmed, "la fenêtre est refermée")
    }

    /// Appuyer AVANT l'annonce brûle la parade : le coup passe en entier.
    func test_enemyHit_blockPressedTooEarly_isBurned() {
        prepare()
        defer { cleanup() }
        sut.phase = .enemyTurn
        XCTAssertTrue(sut.attemptBlock(), "l'appui est consommé…")
        sut.openBlockWindow()
        let hpBefore = sut.kael.hp

        sut.resolveEnemyHit(foe, rawDamage: 40, isSpecial: false, victim: nil,
                            victimHome: .zero, sparkColor: .white, shakeIntensity: 1) {}

        XCTAssertEqual(sut.kael.hp, hpBefore - 40, "…mais la parade n'a rien coupé")
    }

    // MARK: - Dernier souffle (capstone du Souffle)

    func test_lastBreath_leavesKaelAtOneHPOncePerCombat() {
        prepare()
        defer { cleanup() }
        player.skillRanks["breath.capstone"] = 1
        XCTAssertTrue(player.hasLastBreath)
        sut.phase = .enemyTurn
        sut.kael.hp = 10

        sut.resolveEnemyHit(foe, rawDamage: 999, isSpecial: false, victim: nil,
                            victimHome: .zero, sparkColor: .white, shakeIntensity: 1) {}
        XCTAssertEqual(sut.kael.hp, 1, "le coup fatal laisse Kael debout")
        XCTAssertTrue(sut.lastBreathUsed)

        sut.resolveEnemyHit(foe, rawDamage: 999, isSpecial: false, victim: nil,
                            victimHome: .zero, sparkColor: .white, shakeIntensity: 1) {}
        XCTAssertEqual(sut.kael.hp, 0, "une seule fois par combat")
        XCTAssertFalse(sut.kael.isAlive)
    }

    // MARK: - Fin de combat

    /// Un petit ennemi (60 PV × 1,4 = 84) : l'XP gagnée (84 / 3 = 28) reste
    /// sous le seuil du niveau 2 (80), donc lisible sans changement de niveau.
    func test_killingLastEnemy_finishesCombatAndRewardsPlayer() {
        prepare()
        defer { cleanup() }
        var completion: (resonance: Int, gold: Int)?
        sut.attach(to: scene, enemyName: "Louveteau", enemyHP: 60,
                   goldReward: 45, player: player) { completion = ($0, $1) }
        sut.startPlayerTurn()
        foe.combatant.hp = 1
        player.currentHP = 40

        sut.perform(.attack)

        XCTAssertFalse(foe.combatant.isAlive)
        XCTAssertEqual(sut.phase, .finished)
        XCTAssertEqual(player.currentHP, player.currentMaxHP, "PV restaurés après la victoire")
        XCTAssertEqual(player.level, 1)
        XCTAssertEqual(player.xp, foe.combatant.maxHP / 3, "XP = Σ PV max / 3")
        XCTAssertNil(completion, "la fermeture attend son délai (SKAction) — pas de boucle ici")
    }
}
