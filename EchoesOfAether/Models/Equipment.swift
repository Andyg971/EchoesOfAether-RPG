import Foundation

// Catalogue d'équipement. Canon : Kael se bat AUX POINGS (jamais d'épée),
// Lyra porte des bâtons de prêtresse, Eran des bâtons de sorcier.
// Données pures — les effets se lisent dans `PlayerState+Equipment`,
// l'affichage dans l'inventaire et la boutique.

/// Héros qui portent une arme.
enum Hero: String, CaseIterable, Sendable {
    case kael, lyra, eran

    var displayName: String {
        switch self {
        case .kael: "Kael"
        case .lyra: "Lyra"
        case .eran: "Eran"
        }
    }
}

/// Style d'arme : à palier égal, chaque style échange un peu de puissance
/// brute contre un atout. Aucun n'est meilleur que les autres.
enum WeaponStyle: String, CaseIterable, Sendable {
    // Kael — armes de poing
    /// Gantelets : référence équilibrée (les stats d'avant la refonte).
    case gauntlets
    /// Bandelettes : moins de dégâts, plus de critiques et d'esquive.
    case wraps
    /// Poings de fer : frappe la plus lourde, mais Kael esquive moins.
    case knuckles
    /// Gants d'écho : Entaille noire renforcée et Magie rendue à chaque coup.
    case gloves
    // Lyra — bâtons de prêtresse
    /// Bâton sacré : sorts et soins plus puissants.
    case sacredStaff
    /// Crosse : réserve de Magie bien plus large, frappe un peu.
    case crook
    // Eran — bâtons de sorcier
    /// Bâton de sorcier : sorts nettement plus puissants.
    case arcaneStaff
    /// Bâton ferré : frappe au corps à corps, un peu de magie.
    case battleStaff

    var hero: Hero {
        switch self {
        case .gauntlets, .wraps, .knuckles, .gloves: .kael
        case .sacredStaff, .crook: .lyra
        case .arcaneStaff, .battleStaff: .eran
        }
    }

    var nameKey: LocalizedStringResource {
        switch self {
        case .gauntlets:   "equipment.style.balanced"
        case .wraps:       "equipment.style.swift"
        case .knuckles:    "equipment.style.heavy"
        case .gloves:      "equipment.style.arcane"
        case .sacredStaff: "equipment.style.holy"
        case .crook:       "equipment.style.enduring"
        case .arcaneStaff: "equipment.style.arcane"
        case .battleStaff: "equipment.style.martial"
        }
    }
}

/// Bonus apportés par une pièce d'équipement, cumulés aux stats du héros.
struct EquipmentBonus: Equatable, Sendable {
    var attack = 0
    var slash = 0
    /// Chance de critique en plus (0,05 = +5 points).
    var crit = 0.0
    /// Chance d'esquive en plus ou en moins.
    var dodge = 0.0
    /// Magie rendue en plus par attaque physique.
    var mpRegen = 0
    /// Puissance des sorts et des soins en plus (0,08 = +8 %).
    var spellPower = 0.0
    var maxMP = 0
}

struct Weapon: Sendable {
    let id: String
    let style: WeaponStyle
    /// Palier 1, 2 ou 3.
    let tier: Int
    /// Prix à la forge de Bram ; 0 = jamais vendu (bâtons d'Eran, trouvés
    /// au fil de l'Acte III et IV : la forge est hors d'atteinte).
    let price: Int
    let nameKey: LocalizedStringResource
    let bonus: EquipmentBonus

    var hero: Hero { style.hero }
    var isSold: Bool { price > 0 }
}

struct Accessory: Sendable {
    let id: String
    let price: Int
    let nameKey: LocalizedStringResource
    let bonus: EquipmentBonus
}

enum EquipmentCatalog {
    static let maxTier = 3

    /// Ordre d'affichage : par héros, par style, puis par palier.
    static let weapons: [Weapon] = kaelWeapons + lyraWeapons + eranWeapons

    private static let kaelWeapons: [Weapon] = [
        Weapon(id: "gauntlets1", style: .gauntlets, tier: 1, price: 80,
               nameKey: "weapon.gauntlets1.name", bonus: EquipmentBonus(attack: 22, slash: 35)),
        Weapon(id: "gauntlets2", style: .gauntlets, tier: 2, price: 180,
               nameKey: "weapon.gauntlets2.name", bonus: EquipmentBonus(attack: 44, slash: 70)),
        Weapon(id: "gauntlets3", style: .gauntlets, tier: 3, price: 420,
               nameKey: "weapon.gauntlets3.name", bonus: EquipmentBonus(attack: 66, slash: 105)),

        Weapon(id: "wraps1", style: .wraps, tier: 1, price: 90, nameKey: "weapon.wraps1.name",
               bonus: EquipmentBonus(attack: 17, slash: 26, crit: 0.05, dodge: 0.02)),
        Weapon(id: "wraps2", style: .wraps, tier: 2, price: 200, nameKey: "weapon.wraps2.name",
               bonus: EquipmentBonus(attack: 34, slash: 52, crit: 0.10, dodge: 0.04)),
        Weapon(id: "wraps3", style: .wraps, tier: 3, price: 440, nameKey: "weapon.wraps3.name",
               bonus: EquipmentBonus(attack: 51, slash: 78, crit: 0.15, dodge: 0.06)),

        Weapon(id: "knuckles1", style: .knuckles, tier: 1, price: 95, nameKey: "weapon.knuckles1.name",
               bonus: EquipmentBonus(attack: 30, slash: 46, dodge: -0.03)),
        Weapon(id: "knuckles2", style: .knuckles, tier: 2, price: 210, nameKey: "weapon.knuckles2.name",
               bonus: EquipmentBonus(attack: 60, slash: 92, dodge: -0.06)),
        Weapon(id: "knuckles3", style: .knuckles, tier: 3, price: 460, nameKey: "weapon.knuckles3.name",
               bonus: EquipmentBonus(attack: 90, slash: 138, dodge: -0.09)),

        Weapon(id: "gloves1", style: .gloves, tier: 1, price: 100, nameKey: "weapon.gloves1.name",
               bonus: EquipmentBonus(attack: 14, slash: 50, mpRegen: 3)),
        Weapon(id: "gloves2", style: .gloves, tier: 2, price: 220, nameKey: "weapon.gloves2.name",
               bonus: EquipmentBonus(attack: 28, slash: 100, mpRegen: 6)),
        Weapon(id: "gloves3", style: .gloves, tier: 3, price: 480, nameKey: "weapon.gloves3.name",
               bonus: EquipmentBonus(attack: 42, slash: 150, mpRegen: 9))
    ]

