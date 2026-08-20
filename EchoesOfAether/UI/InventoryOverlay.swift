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

    private let root = SKNode()
    private let panel = SKShapeNode()
    private let titleLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
    private let closeButton = SKShapeNode(rectOf: CGSize(width: 100, height: 40))

    private var statLabels: [SKNode] = []
    private var playerState: PlayerState?
    private var completion: (() -> Void)?

    /// Renvoie true si une potion a bien été bue (fiole dispo + PV non pleins).
    var onUsePotion: (() -> Bool)?
    private var potionUsable = false
    private let lineH: CGFloat = 26
    /// Colonne courante pendant `buildContent` : centre et largeur.
    /// Les constructeurs de lignes s'y calent au lieu du panneau entier,
    /// ce qui rend la mise en deux colonnes transparente pour eux.
    private var centreColonne: CGFloat = 0
    private var largeurColonne: CGFloat = 0
    /// Bord gauche de la colonne courante.
    private var bordGauche: CGFloat { centreColonne - largeurColonne / 2 }

    /// Le bouton A n'apparaît en inventaire que s'il y a une potion à boire.
    var canUsePotion: Bool { isActive && potionUsable }

    private var panelWidth: CGFloat = 320
    private var panelHeight: CGFloat = 580

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
    }

    func layout(in size: CGSize, safeBottom: CGFloat = 0) {
        panelWidth = min(Self.panelSize.width, max(300, size.width - 48))
        panelHeight = Self.panelSize.height
        root.position = CGPoint(x: size.width / 2, y: (size.height + safeBottom) / 2)

        // Cadre pixel SNES : coins carrés, double bordure, zéro glow.
        PixelUI.stylePanel(panel, size: CGSize(width: panelWidth, height: panelHeight),
                           fill: SKColor(red: 0.04, green: 0.04, blue: 0.07, alpha: 0.97),
                           accent: SKColor(red: 0.45, green: 0.35, blue: 0.75, alpha: 1))

        titleLabel.position = CGPoint(x: 0, y: panelHeight / 2 - 36)
        closeButton.position = CGPoint(x: 0, y: -panelHeight / 2 + 34)

        // Filet de sécurité : réduirait le panneau s'il ne tenait pas en
        // hauteur. Depuis le passage en deux colonnes, il tient partout et ce
        // facteur vaut 1 (root déjà centré → simple échelle).
        root.setScale(UIScale.fittingFactor(for: size, contentHeight: panelHeight + 12))
    }

    func open(player: PlayerState, completion: @escaping () -> Void) {
        self.playerState = player
        self.completion = completion
        titleLabel.text = String(localized: "inventory.title")
        root.isHidden = false
        AudioEngine.shared.playShopOpen()
        buildContent(player: player)
        AccessibilitySettings.announce(String(localized: "inventory.title"))
    }

    func handleTap(at point: CGPoint, in scene: SKScene) -> Bool {
        guard isActive else { return false }
        let local = root.convert(point, from: scene)

        if closeButton.contains(local) {
            close()
            return true
        }
        if let hit = root.childNode(withName: "potionUse") as? SKShapeNode,
           hit.contains(local) {
            useSelectedPotion()
            return true
        }

        return true // absorb taps
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

        y = addSection(String(localized: "inventory.section.equipment"), y: y)
        y = addRow(icon: .sword, label: weaponName(player.weaponLevel),
                   detail: String(localized: "inventory.attack \(player.attackDamage)"), y: y, lineH: lineH)
        y = addRow(icon: .shield, label: armorName(player.armorLevel),
                   detail: String(localized: "inventory.defense \(player.armorLevel * 50)"), y: y, lineH: lineH)

        y -= 6 // spacer

        y = addSection(String(localized: "inventory.section.items"), y: y)
        // La ligne « Potions » est actionnable : bouton A ou toucher = en boire.
        potionUsable = player.potions > 0 && player.currentHP < player.currentMaxHP
        let potionRowY = y
        y = addRow(icon: .potion, label: String(localized: "inventory.potions"),
                   detail: "\(player.potions)/3", y: y, lineH: lineH)
        addPotionAction(at: potionRowY)
        y = addRow(icon: .gem, label: String(localized: "inventory.shards"),
                   detail: "\(player.aetherShards)", y: y, lineH: lineH)

        y -= 6

        y = addRow(icon: .coin, label: String(localized: "inventory.gold"),
                   detail: "\(player.gold)", y: y, lineH: lineH,
                   color: SKColor(red: 0.90, green: 0.78, blue: 0.30, alpha: 1))

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
            JuiceEngine.popIn(label, delay: Double(i) * 0.03)
        }
    }

    /// Zone tactile sur la ligne des potions + indice « A · Boire » quand
    /// une fiole est disponible et que les PV ne sont pas pleins.
    private func addPotionAction(at rowY: CGFloat) {
        // Rien de tappable si aucune fiole ou PV déjà pleins : la ligne reste
        // une simple stat (pas de buzz d'erreur sur un tap anodin).
        guard potionUsable else { return }

        let hit = SKShapeNode(rectOf: CGSize(width: largeurColonne - 32, height: lineH))
        hit.fillColor = .clear
        hit.strokeColor = .clear
        hit.name = "potionUse"
        hit.position = CGPoint(x: centreColonne, y: rowY - 2)
        root.addChild(hit)
        statLabels.append(hit)

        // Léger surlignage doré de la ligne buvable.
        let glow = SKShapeNode(rectOf: CGSize(width: largeurColonne - 36, height: lineH))
        glow.fillColor = PixelUI.gold.withAlphaComponent(0.10)
        glow.strokeColor = PixelUI.goldDim
        glow.lineWidth = 1
        glow.glowWidth = 0
        glow.position = CGPoint(x: 0, y: rowY - 2)
        glow.zPosition = -0.5
        root.addChild(glow)
        statLabels.append(glow)

        let hint = SKLabelNode(fontNamed: PixelUI.uiFont)
        hint.text = String(localized: "inventory.potionHint")
        hint.fontSize = 13
        hint.fontColor = PixelUI.gold
        hint.horizontalAlignmentMode = .center
        hint.verticalAlignmentMode = .center
        hint.position = CGPoint(x: 0, y: -panelHeight / 2 + 62)
        root.addChild(hint)
        statLabels.append(hint)
    }

    /// Bouton A / toucher la ligne : boit une potion. Erreur haptique si
    /// impossible (aucune fiole ou PV déjà pleins).
    func useSelectedPotion() {
        // A n'est visible et la ligne n'est tappable que si buvable : un échec
        // ici (PV redevenus pleins entre-temps) reste silencieux.
        guard potionUsable, onUsePotion?() == true else { return }
        HapticsEngine.success()
        showHealToast()
        if let player = playerState { buildContent(player: player) }
    }

    private func showHealToast() {
        root.childNode(withName: "healToast")?.removeFromParent()
        let toast = SKLabelNode(fontNamed: PixelUI.uiFont)
        toast.name = "healToast"
        toast.text = String(localized: "inventory.healed")
        toast.fontSize = 20
        toast.fontColor = SKColor(red: 0.55, green: 0.92, blue: 0.58, alpha: 1)
        toast.verticalAlignmentMode = .center
        toast.horizontalAlignmentMode = .center
        toast.position = CGPoint(x: 0, y: panelHeight / 2 - 68)
        toast.zPosition = 30
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

    // MARK: - Row Builders

    private func addSection(_ text: String, y: CGFloat) -> CGFloat {
        let sectionLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
        sectionLabel.text = text
        sectionLabel.fontSize = 17
        sectionLabel.fontColor = SKColor(red: 0.60, green: 0.50, blue: 0.85, alpha: 0.8)
        sectionLabel.horizontalAlignmentMode = .left
        sectionLabel.position = CGPoint(x: bordGauche + 24, y: y - 6)
        root.addChild(sectionLabel)
        statLabels.append(sectionLabel)

        // Filet sous le titre de section. Il est enfant du label, donc en
        // coordonnées LOCALES : l'ancien `y - 18` y réinjectait une valeur du
        // repère du panneau, ce qui envoyait le filet à `2y - 24` — hors du
        // panneau pour toute section un peu haute, donc invisible. Le décalage
        // voulu était simplement 18 pt sous la ligne de base.
        let div = SKShapeNode(rectOf: CGSize(width: largeurColonne - 40, height: 1))
        div.fillColor = SKColor(white: 0.18, alpha: 0.5)
        div.strokeColor = .clear
        div.position = CGPoint(x: largeurColonne / 2 - 24, y: -12)
        sectionLabel.addChild(div)

        return y - 28
    }

    private func addRow(icon: PixelIcons.Kind, label: String, detail: String,
                        y: CGFloat, lineH: CGFloat,
                        color: SKColor = .white) -> CGFloat {
        let iconNode = PixelIcons.node(icon, pixel: 2)
        iconNode.position = CGPoint(x: bordGauche + 32, y: y + 2)
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
        nameLabel.position = CGPoint(x: bordGauche + 52, y: y - 4)
        root.addChild(nameLabel)
        statLabels.append(nameLabel)

        let detailLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
        detailLabel.text = detail
        detailLabel.fontSize = 18
        detailLabel.fontColor = color
        detailLabel.horizontalAlignmentMode = .right
        detailLabel.position = CGPoint(x: bordGauche + largeurColonne - 24, y: y - 4)
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
        // Objet en poche, donneur pas encore prévenu : ambre, entre le jaune
        // « en cours » et le vert « terminée ».
        case .found:    color = SKColor(red: 0.95, green: 0.60, blue: 0.25, alpha: 1)
        case .complete: color = SKColor(red: 0.40, green: 0.80, blue: 0.45, alpha: 1)
        }
        let stateLabel: String
        switch state {
        case .inactive: stateLabel = String(localized: "quest.state.inactive")
        case .active:   stateLabel = String(localized: "quest.state.active")
        case .found:    stateLabel = String(localized: "quest.state.found")
        case .complete: stateLabel = String(localized: "quest.state.complete")
        }
        // Puce d'état pixel : carré plein coloré selon l'état (cohérent
        // avec le journal de quêtes).
        let chip = SKSpriteNode(color: color, size: CGSize(width: 8, height: 8))
        chip.position = CGPoint(x: bordGauche + 32, y: y + 2)
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

    /// Bouton B : fermeture programmée (contrôles classiques).
    func dismiss() { close() }

    private func close() {
        root.isHidden = true
        // Vider AVANT d'appeler : si la completion rouvre un overlay qui
        // stocke sa propre completion, l'ordre inverse l'écraserait.
        let done = completion
        completion = nil
        done?()
    }
}
