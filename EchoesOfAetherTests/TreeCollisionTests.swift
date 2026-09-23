import XCTest
import SpriteKit
@testable import EchoesOfAether

/// Kael ne traverse pas les arbres animés.
///
/// Deux régressions verrouillées :
/// 1. **Le feuillage qui touche le sol.** Feuillus ronds et sapins animés ont
///    des branches jusqu'au sol (86–97 % du canevas à hauteur de Kael) ; leur
///    empreinte ne couvrait que le tronc (58–62 %) — Kael entrait dans les
///    branches par les côtés.
/// 2. **La règle d'échappement.** Coincé dans une empreinte, Kael pouvait
///    tout traverser tant qu'il y restait (arbres collés à une maison,
///    bosquets qui se chevauchent). Il est désormais dégagé au point libre
///    le plus proche dès son premier pas, puis les collisions s'appliquent.
@MainActor
final class TreeCollisionTests: XCTestCase {

    /// `GameManager.scene` est WEAK : sans cette référence, la scène meurt
    /// aussitôt et `updatePadMovement` ne fait rien — les tests passeraient à vide.
    private var heldScene: SKScene?

    private func village() -> (GameManager, SKScene) {
        let scene = SKScene(size: CGSize(width: 844, height: 390))
        let gm = GameManager(); gm.activeSlot = 3; gm.scene = scene
        gm.world.build(in: scene)
        gm.phase = .village; gm.world.switchToVillage(in: scene)
        gm.state = .exploration
        heldScene = scene
        return (gm, scene)
    }

    private func animatedTrees(_ gm: GameManager) -> [SKNode] {
        gm.world.worldNode.children.filter {
            let a = $0.userData?["pixelAsset"] as? String ?? ""
            return a.hasPrefix("atree_cool") || a.hasPrefix("atree_dark")
                || a.hasPrefix("atree_autumn") || a.hasPrefix("apine")
        }
    }

    private func walk(_ gm: GameManager, from start: CGPoint, dx: CGFloat, dy: CGFloat,
                      seconds: Double = 1.0) -> CGPoint {
        gm.world.kael.position = start
        gm.padActive = true
        gm.padVector = CGVector(dx: dx, dy: dy)
        for _ in 0..<Int(seconds * 60) { gm.updatePadMovement(deltaTime: 1.0 / 60) }
        gm.padActive = false
        XCTAssertNotNil(gm.scene, "scène libérée : la marche n'a pas eu lieu")
        return gm.world.kael.position
    }

    func test_foliageFootprintRatio_readsTheDrawing() {
        XCTAssertGreaterThan(WorldBuilder.foliageFootprintRatio(of: "atree_cool", minimum: 0), 0.72,
                             "feuillu : branches basses sur ~86 % du canevas")
        XCTAssertGreaterThan(WorldBuilder.foliageFootprintRatio(of: "apine_cool", minimum: 0), 0.80,
                             "sapin : branches basses sur ~95 % du canevas")
        XCTAssertEqual(WorldBuilder.foliageFootprintRatio(of: "atree_leaf", minimum: 0.58), 0.58,
                       accuracy: 0.001, "le chêne a un vrai tronc : il garde son ratio d'origine")
        XCTAssertEqual(WorldBuilder.foliageFootprintRatio(of: "inexistant", minimum: 0.62), 0.62)
    }

    /// Kael, collé au flanc d'un feuillu animé à hauteur de son pied, ne
    /// peut pas s'avancer dans les branches basses.
    func test_animatedTrees_blockFromTheSide() {
        defer { SaveManager.delete(slot: 3) }
        let (gm, _) = village()
        let trees = animatedTrees(gm)
        XCTAssertFalse(trees.isEmpty)
        var checked = 0
        for tree in trees {
            let f = tree.calculateAccumulatedFrame()
            let y = tree.position.y + 6
            // Départ à gauche du feuillage, hors de tout obstacle ; on marche vers le centre.
            let start = CGPoint(x: f.minX - 8, y: y)
            guard !gm.world.isBlocked(start) else { continue }
            let end = walk(gm, from: start, dx: 1, dy: 0, seconds: 0.4)
            // Les branches basses occupent ~86 % au moins de la largeur : Kael
            // ne doit pas dépasser le premier dixième de la silhouette.
            XCTAssertLessThan(end.x, f.minX + f.width * 0.15,
                              "\(tree.userData?["pixelAsset"] ?? "?") à \(tree.position) : Kael entre dans le feuillage")
            checked += 1
        }
        XCTAssertGreaterThan(checked, 5, "trop peu d'arbres vérifiés")
    }

    /// Coincé dans l'empreinte d'une maison, Kael est dégagé, et ne peut plus
    /// traverser l'arbre du verger qui la jouxte.
    func test_insideAnObstacle_isFreed_thenCannotCrossTheNeighbour() throws {
        defer { SaveManager.delete(slot: 3) }
        let (gm, _) = village()
        let world = gm.world
        // Un grand obstacle (maison) chevauché par un petit (décor accolé),
        // tel qu'on puisse poser Kael DANS le grand, juste sous le petit.
        var setup: (house: CGRect, tree: CGRect, start: CGPoint)?
        search: for house in world.obstacles where house.height > 60 {
            for tree in world.obstacles where tree != house && tree.intersects(house) && tree.height < 40 {
                let x = min(max(tree.midX, house.minX + 2), house.maxX - 2)
                let start = CGPoint(x: x, y: tree.minY - 6)
                if house.contains(start), !tree.contains(start), tree.minX < x, x < tree.maxX,
                   !world.obstacles.contains(where: { $0 != house && $0.contains(start) }) {
                    setup = (house, tree, start); break search
                }
            }
        }
        let (_, tree, start) = try XCTUnwrap(setup, "aucun décor accolé à une maison dans le village")
        // Au premier pas, Kael est dégagé de la maison…
        let first = walk(gm, from: start, dx: 0, dy: 1, seconds: 1.0 / 60)
        XCTAssertFalse(world.isBlocked(first), "Kael reste dans une empreinte")
        XCTAssertLessThan(first.distance(to: start), 130, "dégagé trop loin")
        // …et, poussé vers l'arbre, il ne le traverse plus.
        let end = walk(gm, from: start, dx: 0, dy: 1, seconds: 1.5)
        XCTAssertFalse(world.isBlocked(end))
        XCTAssertFalse(abs(end.x - tree.midX) < tree.width / 2 && end.y > tree.maxY,
                       "coincé dans la maison, Kael a traversé l'arbre voisin")
    }
}
