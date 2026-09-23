import XCTest
import SpriteKit
@testable import EchoesOfAether

/// ACCESSIBILITÉ : depuis l'entrée de chaque zone, Kael doit pouvoir marcher
/// jusqu'à chaque point d'intérêt (PNJ, portes, ramassages de quête, entrées,
/// sorties). Un obstacle mal placé ou élargi — un arbre dont l'empreinte
/// déborde sur le sentier — peut couper une zone en deux sans qu'aucun autre
/// test ne le voie : le joueur, lui, reste bloqué.
///
/// Parcours en largeur sur une grille de 6 pt (le pas d'échantillonnage de
/// `clampDestination`), en utilisant `isBlocked` — exactement le test que fait
/// le déplacement. Un POI est atteint si une case libre à moins de `reach`
/// de lui est accessible (on interagit à distance, pas en marchant dessus).
@MainActor
final class ZoneReachabilityTests: XCTestCase {

    private let step: CGFloat = 6
    private let size = CGSize(width: 844, height: 390)

    private func prepare() -> (GameManager, SKScene) {
        let scene = SKScene(size: size)
        let gm = GameManager(); gm.activeSlot = 3; gm.scene = scene
        gm.world.build(in: scene)
        return (gm, scene)
    }

    /// Cases accessibles depuis `start`, bornes du déplacement comprises.
    private func reachable(_ world: WorldBuilder, from start: CGPoint) -> (Set<Int>, cols: Int, rows: Int) {
        let w = world.worldWidth > 0 ? world.worldWidth : size.width
        let h = world.worldHeight > 0 ? world.worldHeight : size.height
        let cols = Int(w / step) + 1, rows = Int(h / step) + 1
        func pt(_ c: Int, _ r: Int) -> CGPoint { CGPoint(x: CGFloat(c) * step, y: CGFloat(r) * step) }
        func ok(_ c: Int, _ r: Int) -> Bool {
            let p = pt(c, r)
            return p.x >= 34 && p.x <= w - 34 && p.y >= 86 && p.y <= h - 44 && !world.isBlocked(p)
        }
        var seen = Set<Int>()
        let c0 = Int((start.x / step).rounded()), r0 = Int((max(start.y, 86) / step).rounded())
        // Départ : la case libre la plus proche du spawn.
        var queue: [(Int, Int)] = []
        search: for radius in 0...6 {
            for dc in -radius...radius { for dr in -radius...radius where ok(c0 + dc, r0 + dr) {
                queue.append((c0 + dc, r0 + dr)); break search
            } }
        }
        XCTAssertFalse(queue.isEmpty, "spawn emmuré")
        for (c, r) in queue { seen.insert(r * cols + c) }
        var i = 0
        while i < queue.count {
            let (c, r) = queue[i]; i += 1
            for (dc, dr) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                let nc = c + dc, nr = r + dr
                guard nc >= 0, nr >= 0, nc < cols, nr < rows, !seen.contains(nr * cols + nc),
                      ok(nc, nr) else { continue }
                seen.insert(nr * cols + nc); queue.append((nc, nr))
            }
        }
        return (seen, cols, rows)
    }

    private func assertReachable(_ zone: String, _ world: WorldBuilder, from start: CGPoint,
                                 _ targets: [(String, CGPoint)], reach: CGFloat = 44,
                                 file: StaticString = #filePath, line: UInt = #line) {
        let (seen, cols, _) = reachable(world, from: start)
        let rad = Int(reach / step)
        for (name, t) in targets {
            let tc = Int((t.x / step).rounded()), tr = Int((t.y / step).rounded())
            var hit = false
            outer: for dc in -rad...rad {
                for dr in -rad...rad where CGFloat(dc * dc + dr * dr) * step * step <= reach * reach {
                    let c = tc + dc, r = tr + dr
                    if c >= 0, r >= 0, seen.contains(r * cols + c) { hit = true; break outer }
                }
            }
            XCTAssertTrue(hit, "\(zone) : « \(name) » inaccessible depuis l'entrée", file: file, line: line)
        }
    }

    // MARK: - Village

    func test_village_everyNPCAndDoorIsReachable() {
        defer { SaveManager.delete(slot: 3) }
        let (gm, scene) = prepare()
        let w = gm.world
        gm.phase = .village; w.switchToVillage(in: scene)
        w.endLyraVigil(); w.layout(in: scene.size)
        var targets: [(String, CGPoint)] = [
            ("Lyra", w.lyra.position), ("Dorin", w.dorin.position), ("Bram", w.bram.position),
            ("Mara", w.mara.position), ("Sage", w.sage.position), ("Garen", w.garen.position),
            ("enfant", w.child.position), ("villageoise", w.villager.position)
        ]
        for kind in [HouseInteriorKind.armory, .apothecary, .inn] {
            targets.append(("porte \(kind)", w.houseDoorPosition(for: kind, in: scene.size)))
        }
        assertReachable("village", w, from: w.kael.position, targets)
    }

    // MARK: - Forêt d'Ébène

    func test_forest_everyEntranceAndPickupIsReachable() {
        defer { SaveManager.delete(slot: 3) }
        let (gm, scene) = prepare()
        gm.phase = .forest; gm.showForest(in: scene)
        let w = size.width, h = gm.world.worldHeight
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: w * x, y: h * y) }
        assertReachable("forêt", gm.world, from: p(0.5, 0.05), [
            ("seuil du Sanctuaire", p(0.55, 0.90)), ("mines", p(0.88, 0.30)),
            ("caverne", p(0.12, 0.80)), ("jouet", p(0.80, 0.45)), ("talisman", p(0.28, 0.72)),
            ("fer corrompu", p(0.40, 0.63)), ("herbe lunaire", p(0.12, 0.40)),
            ("insigne", p(0.68, 0.18)), ("cristal-mère", p(0.78, 0.70))
        ])
    }

    // MARK: - Autres zones

    func test_desert_poisAreReachable() {
        defer { SaveManager.delete(slot: 3) }
        let (gm, scene) = prepare()
        gm.world.switchToDesert(in: scene, progress: 0, chestTaken: false)
        let w = size.width, h = gm.world.worldHeight
        assertReachable("désert", gm.world, from: CGPoint(x: w * 0.5, y: h * 0.06), [
            ("sortie", CGPoint(x: w * 0.5, y: h * DesertPOI.exitY)),
            ("caravanier", DesertPOI.npcCaravanier.scaled(w: w, h: h)),
            ("marchand", DesertPOI.npcMerchant.scaled(w: w, h: h)),
            ("enfant", DesertPOI.npcChild.scaled(w: w, h: h)),
            ("coffre enfoui", CGPoint(x: w * 0.10, y: h * DesertPOI.chestY)),
            ("oasis", DesertPOI.oasis.scaled(w: w, h: h))
        ], reach: DesertPOI.reach)
    }

    func test_mines_poisAreReachable() {
        defer { SaveManager.delete(slot: 3) }
        let (gm, scene) = prepare()
        gm.world.switchToMines(in: scene, progress: 0, goldTaken: false)
        let w = size.width, h = gm.world.worldHeight
        assertReachable("mines", gm.world, from: CGPoint(x: w * 0.5, y: h * 0.07), [
            ("sortie", CGPoint(x: w * 0.5, y: h * MinesPOI.exitY)),
            ("plaque", MinesPOI.plaque.scaled(w: w, h: h)),
            ("veine d'or", MinesPOI.goldVein.scaled(w: w, h: h))
        ], reach: MinesPOI.reach)
    }

    func test_ruins_threshold_voidHeart_poisAreReachable() {
        defer { SaveManager.delete(slot: 3) }
        do {
            let (gm, scene) = prepare()
            gm.phase = .ruins; gm.showRuins(in: scene)
            let plan = RuinsLayout(sceneSize: size)
            assertReachable("ruines", gm.world, from: plan.entrance,
                            [("inscription d'Eran", plan.eranInscription),
                             ("mur de la Découverte", plan.discoveryWall)], reach: 60)
        }
        do {
            let (gm, scene) = prepare()
            gm.phase = .act3; gm.showThreshold(in: scene)
            let plan = ThresholdLayout(sceneSize: size)
            var targets: [(String, CGPoint)] = [("Eran", plan.eran), ("portail", plan.portal)]
            targets += plan.steles.map { ("stèle \($0.id)", $0.pos) }
            assertReachable("Seuil", gm.world, from: plan.entrance, targets, reach: 55)
        }
        do {
            let (gm, scene) = prepare()
            gm.phase = .act4; gm.showVoidHeart(in: scene)
            let plan = VoidHeartLayout(sceneSize: size)
            var targets: [(String, CGPoint)] = [("la Voix", plan.voiceConfront), ("le Cœur", plan.heart)]
            targets += plan.memories.map { ("souvenir \($0.id)", $0.pos) }
            assertReachable("Cœur du Vide", gm.world, from: plan.entrance, targets, reach: 55)
        }
    }
}
