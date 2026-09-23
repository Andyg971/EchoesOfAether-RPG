import XCTest
import SpriteKit
@testable import EchoesOfAether

/// Les drapeaux de lancement d'audit (`--zone-*`, `--combat-*`…), l'outil de
/// toutes les vérifications simulateur. Deux garanties :
///
/// 1. **Le contrat menu ↔ setup.** Un drapeau qui PREND LA MAIN dans
///    `GameManager.setup` doit aussi figurer dans `debugZoneArgs`
///    (`MainMenuScene`), sinon l'app reste au menu et le drapeau n'est jamais
///    lu — c'est arrivé à `--bubble-test`. Vérifié en lisant les sources.
/// 2. **Chaque zone atterrit où elle le dit** : phase et excursion posées,
///    Kael visible, exploration rendue.
@MainActor
final class DebugLaunchFlagsTests: XCTestCase {

    /// Drapeaux qui MODIFIENT un lancement sans le déclencher : ils
    /// s'utilisent avec un `--zone-*` et n'ont pas à être dans le menu.
    private let modifiers: Set<String> = ["--cam-y", "--cave-cleared", "--quests-active",
                                          "--skills-maxed", "--overlay-test", "--overworld-at"]

    private var repoRoot: URL? {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return FileManager.default.fileExists(atPath: root.appendingPathComponent("EchoesOfAether").path)
            ? root : nil
    }

    private func flags(in source: String, pattern: String) throws -> Set<String> {
        let regex = try NSRegularExpression(pattern: pattern)
        return Set(regex.matches(in: source, range: NSRange(source.startIndex..., in: source)).map {
            String(source[Range($0.range(at: 1), in: source)!])
        })
    }

    // MARK: - Contrat menu ↔ setup

    func test_everyLaunchingFlag_isListedInTheMenu_andViceVersa() throws {
        guard let root = repoRoot else { throw XCTSkip("hors du dépôt") }
        let core = root.appendingPathComponent("EchoesOfAether/Core")
        var read: Set<String> = []
        for name in ["GameManager+SetupDebugZones.swift", "GameManager+SetupDebugCombat.swift"] {
            let s = try String(contentsOf: core.appendingPathComponent(name), encoding: .utf8)
            read.formUnion(try flags(in: s, pattern: #"(?:contains|firstIndex)\((?:of: )?"(--[a-z0-9-]+)"\)"#))
        }
        let menuSource = try String(contentsOf: root.appendingPathComponent(
            "EchoesOfAether/Game/Scenes/MainMenuScene.swift"), encoding: .utf8)
        let listStart = try XCTUnwrap(menuSource.range(of: "let debugZoneArgs"))
        let listEnd = try XCTUnwrap(menuSource.range(of: "]", range: listStart.upperBound..<menuSource.endIndex))
        let listed = try flags(in: String(menuSource[listStart.lowerBound..<listEnd.upperBound]),
                               pattern: #""(--[a-z0-9-]+)""#)

        XCTAssertGreaterThan(read.count, 15, "balayage trop maigre : regex cassée ?")
        XCTAssertEqual(read.subtracting(modifiers).subtracting(listed), [],
                       "drapeaux lus par setup mais absents de debugZoneArgs : l'app resterait au menu")
        XCTAssertEqual(listed.subtracting(read), [], "drapeaux listés au menu que setup ne lit plus")
    }

    // MARK: - Chaque zone atterrit où elle le dit

    private func launch(_ args: [String]) -> (GameManager, SKScene, Bool) {
        let scene = SKScene(size: CGSize(width: 844, height: 390))
        let gm = GameManager()
        gm.activeSlot = 3
        gm.scene = scene
        gm.attachOverlays(to: scene)
        gm.launchArguments = ["EchoesOfAether"] + args
        let tookOver = gm.applyDebugZoneArguments(scene: scene)
        return (gm, scene, tookOver)
    }

    func test_zoneFlags_landInTheRightPlace() {
        defer { SaveManager.delete(slot: 3) }
        let cases: [(flag: String, check: (GameManager) -> Bool, what: String)] = [
            ("--zone-village",   { $0.phase == .village }, "village"),
            ("--zone-forest",    { $0.phase == .forest }, "forêt"),
            ("--zone-mines",     { $0.inMines }, "mines"),
            ("--zone-cave",      { $0.inCave }, "caverne"),
            ("--zone-desert",    { $0.inDesert }, "désert"),
            ("--zone-overworld", { $0.inOverworld }, "carte du monde"),
            ("--zone-shrine",    { $0.phase == .shrine }, "sanctuaire"),
            ("--zone-ruins",     { $0.phase == .ruins }, "ruines"),
            ("--zone-threshold", { $0.phase == .act3 }, "Seuil"),
            ("--zone-voidheart", { $0.phase == .act4 }, "Cœur du Vide")
        ]
        for c in cases {
            let (gm, scene, tookOver) = launch([c.flag])
            XCTAssertTrue(tookOver, "\(c.flag) doit prendre la main")
            XCTAssertTrue(c.check(gm), "\(c.flag) : pas arrivé en \(c.what)")
            XCTAssertFalse(gm.world.kael.isHidden, "\(c.flag) : Kael invisible")
            _ = scene
        }
    }

    func test_interiorFlag_entersTheHouse_andUnknownKindFallsThrough() {
        defer { SaveManager.delete(slot: 3) }

        let (gm, _, tookOver) = launch(["--interior", "inn"])
        XCTAssertTrue(tookOver)
        XCTAssertEqual(gm.activeInterior, .inn)

        let (gm2, _, tookOver2) = launch(["--interior", "palais"])
        XCTAssertFalse(tookOver2, "un intérieur inconnu ne prend pas la main (partie normale)")
        XCTAssertNil(gm2.activeInterior)
    }

    func test_noFlag_doesNotTakeOver() {
        defer { SaveManager.delete(slot: 3) }
        let (_, _, tookOver) = launch([])
        XCTAssertFalse(tookOver, "sans drapeau, setup continue vers la sauvegarde")
    }
}
