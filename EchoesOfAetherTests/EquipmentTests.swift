import XCTest
@testable import EchoesOfAether

/// Arsenal du groupe — canon : Kael aux poings, Lyra au bâton de prêtresse,
/// Eran au bâton de sorcier. Accessoires gardés dans le sac, migration des
/// anciennes sauvegardes, vitrine de la forge de Bram, bonus en combat.
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
                let lowTotal = low.bonus.attack + low.bonus.slash + low.bonus.maxMP
                    + Int(low.bonus.spellPower * 100)
                let highTotal = high.bonus.attack + high.bonus.slash + high.bonus.maxMP
                    + Int(high.bonus.spellPower * 100)
                XCTAssertGreaterThan(highTotal, lowTotal, high.id)
                if high.isSold { XCTAssertGreaterThan(high.price, low.price, high.id) }
            }
        }
    }

    // MARK: - Migration

    func test_legacyWeaponLevel_grantsBladesAndKeepsOldStats() {
        let player = PlayerState()
        player.weaponLevel = 2
        XCTAssertEqual(player.ownedWeapons, ["gauntlets1", "gauntlets2"])
        XCTAssertEqual(player.equippedWeaponID, "gauntlets2")
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
        XCTAssertEqual(restored.equippedWeaponID, "gauntlets3")
        XCTAssertEqual(restored.ownedWeapons, ["gauntlets1", "gauntlets2", "gauntlets3"])
        XCTAssertEqual(restored.ownedAccessories, ["shade"], "l'accessoire porté rejoint le sac")
        XCTAssertEqual(restored.equippedAccessory, "shade")
    }

    func test_saveRoundTrip_keepsArsenalAndAccessories() throws {
        let player = PlayerState()
        player.acquire(try XCTUnwrap(EquipmentCatalog.weapon(id: "wraps2")))
        player.acquire(try XCTUnwrap(EquipmentCatalog.weapon(id: "gloves1")))
        player.equipWeapon(id: "wraps2")
        player.acquire(try XCTUnwrap(EquipmentCatalog.weapon(id: "crook2")))
        player.acquire(try XCTUnwrap(EquipmentCatalog.accessory(id: "ember")))
        player.acquire(try XCTUnwrap(EquipmentCatalog.accessory(id: "resonance")))

        let encoded = try JSONEncoder().encode(player.toSaveData(phase: .forest, resonance: 0))
        let restored = PlayerState()
        restored.load(from: try JSONDecoder().decode(SaveData.self, from: encoded))

        XCTAssertEqual(restored.ownedWeapons, ["wraps2", "gloves1", "crook2"])
        XCTAssertEqual(restored.equippedWeaponID, "wraps2")
        XCTAssertEqual(restored.equippedWeapon(for: .lyra)?.id, "crook2")
        XCTAssertEqual(restored.ownedAccessories, ["ember", "resonance"])
        XCTAssertEqual(restored.equippedAccessory, "resonance")
    }

    func test_sanitize_dropsUnknownIDsAndEquipsBestOwned() {
        let player = PlayerState()
        player.restoreEquipment(weaponLevel: 0,
                                ownedWeapons: ["knuckles1", "knuckles2", "excalibur"],
                                equippedWeapon: "excalibur",
                                ownedAccessories: ["mystery"],
                                equippedAccessory: "mystery")
        XCTAssertEqual(player.ownedWeapons, ["knuckles1", "knuckles2"])
        XCTAssertEqual(player.equippedWeaponID, "knuckles2")
        XCTAssertTrue(player.ownedAccessories.isEmpty)
        XCTAssertNil(player.equippedAccessory)
    }

    func test_newGamePlus_carriesArsenal() throws {
        let finished = PlayerState()
        finished.acquire(try XCTUnwrap(EquipmentCatalog.weapon(id: "gloves3")))
        finished.acquire(try XCTUnwrap(EquipmentCatalog.accessory(id: "shade")))
        let seed = NewGamePlusSeed(from: finished.toSaveData(phase: .act4, resonance: 0))

        let fresh = PlayerState()
        fresh.applyNewGamePlusSeed(seed)
        XCTAssertEqual(fresh.equippedWeaponID, "gloves3")
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
        player.acquire(try XCTUnwrap(EquipmentCatalog.weapon(id: "knuckles1")))
        XCTAssertLessThan(player.dodgeChance, 0.10, "les poings de fer pèsent sur l'esquive")
        let heavyAttack = player.attackDamage

        player.acquire(try XCTUnwrap(EquipmentCatalog.weapon(id: "wraps1")))
        XCTAssertGreaterThan(player.critChance, 0.12, "les bandelettes créent des critiques")
        XCTAssertLessThan(player.attackDamage, heavyAttack)

        player.acquire(try XCTUnwrap(EquipmentCatalog.weapon(id: "gloves1")))
        XCTAssertGreaterThan(player.attackMPRegen, 6, "les gants d'écho rendent de la Magie")
    }

    func test_equip_requiresOwnership() {
        let player = PlayerState()
        XCTAssertFalse(player.equipWeapon(id: "gauntlets3"))
        XCTAssertFalse(player.equipAccessory(id: "ember"))
        XCTAssertNil(player.equippedWeaponID)
    }

    func test_preview_leavesEquipmentUntouched() throws {
        let player = PlayerState()
        player.acquire(try XCTUnwrap(EquipmentCatalog.weapon(id: "gauntlets1")))
        let preview = player.preview(hero: .kael, weaponID: "knuckles3", accessoryID: "ember")
        XCTAssertEqual(player.equippedWeaponID, "gauntlets1")
        XCTAssertNil(player.equippedAccessory)
        XCTAssertEqual(preview.attack, 42 + 90)
        XCTAssertEqual(preview.critPercent, 25)
    }

    func test_arsenal_listsBestTierOfEachStyle() {
        let player = PlayerState()
        player.ownedWeapons = ["gauntlets1", "gauntlets2", "wraps1", "sacred1"]
        XCTAssertEqual(player.arsenal(for: .kael).map(\.id), ["gauntlets2", "wraps1"])
        XCTAssertEqual(player.arsenal(for: .lyra).map(\.id), ["sacred1"])
        XCTAssertEqual(player.nextWeapon(for: .gauntlets)?.id, "gauntlets3")
        XCTAssertEqual(player.nextWeapon(for: .gloves)?.id, "gloves1")
    }

    // MARK: - Forge de Bram

    func test_bram_offersFistsForKael_staffsForLyra_neverEransStaffs() {
        let gm = GameManager()
        let names = gm.bramItems().map { String(localized: $0.nameKey) }
        XCTAssertEqual(names.count, 4 + 2 + 1 + 3, "4 poings, 2 bâtons de Lyra, 1 armure, 3 accessoires")
        XCTAssertEqual(names.first, String(localized: "weapon.gauntlets1.name"))
        XCTAssertFalse(names.contains(String(localized: "weapon.arcane1.name")), "Eran apporte ses bâtons")

        gm.player.acquire(EquipmentCatalog.accessories[0])
        gm.player.weaponLevel = 3
        gm.player.lyraDeceased = true
        let after = gm.bramItems()
        XCTAssertEqual(after.count, 3 + 1 + 2, "gantelets au max, Lyra disparue, accessoire acheté retiré")
    }

    func test_bram_buyingWeaponEquipsIt() {
        let gm = GameManager()
        gm.player.gold = 500
        let items = gm.bramItems()
        guard let staff = items.firstIndex(where: {
            String(localized: $0.nameKey) == String(localized: "weapon.sacred1.name")
        }) else { return XCTFail("bâton de prêtresse absent") }
        items[staff].onBuy(gm.player)
        XCTAssertEqual(gm.player.equippedWeapon(for: .lyra)?.id, "sacred1")
        XCTAssertNil(gm.player.equippedWeaponID, "le bâton est pour Lyra, Kael reste aux poings")
    }

    // MARK: - Lyra et Eran

    func test_legacySwordIDs_becomeFistWeapons() {
        let player = PlayerState()
        player.restoreEquipment(weaponLevel: 0, ownedWeapons: ["blade2", "rapier1"],
                                equippedWeapon: "rapier1",
                                ownedAccessories: nil, equippedAccessory: nil)
        XCTAssertEqual(player.ownedWeapons, ["gauntlets2", "wraps1"])
        XCTAssertEqual(player.equippedWeaponID, "wraps1")
    }

    func test_staff_boostsAllyInCombat() throws {
        let player = PlayerState()
        player.acquire(try XCTUnwrap(EquipmentCatalog.weapon(id: "crook2")))
        let bonus = player.weaponBonus(for: CombatAllyKind.lyra.hero)
        let lyra = CombatSystem.AllyState(kind: .lyra, level: 1, weaponBonus: bonus)
        XCTAssertEqual(lyra.combatant.maxMP, CombatAllyKind.lyra.maxMP(level: 1) + 20)
        XCTAssertEqual(CombatAllyKind.lyraEcho.hero, .lyra, "l'Écho garde le bâton de Lyra")
    }

    func test_eranStaffs_comeWithTheStory_andOnlyOnce() {
        let player = PlayerState()
        XCTAssertTrue(player.grantStoryWeapons().isEmpty, "pas d'Eran, pas de bâton")

        player.act3EranMet = true
        XCTAssertEqual(Set(player.grantStoryWeapons().map(\.id)), ["arcane1", "battle1"])
        XCTAssertEqual(player.equippedWeapon(for: .eran)?.id, "arcane1")
        XCTAssertTrue(player.grantStoryWeapons().isEmpty, "idempotent")

        player.equipWeapon(id: "battle1")
        player.act3ShadesDefeated = true
        XCTAssertEqual(Set(player.grantStoryWeapons().map(\.id)), ["arcane2", "battle2"])
        XCTAssertEqual(player.equippedWeapon(for: .eran)?.id, "battle2", "il garde son style")

        player.act4DevourersDefeated = true
        player.grantStoryWeapons()
        XCTAssertEqual(player.arsenal(for: .eran).map(\.tier), [3, 3])
    }

    func test_allyPreview_comparesStaffs() throws {
        let player = PlayerState()
        player.acquire(try XCTUnwrap(EquipmentCatalog.weapon(id: "sacred1")))
        let worn = player.preview(hero: .lyra, weaponID: "sacred1")
        let crook = player.preview(hero: .lyra, weaponID: "crook1")
        XCTAssertGreaterThan(worn.spellPercent, crook.spellPercent)
        XCTAssertGreaterThan(crook.maxMP, worn.maxMP)
        XCTAssertEqual(worn.slash, 0, "Lyra n'a pas d'Entaille")
    }
}