    private static let lyraWeapons: [Weapon] = [
        Weapon(id: "sacred1", style: .sacredStaff, tier: 1, price: 70, nameKey: "weapon.sacred1.name",
               bonus: EquipmentBonus(spellPower: 0.08, maxMP: 4)),
        Weapon(id: "sacred2", style: .sacredStaff, tier: 2, price: 160, nameKey: "weapon.sacred2.name",
               bonus: EquipmentBonus(spellPower: 0.16, maxMP: 8)),
        Weapon(id: "sacred3", style: .sacredStaff, tier: 3, price: 360, nameKey: "weapon.sacred3.name",
               bonus: EquipmentBonus(spellPower: 0.24, maxMP: 12)),

        Weapon(id: "crook1", style: .crook, tier: 1, price: 70, nameKey: "weapon.crook1.name",
               bonus: EquipmentBonus(attack: 6, maxMP: 10)),
        Weapon(id: "crook2", style: .crook, tier: 2, price: 160, nameKey: "weapon.crook2.name",
               bonus: EquipmentBonus(attack: 12, maxMP: 20)),
        Weapon(id: "crook3", style: .crook, tier: 3, price: 360, nameKey: "weapon.crook3.name",
               bonus: EquipmentBonus(attack: 18, maxMP: 30))
    ]

    private static let eranWeapons: [Weapon] = [
        Weapon(id: "arcane1", style: .arcaneStaff, tier: 1, price: 0, nameKey: "weapon.arcane1.name",
               bonus: EquipmentBonus(spellPower: 0.10, maxMP: 2)),
        Weapon(id: "arcane2", style: .arcaneStaff, tier: 2, price: 0, nameKey: "weapon.arcane2.name",
               bonus: EquipmentBonus(spellPower: 0.20, maxMP: 4)),
        Weapon(id: "arcane3", style: .arcaneStaff, tier: 3, price: 0, nameKey: "weapon.arcane3.name",
               bonus: EquipmentBonus(spellPower: 0.30, maxMP: 6)),

        Weapon(id: "battle1", style: .battleStaff, tier: 1, price: 0, nameKey: "weapon.battle1.name",
               bonus: EquipmentBonus(attack: 8, spellPower: 0.03)),
        Weapon(id: "battle2", style: .battleStaff, tier: 2, price: 0, nameKey: "weapon.battle2.name",
               bonus: EquipmentBonus(attack: 16, spellPower: 0.06)),
        Weapon(id: "battle3", style: .battleStaff, tier: 3, price: 0, nameKey: "weapon.battle3.name",
               bonus: EquipmentBonus(attack: 24, spellPower: 0.09))
    ]

    /// Un seul accessoire se porte à la fois (Kael) : c'est un arbitrage de
    /// build. Les valeurs reprennent l'ancien comportement (critique
    /// 12 → 25 %, esquive 10 → 25 %, Magie par coup 6 → 16).
    static let accessories: [Accessory] = [
        Accessory(id: "ember", price: 140, nameKey: "shop.acc.ember.name",
                  bonus: EquipmentBonus(crit: 0.13)),
        Accessory(id: "shade", price: 160, nameKey: "shop.acc.shade.name",
                  bonus: EquipmentBonus(dodge: 0.15)),
        Accessory(id: "resonance", price: 180, nameKey: "shop.acc.resonance.name",
                  bonus: EquipmentBonus(mpRegen: 10))
    ]

    /// Ids de la première version de l'arsenal (des épées, contraires au
    /// canon) → leur équivalent en armes de poing, même palier, mêmes stats.
    static let legacyWeaponIDs: [String: String] = {
        let renames = ["blade": "gauntlets", "rapier": "wraps",
                       "greatsword": "knuckles", "echo": "gloves"]
        var map: [String: String] = [:]
        for (old, new) in renames {
            for tier in 1...maxTier { map["\(old)\(tier)"] = "\(new)\(tier)" }
        }
        return map
    }()

    static func weapon(id: String?) -> Weapon? {
        guard let id else { return nil }
        let current = legacyWeaponIDs[id] ?? id
        return weapons.first { $0.id == current }
    }

    static func weapon(style: WeaponStyle, tier: Int) -> Weapon? {
        weapons.first { $0.style == style && $0.tier == tier }
    }

    static func styles(for hero: Hero) -> [WeaponStyle] {
        WeaponStyle.allCases.filter { $0.hero == hero }
    }

    static func accessory(id: String?) -> Accessory? {
        guard let id else { return nil }
        return accessories.first { $0.id == id }
    }
}
