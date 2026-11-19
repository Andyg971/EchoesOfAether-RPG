import SpriteKit

@MainActor
final class InventoryOverlay {

    /// Taille du panneau, en points de scène (la largeur est un plafond :
    /// elle se réduit sur un écran plus étroit).
    ///
    /// Panneau PAYSAGE, en deux colonnes — même correction que l'écran
    /// d'options. En une colonne, les 4 sections et 11 lignes empilées
    /// donnaient 340 × 520 sur un écran de 852 × 393 : `fittingFactor`
    /// réduisait le tout à ×0,72 et les libellés tombaient à 10,7 pt, sous
    /// les 11 pt minimum recommandés. En deux colonnes la hauteur passe à
    /// 340 pt et le panneau tient sans aucune réduction.
    static let panelSize = CGSize(width: 660, height: 340)

    let root = SKNode()
    private let panel = SKShapeNode()
    private let titleLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
    private let closeButton = SKShapeNode(rectOf: CGSize(width: 100, height: 40))

    var statLabels: [SKNode] = []
    var playerState: PlayerState?
    private var completion: (() -> Void)?

    /// Renvoie true si une potion a bien été bue (fiole dispo + PV non pleins).
    var onUsePotion: (() -> Bool)?
    var potionUsable = false
    let lineH: CGFloat = 26
    /// Colonne courante pendant `buildContent` : centre et largeur.
    /// Les constructeurs de lignes s'y calent au lieu du panneau entier,
    /// ce qui rend la mise en deux colonnes transparente pour eux.
    var centreColonne: CGFloat = 0
    var largeurColonne: CGFloat = 0
    /// Bord gauche de la colonne courante.
    var bordGauche: CGFloat { centreColonne - largeurColonne / 2 }

    /// Lignes sur lesquelles A (ou un toucher) agit, de haut en bas, et la
    /// ligne sous le curseur.
    var actions: [InventoryAction] = []
    var cursor: InventoryAction?
    /// Sélecteur d'arme / d'accessoire, ouvert par-dessus l'inventaire.
    let picker = EquipmentPicker()

    /// Une potion est buvable (fiole dispo, PV non pleins).
    var canUsePotion: Bool { isActive && potionUsable }

    var panelWidth: CGFloat = 320
    var panelHeight: CGFloat = 580

    var isActive: Bool { root.parent != nil && !root.isHidden }

    func attach(to scene: SKScene) {
        root.zPosition = 1_100
        root.isHidden = true
        scene.addChild(root)

        root.addChild(panel)

        titleLabel.fontSize = 26
        titleLabel.fontColor = Palette.aether
        titleLabel.horizontalAlignmentMode = .center
        root.addChild(titleLabel)

        setupCloseButton()
        picker.attach(to: root)
        picker.onEquip = { [weak self] in self?.rebuild() }
    }

    /// `contentRange` : bande horizontale libre (en points de scène). Les
    /// boutons A/B vivent à droite, hors des marges système : le panneau
    /// s'arrête avant eux au lieu de passer dessous — le bouton B masquait la
    /// fin de la colonne des quêtes (« Non démarrée »).
    func layout(in size: CGSize, safeBottom: CGFloat = 0,
                contentRange: ClosedRange<CGFloat>? = nil) {
        let range = contentRange ?? 24...(size.width - 24)
        let scale = UIScale.fittingFactor(for: size, contentHeight: Self.panelSize.height + 12)
        panelWidth = min(Self.panelSize.width, max(300, (range.upperBound - range.lowerBound) / scale))
        panelHeight = Self.panelSize.height
        root.position = CGPoint(x: (range.lowerBound + range.upperBound) / 2,
                                y: (size.height + safeBottom) / 2)

        // Cadre pixel SNES : coins carrés, double bordure, zéro glow.
        PixelUI.stylePanel(panel, size: CGSize(width: panelWidth, height: panelHeight),
                           fill: SKColor(red: 0.04, green: 0.04, blue: 0.07, alpha: 0.97),
                           accent: SKColor(red: 0.45, green: 0.35, blue: 0.75, alpha: 1))

        titleLabel.position = CGPoint(x: 0, y: panelHeight / 2 - 36)
        closeButton.position = CGPoint(x: 0, y: -panelHeight / 2 + 34)
        picker.layout(inventorySize: CGSize(width: panelWidth, height: panelHeight))

        // Filet de sécurité : réduirait le panneau s'il ne tenait pas en
        // hauteur. Depuis le passage en deux colonnes, il tient partout et ce
        // facteur vaut 1 (root déjà centré → simple échelle).
        root.setScale(scale)
        if isActive { rebuild() }
    }

    func open(player: PlayerState, completion: @escaping () -> Void) {
        self.playerState = player
        self.completion = completion
        titleLabel.text = String(localized: "inventory.title")
        root.isHidden = false
        cursor = nil
        picker.close()
        AudioEngine.shared.playShopOpen()
        buildContent(player: player)
        AccessibilitySettings.announce(String(localized: "inventory.title"))
    }

    func handleTap(at point: CGPoint, in scene: SKScene) -> Bool {
        guard isActive else { return false }
        let local = root.convert(point, from: scene)

        if picker.isOpen {
            picker.handleTap(at: local)
            return true
        }
        if closeButton.contains(local) {
            close()
            return true
        }
        if let action = action(at: local) {
            cursor = action
            perform(action)
        }
        return true // absorb taps
    }

    /// Bouton B : ferme le sélecteur s'il est ouvert, sinon l'inventaire.
    func back() {
        if picker.isOpen {
            picker.close()
            refreshCursor()
        } else {
            close()
        }
    }

    /// Fermeture programmée de tout l'inventaire.
    func dismiss() {
        picker.close()
        close()
    }

