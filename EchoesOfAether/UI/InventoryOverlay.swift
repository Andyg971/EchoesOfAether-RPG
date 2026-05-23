import SpriteKit

@MainActor
final class InventoryOverlay {
    private let root = SKNode()
    private let panel = SKShapeNode()
    private let titleLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let closeButton = SKShapeNode(rectOf: CGSize(width: 100, height: 40), cornerRadius: 10)

    private var statLabels: [SKLabelNode] = []
    private var playerState: PlayerState?
    private var completion: (() -> Void)?

    private var panelWidth: CGFloat = 320
    private var panelHeight: CGFloat = 580

    var isActive: Bool { root.parent != nil && !root.isHidden }

    func attach(to scene: SKScene) {
        root.zPosition = 1_100
        root.isHidden = true
        scene.addChild(root)

        panel.fillColor = SKColor(red: 0.04, green: 0.04, blue: 0.07, alpha: 0.97)
        panel.strokeColor = SKColor(red: 0.45, green: 0.35, blue: 0.75, alpha: 1)
        panel.lineWidth = 2
        root.addChild(panel)

        titleLabel.fontSize = 20
        titleLabel.fontColor = SKColor(red: 0.78, green: 0.68, blue: 1, alpha: 1)
        titleLabel.horizontalAlignmentMode = .center
        root.addChild(titleLabel)

        setupCloseButton()
    }

    func layout(in size: CGSize, safeBottom: CGFloat = 0) {
        panelWidth = min(340, max(280, size.width - 32))
        panelHeight = min(580, max(440, size.height - safeBottom - 80))
        root.position = CGPoint(x: size.width / 2, y: (size.height + safeBottom) / 2)

        panel.path = CGPath(
            roundedRect: CGRect(x: -panelWidth / 2, y: -panelHeight / 2,
                                width: panelWidth, height: panelHeight),
            cornerWidth: 18, cornerHeight: 18, transform: nil
        )

        titleLabel.position = CGPoint(x: 0, y: panelHeight / 2 - 36)
        closeButton.position = CGPoint(x: 0, y: -panelHeight / 2 + 34)
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

        let startY = panelHeight / 2 - 70
        let lineH: CGFloat = 30
        var y = startY

        // Section : Équipement
        y = addSection(String(localized: "inventory.section.equipment"), y: y)
        y = addRow(icon: "⚔", label: weaponName(player.weaponLevel),
                   detail: String(localized: "inventory.attack \(player.attackDamage)"), y: y, lineH: lineH)
        y = addRow(icon: "🛡", label: armorName(player.armorLevel),
                   detail: String(localized: "inventory.defense \(player.armorLevel * 50)"), y: y, lineH: lineH)

        y -= 10 // spacer

        // Section : Consommables
        y = addSection(String(localized: "inventory.section.items"), y: y)
        y = addRow(icon: "🧪", label: String(localized: "inventory.potions"),
                   detail: "\(player.potions)/3", y: y, lineH: lineH)
        y = addRow(icon: "💎", label: String(localized: "inventory.shards"),
                   detail: "\(player.aetherShards)", y: y, lineH: lineH)

        y -= 10

        // Section : Stats
        y = addSection(String(localized: "inventory.section.stats"), y: y)
        y = addRow(icon: "❤️", label: String(localized: "inventory.maxHP"),
                   detail: "\(player.currentMaxHP)", y: y, lineH: lineH)
        y = addRow(icon: "⚡", label: String(localized: "inventory.attackDmg"),
                   detail: "\(player.attackDamage)", y: y, lineH: lineH)
        y = addRow(icon: "🌑", label: String(localized: "inventory.blackSlashDmg"),
                   detail: "\(player.blackSlashDamage)", y: y, lineH: lineH)

        y -= 10

        // Gold
        y = addRow(icon: "🪙", label: String(localized: "inventory.gold"),
                   detail: "\(player.gold)", y: y, lineH: lineH,
                   color: SKColor(red: 0.90, green: 0.78, blue: 0.30, alpha: 1))

        y -= 10

        // Section : Quêtes
        y = addSection(String(localized: "inventory.section.quests"), y: y)
        y = addQuestRow(icon: questIcon(player.questDelivery),
                        label: String(localized: "quest.delivery.name"),
                        state: player.questDelivery, y: y, lineH: lineH)
        y = addQuestRow(icon: questIcon(player.questChildToy),
                        label: String(localized: "quest.childToy.name"),
                        state: player.questChildToy, y: y, lineH: lineH)
        y = addQuestRow(icon: questIcon(player.questLyraShards),
                        label: String(localized: "quest.lyraShards.name"),
                        state: player.questLyraShards, y: y, lineH: lineH)

        // Animate
        for (i, label) in statLabels.enumerated() {
            JuiceEngine.popIn(label, delay: Double(i) * 0.03)
        }
    }

