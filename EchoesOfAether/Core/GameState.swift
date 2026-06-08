import SpriteKit

enum GameState {
    case exploration
    case dialogue
    case combat
    case shop
    case inventory
    case transition
}


enum HouseInteriorKind: String {
    case armory
    case apothecary
    case inn
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
    case act3    = 8   // Le Seuil — Kael comme antagoniste

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

    // Niveau max ; après L30, plus de XP gagné. Choix narratif : Kael
    // atteint le plafond avant le Seuil de l'Acte III.
    static let maxLevel: Int = 30

    var gold: Int = 20
    var maxHP: Int = 280
    var currentHP: Int = 280      // PV actuels — non sauvegardé, reset sur load
    var weaponLevel: Int = 0      // 0=poings, 1=lame fer, 2=lame runique
    var armorLevel: Int = 0       // 0=aucune, 1=cotte mailles, 2=armure renforcée
    var potions: Int = 0          // max 3
    var aetherShards: Int = 0     // recharge ATB

    var level: Int = 1
    var xp: Int = 0               // XP cumulé dans le niveau courant

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
    var loreDiscovered: Set<String> = []  // IDs entrées lore trouvées
    var act3EranMet: Bool = false      // rencontre Eran au Seuil faite
    var act3BossDefeated: Bool = false // Gardien du Seuil vaincu → vraie fin
    // Choix d'Eran qui détermine la fin de l'Acte III :
    // nil = non choisi, 0 = franchir le Seuil, 1 = résister / refuser le Vide.
    var act3EndingChoice: Int? = nil

    // MARK: - Stats dérivées (incluent le bonus de niveau)
    //
    // Gain par niveau : +12 HP / +2 ATK / +4 Black Slash. L1 → L30 :
    // HP 280→628, ATK 42→100, Black Slash 92→208 (avant équipement).
    var attackDamage: Int      { 42 + weaponLevel * 22 + (level - 1) * 2 }
    var blackSlashDamage: Int  { 92 + weaponLevel * 35 + (level - 1) * 4 }
    var currentMaxHP: Int      { maxHP + armorLevel * 50 + (level - 1) * 12 }

    var potionsFull: Bool { potions >= 3 }

    // MARK: - Système de niveau

    /// XP nécessaire pour passer du niveau `n` au niveau `n+1`.
    /// Courbe : 80 * n^1.5 — progression douce au début, plus longue en fin.
    static func xpForLevel(_ n: Int) -> Int {
        guard n >= 1, n < maxLevel else { return Int.max }
        return Int(80.0 * pow(Double(n), 1.5))
    }

    /// XP requis avant le prochain niveau (au niveau actuel).
    var xpToNextLevel: Int { Self.xpForLevel(level) }

    /// Progression vers le prochain niveau (0...1).
    var xpProgress: CGFloat {
        guard level < Self.maxLevel else { return 1 }
        let need = xpToNextLevel
        return need > 0 ? CGFloat(xp) / CGFloat(need) : 0
    }

    /// Ajoute de l'XP et déclenche un level-up tant que le seuil est dépassé.
    /// Retourne le nombre de niveaux gagnés (0 si rien ; > 0 → afficher overlay).
    /// Plafonnée à `maxLevel`.
    @discardableResult
    func gainXP(_ amount: Int) -> Int {
        guard amount > 0, level < Self.maxLevel else { return 0 }
        xp += amount
        var leveledUp = 0
        while level < Self.maxLevel, xp >= xpToNextLevel {
            xp -= xpToNextLevel
            level += 1
            leveledUp += 1
        }
        if level >= Self.maxLevel {
            xp = 0   // affichage propre au plafond
        }
        return leveledUp
    }

    // MARK: - Save / Load

    func toSaveData(phase: GamePhase, resonance: Int) -> SaveData {
        SaveData(
            gold: gold, maxHP: maxHP,
            weaponLevel: weaponLevel, armorLevel: armorLevel,
            potions: potions, aetherShards: aetherShards,
            level: level, xp: xp,
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
            loreDiscovered: Array(loreDiscovered),
            act3EranMet: act3EranMet,
            act3BossDefeated: act3BossDefeated,
            act3EndingChoice: act3EndingChoice,
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
        // Saves antérieurs au système de niveau : repart à L1/0
        level = max(1, min(Self.maxLevel, data.level ?? 1))
        xp = max(0, data.xp ?? 0)
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
        loreDiscovered = Set(data.loreDiscovered)
        act3EranMet = data.act3EranMet ?? false
        act3BossDefeated = data.act3BossDefeated ?? false
        act3EndingChoice = data.act3EndingChoice
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
    // Niveau & XP (optionnels — saves antérieurs au système n'ont pas ces clés)
    let level: Int?
    let xp: Int?
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
    let loreDiscovered: [String]
    // Acte III (optionnels — saves antérieurs n'ont pas ces clés)
    let act3EranMet: Bool?
    let act3BossDefeated: Bool?
    let act3EndingChoice: Int?
    let phase: GamePhase
    let resonanceTotal: Int
}
