import XCTest
@testable import EchoesOfAether

/// Arsenal de Kael : styles d'armes, accessoires gardés dans le sac,
/// migration des anciennes sauvegardes et vitrine de la forge de Bram.
@MainActor
final class EquipmentTests: XCTestCase {

    // MARK: - Catalogue

    func test_catalog_hasOneWeaponPerStyleAndTier() {
        for style in WeaponStyle.allCases {
            for tier in 1...EquipmentCatalog.maxTier {
                XCTAssertNotNil(EquipmentCatalog.weapon(style: style, tier: tier), "\(style) palier \(tier)")
            }
        }
        XCTAssertEqual(Set(EquipmentCatalog.weapons.map(\.id)).count, EquipmentCatalog.weapons.count,
                       "ids uniques")
    }

    func test_catalog_higherTierBeatsLowerTierOfSameStyle() {
        for style in WeaponStyle.allCases {
            for tier in 2...EquipmentCatalog.maxTier {
                guard let low = EquipmentCatalog.weapon(style: style, tier: tier - 1),
                      let high = EquipmentCatalog.weapon(style: style, tier: tier) else {
                    return XCTFail("catalogue incomplet")
                }
                XCTAssertGreaterThan(high.bonus.attack, low.bonus.attack, high.id)
                XCTAssertGreaterThan(high.bonus.slash, low.bonus.slash, high.id)
                XCTAssertGreaterThan(high.price, low.price, high.id)
            }
        }
    }

    // MARK: - Migration

    func test_legacyWeaponLevel_grantsBladesAndKeepsOldStats() {
        let player = PlayerState()
        player.weaponLevel = 2
        XCTAssertEqual(player.ownedWeapons, ["blade1", "blade2"])
        XCTAssertEqual(player.equippedWeaponID, "blade2")
        // Mêmes valeurs qu'avant les styles : 42 + 2 × 22 et 92 + 2 × 35.
        XCTAssertEqual(player.attackDamage, 86)
        XCTAssertEqual(player.blackSlashDamage, 162)
    }

    func test_load_saveWithoutArsenal_readsTheBladeTier() throws {
        let old = PlayerState()
        old.weaponLevel = 3
        old.equippedAccessory = "shade"
        let encoded = try JSONEncoder().encode(old.toSaveData(phase: .village, resonance: 0))
        // Sauvegarde d'avant la refonte : ces clés n'existaient pas.
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        json["ownedWeapons"] = nil
        json["equippedWeapon"] = nil
        json["ownedAccessories"] = nil
        let legacy = try JSONDecoder().decode(SaveData.self,
                                              from: JSONSerialization.data(withJSONObject: json))

        let restored = PlayerState()
        restored.load(from: legacy)
        XCTAssertEqual(restored.equippedWeaponID, "blade3")
        XCTAssertEqual(restored.ownedWeapons, ["blade1", "blade2", "blade3"])
        XCTAssertEqual(restored.ownedAccessories, ["shade"], "l'accessoire porté rejoint le sac")
        XCTAssertEqual(restored.equippedAccessory, "shade")
    }

    func test_saveRoundTrip_keepsArsenalAndAccessories() throws {
        let player = PlayerState()
        player.acquire(try XCTUnwrap(EquipmentCatalog.weapon(id: "rapier2")))
        player.acquire(try XCTUnwrap(EquipmentCatalog.weapon(id: "echo1")))
        player.equipWeapon(id: "rapier2")
        player.acquire(try XCTUnwrap(EquipmentCatalog.accessory(id: "ember")))
        player.acquire(try XCTUnwrap(EquipmentCatalog.accessory(id: "resonance")))

        let encoded = try JSONEncoder().encode(player.toSaveData(phase: .forest, resonance: 0))
        let restored = PlayerState()
        restored.load(from: try JSONDecoder().decode(SaveData.self, from: encoded))

        XCTAssertEqual(restored.ownedWeapons, ["rapier2", "echo1"])
        XCTAssertEqual(restored.equippedWeaponID, "rapier2")
        XCTAssertEqual(restored.ownedAccessories, ["ember", "resonance"])
        XCTAssertEqual(restored.equippedAccessory, "resonance")
    }

    func test_sanitize_dropsUnknownIDsAndEquipsBestOwned() {
        let player = PlayerState()
        player.restoreEquipment(weaponLevel: 0,
                                ownedWeapons: ["greatsword1", "greatsword2", "excalibur"],
                                equippedWeapon: "excalibur",
                                ownedAccessories: ["mystery"],
                                equippedAccessory: "mystery")
        XCTAssertEqual(player.ownedWeapons, ["greatsword1", "greatsword2"])
        XCTAssertEqual(player.equippedWeaponID, "greatsword2")
        XCTAssertTrue(player.ownedAccessories.isEmpty)
        XCTAssertNil(player.equippedAccessory)
    }

