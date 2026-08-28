import SpriteKit

/// ARBRE DE L'AETHER — écran d'investissement des points de compétence.
/// Trois colonnes (une par voie), quatre nœuds chacune, tout en pixel art :
/// cadres SNES `PixelUI`, icônes `PixelIcons` dessinées en grille, rangs
/// affichés en carrés pleins/vides. Aucun emoji, aucun glow.
@MainActor
final class SkillTreeOverlay {

    private let root = SKNode()
    private weak var player: PlayerState?
    private var sceneSize: CGSize = .zero
    private var ready = false
    /// Refonte : premier tap arme la confirmation, second la valide.
    private var respecArmed = false

    /// Fermeture demandée — le GameManager en profite pour rafraîchir le HUD
    /// (les PV/MP max ont pu changer).
    var onClose: (() -> Void)?
    /// Refonte confirmée : au GameManager de débiter l'or et d'appeler
    /// `respecSkills()`. Retourne true si la dépense a été acceptée.
    var onRespec: (() -> Bool)?

    var isActive: Bool { root.parent != nil && !root.isHidden }

    private static let branchAccents: [SkillBranch: SKColor] = [
        .blade:  SKColor(red: 0.88, green: 0.38, blue: 0.32, alpha: 1),
        .aether: SKColor(red: 0.72, green: 0.45, blue: 1.00, alpha: 1),
        .breath: SKColor(red: 0.42, green: 0.82, blue: 0.56, alpha: 1)
    ]

    private static func icon(for node: SkillNode) -> PixelIcons.Kind {
        if node.isCapstone { return .darkMoon }
        switch node.branch {
        case .blade:  return .sword
        case .aether: return .gem
        case .breath: return .heart
        }
    }

    func attach(to scene: SKScene) {
        root.zPosition = 1_600
        root.isHidden = true
        scene.addChild(root)
    }

    func show(player: PlayerState, in scene: SKScene) {
        self.player = player
        self.sceneSize = scene.size
        respecArmed = false
        selection = 0
        root.isHidden = false
        ready = false
        rebuild()
        // Le pied de page ne doit pas s'ouvrir vide : on décrit d'emblée le
        // nœud sous le curseur.
        let first = SkillTree.allNodes[selection]
        setDetail("\(first.title) — \(first.detail)", color: SKColor(white: 0.80, alpha: 1))
        root.run(.sequence([
            .wait(forDuration: 0.18),
            .run { [weak self] in self?.ready = true }
        ]))
        AccessibilitySettings.announce(
            "\(String(localized: "skill.title")). "
            + String(localized: "skill.points \(player.skillPointsAvailable)"))
    }

    func dismiss() {
        guard isActive else { return }
        root.isHidden = true
        root.removeAllChildren()
        ready = false
        onClose?()
    }

    // MARK: - Construction

    private func rebuild() {
        guard let player else { return }
        root.removeAllChildren()
        let w = sceneSize.width, h = sceneSize.height

        // Le voile déborde largement : la scène est plus étroite que l'écran
        // réel (aspect fill), donc un scrim à `scene.size` laisse le village
        // visible sur les côtés — c'est ce qui arrive au menu pause.
        let scrim = SKShapeNode(rectOf: CGSize(width: w * 3, height: h * 3))
        scrim.fillColor = SKColor(red: 0.02, green: 0.01, blue: 0.05, alpha: 0.93)
        scrim.strokeColor = .clear
        scrim.position = CGPoint(x: w / 2, y: h / 2)
        root.addChild(scrim)

        let title = SKLabelNode(fontNamed: PixelUI.uiFont)
        title.text = String(localized: "skill.title")
        title.fontSize = 26
        title.fontColor = Palette.aether
        title.horizontalAlignmentMode = .center
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: w / 2, y: h - 30)
        root.addChild(title)

        let points = SKLabelNode(fontNamed: PixelUI.uiFont)
        points.text = String(localized: "skill.points \(player.skillPointsAvailable)")
        points.fontSize = 19
        points.fontColor = player.skillPointsAvailable > 0 ? PixelUI.gold
                                                           : SKColor(white: 0.55, alpha: 1)
        points.horizontalAlignmentMode = .center
        points.verticalAlignmentMode = .center
        points.position = CGPoint(x: w / 2, y: h - 56)
        root.addChild(points)

        // Trois colonnes réparties sur la largeur (jeu en paysage). Marge
        // large : les boutons A/B du HUD vivent au-dessus de l'overlay et
        // mordraient sur la colonne de droite.
        let colW = min(196, (w - 120) / 3)
        let startX = w / 2 - colW
        for (i, branch) in SkillBranch.allCases.enumerated() {
            buildColumn(branch, player: player,
                        centerX: startX + CGFloat(i) * colW,
                        topY: h - 88, width: colW - 12)
        }

