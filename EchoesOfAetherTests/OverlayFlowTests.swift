import XCTest
import SpriteKit
@testable import EchoesOfAether

/// Le COMPORTEMENT des overlays (pas leur lisibilité, cf.
/// `OverlayLegibilityTests`) : ce qu'un tap ou le curseur des contrôles
/// classiques déclenche — le bon callback, l'achat qui débite, la potion qui
/// soigne, le respec qui arme avant d'exécuter, le tutoriel qui se termine.
///
/// Scène vivante (`LiveScene`) : certains overlays n'acceptent le curseur
/// qu'après leur animation d'entrée.
@MainActor
final class OverlayFlowTests: XCTestCase {

    private var live: LiveScene!
    private var scene: SKScene { live.scene }
    private var defaultsBefore: [String: Any] = [:]
    private var difficultyBefore: Difficulty!

    private let touchedKeys = [AccessibilitySettings.reduceMotionKey, TutorialOverlay.seenKey]



    /// Point scène du premier nœud nommé `name` (après son éventuel popIn).
    private func point(of name: String, file: StaticString = #filePath, line: UInt = #line) -> CGPoint {
        var found: SKNode?
        // Le popIn peut porter sur un ANCÊTRE (la ligne qui contient le bouton) :
        // tant qu'un maillon est à l'échelle 0, le point converti vaut NaN.
        live.wait(until: {
            found = self.scene.childNode(withName: "//\(name)")
            var node = found
            while let n = node, n !== self.scene {
                if n.xScale < 0.99 { return false }
                node = n.parent
            }
            return found != nil
        }, timeout: 4)
        guard let node = found, let parent = node.parent else {
            XCTFail("nœud \(name) introuvable", file: file, line: line); return .zero
        }
        // Centre du CADRE (le path d'un SKShapeNode n'est pas forcément centré
        // sur sa position) : c'est là qu'un doigt tape.
        return scene.convert(CGPoint(x: node.frame.midX, y: node.frame.midY), from: parent)
    }

    // XCTest déclare setUp/tearDown non isolés et interdit de les isoler : l'état
    // @MainActor se prépare donc au début de chaque test (`prepare()` + `defer`).
    private func prepare() {
        live = LiveScene()
        difficultyBefore = Difficulty.current
        for k in touchedKeys { defaultsBefore[k] = UserDefaults.standard.object(forKey: k) }
    }

    private func cleanup() {
        Difficulty.current = difficultyBefore
        for k in touchedKeys {
            if let v = defaultsBefore[k] { UserDefaults.standard.set(v, forKey: k) }
            else { UserDefaults.standard.removeObject(forKey: k) }
        }
        live.tearDown()
        live = nil
    }

    // MARK: - Pause

    func test_pause_cursorReachesEveryButton() {
        prepare()
        defer { cleanup() }
        let pause = PauseOverlay()
        pause.attach(to: scene)
        var fired: [String] = []
        pause.onResume = { fired.append("resume") }
        pause.onSave = { fired.append("save") }
        pause.onSkills = { fired.append("skills") }
        pause.onOptions = { fired.append("options") }
        pause.onMainMenu = { fired.append("menu") }
        pause.show(in: scene)
        live.wait(1.2)   // les boutons n'acceptent le curseur qu'après leur entrée

        pause.confirmSelection()
        XCTAssertEqual(fired.last, "resume", "premier bouton : Reprendre")
        pause.moveSelection(-1); pause.confirmSelection()
        XCTAssertEqual(fired.last, "save")
        pause.moveSelection(-1); pause.confirmSelection()
        XCTAssertEqual(fired.last, "skills")
        pause.moveSelection(-1); pause.confirmSelection()
        XCTAssertEqual(fired.last, "options")
        pause.moveSelection(-1); pause.confirmSelection()
        XCTAssertEqual(fired.last, "menu")

        pause.dismiss()
        XCTAssertEqual(fired.last, "resume", "B = Reprendre")
    }

