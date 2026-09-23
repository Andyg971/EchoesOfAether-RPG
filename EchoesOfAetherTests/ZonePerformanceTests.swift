import XCTest
import SpriteKit
@testable import EchoesOfAether

/// Budget de PERFORMANCE par zone, en mesures indépendantes de la machine
/// (le simulateur rend sur le GPU du Mac : un FPS mesuré ici ne dirait rien
/// d'un iPhone SE). Ce qui coûte réellement sur un vieux téléphone :
///
/// - **nœuds** : parcourus à chaque image (mise à jour + tri de profondeur) ;
/// - **SKShapeNode** : chacun est un appel de dessin à part, jamais regroupé
///   (contrairement aux sprites d'un même atlas) ;
/// - **nœuds animés** : une action en boucle = du travail CPU à chaque image ;
/// - **construction** : le temps de chargement ressenti à l'entrée d'une zone.
///
/// Le tableau est imprimé dans le journal de test ; les budgets sont réglés
/// ~40 % au-dessus de la mesure du 2026-09-23 pour attraper une régression
/// (un semis qui explose, une boucle de particules qui ne s'arrête plus).
@MainActor
final class ZonePerformanceTests: XCTestCase {

    private struct Metrics {
        var nodes = 0, sprites = 0, shapes = 0, labels = 0, animated = 0
    }

    private func measure(_ root: SKNode) -> Metrics {
        var m = Metrics()
        func walk(_ n: SKNode) {
            m.nodes += 1
            if n is SKSpriteNode { m.sprites += 1 }
            if n is SKShapeNode { m.shapes += 1 }
            if n is SKLabelNode { m.labels += 1 }
            if n.hasActions() { m.animated += 1 }
            n.children.forEach(walk)
        }
        walk(root)
        return m
    }

    private struct Budget { let nodes: Int; let shapes: Int; let animated: Int; let buildMS: Double }

    /// Construit une zone sur une scène fraîche et mesure.
    private func zone(_ name: String, budget: Budget,
                      _ build: (GameManager, SKScene) -> Void) -> String {
        let scene = SKScene(size: CGSize(width: 844, height: 390))
        let gm = GameManager()
        gm.activeSlot = 3
        gm.scene = scene
        gm.world.build(in: scene)
        let start = CFAbsoluteTimeGetCurrent()
        build(gm, scene)
        let ms = (CFAbsoluteTimeGetCurrent() - start) * 1000
        let m = measure(scene)
        XCTAssertLessThanOrEqual(m.nodes, budget.nodes, "\(name) : \(m.nodes) nœuds")
        XCTAssertLessThanOrEqual(m.shapes, budget.shapes, "\(name) : \(m.shapes) SKShapeNode")
        XCTAssertLessThanOrEqual(m.animated, budget.animated, "\(name) : \(m.animated) nœuds animés")
        XCTAssertLessThanOrEqual(ms, budget.buildMS, "\(name) : construite en \(Int(ms)) ms")
        return String(format: "%-14@ %6d nœuds %6d sprites %5d shapes %4d labels %5d animés %7.0f ms",
                      name as NSString, m.nodes, m.sprites, m.shapes, m.labels, m.animated, ms)
    }

    func test_zoneBudgets() {
        defer { SaveManager.delete(slot: 3) }
        // Mesure du 2026-09-23 (après la mise à plat des tuiles) + 40 %.
        // Temps de construction : ×4 + 150 ms, le simulateur est bruité.
        var rows: [String] = []
        rows.append(zone("village", budget: Budget(nodes: 6600, shapes: 240, animated: 160, buildMS: 398)) { gm, s in gm.world.switchToVillage(in: s) })
        rows.append(zone("forêt", budget: Budget(nodes: 4620, shapes: 230, animated: 260, buildMS: 470)) { gm, s in gm.phase = .forest; gm.showForest(in: s) })
        rows.append(zone("mines", budget: Budget(nodes: 2200, shapes: 140, animated: 100, buildMS: 334)) { gm, s in
            gm.world.switchToMines(in: s, progress: 0, goldTaken: false) })
        rows.append(zone("caverne", budget: Budget(nodes: 810, shapes: 70, animated: 70, buildMS: 262)) { gm, s in
            gm.world.switchToCave(in: s, cleared: false, chestTaken: false) })
        rows.append(zone("désert", budget: Budget(nodes: 3480, shapes: 450, animated: 70, buildMS: 438)) { gm, s in
            gm.world.switchToDesert(in: s, progress: 0, chestTaken: false) })
        rows.append(zone("carte", budget: Budget(nodes: 14680, shapes: 20, animated: 50, buildMS: 610)) { gm, s in gm.world.switchToOverworld(in: s) })
        rows.append(zone("sanctuaire", budget: Budget(nodes: 860, shapes: 70, animated: 60, buildMS: 270)) { gm, s in gm.world.switchToShrine(in: s) })
        rows.append(zone("ruines", budget: Budget(nodes: 1600, shapes: 130, animated: 70, buildMS: 278)) { gm, s in gm.phase = .ruins; gm.showRuins(in: s) })
        rows.append(zone("Seuil", budget: Budget(nodes: 2230, shapes: 120, animated: 100, buildMS: 282)) { gm, s in gm.phase = .act3; gm.showThreshold(in: s) })
        rows.append(zone("Cœur du Vide", budget: Budget(nodes: 2090, shapes: 110, animated: 80, buildMS: 290)) { gm, s in gm.phase = .act4; gm.showVoidHeart(in: s) })
        rows.append(zone("auberge", budget: Budget(nodes: 430, shapes: 60, animated: 30, buildMS: 318)) { gm, s in gm.world.switchToInterior(.inn, in: s) })
        print("PERF-TABLE\n" + rows.joined(separator: "\n") + "\nPERF-END")
    }
}
