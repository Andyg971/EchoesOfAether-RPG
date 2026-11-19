import Foundation

// PlayerState — arsenal : armes et accessoires possédés, pièce portée,
// bonus cumulés et remise en ordre au chargement.
extension PlayerState {

    var equippedWeapon: Weapon? { EquipmentCatalog.weapon(id: equippedWeaponID) }
    var equippedAccessoryItem: Accessory? { EquipmentCatalog.accessory(id: equippedAccessory) }

    /// Bonus de l'arme et de l'accessoire portés.
    var equipmentBonus: EquipmentBonus {
        (equippedWeapon?.bonus ?? EquipmentBonus()) + (equippedAccessoryItem?.bonus ?? EquipmentBonus())
    }

    /// Palier de l'arme portée (0 = poings nus).
    ///
    /// L'affecter donne et équipe la LAME de ce palier, avec les paliers
    /// inférieurs : c'est ainsi que se lisent les sauvegardes d'avant les
    /// styles d'armes, qui ne connaissaient que la lame.
    var weaponLevel: Int {
        get { equippedWeapon?.tier ?? 0 }
        set {
            let tier = min(max(newValue, 0), EquipmentCatalog.maxTier)
            guard tier > 0 else {
                equippedWeaponID = nil
                return
            }
            for step in 1...tier {
                if let blade = EquipmentCatalog.weapon(style: .blade, tier: step) {
                    ownedWeapons.insert(blade.id)
                }
            }
            equippedWeaponID = EquipmentCatalog.weapon(style: .blade, tier: tier)?.id
        }
    }

    // MARK: - Arsenal

    /// Palier le plus haut possédé dans ce style (0 = aucun).
    func bestOwnedTier(_ style: WeaponStyle) -> Int {
        EquipmentCatalog.weapons
            .filter { $0.style == style && ownedWeapons.contains($0.id) }
            .map(\.tier)
            .max() ?? 0
    }

    /// Une arme par style : la meilleure possédée. Un palier supérieur
    /// surpasse toujours le précédent du même style, inutile de lister les deux.
    var arsenal: [Weapon] {
        WeaponStyle.allCases.compactMap { style in
            EquipmentCatalog.weapon(style: style, tier: bestOwnedTier(style))
        }
    }

    /// Prochaine arme à forger dans ce style (nil = palier maximal atteint).
    func nextWeapon(for style: WeaponStyle) -> Weapon? {
        EquipmentCatalog.weapon(style: style, tier: bestOwnedTier(style) + 1)
    }

    /// Accessoires possédés, dans l'ordre du catalogue.
    var ownedAccessoryList: [Accessory] {
        EquipmentCatalog.accessories.filter { ownedAccessories.contains($0.id) }
    }

    // MARK: - Acquérir / équiper

    /// Achat ou trouvaille : l'arme rejoint l'arsenal et se porte aussitôt.
    func acquire(_ weapon: Weapon) {
        ownedWeapons.insert(weapon.id)
        equippedWeaponID = weapon.id
    }

    func acquire(_ accessory: Accessory) {
        ownedAccessories.insert(accessory.id)
        equippedAccessory = accessory.id
    }

    /// Porte une arme déjà possédée. Faux si elle n'est pas dans l'arsenal.
    @discardableResult
    func equipWeapon(id: String) -> Bool {
        guard ownedWeapons.contains(id), EquipmentCatalog.weapon(id: id) != nil else { return false }
        equippedWeaponID = id
        return true
    }

    @discardableResult
    func equipAccessory(id: String) -> Bool {
        guard ownedAccessories.contains(id), EquipmentCatalog.accessory(id: id) != nil else { return false }
        equippedAccessory = id
        return true
    }

    // MARK: - Chargement

    /// Recharge l'équipement d'une sauvegarde ou d'une graine New Game+.
    /// `ownedWeapons == nil` = sauvegarde d'avant les styles : seul le
    /// palier de lame compte.
    func restoreEquipment(weaponLevel legacyLevel: Int,
                          ownedWeapons owned: [String]?,
                          equippedWeapon: String?,
                          ownedAccessories accessories: [String]?,
                          equippedAccessory accessory: String?) {
        ownedWeapons = []
        if let owned {
            ownedWeapons = Set(owned)
            equippedWeaponID = equippedWeapon
        } else {
            weaponLevel = legacyLevel
        }
        ownedAccessories = Set(accessories ?? [])
        equippedAccessory = accessory
        sanitizeEquipment()
    }

    /// Purge les ids inconnus et garantit que la pièce portée est possédée
    /// et qu'elle est la meilleure de son style.
    func sanitizeEquipment() {
        let weaponIDs = Set(EquipmentCatalog.weapons.map(\.id))
        ownedWeapons.formIntersection(weaponIDs)
        if let current = equippedWeapon, ownedWeapons.contains(current.id) {
            equippedWeaponID = EquipmentCatalog.weapon(style: current.style,
                                                       tier: bestOwnedTier(current.style))?.id
        } else {
            equippedWeaponID = arsenal.max { $0.tier < $1.tier }?.id
        }

        let accessoryIDs = Set(EquipmentCatalog.accessories.map(\.id))
        ownedAccessories.formIntersection(accessoryIDs)
        if let accessory = equippedAccessory {
            if accessoryIDs.contains(accessory) {
                ownedAccessories.insert(accessory)
            } else {
                equippedAccessory = nil
            }
        }
    }
}

extension EquipmentBonus {
    static func + (lhs: EquipmentBonus, rhs: EquipmentBonus) -> EquipmentBonus {
        EquipmentBonus(attack: lhs.attack + rhs.attack,
                       slash: lhs.slash + rhs.slash,
                       crit: lhs.crit + rhs.crit,
                       dodge: lhs.dodge + rhs.dodge,
                       mpRegen: lhs.mpRegen + rhs.mpRegen)
    }
}

/// Stats de combat de Kael pour une tenue donnée (critique et esquive en %).
struct EquipmentPreview: Equatable {
    let attack: Int
    let slash: Int
    let critPercent: Int
    let dodgePercent: Int
    let mpRegen: Int
}

extension PlayerState {
    /// Stats qu'aurait Kael avec cette arme et cet accessoire. Passe par les
    /// mêmes formules que le combat (essai puis retour à la tenue portée)
    /// pour que l'aperçu ne puisse jamais diverger du jeu.
    func preview(weaponID: String?, accessoryID: String?) -> EquipmentPreview {
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
                                mpRegen: attackMPRegen)
    }
}
