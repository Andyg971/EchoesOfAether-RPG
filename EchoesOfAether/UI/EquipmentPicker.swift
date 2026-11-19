import SpriteKit

/// Sélecteur d'arme ou d'accessoire, ouvert par-dessus l'inventaire.
///
/// Une ligne par pièce possédée (la meilleure de chaque style d'arme), le
/// badge ÉQUIPÉ sur celle que porte Kael, et en pied la comparaison de ses
/// stats si l'on équipait la ligne du curseur. Même cadre pixel que
/// l'inventaire : coins carrés, double bordure, zéro glow.
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

    static let panelSize = CGSize(width: 580, height: 296)
    static let rowHeight: CGFloat = 44

    let root = SKNode()
    private var nodes: [SKNode] = []
    private var rows: [SKShapeNode] = []
    private(set) var mode: Mode = .weapons
    private(set) var entries: [Entry] = []
    private(set) var selection = 0
    private var player: PlayerState?
    private var inventorySize = InventoryOverlay.panelSize

    /// Appelé après chaque changement d'équipement (l'inventaire se redessine).
    var onEquip: (() -> Void)?

    var isOpen: Bool { root.parent != nil && !root.isHidden }

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
        entries = Self.entries(for: mode, player: player)
        selection = entries.firstIndex { isEquipped($0.id) } ?? 0
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

    /// Bouton A : porte la pièce du curseur.
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
        if rows.indices.contains(selection) {
            JuiceEngine.popIn(rows[selection].childNode(withName: "badge") ?? rows[selection])
        }
        AccessibilitySettings.announce(String(localized: "equipment.equipped"))
    }

    /// Toucher une ligne l'équipe ; toucher hors du cadre ferme le sélecteur.
    /// `local` est en coordonnées de l'inventaire (même repère que `root`).
    func handleTap(at local: CGPoint) {
        guard isOpen else { return }
        if let index = rows.firstIndex(where: { $0.contains(local) }) {
            selection = index
            refreshSelection()
            confirmSelection()
            return
        }
        let half = CGSize(width: Self.panelSize.width / 2, height: Self.panelSize.height / 2)
        if abs(local.x) > half.width || abs(local.y) > half.height {
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
        mode == .weapons ? player?.equippedWeaponID == id : player?.equippedAccessory == id
    }

    static func entries(for mode: Mode, player: PlayerState) -> [Entry] {
        switch mode {
        case .weapons:
            return player.arsenal.map { weapon in
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

    /// Stats de Kael si la ligne du curseur était portée, face à la tenue actuelle.
    func comparison() -> [(text: String, trend: Int)] {
        guard let player, entries.indices.contains(selection) else { return [] }
        let id = entries[selection].id
        let worn = player.preview(weaponID: player.equippedWeaponID,
                                  accessoryID: player.equippedAccessory)
        let candidate = mode == .weapons
            ? player.preview(weaponID: id, accessoryID: player.equippedAccessory)
            : player.preview(weaponID: player.equippedWeaponID, accessoryID: id)
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
    }

    func register(row: SKShapeNode) { rows.append(row) }
    var rowNodes: [SKShapeNode] { rows }
}
