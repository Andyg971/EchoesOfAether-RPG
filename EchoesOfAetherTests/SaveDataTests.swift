import XCTest
@testable import EchoesOfAether

/// Tests de sérialisation `SaveData` (round-trip) et de rétro-compatibilité
/// (champs optionnels absents des anciennes sauvegardes).
///
/// ⚠️ Cible de test non encore référencée dans le projet Xcode — voir la note
/// dans `PlayerStateTests.swift`.
@MainActor
final class SaveDataTests: XCTestCase {

    func testRoundTripPreservesFields() throws {
        let player = PlayerState()
        player.gold = 137
        player.weaponLevel = 2
        player.armorLevel = 1
        player.potions = 3
        player.aetherShards = 4
        _ = player.gainXP(PlayerState.xpForLevel(1) + 5)   // level 2, xp 5
        player.questDelivery = .complete
        player.questLyraShards = .active
        player.bossDefeated = true
        player.loreDiscovered = ["eran", "void"]
        player.act3EranMet = true
        player.act3EndingChoice = 1

        let data = player.toSaveData(phase: .act3, resonance: 42)
        let encoded = try JSONEncoder().encode(data)
        let decoded = try JSONDecoder().decode(SaveData.self, from: encoded)

        XCTAssertEqual(decoded.gold, 137)
        XCTAssertEqual(decoded.weaponLevel, 2)
        XCTAssertEqual(decoded.armorLevel, 1)
        XCTAssertEqual(decoded.potions, 3)
        XCTAssertEqual(decoded.aetherShards, 4)
        XCTAssertEqual(decoded.level, 2)
        XCTAssertEqual(decoded.xp, 5)
        XCTAssertEqual(decoded.questDelivery, .complete)
        XCTAssertEqual(decoded.questLyraShards, .active)
        XCTAssertTrue(decoded.bossDefeated)
        XCTAssertEqual(Set(decoded.loreDiscovered), ["eran", "void"])
        XCTAssertEqual(decoded.act3EranMet, true)
        XCTAssertEqual(decoded.act3EndingChoice, 1)
        XCTAssertEqual(decoded.phase, .act3)
        XCTAssertEqual(decoded.resonanceTotal, 42)
    }

    func testLoadRestoresPlayerState() throws {
        let original = PlayerState()
        original.gold = 99
        original.kaelCorruptionLevel = 3
        original.act3EndingChoice = 0
        let data = original.toSaveData(phase: .ruins, resonance: 10)

        let encoded = try JSONEncoder().encode(data)
        let decoded = try JSONDecoder().decode(SaveData.self, from: encoded)

        let restored = PlayerState()
        restored.load(from: decoded)
        XCTAssertEqual(restored.gold, 99)
        XCTAssertEqual(restored.kaelCorruptionLevel, 3)
        XCTAssertEqual(restored.act3EndingChoice, 0)
        // currentHP est toujours rempli au chargement.
        XCTAssertEqual(restored.currentHP, restored.currentMaxHP)
    }

    /// Round-trip des champs de l'Acte IV (Le Cœur du Vide).
    func testAct4FieldsRoundTrip() throws {
        let player = PlayerState()
        player.act4MemoriesSeen = ["1", "3"]
        player.act4ReflectionsFreed = ["elder", "smith", "lost"]
        player.act4DevourersDefeated = true
        player.act4VoiceConfronted = true
        player.act4BossDefeated = true
        player.act4EndingChoice = 1

        let data = player.toSaveData(phase: .act4, resonance: 77)
        let encoded = try JSONEncoder().encode(data)
        let decoded = try JSONDecoder().decode(SaveData.self, from: encoded)

        XCTAssertEqual(decoded.phase, .act4)
        XCTAssertEqual(Set(decoded.act4MemoriesSeen ?? []), ["1", "3"])
        XCTAssertEqual(Set(decoded.act4ReflectionsFreed ?? []), ["elder", "smith", "lost"])
        XCTAssertEqual(decoded.act4DevourersDefeated, true)
        XCTAssertEqual(decoded.act4VoiceConfronted, true)
        XCTAssertEqual(decoded.act4BossDefeated, true)
        XCTAssertEqual(decoded.act4EndingChoice, 1)

        let restored = PlayerState()
        restored.load(from: decoded)
        XCTAssertEqual(restored.act4MemoriesSeen, ["1", "3"])
        XCTAssertEqual(restored.act4ReflectionsFreed, ["elder", "smith", "lost"])
        XCTAssertTrue(restored.act4DevourersDefeated)
        XCTAssertTrue(restored.act4VoiceConfronted)
        XCTAssertTrue(restored.act4BossDefeated)
        XCTAssertEqual(restored.act4EndingChoice, 1)
    }

