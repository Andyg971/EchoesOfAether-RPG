import SpriteKit

enum GameState {
    case exploration
    case dialogue
    case combat
    case shop
    case transition
}

enum GamePhase: Int, CaseIterable, Codable {
    case wake
    case village
    case forest
    case shrine
    case complete

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
    var weaponLevel: Int = 0      // 0=poings, 1=lame fer, 2=lame runique
    var armorLevel: Int = 0       // 0=aucune, 1=cotte mailles, 2=armure renforcée
    var potions: Int = 0          // max 3
    var aetherShards: Int = 0     // recharge ATB

    var questDelivery: QuestState = .inactive   // livrer colis de Mara à Garen
    var questMushroom: QuestState = .inactive   // champignon pour Mara (après forêt)
    var talkedToSage: Bool = false
    var talkedToChild: Bool = false
    var talkedToVillager: Bool = false
    var innRested: Bool = false

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
            talkedToSage: talkedToSage, talkedToChild: talkedToChild,
            talkedToVillager: talkedToVillager, innRested: innRested,
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
        talkedToSage = data.talkedToSage
        talkedToChild = data.talkedToChild
        talkedToVillager = data.talkedToVillager
        innRested = data.innRested
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
    let talkedToSage: Bool
    let talkedToChild: Bool
    let talkedToVillager: Bool
    let innRested: Bool
    let phase: GamePhase
    let resonanceTotal: Int
}
