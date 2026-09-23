import XCTest
@testable import EchoesOfAether

/// Le mur d'achat n'a pas le droit de s'ouvrir avant que les droits soient
/// lus : juste après le lancement, `isUnlocked` vaut `false` même pour un
/// joueur qui a payé. Recharger une sauvegarde « fin de l'Acte I » à ce
/// moment-là lui présentait le mur d'achat d'un jeu qu'il possède.
@MainActor
final class StoreGateTests: XCTestCase {

    private func settle(until done: () -> Bool) async {
        for _ in 0..<100 where !done() { await Task.yield() }
    }

    func test_requireFullGame_waitsForEntitlements_thenResumesForABuyer() async {
        defer { SaveManager.delete(slot: 3) }
        let store = StoreManager.shared
        let wasUnlocked = store.isUnlocked
        defer { store.setUnlockedForTesting(wasUnlocked) }
        let gm = GameManager(); gm.activeSlot = 3

        store.setNotReadyForTesting()
        var calls = 0
        gm.requireFullGame { calls += 1 }
        XCTAssertEqual(calls, 0, "droits inconnus : on attend")
        XCTAssertNil(gm.pendingUnlockAction, "et le mur ne s'arme pas")

        store.setUnlockedForTesting(true)          // droits lus : acheteur
        await settle { calls > 0 }
        XCTAssertEqual(calls, 1, "l'acheteur passe sans voir le mur")
        XCTAssertNil(gm.pendingUnlockAction)
    }

    func test_requireFullGame_waitsForEntitlements_thenArmsTheWallForANonBuyer() async {
        defer { SaveManager.delete(slot: 3) }
        let store = StoreManager.shared
        let wasUnlocked = store.isUnlocked
        defer { store.setUnlockedForTesting(wasUnlocked) }
        let gm = GameManager(); gm.activeSlot = 3

        store.setNotReadyForTesting()
        var calls = 0
        gm.requireFullGame { calls += 1 }
        store.setUnlockedForTesting(false)         // droits lus : pas d'achat
        await settle { gm.pendingUnlockAction != nil }
        XCTAssertEqual(calls, 0)
        XCTAssertNotNil(gm.pendingUnlockAction, "le mur s'arme une fois les droits connus")
    }

    /// Le fichier `.storekit` du dépôt, celui que charge le schéma Xcode.
    private var storeKitFile: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("EchoesOfAether.storekit")
    }

    func test_storeIsConfigured_andProductIDMatchesTheStoreKitFile() throws {
        XCTAssertTrue(StoreManager.isStoreKitConfigured, "mur d'achat branché")
        let json = try String(contentsOf: storeKitFile, encoding: .utf8)
        XCTAssertTrue(json.contains("\"\(StoreManager.fullGameID)\""))
        XCTAssertTrue(json.contains("\"NonConsumable\""))
    }
}
