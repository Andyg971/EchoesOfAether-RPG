import SpriteKit

/// Sélecteur d'arme ou d'accessoire, ouvert par-dessus l'inventaire.
///
/// Armes : un onglet par héros (Kael aux poings, Lyra au bâton de
/// prêtresse, Eran au bâton de sorcier), une ligne par style possédé, le
/// badge ÉQUIPÉ sur la pièce portée et, en pied, la comparaison des stats si
/// l'on équipait la ligne du curseur. Même cadre pixel que l'inventaire.
@MainActor
final class EquipmentPicker {
    enum Mode { case weapons, accessories }

    struct Entry {
        let id: String
        let name: String
        let tag: String
        let tagColor: SKColor
        let summary: String
        let icon: PixelIcons.Kind
    }

    static let panelSize = CGSize(width: 580, height: 320)
    static let rowHeight: CGFloat = 44

    let root = SKNode()
    private var nodes: [SKNode] = []
    private var rows: [SKShapeNode] = []
    private(set) var tabs: [(hero: Hero, node: SKShapeNode)] = []
    private(set) var mode: Mode = .weapons
    /// Héros affichés (onglets) et héros courant.
    private(set) var heroes: [Hero] = [.kael]
    private(set) var hero: Hero = .kael
    private(set) var entries: [Entry] = []
    private(set) var selection = 0
    private(set) var player: PlayerState?
    var inventorySize = InventoryOverlay.panelSize

    /// Appelé après chaque changement d'équipement (l'inventaire se redessine).
    var onEquip: (() -> Void)?

    var isOpen: Bool { root.parent != nil && !root.isHidden }
    var panelSize: CGSize {
        CGSize(width: min(Self.panelSize.width, inventorySize.width - 40), height: Self.panelSize.height)
    }

    func attach(to parent: SKNode) {
        root.zPosition = 60
        root.isHidden = true
        parent.addChild(root)
    }

    func layout(inventorySize: CGSize) {
        self.inventorySize = inventorySize
        if isOpen { build() }
    }

    func open(_ mode: Mode, player: PlayerState) {
        self.mode = mode
        self.player = player
        heroes = mode == .weapons
            ? Hero.allCases.filter { !player.arsenal(for: $0).isEmpty }
            : [.kael]
        if heroes.isEmpty { heroes = [.kael] }
        hero = heroes[0]
        reloadEntries()
        root.isHidden = false
        AudioEngine.shared.playShopOpen()
        build()
        AccessibilitySettings.announce(title)
    }

    func close() {
        root.isHidden = true
        clear()
    }

    func moveSelection(_ dy: Int) {
        guard isOpen, !entries.isEmpty, dy != 0 else { return }
        selection = (selection - dy + entries.count) % entries.count
        HapticsEngine.light()
        AudioEngine.shared.playStep()
        refreshSelection()
        let entry = entries[selection]
        AccessibilitySettings.announce("\(entry.name). \(entry.summary)")
    }

    /// Gauche / droite (ou L1 / R1) : héros précédent / suivant.
    func switchHero(_ step: Int) {
        guard isOpen, heroes.count > 1, step != 0,
              let index = heroes.firstIndex(of: hero) else { return }
        hero = heroes[(index + step + heroes.count) % heroes.count]
        HapticsEngine.light()
        AudioEngine.shared.playStep()
        reloadEntries()
        build()
        AccessibilitySettings.announce(hero.displayName)
    }

    /// Bouton A : le héros courant porte la pièce du curseur.
    func confirmSelection() {
        guard isOpen, entries.indices.contains(selection), let player else { return }
        let id = entries[selection].id
        guard !isEquipped(id) else {
            HapticsEngine.light()
            return
        }
        let done = mode == .weapons ? player.equipWeapon(id: id) : player.equipAccessory(id: id)
        guard done else { return }
        HapticsEngine.success()
        AudioEngine.shared.playSelect()
        onEquip?()
        build()
        if rows.indices.contains(selection), let badge = rows[selection].childNode(withName: "badge") {
            JuiceEngine.popIn(badge)
        }
        AccessibilitySettings.announce(String(localized: "equipment.equipped"))
    }

    /// Toucher un onglet change de héros, toucher une ligne l'équipe,
    /// toucher hors du cadre ferme le sélecteur. `local` est en coordonnées
    /// de l'inventaire (même repère que `root`).
    func handleTap(at local: CGPoint) {
        guard isOpen else { return }
        if let tab = tabs.first(where: { $0.node.contains(local) }), tab.hero != hero,
           let current = heroes.firstIndex(of: hero), let target = heroes.firstIndex(of: tab.hero) {
            switchHero(target - current)
            return
        }
        if let index = rows.firstIndex(where: { $0.contains(local) }) {
            selection = index
            refreshSelection()
            confirmSelection()
            return
        }
        if abs(local.x) > panelSize.width / 2 || abs(local.y) > panelSize.height / 2 {
            HapticsEngine.light()
            close()
        }
    }

    // MARK: - Données

    var title: String {
        mode == .weapons
            ? String(localized: "equipment.picker.weapons")
            : String(localized: "equipment.picker.accessories")
    }

    func isEquipped(_ id: String) -> Bool {
        mode == .weapons
            ? player?.equippedWeapon(for: hero)?.id == id
            : player?.equippedAccessory == id
    }

    private func reloadEntries() {
        guard let player else { return }
        entries = Self.entries(for: mode, hero: hero, player: player)
        selection = entries.firstIndex { isEquipped($0.id) } ?? 0
    }

    static func entries(for mode: Mode, hero: Hero, player: PlayerState) -> [Entry] {
        switch mode {
        case .weapons:
            return player.arsenal(for: hero).map { weapon in
                Entry(id: weapon.id, name: String(localized: weapon.nameKey),
                      tag: String(localized: weapon.style.nameKey),
                      tagColor: EquipmentText.color(for: weapon.style),
                      summary: EquipmentText.summary(weapon.bonus),
                      icon: .weapon(weapon.style))
            }
        case .accessories:
            return player.ownedAccessoryList.map { accessory in
                Entry(id: accessory.id, name: String(localized: accessory.nameKey),
                      tag: "", tagColor: .clear,
                      summary: EquipmentText.summary(accessory.bonus),
                      icon: .accessory(id: accessory.id))
            }
        }
    }

    /// Stats du héros si la ligne du curseur était portée, face à la tenue actuelle.
    func comparison() -> [(text: String, trend: Int)] {
        guard let player, entries.indices.contains(selection) else { return [] }
        let id = entries[selection].id
        let wornWeapon = player.equippedWeapon(for: hero)?.id
        let worn = player.preview(hero: hero, weaponID: wornWeapon,
                                  accessoryID: player.equippedAccessory)
        let candidate = mode == .weapons
            ? player.preview(hero: hero, weaponID: id, accessoryID: player.equippedAccessory)
            : player.preview(hero: .kael, weaponID: wornWeapon, accessoryID: id)
        return EquipmentText.comparisons(from: worn, to: candidate)
    }

    // MARK: - Rendu (EquipmentPicker+Build)

    func track(_ node: SKNode) {
        root.addChild(node)
        nodes.append(node)
    }

    func clear() {
        root.childNode(withName: "comparison")?.removeFromParent()
        nodes.forEach { $0.removeFromParent() }
        nodes.removeAll()
        rows.removeAll()
        tabs.removeAll()
    }

    func register(row: SKShapeNode) { rows.append(row) }
    func register(tab: SKShapeNode, hero: Hero) { tabs.append((hero, tab)) }
    var rowNodes: [SKShapeNode] { rows }
}
