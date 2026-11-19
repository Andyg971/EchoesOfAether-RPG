import Foundation

// Catalogue d'équipement : armes (quatre styles × trois paliers) et
// accessoires. Données pures — les effets se lisent dans
// `PlayerState+Equipment`, l'affichage dans l'inventaire et la boutique.

/// Style d'arme : à palier égal, chaque style échange un peu d'attaque brute
/// contre un atout. Aucun n'est meilleur que les autres, c'est un choix de jeu.
enum WeaponStyle: String, CaseIterable, Sendable {
    /// Lame : référence équilibrée (les stats d'avant la refonte).
    case blade
    /// Rapière : moins de dégâts, plus de critiques et d'esquive.
    case rapier
    /// Espadon : frappe la plus lourde, mais Kael esquive moins.
    case greatsword
    /// Lame d'écho : Entaille noire renforcée et Magie rendue à chaque coup.
    case echo

    var nameKey: LocalizedStringResource {
        switch self {
        case .blade:      "equipment.style.blade"
        case .rapier:     "equipment.style.rapier"
        case .greatsword: "equipment.style.greatsword"
        case .echo:       "equipment.style.echo"
        }
    }
}

/// Bonus apportés par une pièce d'équipement, cumulés aux stats de Kael.
struct EquipmentBonus: Equatable, Sendable {
    var attack = 0
    var slash = 0
    /// Chance de critique en plus (0,05 = +5 points).
    var crit = 0.0
    /// Chance d'esquive en plus ou en moins.
    var dodge = 0.0
    /// Magie rendue en plus par attaque physique.
    var mpRegen = 0
}

struct Weapon: Sendable {
    let id: String
    let style: WeaponStyle
    /// Palier 1 (fer), 2 (runique) ou 3 (Aetherite).
    let tier: Int
    let price: Int
    let nameKey: LocalizedStringResource
    let bonus: EquipmentBonus
}

struct Accessory: Sendable {
    let id: String
    let price: Int
    let nameKey: LocalizedStringResource
    let bonus: EquipmentBonus
}

enum EquipmentCatalog {
    static let maxTier = 3

    /// Ordre d'affichage : par palier, puis par style.
    static let weapons: [Weapon] = [
        Weapon(id: "blade1", style: .blade, tier: 1, price: 80,
               nameKey: "weapon.blade1.name",
               bonus: EquipmentBonus(attack: 22, slash: 35)),
        Weapon(id: "rapier1", style: .rapier, tier: 1, price: 90,
               nameKey: "weapon.rapier1.name",
               bonus: EquipmentBonus(attack: 17, slash: 26, crit: 0.05, dodge: 0.02)),
        Weapon(id: "greatsword1", style: .greatsword, tier: 1, price: 95,
               nameKey: "weapon.greatsword1.name",
               bonus: EquipmentBonus(attack: 30, slash: 46, dodge: -0.03)),
        Weapon(id: "echo1", style: .echo, tier: 1, price: 100,
               nameKey: "weapon.echo1.name",
               bonus: EquipmentBonus(attack: 14, slash: 50, mpRegen: 3)),

        Weapon(id: "blade2", style: .blade, tier: 2, price: 180,
               nameKey: "weapon.blade2.name",
               bonus: EquipmentBonus(attack: 44, slash: 70)),
        Weapon(id: "rapier2", style: .rapier, tier: 2, price: 200,
               nameKey: "weapon.rapier2.name",
               bonus: EquipmentBonus(attack: 34, slash: 52, crit: 0.10, dodge: 0.04)),
        Weapon(id: "greatsword2", style: .greatsword, tier: 2, price: 210,
               nameKey: "weapon.greatsword2.name",
               bonus: EquipmentBonus(attack: 60, slash: 92, dodge: -0.06)),
        Weapon(id: "echo2", style: .echo, tier: 2, price: 220,
               nameKey: "weapon.echo2.name",
               bonus: EquipmentBonus(attack: 28, slash: 100, mpRegen: 6)),

        Weapon(id: "blade3", style: .blade, tier: 3, price: 420,
               nameKey: "weapon.blade3.name",
               bonus: EquipmentBonus(attack: 66, slash: 105)),
        Weapon(id: "rapier3", style: .rapier, tier: 3, price: 440,
               nameKey: "weapon.rapier3.name",
               bonus: EquipmentBonus(attack: 51, slash: 78, crit: 0.15, dodge: 0.06)),
        Weapon(id: "greatsword3", style: .greatsword, tier: 3, price: 460,
               nameKey: "weapon.greatsword3.name",
               bonus: EquipmentBonus(attack: 90, slash: 138, dodge: -0.09)),
        Weapon(id: "echo3", style: .echo, tier: 3, price: 480,
               nameKey: "weapon.echo3.name",
               bonus: EquipmentBonus(attack: 42, slash: 150, mpRegen: 9))
    ]

    /// Un seul accessoire se porte à la fois : c'est un arbitrage de build.
    /// Les valeurs reprennent l'ancien comportement (critique 12 → 25 %,
    /// esquive 10 → 25 %, Magie par coup 6 → 16).
    static let accessories: [Accessory] = [
        Accessory(id: "ember", price: 140, nameKey: "shop.acc.ember.name",
                  bonus: EquipmentBonus(crit: 0.13)),
        Accessory(id: "shade", price: 160, nameKey: "shop.acc.shade.name",
                  bonus: EquipmentBonus(dodge: 0.15)),
        Accessory(id: "resonance", price: 180, nameKey: "shop.acc.resonance.name",
                  bonus: EquipmentBonus(mpRegen: 10))
    ]

    static func weapon(id: String?) -> Weapon? {
        guard let id else { return nil }
        return weapons.first { $0.id == id }
    }

    static func weapon(style: WeaponStyle, tier: Int) -> Weapon? {
        weapons.first { $0.style == style && $0.tier == tier }
    }

    static func accessory(id: String?) -> Accessory? {
        guard let id else { return nil }
        return accessories.first { $0.id == id }
    }
}