    func test_newGamePlus_carriesArsenal() throws {
        let finished = PlayerState()
        finished.acquire(try XCTUnwrap(EquipmentCatalog.weapon(id: "echo3")))
        finished.acquire(try XCTUnwrap(EquipmentCatalog.accessory(id: "shade")))
        let seed = NewGamePlusSeed(from: finished.toSaveData(phase: .act4, resonance: 0))

        let fresh = PlayerState()
        fresh.applyNewGamePlusSeed(seed)
        XCTAssertEqual(fresh.equippedWeaponID, "echo3")
        XCTAssertEqual(fresh.equippedAccessory, "shade")
    }

    // MARK: - Effets

    func test_accessories_matchTheirFormerValues() {
        let player = PlayerState()
        player.ownedAccessories = ["ember", "shade", "resonance"]
        player.equipAccessory(id: "ember")
        XCTAssertEqual(player.critChance, 0.25, accuracy: 0.0001)
        player.equipAccessory(id: "shade")
        XCTAssertEqual(player.dodgeChance, 0.25, accuracy: 0.0001)
        player.equipAccessory(id: "resonance")
        XCTAssertEqual(player.attackMPRegen, 16)
    }

    func test_styles_tradeAttackForPerks() throws {
        let player = PlayerState()
        player.acquire(try XCTUnwrap(EquipmentCatalog.weapon(id: "greatsword1")))
        XCTAssertLessThan(player.dodgeChance, 0.10, "l'espadon pèse sur l'esquive")
        let heavyAttack = player.attackDamage

        player.acquire(try XCTUnwrap(EquipmentCatalog.weapon(id: "rapier1")))
        XCTAssertGreaterThan(player.critChance, 0.12, "la rapière crée des critiques")
        XCTAssertLessThan(player.attackDamage, heavyAttack)

        player.acquire(try XCTUnwrap(EquipmentCatalog.weapon(id: "echo1")))
        XCTAssertGreaterThan(player.attackMPRegen, 6, "la lame d'écho rend de la Magie")
    }

    func test_equip_requiresOwnership() {
        let player = PlayerState()
        XCTAssertFalse(player.equipWeapon(id: "blade3"))
        XCTAssertFalse(player.equipAccessory(id: "ember"))
        XCTAssertNil(player.equippedWeaponID)
    }

    func test_preview_leavesEquipmentUntouched() throws {
        let player = PlayerState()
        player.acquire(try XCTUnwrap(EquipmentCatalog.weapon(id: "blade1")))
        let preview = player.preview(weaponID: "greatsword3", accessoryID: "ember")
        XCTAssertEqual(player.equippedWeaponID, "blade1")
        XCTAssertNil(player.equippedAccessory)
        XCTAssertEqual(preview.attack, 42 + 90)
        XCTAssertEqual(preview.critPercent, 25)
    }

    func test_arsenal_listsBestTierOfEachStyle() {
        let player = PlayerState()
        player.ownedWeapons = ["blade1", "blade2", "rapier1"]
        XCTAssertEqual(player.arsenal.map(\.id), ["blade2", "rapier1"])
        XCTAssertEqual(player.nextWeapon(for: .blade)?.id, "blade3")
        XCTAssertEqual(player.nextWeapon(for: .echo)?.id, "echo1")
    }

    // MARK: - Forge de Bram

    func test_bram_offersNextTierOfEveryStyle_thenArmorAndAccessories() {
        let gm = GameManager()
        let names = gm.bramItems().map { String(localized: $0.nameKey) }
        XCTAssertEqual(names.count, 4 + 1 + 3, "4 armes, 1 armure, 3 accessoires")
        XCTAssertEqual(names.first, String(localized: "weapon.blade1.name"))

        gm.player.acquire(EquipmentCatalog.accessories[0])
        gm.player.weaponLevel = 3
        let after = gm.bramItems()
        XCTAssertEqual(after.count, 3 + 1 + 2, "lame au max, accessoire acheté retiré")
    }

    func test_bram_buyingWeaponEquipsIt() {
        let gm = GameManager()
        gm.player.gold = 500
        let items = gm.bramItems()
        guard let echo = items.firstIndex(where: {
            String(localized: $0.nameKey) == String(localized: "weapon.echo1.name")
        }) else { return XCTFail("lame des Murmures absente") }
        items[echo].onBuy(gm.player)
        XCTAssertEqual(gm.player.equippedWeaponID, "echo1")
        XCTAssertTrue(gm.player.ownedWeapons.contains("echo1"))
    }
}
