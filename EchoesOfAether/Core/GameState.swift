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
    case act4    = 9   // Le Cœur du Vide — au-delà du Seuil

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
    var aetherShards: Int = 0     // Éclats d'Aether (quête de Lyra, boutique)

    var level: Int = 1
    var xp: Int = 0               // XP cumulé dans le niveau courant

    var questDelivery: QuestState = .inactive   // livrer colis de Mara à Garen
    var questMushroom: QuestState = .inactive   // champignon pour Mara (après forêt)
    var questLyraShards: QuestState = .inactive // Lyra demande 5 Aether Shards
    var questChildToy: QuestState = .inactive   // enfant a perdu jouet en forêt
    var questMedallion: QuestState = .inactive  // talisman du fils de la villageoise
    var questBramOre: QuestState = .inactive    // fer corrompu pour la forge de Bram
    var questSageHerb: QuestState = .inactive   // herbe lunaire pour les tisanes de Sage
    var questGarenScout: QuestState = .inactive // éclaireur disparu de Garen (Tomm)
    var questMines: QuestState = .inactive      // les mines silencieuses (Cendreval)
    var minesProgress: Int = 0                  // 0=intact, 1=mineurs, 2=spectres, 3=golem vaincu
    var minesGoldTaken: Bool = false            // veine d'or ramassée (une fois)
    var questDesert: QuestState = .inactive     // le désert d'Ossara (carte du monde)
    var desertProgress: Int = 0                 // 0=intact, 1=pillards, 2=charognards, 3=colosse vaincu
    var desertChestTaken: Bool = false          // coffre enfoui ramassé (une fois)
    var desertOasisUsed: Bool = false           // oasis bue (une fois, non sauvegardé)
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
    var bestiarySeen: Set<String> = []    // espèces croisées en combat (bestiaire)
    var act3EranMet: Bool = false
    var act3EchoJoined: Bool = false            // l'Écho de Lyra a rejoint Kael
    var act3SpiritsCalmed: Set<String> = []     // esprits errants apaisés (quête)
    var act3StelesRead: Set<String> = []        // stèles du Vide examinées
    var act3ShadesDefeated: Bool = false        // combat annexe : ombres purgées      // rencontre Eran au Seuil faite
    var act3BossDefeated: Bool = false // Gardien du Seuil vaincu → vraie fin
    // Choix d'Eran qui détermine la fin de l'Acte III :
    // nil = non choisi, 0 = franchir le Seuil, 1 = résister / refuser le Vide.
    var act3EndingChoice: Int? = nil
    var act4MemoriesSeen: Set<String> = []       // fragments de mémoire examinés
    var act4ReflectionsFreed: Set<String> = []   // reflets absorbés libérés
    var act4DevourersDefeated: Bool = false      // combat annexe : dévoreurs purgés
    var act4VoiceConfronted: Bool = false        // confrontation de la Voix faite
    var act4BossDefeated: Bool = false           // Avatar du Vide vaincu
    // Choix final devant le Cœur : nil = non choisi,
    // 0 = détruire le Cœur (libérer les échos), 1 = fusionner avec le Cœur.
    var act4EndingChoice: Int? = nil

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
            questMedallion: questMedallion,
            questBramOre: questBramOre,
            questSageHerb: questSageHerb,
            questGarenScout: questGarenScout,
            questMines: questMines,
            minesProgress: minesProgress,
            minesGoldTaken: minesGoldTaken,
            questDesert: questDesert,
            desertProgress: desertProgress,
            desertChestTaken: desertChestTaken,
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
            bestiarySeen: Array(bestiarySeen),
            act3EchoJoined: act3EchoJoined,
            act3SpiritsCalmed: Array(act3SpiritsCalmed),
            act3StelesRead: Array(act3StelesRead),
            act3ShadesDefeated: act3ShadesDefeated,
            act4MemoriesSeen: Array(act4MemoriesSeen),
            act4ReflectionsFreed: Array(act4ReflectionsFreed),
            act4DevourersDefeated: act4DevourersDefeated,
            act4VoiceConfronted: act4VoiceConfronted,
            act4BossDefeated: act4BossDefeated,
            act4EndingChoice: act4EndingChoice,
            savedAt: Date(),
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
        questMedallion = data.questMedallion ?? .inactive
        questBramOre = data.questBramOre ?? .inactive
        questSageHerb = data.questSageHerb ?? .inactive
        questGarenScout = data.questGarenScout ?? .inactive
        questMines = data.questMines ?? .inactive
        minesProgress = data.minesProgress ?? 0
        minesGoldTaken = data.minesGoldTaken ?? false
        questDesert = data.questDesert ?? .inactive
        desertProgress = data.desertProgress ?? 0
        desertChestTaken = data.desertChestTaken ?? false
        desertOasisUsed = false
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
        bestiarySeen = Set(data.bestiarySeen ?? [])
        act3EchoJoined = data.act3EchoJoined ?? false
        act3SpiritsCalmed = Set(data.act3SpiritsCalmed ?? [])
        act3StelesRead = Set(data.act3StelesRead ?? [])
        act3ShadesDefeated = data.act3ShadesDefeated ?? false
        act4MemoriesSeen = Set(data.act4MemoriesSeen ?? [])
        act4ReflectionsFreed = Set(data.act4ReflectionsFreed ?? [])
        act4DevourersDefeated = data.act4DevourersDefeated ?? false
        act4VoiceConfronted = data.act4VoiceConfronted ?? false
        act4BossDefeated = data.act4BossDefeated ?? false
        act4EndingChoice = data.act4EndingChoice
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
    // Optionnel — saves antérieures à la quête du talisman
    let questMedallion: QuestState?
    // Optionnels — saves antérieures aux quêtes annexes (Bram, Sage, Garen)
    let questBramOre: QuestState?
    let questSageHerb: QuestState?
    let questGarenScout: QuestState?
    // Optionnels — saves antérieures aux mines de Cendreval
    let questMines: QuestState?
    let minesProgress: Int?
    let minesGoldTaken: Bool?
    // Optionnels — saves antérieures au désert d'Ossara
    let questDesert: QuestState?
    let desertProgress: Int?
    let desertChestTaken: Bool?
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
    let bestiarySeen: [String]?
    // Acte III étendu (optionnels — rétro-compatibles)
    let act3EchoJoined: Bool?
    let act3SpiritsCalmed: [String]?
    let act3StelesRead: [String]?
    let act3ShadesDefeated: Bool?
    // Acte IV — le Cœur du Vide (optionnels — rétro-compatibles)
    let act4MemoriesSeen: [String]?
    let act4ReflectionsFreed: [String]?
    let act4DevourersDefeated: Bool?
    let act4VoiceConfronted: Bool?
    let act4BossDefeated: Bool?
    let act4EndingChoice: Int?
    // Horodatage pour la résolution de conflit iCloud (nil = save ancienne)
    let savedAt: Date?
    let phase: GamePhase
    let resonanceTotal: Int
}
