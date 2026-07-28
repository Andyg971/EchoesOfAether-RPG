import SpriteKit

/// Une entrée du journal (titre + description + état).
struct QuestEntry {
    let title: String
    let desc: String
    let state: QuestState   // .active ou .complete (les .inactive ne s'affichent pas)
    /// Vignette pixel art par type de quête (colis, gemme, potion…).
    var icon: PixelIcons.Kind = .bag
}

/// Journal des quêtes — overlay pixel art listant les quêtes en cours
/// et terminées. Ouvert depuis le HUD, fermé au tap du bouton.
@MainActor
final class QuestLogOverlay {
    private let root = SKNode()
    private var nodes: [SKNode] = []
    private var panelWidth: CGFloat = 320
    private var panelHeight: CGFloat = 460
    private var entries: [QuestEntry] = []
    private var page = 0        // pagination (feuilletée au joystick haut/bas)

    var onClose: (() -> Void)?
    var isActive: Bool { root.parent != nil && !root.isHidden }

    func attach(to scene: SKScene) {
        root.zPosition = 1_700
        root.isHidden = true
        scene.addChild(root)
    }

    func layout(in size: CGSize) {
        panelWidth = min(360, max(300, size.width - 36))
        panelHeight = min(500, max(420, size.height - 104))
        root.position = CGPoint(x: size.width / 2, y: size.height / 2)
        // iPad : agrandit. iPhone paysage : réduit pour tenir en hauteur.
        root.setScale(UIScale.fittingFactor(for: size, contentHeight: panelHeight + 12))
    }

    func open(entries: [QuestEntry], completion: @escaping () -> Void) {
        onClose = completion
        self.entries = entries
        page = 0
        root.isHidden = false
        buildContent()
        AudioEngine.shared.playShopOpen()
        AccessibilitySettings.announce(String(localized: "questlog.title"))
    }

    /// Joystick haut/bas : feuillette les pages de quêtes.
    func scroll(_ dy: Int) {
        guard isActive, dy != 0 else { return }
        page = max(0, page - dy)
        HapticsEngine.light()
        AudioEngine.shared.playStep()
        buildContent()
    }

    func handleTap(at point: CGPoint, in scene: SKScene) -> Bool {
        guard isActive else { return false }
        let local = root.convert(point, from: scene)
        if let btn = root.childNode(withName: "questClose") as? SKShapeNode,
           btn.contains(local) {
            close()
            return true
        }
        return true   // capture tous les taps tant que l'overlay est ouvert
    }

    // MARK: - Build

