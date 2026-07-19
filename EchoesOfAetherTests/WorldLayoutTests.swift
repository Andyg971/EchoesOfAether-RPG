import XCTest
import SpriteKit
@testable import EchoesOfAether

/// Invariant de `WorldBuilder.layout(in:)`.
///
/// `layout()` est rejoué à chaque (re)dimensionnement de scène : rotation
/// paysage gauche ↔ droite, Stage Manager, changement de safe area. Il place
/// le plan du VILLAGE — Kael au spawn + les PNJ à leur poste. Ce plan ne doit
/// s'appliquer QUE dans le village.
///
/// Le bug (corrigé par le garde `villagePlanActive`) : le plan s'appliquait
/// dans toutes les zones. Toute rotation en forêt renvoyait donc Kael à
/// l'entrée sud du village, et `--cam-y` était écrasé par le layout suivant
/// (kael.y = 112 au lieu des 788 demandés). Hors village, `layout()` doit
/// être un no-op pour Kael. D'où ces tests.
@MainActor
final class WorldLayoutTests: XCTestCase {

    /// Scène paysage type iPhone (points), comme au runtime.
    private func makeScene() -> SKScene {
        SKScene(size: CGSize(width: 874, height: 402))
    }

    // MARK: - Spawn du village

    func test_build_poseKaelAuSpawnDuVillage() {
        let world = WorldBuilder()
        let scene = makeScene()
        world.build(in: scene)

        // Le village est un monde vertical scrollable ; le spawn est à 10 %
        // de sa hauteur, devant la maison de Kael.
        XCTAssertGreaterThan(world.worldHeight, 0)
        XCTAssertEqual(world.kael.position.y / world.worldHeight, 0.10, accuracy: 0.001)
        XCTAssertEqual(world.kael.position.x / scene.size.width, 0.485, accuracy: 0.001)
    }

    /// En village (plan actif), un layout ramène Kael au spawn : c'est voulu,
    /// c'est là que le plan a autorité.
    func test_layout_enVillage_rameneKaelAuSpawn() {
        let world = WorldBuilder()
        let scene = makeScene()
        world.build(in: scene)                       // villagePlanActive = true
        world.kael.position = CGPoint(x: 12, y: 3_000)

        world.layout(in: scene.size)

        XCTAssertEqual(world.kael.position.y / world.worldHeight, 0.10, accuracy: 0.001)
    }

    // MARK: - Régression : hors village, le resize ne déplace pas Kael

    /// Le cœur du bug : une rotation en forêt renvoyait Kael à l'entrée sud.
    func test_layout_horsVillage_neDeplacePasKael() {
        let world = WorldBuilder()
        let scene = makeScene()
        world.build(in: scene)
        world.villagePlanActive = false              // simule un changement de zone

        // Entrée de zone (ce que fait GameManager) : Kael au nord du trek.
        let entree = CGPoint(x: scene.size.width * 0.55, y: world.worldHeight * 0.86)
        world.kael.position = entree

        world.layout(in: scene.size)                 // rotation / Stage Manager / safe area

        XCTAssertEqual(world.kael.position.x, entree.x, accuracy: 0.001)
        XCTAssertEqual(world.kael.position.y, entree.y, accuracy: 0.001,
                       "layout() a téléporté Kael hors de son entrée de zone")
    }

    /// Un resize répété hors village ne doit pas davantage le faire dériver.
    func test_layoutsRepetes_horsVillage_laissentKaelSurPlace() {
        let world = WorldBuilder()
        let scene = makeScene()
        world.build(in: scene)
        world.villagePlanActive = false

        let position = CGPoint(x: 300, y: world.worldHeight * 0.42)
        world.kael.position = position
        for _ in 0..<5 { world.layout(in: scene.size) }

        XCTAssertEqual(world.kael.position.x, position.x, accuracy: 0.001)
        XCTAssertEqual(world.kael.position.y, position.y, accuracy: 0.001)
    }

    /// En village, `layout()` garde la main sur les PNJ : eux se replacent.
    func test_layout_enVillage_replaceLesPNJ() {
        let world = WorldBuilder()
        let scene = makeScene()
        world.build(in: scene)

        let poste = world.bram.position
        world.bram.position = CGPoint(x: 5, y: 5)
        world.layout(in: scene.size)

        XCTAssertEqual(world.bram.position.x, poste.x, accuracy: 0.001)
        XCTAssertEqual(world.bram.position.y, poste.y, accuracy: 0.001)
    }
}
