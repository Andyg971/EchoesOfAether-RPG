import Foundation

// PlayerState — arsenal du groupe : armes possédées, pièce portée par chaque
// héros, bonus cumulés et remise en ordre au chargement.
extension PlayerState {

    var equippedWeapon: Weapon? { EquipmentCatalog.weapon(id: equippedWeaponID) }
    var equippedAccessoryItem: Accessory? { EquipmentCatalog.accessory(id: equippedAccessory) }

    func equippedWeapon(for hero: Hero) -> Weapon? {
        hero == .kael ? equippedWeapon : EquipmentCatalog.weapon(id: equippedAllyWeapons[hero.rawValue])
    }

    /// Bonus de l'arme et de l'accessoire portés par Kael.
    var equipmentBonus: EquipmentBonus {
        weaponBonus(for: .kael) + (equippedAccessoryItem?.bonus ?? EquipmentBonus())
    }

    /// Bonus de l'arme seule (Lyra et Eran ne portent pas d'accessoire).
    func weaponBonus(for hero: Hero) -> EquipmentBonus {
        equippedWeapon(for: hero)?.bonus ?? EquipmentBonus()
    }

    /// Palier de l'arme portée par Kael (0 = poings nus).
    ///
    /// L'affecter donne et équipe les GANTELETS de ce palier, avec les
    /// paliers inférieurs : c'est ainsi que se lisent les sauvegardes d'avant
    /// les styles d'armes, qui ne connaissaient qu'une ligne d'armes.
    var weaponLevel: Int {
        get { equippedWeapon?.tier ?? 0 }
        set {
            let tier = min(max(newValue, 0), EquipmentCatalog.maxTier)
            guard tier > 0 else {
                equippedWeaponID = nil
                return
            }
            for step in 1...tier {
                if let gauntlets = EquipmentCatalog.weapon(style: .gauntlets, tier: step) {
                    ownedWeapons.insert(gauntlets.id)
                }
            }
            equippedWeaponID = EquipmentCatalog.weapon(style: .gauntlets, tier: tier)?.id
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

    /// Une arme par style du héros : la meilleure possédée. Un palier
    /// supérieur surpasse toujours le précédent du même style.
    func arsenal(for hero: Hero) -> [Weapon] {
        EquipmentCatalog.styles(for: hero).compactMap { style in
            EquipmentCatalog.weapon(style: style, tier: bestOwnedTier(style))
        }
    }

    /// Le sélecteur a-t-il quelque chose à montrer ou à choisir ?
    var hasWeaponChoice: Bool {
        Hero.allCases.reduce(0) { $0 + arsenal(for: $1).count } >= 2
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

    /// Achat ou trouvaille : l'arme rejoint l'arsenal et son héros la porte
    /// aussitôt.
    func acquire(_ weapon: Weapon) {
        ownedWeapons.insert(weapon.id)
        setEquipped(weapon)
    }

    func acquire(_ accessory: Accessory) {
        ownedAccessories.insert(accessory.id)
        equippedAccessory = accessory.id
    }

    /// Porte une arme déjà possédée (par le héros auquel elle est destinée).
    @discardableResult
    func equipWeapon(id: String) -> Bool {
        guard ownedWeapons.contains(id), let weapon = EquipmentCatalog.weapon(id: id) else { return false }
        setEquipped(weapon)
        return true
    }

    @discardableResult
    func equipAccessory(id: String) -> Bool {
        guard ownedAccessories.contains(id), EquipmentCatalog.accessory(id: id) != nil else { return false }
        equippedAccessory = id
        return true
    }

    private func setEquipped(_ weapon: Weapon) {
        if weapon.hero == .kael {
            equippedWeaponID = weapon.id
        } else {
            equippedAllyWeapons[weapon.hero.rawValue] = weapon.id
        }
    }

    // MARK: - Bâtons d'Eran (récompenses d'histoire)

    /// Eran arrive avec ses deux bâtons de sorcier ; les combats annexes du
    /// Seuil puis du Cœur lui en rapportent de meilleurs. La forge de Bram
    /// est hors d'atteinte aux Actes III-IV : c'est la seule source.
    /// Idempotent : renvoie seulement les bâtons du palier nouvellement atteint.
    @discardableResult
    func grantStoryWeapons() -> [Weapon] {
        guard act3EranMet else { return [] }
        var tier = 1
        if act3ShadesDefeated { tier = 2 }
        if act4DevourersDefeated { tier = 3 }
        var granted: [Weapon] = []
        for style in EquipmentCatalog.styles(for: .eran) {
            for step in 1...tier {
                guard let staff = EquipmentCatalog.weapon(style: style, tier: step),
                      !ownedWeapons.contains(staff.id) else { continue }
                ownedWeapons.insert(staff.id)
                granted.append(staff)
            }
        }
        // Eran garde le style qu'il porte, au meilleur palier obtenu.
        let worn = equippedWeapon(for: .eran)?.style ?? .arcaneStaff
        if let best = EquipmentCatalog.weapon(style: worn, tier: bestOwnedTier(worn)) {
            setEquipped(best)
        }
        return granted.filter { $0.tier == tier }
    }

    // MARK: - Chargement

    /// Recharge l'équipement d'une sauvegarde ou d'une graine New Game+.
    /// `ownedWeapons == nil` = sauvegarde d'avant les styles : seul le
    /// palier d'arme de Kael compte.
    func restoreEquipment(weaponLevel legacyLevel: Int,
                          ownedWeapons owned: [String]?,
                          equippedWeapon: String?,
                          equippedAllyWeapons allies: [String: String]? = nil,
                          ownedAccessories accessories: [String]?,
                          equippedAccessory accessory: String?) {
        let rename = { (id: String) in EquipmentCatalog.legacyWeaponIDs[id] ?? id }
        ownedWeapons = []
        equippedAllyWeapons = [:]
        if let owned {
            ownedWeapons = Set(owned.map(rename))
            equippedWeaponID = equippedWeapon.map(rename)
            equippedAllyWeapons = allies ?? [:]
        } else {
            weaponLevel = legacyLevel
        }
        ownedAccessories = Set(accessories ?? [])
        equippedAccessory = accessory
        sanitizeEquipment()
    }

    /// Purge les ids inconnus et garantit, pour chaque héros, que la pièce
    /// portée est possédée et qu'elle est la meilleure de son style.
    func sanitizeEquipment() {
        let weaponIDs = Set(EquipmentCatalog.weapons.map(\.id))
        ownedWeapons.formIntersection(weaponIDs)
        for hero in Hero.allCases {
            let worn = equippedWeapon(for: hero).flatMap { weapon -> Weapon? in
                guard ownedWeapons.contains(weapon.id), weapon.hero == hero else { return nil }
                return EquipmentCatalog.weapon(style: weapon.style, tier: bestOwnedTier(weapon.style))
            }
            let choice = worn ?? arsenal(for: hero).max { $0.tier < $1.tier }
            if hero == .kael {
                equippedWeaponID = choice?.id
            } else {
                equippedAllyWeapons[hero.rawValue] = choice?.id
            }
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
                       mpRegen: lhs.mpRegen + rhs.mpRegen,
                       spellPower: lhs.spellPower + rhs.spellPower,
                       maxMP: lhs.maxMP + rhs.maxMP)
    }
}
