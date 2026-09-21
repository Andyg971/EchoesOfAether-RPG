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
    /// `found` — l'objet est ramassé, le donneur ne le sait pas encore.
    ///
    /// Les autres quêtes s'en passent : ramasser l'insigne de Tomm suffit à
    /// clore, et revoir Garen n'est qu'un épilogue rejouable. La quête de Lyra
    /// a besoin de l'étape en plus : ce qu'elle lit dans le cristal est la
    /// chute, et une chute ne se rejoue pas.
    ///
    /// Nouvelle valeur brute : les sauvegardes d'avant ne la contiennent
    /// jamais, elles se relisent sans rien perdre.
    case inactive, active, found, complete
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

    /// ARBRE DE L'AETHER — rangs investis par nœud (`SkillTree.allNodes`).
    /// 1 point par niveau ; voir `SkillTree.swift` pour les bonus dérivés.
    var skillRanks: [String: Int] = [:]

    /// ACCESSOIRE ÉQUIPÉ (un seul à la fois — c'est ce qui en fait un choix
    /// de build et non une accumulation). nil = aucun.
    /// `ember` = critiques, `shade` = esquive, `resonance` = régénération de MP.
    var equippedAccessory: String? = nil

    /// Chance de coup critique : l'accessoire de braise la double, la voie
    /// de la Lame s'ajoute par-dessus.
    var critChance: Double {
        (equippedAccessory == "ember" ? 0.25 : 0.12) + skillCritBonus
    }
    /// Chance d'esquiver un coup normal : l'amulette d'ombre la relève, la
    /// voie du Souffle s'ajoute par-dessus.
    var dodgeChance: Double {
        (equippedAccessory == "shade" ? 0.25 : 0.10) + skillDodgeBonus
    }
    /// Magie régénérée par une attaque physique : le sceau la triple, et
    /// permet de tenir une rotation de sorts bien plus longtemps.
    var attackMPRegen: Int {
        (equippedAccessory == "resonance" ? 16 : 6) + skillMPRegenBonus
    }

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
    // Caverne aux Échos (donjon optionnel, entrée dans la forêt)
    var caveCleared: Bool = false               // gardien d'ossements vaincu
    var caveChestTaken: Bool = false            // coffre de la caverne ramassé
    /// Coffres de la CARTE DU MONDE déjà ouverts (récompense l'exploration
    /// hors des sentiers : chaque coffre ne se ramasse qu'une fois).
    var overworldChestsTaken: Set<String> = []
    var talkedToSage: Bool = false
    var talkedToChild: Bool = false
    var talkedToVillager: Bool = false
    var innRested: Bool = false
    var forestProgress: Int = 0  // 0=fresh, 1=beast dead, 2=wolves dead
    var bossDefeated: Bool = false
    var lyraDeceased: Bool = false
    var act2SageConsulted: Bool = false
    var act2Returned: Bool = false   // Kael a regagné Solis à pied (retour Acte II via la carte)
    var ruinsProgress: Int = 0     // 0=fresh, 1=combat1 done, 2=archivist done
    var act2DorinPassed: Bool = false
    var act2NightmareSeen: Bool = false
    var act2Vision1Seen: Bool = false
    var act2EranFound: Bool = false
    var kaelCorruptionLevel: Int = 0  // 0-3, progression visuelle
    var kaelChoseCorruption: Bool = false  // a saisi le pouvoir sciemment (vs dépassé) — mort de Lyra
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

    // New Game+ : 0 = première partie. Chaque relance après une fin
    // incrémente le compteur ; il durcit les combats et conserve la
    // progression (niveau, or, équipement). Les deux fins donnent une
    // vraie raison de recommencer.
    var newGamePlus: Int = 0

    // MARK: - Stats dérivées (incluent le bonus de niveau)
    //
    // Gain par niveau : +12 HP / +2 ATK / +4 Black Slash. L1 → L30 :
    // HP 280→628, ATK 42→100, Black Slash 92→208 (avant équipement).
    // Les bonus `skill*` viennent de l'Arbre de l'Aether (SkillTree.swift) :
    // le niveau donne la courbe de base, l'arbre la personnalise.
    var attackDamage: Int      { 42 + weaponLevel * 22 + (level - 1) * 2 + skillAttackBonus }
    var blackSlashDamage: Int  { 92 + weaponLevel * 35 + (level - 1) * 4 + skillSlashBonus }
    var currentMaxHP: Int      { maxHP + armorLevel * 50 + (level - 1) * 12 + skillMaxHPBonus }
    /// Points de Magie : réserve qui alimente les sorts et l'Entaille noire.
    /// Kael est mage : il porte trois éléments et doit pouvoir les enchaîner,
    /// d'où la réserve la plus large du groupe (L1 = 46, L30 = 191). Lyra la
    /// suit de près (42), Eran l'homme d'acier plafonne à 18 — ses techniques
    /// coûtent aussi deux fois moins. Les attaques physiques n'en coûtent pas
    /// et en régénèrent un peu.
    var maxMP: Int             { 46 + (level - 1) * 5 + skillMaxMPBonus }

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
}
