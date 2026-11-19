import SpriteKit

// Articles des boutiques.
// Extrait de GameManager.swift (découpage du monolithe).
@MainActor
extension GameManager {
    // MARK: - Shop Items

    /// Forge de Bram : pour chaque style d'arme, seul le PALIER SUIVANT est
    /// en vitrine (l'étal reste lisible et la progression claire). Acheter
    /// une arme la range dans l'arsenal et la fait porter aussitôt ; on en
    /// change ensuite depuis l'inventaire. Palier 3 (Aetherite) : gold sink.
    func bramItems() -> [ShopItem] {
        var items = WeaponStyle.allCases
            .compactMap { player.nextWeapon(for: $0) }
            .sorted { $0.tier < $1.tier }
            .map(weaponItem)

        let armors: [(name: LocalizedStringResource, price: Int)] = [
            ("shop.bram.chainMail.name", 60),
            ("shop.bram.reinforced.name", 150),
            ("shop.bram.aetheritePlate.name", 380)
        ]
        if player.armorLevel < armors.count {
            let next = armors[player.armorLevel]
            let targetLevel = player.armorLevel + 1
            items.append(ShopItem(
                nameKey: next.name, price: next.price, icon: .shield,
                detail: EquipmentText.armorSummary(maxHP: targetLevel * PlayerState.armorHPPerLevel),
                canBuy: { [weak self] _ in (self?.player.armorLevel ?? 3) < targetLevel },
                onBuy: { [weak self] _ in self?.player.armorLevel = targetLevel }
            ))
        }
        // ACCESSOIRES : un seul se porte à la fois — un ARBITRAGE (frapper
        // fort / encaisser / soutenir). Ceux déjà achetés restent dans le sac
        // et se changent depuis l'inventaire : la vitrine ne les repropose pas.
        for accessory in EquipmentCatalog.accessories
        where !player.ownedAccessories.contains(accessory.id) {
            items.append(ShopItem(
                nameKey: accessory.nameKey, price: accessory.price,
                icon: .accessory(id: accessory.id),
                detail: EquipmentText.summary(accessory.bonus),
                canBuy: { [weak self] _ in self?.player.ownedAccessories.contains(accessory.id) == false },
                onBuy: { [weak self] _ in self?.player.acquire(accessory) }
            ))
        }
        return items
    }

    private func weaponItem(_ weapon: Weapon) -> ShopItem {
        ShopItem(
            nameKey: weapon.nameKey, price: weapon.price,
            icon: .weapon(weapon.style),
            detail: EquipmentText.weaponLine(weapon),
            canBuy: { [weak self] _ in self?.player.ownedWeapons.contains(weapon.id) == false },
            onBuy: { [weak self] _ in self?.player.acquire(weapon) }
        )
    }

    func maraItems() -> [ShopItem] {
        [
            ShopItem(
                nameKey: "shop.mara.potion.name",
                descKey: "shop.mara.potion.desc",
                price: 15,
                icon: .potion,
                canBuy: { [weak self] _ in !(self?.player.potionsFull ?? false) },
                onBuy: { [weak self] _ in
                    guard let self, player.potions < 3 else { return }
                    player.potions += 1
                }
            ),
            // Mara vendait ici les Éclats d'Aether de la quête de Lyra — on
            // pouvait donc acheter au comptoir la réponse à « ma marque va-t-elle
            // me tuer ». C'est ce qui faisait sonner cette quête comme une
            // course aux commissions : le cristal se trouve en forêt, à pied.
        ]
    }

    func innItems() -> [ShopItem] {
        [
            ShopItem(
                nameKey: "shop.inn.rest.name",
                descKey: "shop.inn.rest.desc",
                price: 10,
                icon: .heart,
                canBuy: { [weak self] _ in !(self?.player.innRested ?? false) },
                onBuy: { [weak self] _ in self?.player.innRested = true }
            )
        ]
    }
}