    // MARK: - Mort

    func test_death_retryOrCrystal() {
        prepare()
        defer { cleanup() }
        let death = DeathOverlay()
        death.attach(to: scene)
        var fired: [String] = []
        death.onRetry = { fired.append("retry") }
        death.onReturnToCrystal = { fired.append("crystal") }
        death.show(in: scene)
        XCTAssertTrue(death.isActive)

        death.confirmSelection()
        XCTAssertEqual(fired, ["retry"], "par défaut : réessayer")
        death.moveSelection(-1)
        death.confirmSelection()
        XCTAssertEqual(fired, ["retry", "crystal"])
    }

    // MARK: - Mur d'achat

    func test_paywall_buyRestoreLater() {
        prepare()
        defer { cleanup() }
        let paywall = PaywallOverlay()
        paywall.attach(to: scene)
        var fired: [String] = []
        paywall.onBuy = { fired.append("buy") }
        paywall.onRestore = { fired.append("restore") }
        paywall.onLater = { fired.append("later") }
        paywall.open()
        XCTAssertTrue(paywall.isActive)

        paywall.confirmSelection()
        paywall.moveSelection(-1); paywall.confirmSelection()
        paywall.moveSelection(-1); paywall.confirmSelection()
        XCTAssertEqual(fired, ["buy", "restore", "later"])
        paywall.dismiss()
        XCTAssertEqual(fired.last, "later", "B = Plus tard")
    }

    // MARK: - Boutique

    func test_shop_buyDebitsAndAppliesItem_refusesWhenPoor() {
        prepare()
        defer { cleanup() }
        let gm = GameManager()
        let shop = ShopOverlay()
        shop.attach(to: scene)
        gm.player.gold = 100
        gm.player.weaponLevel = 0
        var closed = false
        shop.open(title: "Bram", items: gm.bramItems(), player: gm.player) { closed = true }
        XCTAssertTrue(shop.isActive)

        shop.confirmSelection()   // lame de fer, 80 or
        XCTAssertEqual(gm.player.weaponLevel, 1, "l'arme monte d'un cran")
        XCTAssertEqual(gm.player.gold, 20)

        shop.moveSelection(-1)    // cotte de mailles, 60 or
        shop.confirmSelection()
        XCTAssertEqual(gm.player.armorLevel, 0, "trop pauvre : rien n'est vendu")
        XCTAssertEqual(gm.player.gold, 20)

        shop.dismiss()
        XCTAssertTrue(closed)
        XCTAssertFalse(shop.isActive)
    }

    func test_shop_innRest_onlyOnce() {
        prepare()
        defer { cleanup() }
        let gm = GameManager()
        let shop = ShopOverlay()
        shop.attach(to: scene)
        gm.player.gold = 50
        shop.open(title: "Auberge", items: gm.innItems(), player: gm.player) {}
        shop.confirmSelection()
        XCTAssertTrue(gm.player.innRested)
        XCTAssertEqual(gm.player.gold, 40)
        shop.confirmSelection()
        XCTAssertEqual(gm.player.gold, 40, "une seule nuit")
    }

    // MARK: - Inventaire

    func test_inventory_potionHealsThroughCallback() {
        prepare()
        defer { cleanup() }
        let gm = GameManager()
        let inventory = InventoryOverlay()
        inventory.attach(to: scene)
        gm.player.potions = 1
        gm.player.currentHP = 10
        var closed = false
        inventory.onUsePotion = { gm.useHealthPotion() }
        inventory.open(player: gm.player) { closed = true }
        XCTAssertTrue(inventory.canUsePotion)

        inventory.useSelectedPotion()
        XCTAssertEqual(gm.player.potions, 0)
        XCTAssertGreaterThan(gm.player.currentHP, 10)
        XCTAssertFalse(inventory.canUsePotion, "plus de fiole")

        inventory.dismiss()
        XCTAssertTrue(closed)
    }