    func rebuild() {
        if let player = playerState { buildContent(player: player) }
    }

    // MARK: - Build Content

    private func buildContent(player: PlayerState) {
        statLabels.forEach { $0.removeFromParent() }
        statLabels.removeAll()

        let startY = panelHeight / 2 - 60
        largeurColonne = panelWidth / 2 - 20

        // ── Colonne gauche : ce qu'on porte et ce qu'on consomme ─────────
        centreColonne = -panelWidth / 4
        var y = startY
        var rowY: [InventoryAction: CGFloat] = [:]

        y = addSection(String(localized: "inventory.section.equipment"), y: y)
        rowY[.weapon] = y
        y = addWeaponRow(player: player, y: y)
        y = addRow(icon: .shield, label: armorName(player.armorLevel),
                   detail: String(localized: "inventory.defense \(player.armorLevel * PlayerState.armorHPPerLevel)"),
                   y: y, lineH: lineH)
        rowY[.accessory] = y
        y = addAccessoryRow(player: player, y: y)

        y -= 6 // spacer

        y = addSection(String(localized: "inventory.section.items"), y: y)
        potionUsable = player.potions > 0 && player.currentHP < player.currentMaxHP
        rowY[.potion] = y
        y = addRow(icon: .potion, label: String(localized: "inventory.potions"),
                   detail: String(localized: "inventory.potionCount \(player.potions)"), y: y, lineH: lineH)
        y = addRow(icon: .gem, label: String(localized: "inventory.shards"),
                   detail: "\(player.aetherShards)", y: y, lineH: lineH)
        y = addRow(icon: .coin, label: String(localized: "inventory.gold"),
                   detail: "\(player.gold)", y: y, lineH: lineH,
                   color: SKColor(red: 0.90, green: 0.78, blue: 0.30, alpha: 1))

        installActions(player: player, rowY: rowY)

        // ── Colonne droite : ce qu'on vaut et ce qu'on doit ──────────────
        centreColonne = panelWidth / 4
        y = startY

        y = addSection(String(localized: "inventory.section.stats"), y: y)
        y = addRow(icon: .heart, label: String(localized: "inventory.maxHP"),
                   detail: "\(player.currentMaxHP)", y: y, lineH: lineH)
        y = addRow(icon: .bolt, label: String(localized: "inventory.attackDmg"),
                   detail: "\(player.attackDamage)", y: y, lineH: lineH)
        y = addRow(icon: .darkMoon, label: String(localized: "inventory.blackSlashDmg"),
                   detail: "\(player.blackSlashDamage)", y: y, lineH: lineH)

        y -= 6

        y = addSection(String(localized: "inventory.section.quests"), y: y)
        y = addQuestRow(label: String(localized: "quest.delivery.name"),
                        state: player.questDelivery, y: y, lineH: lineH)
        y = addQuestRow(label: String(localized: "quest.childToy.name"),
                        state: player.questChildToy, y: y, lineH: lineH)
        y = addQuestRow(label: String(localized: "quest.lyraShards.name"),
                        state: player.questLyraShards, y: y, lineH: lineH)

        // Animate
        for (i, label) in statLabels.enumerated() {
            JuiceEngine.popIn(label, delay: Double(i) * 0.02)
        }
    }

    /// Arme de Kael (il se bat aux poings) : nom, puis le style (couleur du
    /// style) à droite — les dégâts sont dans la colonne des statistiques.
    private func addWeaponRow(player: PlayerState, y: CGFloat) -> CGFloat {
        guard let weapon = player.equippedWeapon else {
            return addRow(icon: .fist, label: String(localized: "inventory.weapon.fists"),
                          detail: "", y: y, lineH: lineH)
        }
        return addRow(icon: .weapon(weapon.style), label: String(localized: weapon.nameKey),
                      detail: String(localized: weapon.style.nameKey), y: y, lineH: lineH,
                      color: EquipmentText.color(for: weapon.style))
    }

    private func addAccessoryRow(player: PlayerState, y: CGFloat) -> CGFloat {
        guard let accessory = player.equippedAccessoryItem else {
            return addRow(icon: .gem, label: String(localized: "inventory.accessory.none"),
                          detail: "", y: y, lineH: lineH)
        }
        return addRow(icon: .accessory(id: accessory.id), label: String(localized: accessory.nameKey),
                      detail: EquipmentText.summary(accessory.bonus), y: y, lineH: lineH,
                      color: SKColor(white: 0.70, alpha: 1))
    }

    /// Toast vert bref au centre haut du panneau (soin, équipement).
    func showToast(_ text: String) {
        root.childNode(withName: "inventoryToast")?.removeFromParent()
        let toast = SKLabelNode(fontNamed: PixelUI.uiFont)
        toast.name = "inventoryToast"
        toast.text = text
        toast.fontSize = 20
        toast.fontColor = EquipmentText.gain
        toast.verticalAlignmentMode = .center
        toast.horizontalAlignmentMode = .center
        toast.position = CGPoint(x: 0, y: panelHeight / 2 - 68)
        toast.zPosition = 80
        toast.setScale(0.6)
        toast.alpha = 0
        root.addChild(toast)
        toast.run(.sequence([
            .group([.fadeIn(withDuration: 0.12), .scale(to: 1.0, duration: 0.16)]),
            .wait(forDuration: 0.7),
            .group([.fadeOut(withDuration: 0.3), .moveBy(x: 0, y: 12, duration: 0.3)]),
            .removeFromParent()
        ]))
    }

    // MARK: - Private

    private func setupCloseButton() {
        closeButton.fillColor = Palette.shadowWarm
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
        // Vider AVANT d'appeler : si la completion rouvre un overlay qui
        // stocke sa propre completion, l'ordre inverse l'écraserait.
        let done = completion
        completion = nil
        done?()
    }
}