        buildFooter(player: player, width: w)
        UIScale.apply(to: root, sceneSize: sceneSize)
        refreshSelectionHighlight()
    }

    private func buildColumn(_ branch: SkillBranch, player: PlayerState,
                             centerX: CGFloat, topY: CGFloat, width: CGFloat) {
        let accent = Self.branchAccents[branch] ?? PixelUI.gold

        let header = SKLabelNode(fontNamed: PixelUI.uiFont)
        header.text = branch.title.uppercased()
        header.fontSize = 19
        header.fontColor = accent
        header.horizontalAlignmentMode = .center
        header.verticalAlignmentMode = .center
        header.position = CGPoint(x: centerX, y: topY)
        root.addChild(header)

        let spent = SKLabelNode(fontNamed: PixelUI.uiFont)
        spent.text = String(localized: "skill.branch.spent \(player.skillPointsSpent(in: branch))")
        spent.fontSize = 14
        spent.fontColor = SKColor(white: 0.50, alpha: 1)
        spent.horizontalAlignmentMode = .center
        spent.verticalAlignmentMode = .center
        spent.position = CGPoint(x: centerX, y: topY - 18)
        root.addChild(spent)

        for (i, node) in SkillTree.nodes(in: branch).enumerated() {
            let cell = makeCell(node, player: player, width: width, accent: accent)
            cell.position = CGPoint(x: centerX, y: topY - 52 - CGFloat(i) * 46)
            root.addChild(cell)
        }
    }

    /// Une case de nœud : cadre pixel, icône en grille, titre, pastilles de rang.
    private func makeCell(_ node: SkillNode, player: PlayerState,
                          width: CGFloat, accent: SKColor) -> SKShapeNode {
        let rank = player.skillRank(node.id)
        let lock = player.skillLock(for: node)
        let owned = rank > 0
        let locked = lock != nil && lock != .maxed

        let cell = SKShapeNode()
        PixelUI.stylePanel(cell, size: CGSize(width: width, height: 40),
                           fill: owned ? SKColor(red: 0.10, green: 0.09, blue: 0.16, alpha: 0.97)
                                       : SKColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 0.95),
                           accent: locked ? SKColor(white: 0.28, alpha: 1)
                                          : (owned ? accent : accent.withAlphaComponent(0.55)))
        cell.name = "skillNode:\(node.id)"

        let icon = PixelIcons.node(Self.icon(for: node), pixel: 1.6)
        icon.position = CGPoint(x: -width / 2 + 16, y: 4)
        icon.alpha = locked ? 0.35 : 1
        cell.addChild(icon)

        let label = SKLabelNode(fontNamed: PixelUI.uiFont)
        label.text = node.title
        label.fontSize = 16
        label.fontColor = locked ? SKColor(white: 0.45, alpha: 1) : .white
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: -width / 2 + 30, y: 6)
        label.preferredMaxLayoutWidth = width - 40
        cell.addChild(label)

        // Pastilles de rang : carrés pixel pleins (acquis) ou creux (restants).
        let pip: CGFloat = 6, gap: CGFloat = 3
        for r in 0..<node.maxRank {
            let filled = r < rank
            let dot = SKShapeNode(rect: CGRect(x: 0, y: 0, width: pip, height: pip))
            dot.fillColor = filled ? accent : .clear
            dot.strokeColor = filled ? accent : SKColor(white: 0.35, alpha: 1)
            dot.lineWidth = 1
            dot.glowWidth = 0
            dot.position = CGPoint(x: -width / 2 + 30 + CGFloat(r) * (pip + gap),
                                   y: -14)
            cell.addChild(dot)
        }

        let cost = SKLabelNode(fontNamed: PixelUI.uiFont)
        cost.text = rank >= node.maxRank ? String(localized: "skill.cell.maxed")
                                         : String(localized: "skill.cell.cost \(node.costPerRank)")
        cost.fontSize = 13
        cost.fontColor = rank >= node.maxRank ? PixelUI.gold : SKColor(white: 0.55, alpha: 1)
        cost.horizontalAlignmentMode = .right
        cost.verticalAlignmentMode = .center
        cost.position = CGPoint(x: width / 2 - 8, y: -13)
        cell.addChild(cost)
        return cell
    }

    private func buildFooter(player: PlayerState, width w: CGFloat) {
        let detail = SKLabelNode(fontNamed: PixelUI.uiFont)
        detail.name = "skillDetail"
        detail.fontSize = 16
        detail.fontColor = SKColor(white: 0.80, alpha: 1)
        detail.horizontalAlignmentMode = .center
        detail.verticalAlignmentMode = .center
        detail.position = CGPoint(x: w / 2, y: 52)
        root.addChild(detail)

        let cost = SkillTree.respecCost(level: player.level)
        let respec = PixelUI.makeButton(
            respecArmed ? String(localized: "skill.respec.confirm \(cost)")
                        : String(localized: "skill.respec"),
            size: CGSize(width: 168, height: 34),
            fill: SKColor(red: 0.14, green: 0.07, blue: 0.05, alpha: 1),
            accent: respecArmed ? PixelUI.gold
                                : SKColor(red: 0.60, green: 0.34, blue: 0.22, alpha: 0.9),
            fontSize: 15, name: "skillRespec")
        respec.position = CGPoint(x: w / 2 - 92, y: 22)
        root.addChild(respec)

        let close = PixelUI.makeButton(String(localized: "skill.close"),
            size: CGSize(width: 128, height: 34),
            fill: SKColor(red: 0.08, green: 0.08, blue: 0.14, alpha: 1),
            accent: Palette.panelBorder,
            fontSize: 15, name: "skillClose")
        close.position = CGPoint(x: w / 2 + 92, y: 22)
        root.addChild(close)
    }

    // MARK: - Interaction

    func handleTap(at point: CGPoint, in scene: SKScene) -> Bool {
        guard isActive, ready else { return isActive }
        let local = root.convert(point, from: scene)

        if let btn = root.childNode(withName: "skillClose") as? SKShapeNode,
           btn.contains(local) {
            AudioEngine.shared.playTap()
            dismiss()
            return true
        }
        if let btn = root.childNode(withName: "skillRespec") as? SKShapeNode,
           btn.contains(local) {
            handleRespecTap()
            return true
        }
        for node in SkillTree.allNodes {
            guard let cell = root.childNode(withName: "skillNode:\(node.id)") as? SKShapeNode,
                  cell.contains(local) else { continue }
            invest(node)
            return true
        }
        return true
    }

    /// Investit un rang, ou explique pourquoi c'est impossible.
    private func invest(_ node: SkillNode) {
        guard let player else { return }
        if let lock = player.skillLock(for: node) {
            setDetail(lock.message, color: SKColor(red: 0.90, green: 0.45, blue: 0.40, alpha: 1))
            AudioEngine.shared.playTap()
            HapticsEngine.error()
            AccessibilitySettings.announce(lock.message)
            return
        }
        player.unlockSkill(node)
        respecArmed = false
        rebuild()
        setDetail("\(node.title) — \(node.detail)", color: PixelUI.gold)
        AudioEngine.shared.playSelect()
        HapticsEngine.success()
        AccessibilitySettings.announce(
            "\(node.title). \(node.detail). "
            + String(localized: "skill.points \(player.skillPointsAvailable)"))
    }

    /// Deux temps : le premier tap arme (destructif), le second exécute.
    private func handleRespecTap() {
        guard let player else { return }
        guard player.skillPointsSpent > 0 else {
            setDetail(String(localized: "skill.respec.empty"),
                      color: SKColor(white: 0.65, alpha: 1))
            HapticsEngine.error()
            return
        }
        if !respecArmed {
            respecArmed = true
            rebuild()
            let cost = SkillTree.respecCost(level: player.level)
            setDetail(String(localized: "skill.respec.warning \(cost)"),
                      color: SKColor(red: 0.95, green: 0.65, blue: 0.30, alpha: 1))
            AudioEngine.shared.playTap()
            HapticsEngine.light()
            return
        }
        respecArmed = false
        guard onRespec?() == true else {
            rebuild()
            setDetail(String(localized: "skill.respec.noGold"),
                      color: SKColor(red: 0.90, green: 0.45, blue: 0.40, alpha: 1))
            HapticsEngine.error()
            return
        }
        rebuild()
        setDetail(String(localized: "skill.respec.done"), color: PixelUI.gold)
        AudioEngine.shared.playSelect()
        HapticsEngine.success()
        AccessibilitySettings.announce(String(localized: "skill.respec.done"))
    }

    private func setDetail(_ text: String, color: SKColor) {
        guard let label = root.childNode(withName: "skillDetail") as? SKLabelNode else { return }
        label.text = text
        label.fontColor = color
    }

    // MARK: - Curseur (contrôles classiques)

    private var selection = 0

    /// Joystick : dx change de voie, dy monte/descend dans la voie.
    func moveSelection(dx: Int, dy: Int) {
        guard isActive, ready else { return }
        let perColumn = 4
        var col = selection / perColumn, row = selection % perColumn
        col = (col + dx + SkillBranch.allCases.count) % SkillBranch.allCases.count
        row = (row - dy + perColumn) % perColumn
        selection = col * perColumn + row
        HapticsEngine.light()
        AudioEngine.shared.playStep()
        refreshSelectionHighlight()
        let node = SkillTree.allNodes[selection]
        setDetail("\(node.title) — \(node.detail)", color: SKColor(white: 0.80, alpha: 1))
        AccessibilitySettings.announce("\(node.title). \(node.detail)")
    }

    /// Bouton A : investit sur le nœud sous le curseur.
    func confirmSelection() {
        guard isActive, ready else { return }
        invest(SkillTree.allNodes[selection])
    }

    private func refreshSelectionHighlight() {
        for (i, node) in SkillTree.allNodes.enumerated() {
            guard let cell = root.childNode(withName: "skillNode:\(node.id)") as? SKShapeNode
            else { continue }
            let selected = i == selection
            cell.lineWidth = selected ? 3 : 2
            cell.setScale(selected ? 1.03 : 1.0)
        }
    }
}
