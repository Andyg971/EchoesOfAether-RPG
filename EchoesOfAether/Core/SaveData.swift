import SpriteKit

// Format de sauvegarde (Codable, champs optionnels = ajoutés après coup) et graine de New Game+.
@MainActor
/// Acquis conservés d'une partie à l'autre en New Game+ : niveau, or et
/// équipement traversent, la progression narrative repart de zéro.
struct NewGamePlusSeed {
    let level: Int
    let xp: Int
    let gold: Int
    let weaponLevel: Int
    let armorLevel: Int
    let potions: Int
    let aetherShards: Int
    let newGamePlus: Int   // déjà incrémenté (palier de la nouvelle run)
    /// L'Arbre de l'Aether traverse aussi : le build fait partie des acquis,
    /// au même titre que l'arme et l'armure.
    let skillRanks: [String: Int]

    /// Depuis une sauvegarde terminée → graine de la relance (palier +1).
    init(from data: SaveData) {
        level = data.level ?? 1
        xp = data.xp ?? 0
        gold = data.gold
        weaponLevel = data.weaponLevel
        armorLevel = data.armorLevel
        potions = data.potions
        aetherShards = data.aetherShards
        newGamePlus = (data.newGamePlus ?? 0) + 1
        skillRanks = data.skillRanks ?? [:]
    }

    /// Graine synthétique pour tests (`--ngplus N`) : Kael équipé, palier N.
    init(testTier tier: Int) {
        level = 15; xp = 0; gold = 500
        weaponLevel = 2; armorLevel = 2; potions = 3; aetherShards = 5
        newGamePlus = max(1, tier)
        skillRanks = [:]
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
    // Arbre de l'Aether (optionnel — saves antérieures repartent sans point
    // investi ; les points eux-mêmes se redéduisent du niveau)
    let skillRanks: [String: Int]?
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
    // Caverne aux Échos (optionnels — rétro-compatibles)
    let caveCleared: Bool?
    let caveChestTaken: Bool?
    // Optionnel — retro-compatible (coffres de la carte du monde)
    let overworldChestsTaken: [String]?
    // Optionnel — retro-compatible (accessoire equipe)
    let equippedAccessory: String?
    let talkedToSage: Bool
    let talkedToChild: Bool
    let talkedToVillager: Bool
    let innRested: Bool
    let forestProgress: Int
    let bossDefeated: Bool
    let lyraDeceased: Bool
    let act2SageConsulted: Bool
    // Optionnel — rétro-compatible (retour Acte II à pied via la carte)
    let act2Returned: Bool?
    let ruinsProgress: Int
    let act2DorinPassed: Bool
    let act2NightmareSeen: Bool
    let act2Vision1Seen: Bool
    let act2EranFound: Bool
    let kaelCorruptionLevel: Int
    // Optionnel — rétro-compatible (le joueur a-t-il saisi le pouvoir sciemment ?)
    let kaelChoseCorruption: Bool?
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
    // New Game+ (optionnel — saves antérieures repartent à 0)
    let newGamePlus: Int?
    // Horodatage pour la résolution de conflit iCloud (nil = save ancienne)
    let savedAt: Date?
    let phase: GamePhase
    let resonanceTotal: Int
}
