import XCTest
import SpriteKit
@testable import EchoesOfAether

/// La pêche au lac de Solis, jouée en temps réel (`LiveScene`) : lancer,
/// attente variable (1,3–3,2 s), touche, fenêtre de 0,55 s pour ferrer.
/// Ce qui est verrouillé : on ne gagne QUE si on ferre dans la fenêtre,
/// ferrer trop tôt fait fuir, ne rien faire laisse filer, et on ne peut ni
/// relancer pendant une prise ni rester bloqué après.
@MainActor
final class FishingTests: XCTestCase {

    private var live: LiveScene!
    private var gm: GameManager!

    private func prepare() {
        live = LiveScene()
        gm = GameManager()
        gm.activeSlot = 3
        gm.scene = live.scene
        gm.world.build(in: live.scene)
        gm.hud.attach(to: live.scene)
        gm.state = .exploration
    }

    private func cleanup() {
        SaveManager.delete(slot: 3)
        live.tearDown()
        gm = nil; live = nil
    }

    /// Attend que la prise soit finie et que Kael puisse relancer.
    private func waitUntilIdle() {
        XCTAssertTrue(live.wait(until: { !self.gm.isFishing }, timeout: 6),
                      "la pêche doit rendre la main — sinon Kael reste figé au bord du lac")
    }

    // MARK: -

    func test_hookInsideTheWindow_catchesGold() {
        prepare(); defer { cleanup() }
        let gold = gm.player.gold
        gm.startFishing()
        XCTAssertTrue(gm.isFishing)
        XCTAssertFalse(gm.fishingHookable, "pas de touche au lancer")

        XCTAssertTrue(live.wait(until: { self.gm.fishingHookable }, timeout: 4), "le poisson mord")
        XCTAssertTrue(gm.attemptHook(), "A est consommé")
        let gained = gm.player.gold - gold
        XCTAssertTrue((18...46).contains(gained), "prise de 18 à 46 or, obtenu \(gained)")
        waitUntilIdle()
    }

    func test_hookTooEarly_scaresTheFish() {
        prepare(); defer { cleanup() }
        let gold = gm.player.gold, shards = gm.player.aetherShards
        gm.startFishing()
        XCTAssertTrue(gm.attemptHook(), "l'appui est consommé…")
        XCTAssertEqual(gm.player.gold, gold, "…mais ferrer avant la touche fait fuir")
        XCTAssertEqual(gm.player.aetherShards, shards)
        XCTAssertTrue(gm.fishingResolved)
        waitUntilIdle()
    }

    func test_doingNothing_letsTheFishEscape() {
        prepare(); defer { cleanup() }
        let gold = gm.player.gold
        gm.startFishing()
        XCTAssertTrue(live.wait(until: { self.gm.fishingResolved }, timeout: 5),
                      "la fenêtre se referme toute seule")
        XCTAssertEqual(gm.player.gold, gold)
        waitUntilIdle()
    }

    func test_cannotCastTwice_andHookWithoutFishingIsIgnored() {
        prepare(); defer { cleanup() }
        XCTAssertFalse(gm.attemptHook(), "sans prise en cours, A garde son rôle normal")

        gm.startFishing()
        gm.fishingHookable = true   // on force la touche…
        gm.startFishing()           // …et un second lancer ne doit rien réinitialiser
        XCTAssertTrue(gm.fishingHookable, "un lancer pendant la prise est ignoré")
        XCTAssertTrue(gm.attemptHook())
        XCTAssertFalse(gm.attemptHook(), "la prise est déjà jouée : plus rien à ferrer")
        waitUntilIdle()
    }

    /// Le bouton A au bord du lac lance la prise (câblage `triggerNearbyAction`).
    func test_actionButtonAtTheShore_startsFishing() {
        prepare(); defer { cleanup() }
        gm.phase = .forest
        gm.inOverworld = true
        gm.world.switchToOverworld(in: live.scene)
        let shore = WorldBuilder.overworldFishingSpot(w: gm.world.worldWidth, h: gm.world.worldHeight)
        gm.world.kael.position = shore
        gm.updateInteractionHint()
        XCTAssertTrue(gm.fishingSpotInRange)

        gm.triggerNearbyAction(in: live.scene)
        XCTAssertTrue(gm.isFishing, "A au bord du lac : on lance")
        live.wait(until: { self.gm.fishingResolved }, timeout: 5)
        waitUntilIdle()
    }
}
