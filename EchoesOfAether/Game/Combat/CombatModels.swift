import SpriteKit

// Types de données du combat — combattants, actions, éléments, sorts,
// statuts, configuration de boss et d'ennemis, alliés.
// Extrait de CombatSystem.swift (découpage du monolithe) : aucune
// logique de scène ici, uniquement des valeurs et leurs tables.

struct Combatant {
    let name: String
    let maxHP: Int
    var hp: Int
    var baseDamage: Int = 18
    var statusEffect: StatusEffect? = nil
    var statusTicks: Int = 0
    var stunned: Bool = false
    // Points de Magie (Kael uniquement ; 0 pour les ennemis/alliés PNJ).
    var mp: Int = 0
    var maxMP: Int = 0

    var isAlive: Bool { hp > 0 }
}

enum CombatAction {
    case attack
    case blackSlash
    case spell(CombatSpell)
    case potion
}

enum CombatElement: Hashable {
    case physical
    case fire
    case ice
    case lightning
    case aether

    var icon: String {
        switch self {
        case .physical: return String(localized: "combat.element.physical")
        case .fire: return String(localized: "combat.element.fire")
        case .ice: return String(localized: "combat.element.ice")
        case .lightning: return String(localized: "combat.element.lightning")
        case .aether: return String(localized: "combat.element.aether")
        }
    }

    var color: SKColor {
        switch self {
        case .physical: return SKColor(white: 0.90, alpha: 1)
        case .fire: return SKColor(red: 1.00, green: 0.36, blue: 0.16, alpha: 1)
        case .ice: return SKColor(red: 0.45, green: 0.85, blue: 1.00, alpha: 1)
        case .lightning: return SKColor(red: 1.00, green: 0.82, blue: 0.22, alpha: 1)
        case .aether: return Palette.aetherDeep
        }
    }
}

enum CombatSpell: CaseIterable {
    case ember
    case frost
    case thunder
    case mend
    /// Bénédiction — le sort signature de Lyra : sa nova sacrée soigne
    /// TOUT le groupe. Kael ne l'a pas : c'est le domaine de la prêtresse.
    case blessing
    /// TEMPÊTE — l'ultime de Kael. La glace et la foudre ne sont plus deux
    /// sorts tièdes mais un seul coup : il les fusionne. Frappe les faiblesses
    /// GLACE **et** FOUDRE à la fois, et ne part qu'UNE FOIS par combat — un
    /// atout qu'on garde pour le bon moment, pas un bouton qu'on matraque.
    case tempest
    /// Techniques d'Eran — ce ne sont pas des sorts mais des passes d'armes :
    /// son pack l'anime en frappe tournoyante (vent) et frappe enflammée.
    /// Elles coûtent peu de MP : un guerrier ne canalise pas, il frappe.
    case windBlade
    case emberStrike

    var title: String {
        switch self {
        case .ember: return String(localized: "combat.spell.fire")
        case .frost: return String(localized: "combat.spell.ice")
        case .thunder: return String(localized: "combat.spell.lightning")
        case .mend: return String(localized: "combat.spell.heal")
        case .blessing: return String(localized: "combat.spell.blessing")
        case .windBlade: return String(localized: "combat.spell.windBlade")
        case .emberStrike: return String(localized: "combat.spell.emberStrike")
        case .tempest: return String(localized: "combat.spell.tempest")
        }
    }

    var element: CombatElement? {
        switch self {
        case .ember: return .fire
        case .frost: return .ice
        case .thunder: return .lightning
        case .mend, .blessing: return nil   // sacrés : aucune faiblesse à exploiter
        case .windBlade: return .physical   // acier et vent, rien de magique
        case .emberStrike: return .fire     // la lame s'embrase
        // Tempête : deux éléments à la fois. `element` n'en rend qu'un —
        // `elements` porte la vérité, et le calcul de faiblesse l'utilise.
        case .tempest: return .ice
        }
    }

    /// Éléments réellement portés par le sort. Un seul pour tous, sauf la
    /// Tempête qui en fusionne deux.
    var elements: [CombatElement] {
        if case .tempest = self { return [.ice, .lightning] }
        return element.map { [$0] } ?? []
    }

    var basePower: Int {
        switch self {
        case .ember: return 66
        case .frost: return 58
        case .thunder: return 72
        case .mend: return 78
        case .blessing: return 52   // moins par tête, mais sur tout le groupe
        case .windBlade: return 70
        case .emberStrike: return 80
        case .tempest: return 130   // un seul coup, il doit compter
        }
    }

    /// Coût exact en Points de Magie (Kael). Les sorts plus puissants
    /// coûtent plus cher — il faut gérer sa réserve.
    var mpCost: Int {
        switch self {
        case .ember: return 8
        case .frost: return 10
        case .thunder: return 12
        case .mend: return 12
        case .blessing: return 20   // le soin de groupe se paie
        case .windBlade: return 6    // techniques d'arme : peu coûteuses
        case .emberStrike: return 10
        case .tempest: return 26    // cher : c'est l'atout du combat
        }
    }

    // MARK: - Paliers

