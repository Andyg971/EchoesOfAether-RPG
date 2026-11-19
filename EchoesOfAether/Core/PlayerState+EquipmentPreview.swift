import Foundation

/// Stats de combat d'un héros pour une tenue donnée (critique, esquive et
/// puissance des sorts en %). Les champs qui ne concernent pas le héros
/// restent à 0 et n'apparaissent donc jamais dans une comparaison.
struct EquipmentPreview: Equatable {
    var attack = 0
    var slash = 0
    var critPercent = 0
    var dodgePercent = 0
    var mpRegen = 0
    var spellPercent = 0
    var maxMP = 0
}

extension PlayerState {
    /// Stats qu'aurait le héros avec cette arme (et, pour Kael, cet
    /// accessoire). Passe par les mêmes formules que le combat pour que
    /// l'aperçu ne puisse jamais diverger du jeu.
    func preview(hero: Hero, weaponID: String?, accessoryID: String? = nil) -> EquipmentPreview {
        guard hero == .kael else {
            return allyPreview(hero: hero, bonus: EquipmentCatalog.weapon(id: weaponID)?.bonus ?? EquipmentBonus())
        }
        let worn = (weapon: equippedWeaponID, accessory: equippedAccessory)
        equippedWeaponID = weaponID
        equippedAccessory = accessoryID
        defer {
            equippedWeaponID = worn.weapon
            equippedAccessory = worn.accessory
        }
        return EquipmentPreview(attack: attackDamage,
                                slash: blackSlashDamage,
                                critPercent: Int((critChance * 100).rounded()),
                                dodgePercent: Int((dodgeChance * 100).rounded()),
                                mpRegen: attackMPRegen,
                                spellPercent: Int((spellPowerMultiplier * 100).rounded()),
                                maxMP: maxMP)
    }

    /// Lyra (ou son Écho après sa mort) et Eran, comme le combat les crée.
    func combatKind(for hero: Hero) -> CombatAllyKind? {
        switch hero {
        case .kael: nil
        case .lyra: lyraDeceased ? .lyraEcho : .lyra
        case .eran: .eran
        }
    }

    private func allyPreview(hero: Hero, bonus: EquipmentBonus) -> EquipmentPreview {
        guard let kind = combatKind(for: hero) else { return EquipmentPreview() }
        return EquipmentPreview(attack: kind.attackDamage(level: level) + bonus.attack,
                                spellPercent: Int(((kind.spellMultiplier + bonus.spellPower) * 100).rounded()),
                                maxMP: kind.maxMP(level: level) + bonus.maxMP)
    }
}
