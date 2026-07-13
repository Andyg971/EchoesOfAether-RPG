import SpriteKit

@MainActor
final class InventoryOverlay {
    private let root = SKNode()
    private let panel = SKShapeNode()
    private let titleLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
    private let closeButton = SKShapeNode(rectOf: CGSize(width: 100, height: 40))

    private var statLabels: [SKNode] = []
    private var playerState: PlayerState?
    private var completion: (() -> Void)?

    private var panelWidth: CGFloat = 320
    private var panelHeight: CGFloat = 580

    var isActive: Bool { root.parent != nil && !root.isHidden }

    func attach(to scene: SKScene) {
        root.zPosition = 1_100
        root.isHidden = true
        scene.addChild(root)

        root.addChild(panel)

        titleLabel.fontSize = 26
        titleLabel.fontColor = SKColor(red: 0.78, green: 0.68, blue: 1, alpha: 1)
        titleLabel.horizontalAlignmentMode = .center
        root.addChild(titleLabel)

        setupCloseButton()
    }

    func layout(in size: CGSize, safeBottom: CGFloat = 0) {
        panelWidth = min(340, max(280, size.width - 32))
        // Hauteur FIXE calée sur le contenu (4 sections + 11 lignes) ;
        // le fittingFactor réduit ensuite le tout pour tenir à l'écran.
        panelHeight = 520
        root.position = CGPoint(x: size.width / 2, y: (size.height + safeBottom) / 2)

        // Cadre pixel SNES : coins carrés, double bordure, zéro glow.
        PixelUI.stylePanel(panel, size: CGSize(width: panelWidth, height: panelHeight),
                           fill: SKColor(red: 0.04, green: 0.04, blue: 0.07, alpha: 0.97),
                           accent: SKColor(red: 0.45, green: 0.35, blue: 0.75, alpha: 1))

        titleLabel.position = CGPoint(x: 0, y: panelHeight / 2 - 36)
        closeButton.position = CGPoint(x: 0, y: -panelHeight / 2 + 34)

        // iPad : agrandit. iPhone paysage : réduit pour que le panneau
        // (440 pt min) tienne en hauteur (root déjà centré → simple échelle).
        root.setScale(UIScale.fittingFactor(for: size, contentHeight: panelHeight + 12))
    }

    func open(player: PlayerState, completion: @escaping () -> Void) {
        self.playerState = player
        self.completion = completion
        titleLabel.text = String(localized: "inventory.title")
        root.isHidden = false
        AudioEngine.shared.playShopOpen()
        buildContent(player: player)
    }

    func handleTap(at point: CGPoint, in scene: SKScene) -> Bool {
        guard isActive else { return false }
        let local = root.convert(point, from: scene)

        if closeButton.contains(local) {
            close()
            return true
        }

        return true // absorb taps
    }

    // MARK: - Build Content

    private func buildContent(player: PlayerState) {
        statLabels.forEach { $0.removeFromParent() }
        statLabels.removeAll()

        let startY = panelHeight / 2 - 60
        let lineH: CGFloat = 26
        var y = startY

        // Section : Équipement
        y = addSection(String(localized: "inventory.section.equipment"), y: y)
        y = addRow(icon: .sword, label: weaponName(player.weaponLevel),
                   detail: String(localized: "inventory.attack \(player.attackDamage)"), y: y, lineH: lineH)
        y = addRow(icon: .shield, label: armorName(player.armorLevel),
                   detail: String(localized: "inventory.defense \(player.armorLevel * 50)"), y: y, lineH: lineH)

        y -= 6 // spacer

        // Section : Consommables
        y = addSection(String(localized: "inventory.section.items"), y: y)
        y = addRow(icon: .potion, label: String(localized: "inventory.potions"),
                   detail: "\(player.potions)/3", y: y, lineH: lineH)
        y = addRow(icon: .gem, label: String(localized: "inventory.shards"),
                   detail: "\(player.aetherShards)", y: y, lineH: lineH)

        y -= 6

        // Section : Stats
        y = addSection(String(localized: "inventory.section.stats"), y: y)
        y = addRow(icon: .heart, label: String(localized: "inventory.maxHP"),
                   detail: "\(player.currentMaxHP)", y: y, lineH: lineH)
        y = addRow(icon: .bolt, label: String(localized: "inventory.attackDmg"),
                   detail: "\(player.attackDamage)", y: y, lineH: lineH)
        y = addRow(icon: .darkMoon, label: String(localized: "inventory.blackSlashDmg"),
                   detail: "\(player.blackSlashDamage)", y: y, lineH: lineH)

        y -= 6

        // Gold
        y = addRow(icon: .coin, label: String(localized: "inventory.gold"),
                   detail: "\(player.gold)", y: y, lineH: lineH,
                   color: SKColor(red: 0.90, green: 0.78, blue: 0.30, alpha: 1))

        y -= 6

        // Section : Quêtes
        y = addSection(String(localized: "inventory.section.quests"), y: y)
        y = addQuestRow(label: String(localized: "quest.delivery.name"),
                        state: player.questDelivery, y: y, lineH: lineH)
        y = addQuestRow(label: String(localized: "quest.childToy.name"),
                        state: player.questChildToy, y: y, lineH: lineH)
        y = addQuestRow(label: String(localized: "quest.lyraShards.name"),
                        state: player.questLyraShards, y: y, lineH: lineH)

        // Animate
        for (i, label) in statLabels.enumerated() {
            JuiceEngine.popIn(label, delay: Double(i) * 0.03)
        }
    }