    /// Palier du sort selon le niveau de Kael. Trois paliers sur les 30
    /// niveaux : à 10 et à 20, le sort ne gonfle pas — il **devient autre
    /// chose**, change de nom et fait un bond de puissance. Entre deux
    /// paliers il progresse doucement, pour que chaque niveau serve à
    /// quelque chose.
    static let tierThresholds = [1, 10, 20]

    func tier(at level: Int) -> Int {
        switch level {
        case ..<10: return 1
        case ..<20: return 2
        default:    return 3
        }
    }

    /// Nom du sort à ce niveau. C'est ce que voit le joueur dans le menu.
    func title(at level: Int) -> String {
        let keys: [String]
        switch self {
        case .ember:       keys = ["blaze", "furnace", "inferno"]
        case .frost:       keys = ["bite", "rime", "glaciation"]
        case .thunder:     keys = ["fulgur", "storm", "cataclysm"]
        case .mend:        keys = ["remission", "healing", "rebirth"]
        case .blessing:    keys = ["blessing", "grace", "apotheosis"]
        case .windBlade:   keys = ["gale", "tornado", "hurricane"]
        case .emberStrike: keys = ["ember", "blazing", "immolation"]
        case .tempest:     keys = ["tempest", "maelstrom", "ragnarok"]
        }
        return String(localized: String.LocalizationValue(
            "combat.spellTier." + keys[tier(at: level) - 1]))
    }

    /// Puissance effective. Le palier donne le bond, le niveau la pente.
    func power(at level: Int) -> Int {
        let t = tier(at: level)
        let multiplier = [1.0, 1.7, 2.6][t - 1]
        let within = level - Self.tierThresholds[t - 1]
        return Int(Double(basePower) * multiplier) + within * 4
    }
}

enum StatusEffect {
    case poison        // dégâts par tick
    case aetherBurn    // brûlure d'Éther : dégâts par tour, plus forts
}

struct BossConfig {
    let enrageThreshold: CGFloat   // 0.5 = 50% HP
    let enrageSpeedMult: CGFloat   // 1.5
    let enrageDamageMult: Int      // 2
    let specialAttackInterval: Int // every N enemy turns
    let specialDamage: Int
    let specialName: String        // localized
    /// MÉCANIQUE PROPRE À UN BOSS : fraction des PV max régénérée à la fin de
    /// son tour TANT QUE SON BOUCLIER TIENT (0 = pas de régénération).
    /// L'Archiviste relit son registre et se recompose : le groupe ne gagne
    /// qu'en le BRISANT régulièrement, pas en tapant fort au hasard.
    var regenPercent: CGFloat = 0
    /// Texte affiché quand il se régénère (clé déjà localisée).
    var regenName: String = ""
    /// MUSIQUE propre à ce boss : chaque affrontement majeur a son thème.
    var music: AudioEngine.MusicMood = .boss
}

/// Spécification d'un ennemi à l'entrée en combat (API GameManager).
struct EnemySpec {
    let name: String
    let hp: Int
    let kind: CombatSpriteKind
    var baseDamage: Int = 18
}

/// Alliés jouables : Lyra (actes I-II), son écho spectral et Eran (Acte III).
enum CombatAllyKind {
    case lyra, lyraEcho, eran

    var displayName: String {
        switch self {
        case .lyra: return "Lyra"
        case .lyraEcho: return String(localized: "combat.name.lyraEcho")
        case .eran: return "Eran"
        }
    }

    func maxHP(level: Int) -> Int {
        switch self {
        case .lyra: return 160 + (level - 1) * 14
        case .lyraEcho: return 140 + (level - 1) * 12   // spectrale, fragile
        case .eran: return 190 + (level - 1) * 15       // esprit endurci
        }
    }

    /// Réserve de Magie. Elle dit qui est qui : Lyra vit dans le sacré et
    /// en a le plus ; l'Écho n'est plus qu'un souffle, mais un souffle de
    /// magie pure ; Eran est un guerrier — sa lame s'embrase, il ne canalise
    /// pas. Ses techniques coûtent d'ailleurs deux fois moins cher.
    func maxMP(level: Int) -> Int {
        switch self {
        case .lyra:     return 42 + (level - 1) * 5
        case .lyraEcho: return 38 + (level - 1) * 5
        case .eran:     return 18 + (level - 1) * 2
        }
    }

    func attackDamage(level: Int) -> Int {
        switch self {
        case .lyra, .lyraEcho: return 30 + (level - 1) * 3
        case .eran: return 36 + (level - 1) * 3
        }
    }

    /// Multiplicateur des sorts (les arcanistes frappent plus fort).
    var spellMultiplier: CGFloat {
        switch self {
        case .lyra: return 1.10
        case .lyraEcho: return 1.18
        case .eran: return 1.05
        }
    }

    /// Couleur d'accent (pips d'initiative, plate HP).
    var accentColor: SKColor {
        switch self {
        case .lyra: return SKColor(red: 0.32, green: 0.85, blue: 0.66, alpha: 1)
        case .lyraEcho: return SKColor(red: 0.55, green: 0.90, blue: 0.95, alpha: 1)
        case .eran: return SKColor(red: 0.48, green: 0.75, blue: 1.00, alpha: 1)
        }
    }
}
