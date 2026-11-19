import SpriteKit

// EquipmentPicker — cadre, onglets des héros, lignes, badge ÉQUIPÉ et pied
// de comparaison.
extension EquipmentPicker {

    private var panelTop: CGFloat { panelSize.height / 2 }
    private var rowWidth: CGFloat { panelSize.width - 32 }
    private var showsTabs: Bool { mode == .weapons && heroes.count > 1 }
    private var firstRowY: CGFloat { panelTop - (showsTabs ? 104 : 76) }
    private static let violetEdge = SKColor(red: 0.45, green: 0.35, blue: 0.75, alpha: 1)

    func build() {
        clear()
        track(scrim())

        let panel = SKShapeNode()
        PixelUI.stylePanel(panel, size: panelSize,
                           fill: SKColor(red: 0.05, green: 0.04, blue: 0.09, alpha: 0.98),
                           accent: Self.violetEdge)
        track(panel)

        let titleLabel = label(title, size: 24, color: Palette.aether,
                               align: .center, at: CGPoint(x: 0, y: panelTop - 28))
        track(titleLabel)

        if showsTabs { buildTabs() }

        for (index, entry) in entries.enumerated() {
            let row = makeRow(entry)
            row.position = CGPoint(x: 0, y: firstRowY - CGFloat(index) * Self.rowHeight)
            track(row)
            register(row: row)
        }

        let hintKey: LocalizedStringResource = showsTabs
            ? "equipment.picker.hintHeroes" : "equipment.picker.hint"
        track(label(String(localized: hintKey), size: 15, color: PixelUI.gold,
                    align: .center, at: CGPoint(x: 0, y: -panelTop + 20)))

        refreshSelection()
    }

    /// Voile sombre sur tout l'inventaire : le sélecteur prend le focus.
    private func scrim() -> SKNode {
        let veil = SKSpriteNode(color: SKColor(red: 0.01, green: 0.01, blue: 0.03, alpha: 0.72),
                                size: CGSize(width: inventorySize.width + 8,
                                             height: inventorySize.height + 8))
        veil.zPosition = -1
        return veil
    }

    /// Un onglet pixel par héros ; celui affiché est doré.
    private func buildTabs() {
        let size = CGSize(width: 108, height: 28)
        let spacing: CGFloat = 12
        let total = CGFloat(heroes.count) * size.width + CGFloat(heroes.count - 1) * spacing
        for (index, tabHero) in heroes.enumerated() {
            let selected = tabHero == hero
            let tab = SKShapeNode()
            PixelUI.stylePanel(tab, size: size,
                               fill: selected ? Palette.shadowWarm
                                   : SKColor(red: 0.07, green: 0.06, blue: 0.11, alpha: 1),
                               accent: selected ? PixelUI.gold : Self.violetEdge.withAlphaComponent(0.6))
            tab.position = CGPoint(x: -total / 2 + size.width / 2 + CGFloat(index) * (size.width + spacing),
                                   y: panelTop - 62)
            tab.addChild(label(tabHero.displayName, size: 17,
                               color: selected ? .white : SKColor(white: 0.55, alpha: 1),
                               align: .center, at: .zero))
            track(tab)
            register(tab: tab, hero: tabHero)
        }
    }

    private func makeRow(_ entry: Entry) -> SKShapeNode {
        let size = CGSize(width: rowWidth, height: Self.rowHeight - 6)
        let row = SKShapeNode(rectOf: size)
        row.fillColor = Palette.shadowWarm
        row.glowWidth = 0

        let icon = PixelIcons.node(entry.icon, pixel: 2)
        icon.position = CGPoint(x: -size.width / 2 + 20, y: 0)
        row.addChild(icon)

        let textX = -size.width / 2 + 42
        row.addChild(label(entry.name, size: 18, color: .white,
                           align: .left, at: CGPoint(x: textX, y: 5)))
        row.addChild(label(entry.summary, size: 14, color: SKColor(white: 0.62, alpha: 1),
                           align: .left, at: CGPoint(x: textX, y: -11)))
        if !entry.tag.isEmpty {
            row.addChild(label(entry.tag, size: 16, color: entry.tagColor,
                               align: .right, at: CGPoint(x: size.width / 2 - 12, y: 5)))
        }
        if isEquipped(entry.id) {
            let badge = label(String(localized: "equipment.equipped"), size: 14,
                              color: PixelUI.gold, align: .right,
                              at: CGPoint(x: size.width / 2 - 12, y: -11))
            badge.name = "badge"
            row.addChild(badge)
        }
        return row
    }

    /// Cadre doré sur la ligne du curseur, comparaison des stats en pied.
    func refreshSelection() {
        for (index, row) in rowNodes.enumerated() {
            let selected = index == selection
            row.strokeColor = selected ? PixelUI.gold : Self.violetEdge.withAlphaComponent(0.6)
            row.lineWidth = selected ? 2.5 : 1.5
        }
        root.childNode(withName: "comparison")?.removeFromParent()
        let footer = SKNode()
        footer.name = "comparison"
        footer.position = CGPoint(x: 0, y: firstRowY - CGFloat(max(entries.count, 1)) * Self.rowHeight + 4)
        root.addChild(footer)

        let changes = comparison()
        guard !changes.isEmpty else {
            footer.addChild(label(String(localized: "equipment.picker.worn"), size: 16,
                                  color: SKColor(white: 0.55, alpha: 1), align: .center, at: .zero))
            return
        }
        let labels = changes.map { change in
            label(change.text, size: 16,
                  color: change.trend > 0 ? EquipmentText.gain : EquipmentText.loss,
                  align: .left, at: .zero)
        }
        let gap: CGFloat = 22
        let total = labels.reduce(0) { $0 + $1.frame.width } + gap * CGFloat(labels.count - 1)
        var x = -total / 2
        for item in labels {
            item.position = CGPoint(x: x, y: 0)
            footer.addChild(item)
            x += item.frame.width + gap
        }
    }

    private func label(_ text: String, size: CGFloat, color: SKColor,
                       align: SKLabelHorizontalAlignmentMode, at position: CGPoint) -> SKLabelNode {
        let node = SKLabelNode(fontNamed: PixelUI.uiFont)
        node.text = text
        node.fontSize = size
        node.fontColor = color
        node.horizontalAlignmentMode = align
        node.verticalAlignmentMode = .center
        node.position = position
        return node
    }
}
