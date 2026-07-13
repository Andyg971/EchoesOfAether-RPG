import SpriteKit

/// Une entrée du journal (titre + description + état).
struct QuestEntry {
    let title: String
    let desc: String
    let state: QuestState   // .active ou .complete (les .inactive ne s'affichent pas)
}

/// Journal des quêtes — overlay pixel art listant les quêtes en cours
/// et terminées. Ouvert depuis le HUD, fermé au tap du bouton.
@MainActor
final class QuestLogOverlay {
    private let root = SKNode()
    private var nodes: [SKNode] = []
    private var panelWidth: CGFloat = 320
    private var panelHeight: CGFloat = 460

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
        root.isHidden = false
        buildContent(entries: entries)
        AudioEngine.shared.playShopOpen()
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

    private func buildContent(entries: [QuestEntry]) {
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
            var y = panelHeight / 2 - 70
            for entry in entries {
                let done = entry.state == .complete
                // Puce d'état pixel (carré) + libellé
                let bullet = SKSpriteNode(
                    color: done ? SKColor(red: 0.45, green: 0.85, blue: 0.50, alpha: 1)
                                : SKColor(red: 1.0, green: 0.82, blue: 0.28, alpha: 1),
                    size: CGSize(width: 8, height: 8))
                bullet.position = CGPoint(x: -panelWidth / 2 + 22, y: y + 5)
                root.addChild(bullet)
                nodes.append(bullet)

                let titleL = label(entry.title, size: 16,
                                   color: done ? SKColor(white: 0.55, alpha: 1) : .white)
                titleL.horizontalAlignmentMode = .left
                titleL.position = CGPoint(x: -panelWidth / 2 + 38, y: y)
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
                bodyL.preferredMaxLayoutWidth = panelWidth - 56
                bodyL.position = CGPoint(x: -panelWidth / 2 + 38, y: y - 20)
                root.addChild(bodyL)
                nodes.append(bodyL)

                let div = SKSpriteNode(color: PixelUI.goldDim,
                                       size: CGSize(width: panelWidth - 44, height: 1))
                div.position = CGPoint(x: 0, y: y - 42)
                root.addChild(div)
                nodes.append(div)

                y -= 64
                if y < -panelHeight / 2 + 68 { break }
            }
        }

        let closeBtn = SKShapeNode()
        PixelUI.stylePanel(closeBtn, size: CGSize(width: 120, height: 36),
                           fill: SKColor(red: 0.10, green: 0.08, blue: 0.06, alpha: 1),
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