    /// Round-trip du palier New Game+.
    func testNewGamePlusRoundTrip() throws {
        let player = PlayerState()
        player.newGamePlus = 2
        let data = player.toSaveData(phase: .village, resonance: 0)
        let decoded = try JSONDecoder().decode(
            SaveData.self, from: try JSONEncoder().encode(data))
        XCTAssertEqual(decoded.newGamePlus, 2)

        let restored = PlayerState()
        restored.load(from: decoded)
        XCTAssertEqual(restored.newGamePlus, 2)
    }

    /// La graine New Game+ conserve les acquis et incrémente le palier ;
    /// la progression narrative repart de zéro sur un état frais.
    func testNewGamePlusSeedKeepsProgressResetsStory() throws {
        let finished = PlayerState()
        finished.gold = 900
        finished.weaponLevel = 2
        finished.armorLevel = 2
        _ = finished.gainXP(PlayerState.xpForLevel(1) * 20)
        finished.questBramOre = .complete
        finished.act4EndingChoice = 0
        finished.newGamePlus = 1

        let data = finished.toSaveData(phase: .act4, resonance: 0)
        let seed = NewGamePlusSeed(from: data)
        XCTAssertEqual(seed.newGamePlus, 2)          // palier +1
        XCTAssertEqual(seed.gold, 900)               // acquis conservé

        let fresh = PlayerState()
        fresh.applyNewGamePlusSeed(seed)
        XCTAssertEqual(fresh.gold, 900)              // acquis appliqués
        XCTAssertEqual(fresh.weaponLevel, 2)
        XCTAssertEqual(fresh.newGamePlus, 2)
        XCTAssertEqual(fresh.questBramOre, .inactive) // histoire remise à zéro
        XCTAssertNil(fresh.act4EndingChoice)
    }

    /// Une sauvegarde « legacy » sans les clés optionnelles (level, xp, act3*)
    /// doit se décoder et fournir des valeurs par défaut sûres.
    func testBackwardCompatibilityWithMissingOptionalFields() throws {
        let legacyJSON = """
        {
          "gold": 20,
          "maxHP": 280,
          "weaponLevel": 0,
          "armorLevel": 0,
          "potions": 0,
          "aetherShards": 0,
          "questDelivery": "inactive",
          "questMushroom": "inactive",
          "questLyraShards": "inactive",
          "questChildToy": "inactive",
          "talkedToSage": false,
          "talkedToChild": false,
          "talkedToVillager": false,
          "innRested": false,
          "forestProgress": 0,
          "bossDefeated": false,
          "lyraDeceased": false,
          "act2SageConsulted": false,
          "ruinsProgress": 0,
          "act2DorinPassed": false,
          "act2NightmareSeen": false,
          "act2Vision1Seen": false,
          "act2EranFound": false,
          "kaelCorruptionLevel": 0,
          "loreDiscovered": [],
          "phase": 1,
          "resonanceTotal": 0
        }
        """
        let data = Data(legacyJSON.utf8)
        let decoded = try JSONDecoder().decode(SaveData.self, from: data)

        XCTAssertNil(decoded.level)
        XCTAssertNil(decoded.xp)
        XCTAssertNil(decoded.act3EranMet)
        XCTAssertNil(decoded.act3BossDefeated)
        XCTAssertNil(decoded.act3EndingChoice)
        XCTAssertNil(decoded.act4MemoriesSeen)
        XCTAssertNil(decoded.act4BossDefeated)
        XCTAssertNil(decoded.act4EndingChoice)
        XCTAssertEqual(decoded.phase, .village)

        // Le chargement applique les défauts sûrs.
        let player = PlayerState()
        player.load(from: decoded)
        XCTAssertEqual(player.level, 1)
        XCTAssertEqual(player.xp, 0)
        XCTAssertFalse(player.act3EranMet)
        XCTAssertFalse(player.act3BossDefeated)
        XCTAssertNil(player.act3EndingChoice)
        XCTAssertTrue(player.act4MemoriesSeen.isEmpty)
        XCTAssertFalse(player.act4BossDefeated)
        XCTAssertNil(player.act4EndingChoice)
    }
}