    // MARK: - Row Builders

    private func addSection(_ text: String, y: CGFloat) -> CGFloat {
        let divider = SKShapeNode(rectOf: CGSize(width: panelWidth - 48, height: 1))
        divider.fillColor = SKColor(white: 0.20, alpha: 0.6)
        divider.strokeColor = .clear
        divider.position = CGPoint(x: 0, y: y - 4)
        root.addChild(divider)
        // Reuse statLabels for cleanup
        let wrapper = SKLabelNode()
        wrapper.position = divider.position
        wrapper.addChild(divider)
        // Actually just track divider via a label trick — simpler: track as SKNode
        // Let's just use a separate approach: put divider as child of a label
        divider.removeFromParent()

        let sectionLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        sectionLabel.text = text
        sectionLabel.fontSize = 13
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

    private func addRow(icon: String, label: String, detail: String,
                        y: CGFloat, lineH: CGFloat,
                        color: SKColor = .white) -> CGFloat {
        let iconLabel = SKLabelNode(text: icon)
        iconLabel.fontSize = 16
        iconLabel.position = CGPoint(x: -panelWidth / 2 + 32, y: y - 4)
        root.addChild(iconLabel)
        statLabels.append(iconLabel)

        let nameLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
        nameLabel.text = label
        nameLabel.fontSize = 14
        nameLabel.fontColor = SKColor(white: 0.85, alpha: 1)
        nameLabel.horizontalAlignmentMode = .left
        nameLabel.position = CGPoint(x: -panelWidth / 2 + 52, y: y - 4)
        root.addChild(nameLabel)
        statLabels.append(nameLabel)

        let detailLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        detailLabel.text = detail
        detailLabel.fontSize = 14
        detailLabel.fontColor = color
        detailLabel.horizontalAlignmentMode = .right
        detailLabel.position = CGPoint(x: panelWidth / 2 - 24, y: y - 4)
        root.addChild(detailLabel)
        statLabels.append(detailLabel)

        return y - lineH
    }

    private func questIcon(_ state: QuestState) -> String {
        switch state {
        case .inactive: return "○"
        case .active:   return "◉"
        case .complete: return "✓"
        }
    }

    private func addQuestRow(icon: String, label: String,
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
        return addRow(icon: icon, label: label,
                      detail: stateLabel,
                      y: y, lineH: lineH, color: color)
    }

    // MARK: - Equipment Names

    private func weaponName(_ level: Int) -> String {
        switch level {
        case 0: return String(localized: "inventory.weapon.fists")
        case 1: return String(localized: "inventory.weapon.ironBlade")
        default: return String(localized: "inventory.weapon.runicBlade")
        }
    }

    private func armorName(_ level: Int) -> String {
        switch level {
        case 0: return String(localized: "inventory.armor.none")
        case 1: return String(localized: "inventory.armor.chainMail")
        default: return String(localized: "inventory.armor.reinforced")
        }
    }

    // MARK: - Private

    private func setupCloseButton() {
        closeButton.fillColor = SKColor(red: 0.12, green: 0.08, blue: 0.18, alpha: 1)
        closeButton.strokeColor = SKColor(red: 0.50, green: 0.35, blue: 0.75, alpha: 0.8)
        closeButton.lineWidth = 1.5

        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.text = String(localized: "inventory.close")
        label.fontSize = 14
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