    // MARK: - Row Builders

    private func addSection(_ text: String, y: CGFloat) -> CGFloat {
        let sectionLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
        sectionLabel.text = text
        sectionLabel.fontSize = 17
        sectionLabel.fontColor = SKColor(red: 0.60, green: 0.50, blue: 0.85, alpha: 0.8)
        sectionLabel.horizontalAlignmentMode = .left
        sectionLabel.position = CGPoint(x: -panelWidth / 2 + 24, y: y - 6)
        root.addChild(sectionLabel)
        statLabels.append(sectionLabel)

        let div = SKShapeNode(rectOf: CGSize(width: panelWidth - 48, height: 1))
        div.fillColor = SKColor(white: 0.18, alpha: 0.5)
        div.strokeColor = .clear
        div.position = CGPoint(x: 0, y: y - 18)
        sectionLabel.addChild(div)

        return y - 28
    }

    private func addRow(icon: PixelIcons.Kind, label: String, detail: String,
                        y: CGFloat, lineH: CGFloat,
                        color: SKColor = .white) -> CGFloat {
        let iconNode = PixelIcons.node(icon, pixel: 2)
        iconNode.position = CGPoint(x: -panelWidth / 2 + 32, y: y + 2)
        root.addChild(iconNode)
        statLabels.append(iconNode)
        return addLabels(label: label, detail: detail, y: y, lineH: lineH, color: color)
    }

    /// Libellé + valeur d'une ligne (sans icône) : partagé entre addRow
    /// et addQuestRow.
    private func addLabels(label: String, detail: String,
                           y: CGFloat, lineH: CGFloat,
                           color: SKColor) -> CGFloat {
        let nameLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
        nameLabel.text = label
        nameLabel.fontSize = 18
        nameLabel.fontColor = SKColor(white: 0.85, alpha: 1)
        nameLabel.horizontalAlignmentMode = .left
        nameLabel.position = CGPoint(x: -panelWidth / 2 + 52, y: y - 4)
        root.addChild(nameLabel)
        statLabels.append(nameLabel)

        let detailLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
        detailLabel.text = detail
        detailLabel.fontSize = 18
        detailLabel.fontColor = color
        detailLabel.horizontalAlignmentMode = .right
        detailLabel.position = CGPoint(x: panelWidth / 2 - 24, y: y - 4)
        root.addChild(detailLabel)
        statLabels.append(detailLabel)

        return y - lineH
    }

    private func addQuestRow(label: String,
                             state: QuestState, y: CGFloat, lineH: CGFloat) -> CGFloat {
        let color: SKColor
        switch state {
        case .inactive: color = SKColor(white: 0.40, alpha: 1)
        case .active:   color = SKColor(red: 0.90, green: 0.80, blue: 0.35, alpha: 1)
        case .complete: color = SKColor(red: 0.40, green: 0.80, blue: 0.45, alpha: 1)
        }
        let stateLabel: String
        switch state {
        case .inactive: stateLabel = String(localized: "quest.state.inactive")
        case .active:   stateLabel = String(localized: "quest.state.active")
        case .complete: stateLabel = String(localized: "quest.state.complete")
        }
        // Puce d'état pixel : carré plein coloré selon l'état (cohérent
        // avec le journal de quêtes).
        let chip = SKSpriteNode(color: color, size: CGSize(width: 8, height: 8))
        chip.position = CGPoint(x: -panelWidth / 2 + 32, y: y + 2)
        root.addChild(chip)
        statLabels.append(chip)
        return addLabels(label: label, detail: stateLabel,
                         y: y, lineH: lineH, color: color)
    }

    // MARK: - Equipment Names

    private func weaponName(_ level: Int) -> String {
        switch level {
        case 0: return String(localized: "inventory.weapon.fists")
        case 1: return String(localized: "inventory.weapon.ironBlade")
        case 2: return String(localized: "inventory.weapon.runicBlade")
        default: return String(localized: "inventory.weapon.aetheriteBlade")
        }
    }

    private func armorName(_ level: Int) -> String {
        switch level {
        case 0: return String(localized: "inventory.armor.none")
        case 1: return String(localized: "inventory.armor.chainMail")
        case 2: return String(localized: "inventory.armor.reinforced")
        default: return String(localized: "inventory.armor.aetheritePlate")
        }
    }

    // MARK: - Private

    private func setupCloseButton() {
        closeButton.fillColor = SKColor(red: 0.12, green: 0.10, blue: 0.07, alpha: 1)
        closeButton.strokeColor = PixelUI.goldDim
        closeButton.lineWidth = 2
        closeButton.glowWidth = 0

        let label = SKLabelNode(fontNamed: PixelUI.uiFont)
        label.text = String(localized: "inventory.close")
        label.fontSize = 18
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        closeButton.addChild(label)
        root.addChild(closeButton)
    }

    private func close() {
        root.isHidden = true
        completion?()
        completion = nil
    }
}