    // MARK: - Arbre de l'Aether

    func test_skillTree_investSpendsAPoint_andRespecArmsBeforeExecuting() {
        prepare()
        defer { cleanup() }
        let player = PlayerState()
        player.level = 5   // des points à dépenser
        let tree = SkillTreeOverlay()
        tree.attach(to: scene)
        tree.show(player: player, in: scene)
        tree.ready = true
        let pointsBefore = player.skillPointsAvailable
        XCTAssertGreaterThan(pointsBefore, 0)

        tree.confirmSelection()   // premier nœud de la Lame
        XCTAssertEqual(player.skillPointsAvailable, pointsBefore - 1)
        XCTAssertEqual(player.skillPointsSpent, 1)

        var respecCalls = 0
        tree.onRespec = { respecCalls += 1; player.respecSkills(); return true }
        XCTAssertTrue(tree.handleTap(at: point(of: "skillRespec"), in: scene))
        XCTAssertEqual(respecCalls, 0, "premier tap : on arme seulement")
        XCTAssertTrue(tree.handleTap(at: point(of: "skillRespec"), in: scene))
        XCTAssertEqual(respecCalls, 1, "second tap : on exécute")
        XCTAssertEqual(player.skillPointsSpent, 0)
    }

    // MARK: - Tutoriel

