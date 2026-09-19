import SpriteKit

// Articles des boutiques.
// Extrait de GameManager.swift (découpage du monolithe).
@MainActor
extension GameManager {
    // MARK: - Shop Items

    /// Forge de Bram : seul le PALIER SUIVANT de chaque catégorie est en
    /// vitrine (l'étal reste court et la progression lisible).
    /// Palier 3 (Aetherite) : gold sink de fin de partie.
    func bramItems() -> [ShopItem] {
        let weapons: [(name: LocalizedStringResource, desc: LocalizedStringResource, price: Int)] = [
            ("shop.bram.ironBlade.name", "shop.bram.ironBlade.desc", 80),
            ("shop.bram.runicBlade.name", "shop.bram.runicBlade.desc", 180),
            ("shop.bram.aetheriteBlade.name", "shop.bram.aetheriteBlade.desc", 420)
        ]
        let armors: [(name: LocalizedStringResource, desc: LocalizedStringResource, price: Int)] = [
            ("shop.bram.chainMail.name", "shop.bram.chainMail.desc", 60),
            ("shop.bram.reinforced.name", "shop.bram.reinforced.desc", 150),
            ("shop.bram.aetheritePlate.name", "shop.bram.aetheritePlate.desc", 380)
        ]

        var items: [ShopItem] = []
        if player.weaponLevel < weapons.count {
            let next = weapons[player.weaponLevel]
            let targetLevel = player.weaponLevel + 1
            items.append(ShopItem(
                nameKey: next.name, descKey: next.desc, price: next.price, icon: .sword,
                canBuy: { [weak self] _ in (self?.player.weaponLevel ?? 3) < targetLevel },
                onBuy: { [weak self] _ in self?.player.weaponLevel = targetLevel }
            ))
        }
        if player.armorLevel < armors.count {
            let next = armors[player.armorLevel]
            let targetLevel = player.armorLevel + 1
            items.append(ShopItem(
                nameKey: next.name, descKey: next.desc, price: next.price, icon: .shield,
                canBuy: { [weak self] _ in (self?.player.armorLevel ?? 3) < targetLevel },
                onBuy: { [weak self] _ in self?.player.armorLevel = targetLevel }
            ))
        }
        // ACCESSOIRES : un seul se porte à la fois. En acheter un remplace le
        // précédent — c'est un ARBITRAGE (frapper fort / encaisser / soutenir),
        // pas une accumulation. La vitrine reste lisible : on ne propose que
        // ceux qu'on ne porte pas.
        let accessories: [(id: String, name: LocalizedStringResource,
                           desc: LocalizedStringResource, price: Int)] = [
            ("ember",     "shop.acc.ember.name",     "shop.acc.ember.desc",     140),
            ("shade",     "shop.acc.shade.name",     "shop.acc.shade.desc",     160),
            ("resonance", "shop.acc.resonance.name", "shop.acc.resonance.desc", 180)
        ]
        for acc in accessories where player.equippedAccessory != acc.id {
            items.append(ShopItem(
                nameKey: acc.name, descKey: acc.desc, price: acc.price, icon: .gem,
                canBuy: { [weak self] _ in self?.player.equippedAccessory != acc.id },
                onBuy: { [weak self] _ in self?.player.equippedAccessory = acc.id }
            ))
        }
        return items
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