    private func buildContent() {
        nodes.forEach { $0.removeFromParent() }
        nodes.removeAll()

        let panel = SKShapeNode()
        PixelUI.stylePanel(panel, size: CGSize(width: panelWidth, height: panelHeight))
        root.addChild(panel)
        nodes.append(panel)

        let title = label(String(localized: "questlog.title"), size: 22, color: PixelUI.gold)
        title.position = CGPoint(x: 0, y: panelHeight / 2 - 34)
        root.addChild(title)
        nodes.append(title)

        if entries.isEmpty {
            let empty = label(String(localized: "questlog.empty"), size: 15,
                              color: SKColor(white: 0.5, alpha: 1))
            empty.numberOfLines = 2
            empty.preferredMaxLayoutWidth = panelWidth - 60
            empty.position = CGPoint(x: 0, y: 20)
            root.addChild(empty)
            nodes.append(empty)
        } else {
            let top = panelHeight / 2 - 70
            let rowH: CGFloat = 64
            let perPage = max(1, Int((top - (-panelHeight / 2 + 68)) / rowH))
            let pages = max(1, Int(ceil(Double(entries.count) / Double(perPage))))
            page = min(page, pages - 1)
            let start = page * perPage
            let slice = Array(entries[start ..< min(entries.count, start + perPage)])
            var y = top
            for entry in slice {
                let done = entry.state == .complete
                // Vignette pixel art du type de quête (grisée une fois rendue).
                let icon = PixelIcons.node(entry.icon, pixel: 2)
                icon.position = CGPoint(x: -panelWidth / 2 + 24, y: y + 2)
                if done {
                    icon.forEachDescendantSprite { $0.color = SKColor(white: 0.42, alpha: 1) }
                }
                root.addChild(icon)
                nodes.append(icon)

                // Puce d'état pixel (petit carré coloré) à côté de la vignette.
                let bullet = SKSpriteNode(
                    color: done ? SKColor(red: 0.45, green: 0.85, blue: 0.50, alpha: 1)
                                : SKColor(red: 1.0, green: 0.82, blue: 0.28, alpha: 1),
                    size: CGSize(width: 5, height: 5))
                bullet.position = CGPoint(x: -panelWidth / 2 + 40, y: y + 6)
                root.addChild(bullet)
                nodes.append(bullet)

                let titleL = label(entry.title, size: 16,
                                   color: done ? SKColor(white: 0.55, alpha: 1) : .white)
                titleL.horizontalAlignmentMode = .left
                titleL.position = CGPoint(x: -panelWidth / 2 + 50, y: y)
                root.addChild(titleL)
                nodes.append(titleL)

                let stateL = label(done ? String(localized: "questlog.state.complete")
                                        : String(localized: "questlog.state.active"),
                                   size: 12,
                                   color: done ? SKColor(red: 0.45, green: 0.85, blue: 0.50, alpha: 1)
                                               : SKColor(red: 1.0, green: 0.82, blue: 0.28, alpha: 1))
                stateL.horizontalAlignmentMode = .right
                stateL.position = CGPoint(x: panelWidth / 2 - 22, y: y)
                root.addChild(stateL)
                nodes.append(stateL)

                let bodyL = label(entry.desc, size: 13, color: SKColor(white: 0.62, alpha: 1))
                bodyL.horizontalAlignmentMode = .left
                bodyL.numberOfLines = 2
                bodyL.preferredMaxLayoutWidth = panelWidth - 68
                bodyL.position = CGPoint(x: -panelWidth / 2 + 50, y: y - 20)
                root.addChild(bodyL)
                nodes.append(bodyL)

                let div = SKSpriteNode(color: PixelUI.goldDim,
                                       size: CGSize(width: panelWidth - 44, height: 1))
                div.position = CGPoint(x: 0, y: y - 42)
                root.addChild(div)
                nodes.append(div)

                y -= rowH
            }
            addPager(pages: pages)
        }

        let closeBtn = SKShapeNode()
        PixelUI.stylePanel(closeBtn, size: CGSize(width: 120, height: 36),
                           fill: Palette.shadowWarm,
                           accent: PixelUI.gold)
        closeBtn.name = "questClose"
        closeBtn.position = CGPoint(x: 0, y: -panelHeight / 2 + 26)
        let closeLbl = label(String(localized: "questlog.close"), size: 15, color: .white)
        closeLbl.verticalAlignmentMode = .center
        closeBtn.addChild(closeLbl)
        root.addChild(closeBtn)
        nodes.append(closeBtn)

        for (i, node) in nodes.enumerated() {
            JuiceEngine.popIn(node, delay: Double(i) * 0.02)
        }
    }

    /// Bouton B : fermeture programmée (contrôles classiques).
    func dismiss() { close() }

    private func close() {
        root.isHidden = true
        nodes.forEach { $0.removeFromParent() }
        nodes.removeAll()
        onClose?()
        onClose = nil
    }

    /// Indicateur « ▲ page X/Y ▼ » au-dessus du bouton fermer, si >1 page.
    private func addPager(pages: Int) {
        guard pages > 1 else { return }
        let arrows = (page > 0 ? "▲ " : "  ")
            + String(localized: "lore.pager \(page + 1) \(pages)")
            + (page < pages - 1 ? " ▼" : "  ")
        let l = label(arrows, size: 13, color: PixelUI.gold)
        l.position = CGPoint(x: 0, y: -panelHeight / 2 + 56)
        root.addChild(l)
        nodes.append(l)
    }

    private func label(_ text: String, size: CGFloat, color: SKColor) -> SKLabelNode {
        let l = SKLabelNode(fontNamed: PixelUI.uiFont)
        l.text = text
        l.fontSize = size
        l.fontColor = color
        l.horizontalAlignmentMode = .center
        l.verticalAlignmentMode = .baseline
        return l
    }
}
