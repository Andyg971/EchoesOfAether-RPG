import XCTest
import SpriteKit
@testable import EchoesOfAether

/// Les effets visuels ne s'assertent pas à l'œil — mais leur MÉNAGE, si.
/// Chaque sort, impact ou texte flottant ajoute des nœuds à la scène ; s'ils
/// ne se retirent pas, ils s'empilent combat après combat (mémoire, draw
/// calls, framerate). Ici chaque effet est joué en temps réel (`LiveScene`)
/// et la scène doit revenir à son nombre de nœuds initial.
@MainActor
final class FXCleanupTests: XCTestCase {

    private var live: LiveScene!
    private var combat: CombatSystem!

    private func prepare() {
        live = LiveScene()
        combat = CombatSystem()
        combat.attach(to: live.scene, enemyName: "Bête", enemyHP: 5_000,
                      goldReward: 0, player: PlayerState()) { _, _ in }
        // L'entrée en combat (fondu en damier, entrée des sprites) doit être
        // finie avant de compter : sinon on mesure SES nœuds qui partent.
        live.wait(2.5)
    }

    private func cleanup() {
        live.tearDown()
        combat = nil; live = nil
    }

    /// Nombre total de nœuds sous la scène.
    private func nodeCount() -> Int {
        func count(_ n: SKNode) -> Int { 1 + n.children.reduce(0) { $0 + count($1) } }
        return count(live.scene)
    }

    /// Joue `fx`, vérifie qu'il AJOUTE quelque chose, puis qu'au bout de
    /// `settle` secondes tout est reparti.
    private func assertCleansUp(_ name: String, settle: TimeInterval = 3.5,
                                file: StaticString = #filePath, line: UInt = #line,
                                _ fx: () -> Void) {
        let baseline = nodeCount()
        fx()
        live.wait(0.1)
        XCTAssertGreaterThan(nodeCount(), baseline, "\(name) n'a rien affiché", file: file, line: line)
        let clean = live.wait(until: { self.nodeCount() <= baseline }, timeout: settle)
        XCTAssertTrue(clean, "\(name) laisse \(nodeCount() - baseline) nœud(s) dans la scène",
                      file: file, line: line)
    }

    private var foe: CombatSystem.EnemyState { combat.enemies[0] }

    // MARK: - Sorts

    func test_spellEffects_leaveNothingBehind() {
        prepare(); defer { cleanup() }
        assertCleansUp("Brasier") { combat.playEmberEffect(on: foe, boosted: false) }
        assertCleansUp("Brasier boosté") { combat.playEmberEffect(on: foe, boosted: true) }
        assertCleansUp("Givre") { combat.playFrostEffect(on: foe, boosted: false) }
        assertCleansUp("Blizzard") { combat.playFrostEffect(on: foe, boosted: true) }
        assertCleansUp("Foudre") { combat.playThunderEffect(on: foe, boosted: false) }
        assertCleansUp("Foudre boostée") { combat.playThunderEffect(on: foe, boosted: true) }
        assertCleansUp("Rémission") { combat.playMendEffect(boosted: false) }
    }

    // MARK: - Retours de coup

    func test_hitFeedback_leavesNothingBehind() {
        prepare(); defer { cleanup() }
        assertCleansUp("critique") { combat.playCritEffect(at: foe.homePosition, damage: 150) }
        assertCleansUp("texte flottant") {
            combat.showFloatingText("-42", at: foe.homePosition, color: .white)
        }
    }

    // MARK: - Particules ponctuelles

    func test_oneShotParticles_removeThemselves() {
        prepare(); defer { cleanup() }
        let center = CGPoint(x: 400, y: 200)
        assertCleansUp("étincelles d'impact") {
            live.scene.addChild(ParticleFactory.impactSparks(at: center, count: 16))
        }
        assertCleansUp("éclat d'Aether noir") {
            live.scene.addChild(ParticleFactory.blackAetherBurst(at: center))
        }
        assertCleansUp("marqueur de tap") {
            live.scene.addChild(ParticleFactory.tapMarker(at: center))
        }
    }
}