    func test_tutorial_advanceThroughAllPanels_thenCompletes() {
        prepare()
        defer { cleanup() }
        let tutorial = TutorialOverlay()
        tutorial.attach(to: scene)
        var done = 0
        tutorial.show(in: scene) { done += 1 }
        XCTAssertTrue(tutorial.isActive)
        var guardCount = 0
        while tutorial.isActive, guardCount < 20 { tutorial.advanceExternally(); guardCount += 1 }
        XCTAssertFalse(tutorial.isActive)
        XCTAssertEqual(done, 1)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: TutorialOverlay.seenKey), "vu = mémorisé")
    }

    func test_tutorial_skip_completesImmediately() {
        prepare()
        defer { cleanup() }
        let tutorial = TutorialOverlay()
        tutorial.attach(to: scene)
        var done = 0
        tutorial.show(in: scene, startAt: 1) { done += 1 }
        tutorial.skipExternally()
        XCTAssertFalse(tutorial.isActive)
        XCTAssertEqual(done, 1)
    }

    // MARK: - Journal, lore, niveau

    func test_questLog_dismissCallsCompletion() {
        prepare()
        defer { cleanup() }
        let log = QuestLogOverlay()
        log.attach(to: scene)
        var closed = 0
        log.open(entries: [QuestEntry(title: "T", desc: "D", state: .active)]) { closed += 1 }
        XCTAssertTrue(log.isActive)
        log.scroll(-1)
        log.dismiss()
        XCTAssertEqual(closed, 1)
        XCTAssertFalse(log.isActive)
    }

    func test_lore_tabsAndDismiss() {
        prepare()
        defer { cleanup() }
        let lore = LoreOverlay()
        lore.attach(to: scene)
        var closed = 0
        lore.open(entries: [LoreEntry(title: "T", body: "B")], bestiarySeen: ["beast"]) { closed += 1 }
        XCTAssertTrue(lore.isActive)
        lore.navigateTabs(1)
        lore.scroll(-1)
        lore.navigateTabs(-1)
        lore.dismiss()
        XCTAssertEqual(closed, 1)
    }

    func test_levelUp_tapDismisses() {
        prepare()
        defer { cleanup() }
        let levelUp = LevelUpOverlay()
        levelUp.attach(to: scene)
        var dismissed = 0
        levelUp.show(newLevel: 2, isMax: false) { dismissed += 1 }
        XCTAssertTrue(levelUp.isVisible)
        XCTAssertTrue(levelUp.handleTap(at: CGPoint(x: 10, y: 10), in: scene))
        XCTAssertTrue(live.wait(until: { dismissed == 1 }, timeout: 3), "le fondu de sortie rend la main")
        XCTAssertFalse(levelUp.isVisible)
    }

    // MARK: - Carte du monde

    func test_worldMap_tapOnAvailablePlace_travels_andLockedPlaceDoesNot() {
        prepare()
        defer { cleanup() }
        let gm = GameManager()
        gm.phase = .forest
        let map = gm.worldMap
        map.attach(to: scene)
        var travelled: [String] = []
        map.onTravel = { travelled.append($0) }
        let places = gm.buildMapPlaces()
        map.open(places: places) {}
        XCTAssertTrue(map.isActive)

        let locked = try! XCTUnwrap(places.first { $0.state != .available })
        XCTAssertTrue(map.handleTap(at: scene.convert(map.panelPoint(locked.point), from: map.root), in: scene))
        XCTAssertTrue(travelled.isEmpty, "\(locked.id) est verrouillé")
        XCTAssertTrue(map.isActive)

        let open = try! XCTUnwrap(places.first { $0.state == .available && $0.id != "village" })
        XCTAssertTrue(map.handleTap(at: scene.convert(map.panelPoint(open.point), from: map.root), in: scene))
        XCTAssertEqual(travelled, [open.id])
        XCTAssertFalse(map.isActive)
    }

    // MARK: - Options

    func test_options_volumesDifficultyToggleResetClose() {
        prepare()
        defer { cleanup() }
        let options = OptionsOverlay()
        options.attach(to: scene)
        var volumes: [Float] = [], music: [Float] = []
        var deleted = 0, closed = 0
        options.onVolumeChange = { volumes.append($0) }
        options.onMusicVolumeChange = { music.append($0) }
        options.onDeleteSave = { deleted += 1 }
        options.onClose = { closed += 1 }
        let difficulty = Difficulty.current
        let motion = AccessibilitySettings.reduceMotion
        options.show(in: scene)

        XCTAssertTrue(options.handleTap(at: point(of: "sfxDown"), in: scene))
        XCTAssertTrue(options.handleTap(at: point(of: "sfxUp"), in: scene))
        XCTAssertEqual(volumes.count, 2, "les « < » « > » de volume répondent (régression : boutons dans un conteneur)")
        if volumes.count == 2 { XCTAssertLessThan(volumes[0], volumes[1]) }
        XCTAssertTrue(options.handleTap(at: point(of: "musicUp"), in: scene))
        XCTAssertEqual(music.count, 1)

        XCTAssertTrue(options.handleTap(at: point(of: "cycleDifficulty"), in: scene))
        XCTAssertEqual(Difficulty.current, difficulty.next)

        XCTAssertTrue(options.handleTap(at: point(of: "toggleReduceMotion"), in: scene))
        XCTAssertNotEqual(AccessibilitySettings.reduceMotion, motion)

        XCTAssertTrue(options.handleTap(at: point(of: "optionsReset"), in: scene))
        XCTAssertEqual(deleted, 0, "premier tap : demande confirmation")
        XCTAssertTrue(options.handleTap(at: point(of: "optionsReset"), in: scene))
        XCTAssertEqual(deleted, 1)

        XCTAssertTrue(options.handleTap(at: point(of: "optionsClose"), in: scene))
        XCTAssertEqual(closed, 1)
    }

    // MARK: - Bulle d'interaction

    func test_interactionBubble_showHide() {
        prepare()
        defer { cleanup() }
        let bubble = InteractionBubble()
        bubble.attach(to: scene)
        XCTAssertFalse(bubble.isVisible)
        bubble.show(at: CGPoint(x: 100, y: 100), action: .talk)
        XCTAssertTrue(bubble.isVisible)
        bubble.hide()
        XCTAssertTrue(live.wait(until: { !bubble.isVisible }, timeout: 2), "fondu de sortie")
    }
}
