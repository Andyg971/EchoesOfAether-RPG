import SpriteKit

enum GameState {
    case exploration
    case dialogue
    case combat
    case shop
    case inventory
    case transition
}

enum GamePhase: Int, CaseIterable, Codable {
    case wake
    case village
    case forest
    case shrine
    case complete
    case act2    = 5   // Retour à Solis après le sanctuaire
    case ruins   = 6   // Ruines de la Source
    case fallen  = 7   // Kael seul après la mort de Lyra

    var next: GamePhase? {
        GamePhase(rawValue: rawValue + 1)
    }
}

enum QuestState: String, Codable {
    case inactive, active, complete
}

@MainActor
struct InteractionTarget {
    let node: SKNode
    let radius: CGFloat
    let action: () -> Void

    func contains(_ point: CGPoint) -> Bool {
        point.distance(to: node.position) < radius
    }
}

extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        hypot(x - other.x, y - other.y)
    }
}

// MARK: - PlayerState

@MainActor
final class PlayerState {
    var gold: Int = 20
    var maxHP: Int = 280
    var currentHP: Int = 280      // PV actuels — non sauvegardé, reset sur load
    var weaponLevel: Int = 0      // 0=poings, 1=lame fer, 2=lame runique
    var armorLevel: Int = 0       // 0=aucune, 1=cotte mailles, 2=armure renforcée
    var potions: Int = 0          // max 3
    var aetherShards: Int = 0     // recharge ATB

    var questDelivery: QuestState = .inactive   // livrer colis de Mara à Garen
    var questMushroom: QuestState = .inactive   // champignon pour Mara (après forêt)
    var questLyraShards: QuestState = .inactive // Lyra demande 5 Aether Shards
    var questChildToy: QuestState = .inactive   // enfant a perdu jouet en forêt
    var talkedToSage: Bool = false
    var talkedToChild: Bool = false
    var talkedToVillager: Bool = false
    var innRested: Bool = false
    var forestProgress: Int = 0  // 0=fresh, 1=beast dead, 2=wolves dead
    var bossDefeated: Bool = false
    var lyraDeceased: Bool = false
    var act2SageConsulted: Bool = false
    var ruinsProgress: Int = 0     // 0=fresh, 1=combat1 done, 2=archivist done
    var act2DorinPassed: Bool = false
    var act2NightmareSeen: Bool = false
    var act2Vision1Seen: Bool = false
    var act2EranFound: Bool = false
    var kaelCorruptionLevel: Int = 0  // 0-3, progression visuelle

    var attackDamage: Int { 42 + weaponLevel * 22 }
    var blackSlashDamage: Int { 92 + weaponLevel * 35 }
    var currentMaxHP: Int { maxHP + armorLevel * 50 }

    var potionsFull: Bool { potions >= 3 }

    // MARK: - Save / Load

    func toSaveData(phase: GamePhase, resonance: Int) -> SaveData {
        SaveData(
            gold: gold, maxHP: maxHP,
            weaponLevel: weaponLevel, armorLevel: armorLevel,
            potions: potions, aetherShards: aetherShards,
            questDelivery: questDelivery, questMushroom: questMushroom,
            questLyraShards: questLyraShards, questChildToy: questChildToy,
            talkedToSage: talkedToSage, talkedToChild: talkedToChild,
            talkedToVillager: talkedToVillager, innRested: innRested,
            forestProgress: forestProgress, bossDefeated: bossDefeated,
            lyraDeceased: lyraDeceased,
            act2SageConsulted: act2SageConsulted,
            ruinsProgress: ruinsProgress,
            act2DorinPassed: act2DorinPassed,
            act2NightmareSeen: act2NightmareSeen,
            act2Vision1Seen: act2Vision1Seen,
            act2EranFound: act2EranFound,
            kaelCorruptionLevel: kaelCorruptionLevel,
            phase: phase, resonanceTotal: resonance
        )
    }

    func load(from data: SaveData) {
        gold = data.gold
        maxHP = data.maxHP
        weaponLevel = data.weaponLevel
        armorLevel = data.armorLevel
        potions = data.potions
        aetherShards = data.aetherShards
        questDelivery = data.questDelivery
        questMushroom = data.questMushroom
        questLyraShards = data.questLyraShards
        questChildToy = data.questChildToy
        talkedToSage = data.talkedToSage
        talkedToChild = data.talkedToChild
        talkedToVillager = data.talkedToVillager
        innRested = data.innRested
        forestProgress = data.forestProgress
        bossDefeated = data.bossDefeated
        lyraDeceased = data.lyraDeceased
        act2SageConsulted = data.act2SageConsulted
        ruinsProgress = data.ruinsProgress
        act2DorinPassed = data.act2DorinPassed
        act2NightmareSeen = data.act2NightmareSeen
        act2Vision1Seen = data.act2Vision1Seen
        act2EranFound = data.act2EranFound
        kaelCorruptionLevel = data.kaelCorruptionLevel
        currentHP = currentMaxHP   // toujours plein au chargement
    }
}

// MARK: - SaveData

struct SaveData: Codable {
    let gold: Int
    let maxHP: Int
    let weaponLevel: Int
    let armorLevel: Int
    let potions: Int
    let aetherShards: Int
    let questDelivery: QuestState
    let questMushroom: QuestState
    let questLyraShards: QuestState
    let questChildToy: QuestState
    let talkedToSage: Bool
    let talkedToChild: Bool
    let talkedToVillager: Bool
    let innRested: Bool
    let forestProgress: Int
    let bossDefeated: Bool
    let lyraDeceased: Bool
    let act2SageConsulted: Bool
    let ruinsProgress: Int
    let act2DorinPassed: Bool
    let act2NightmareSeen: Bool
    let act2Vision1Seen: Bool
    let act2EranFound: Bool
    let kaelCorruptionLevel: Int
    let phase: GamePhase
    let resonanceTotal: Int
}
