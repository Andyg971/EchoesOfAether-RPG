import SpriteKit

@MainActor
final class LoreOverlay {
    private let root = SKNode()
    private var entryLabels: [SKNode] = []
    private var panelWidth: CGFloat = 300
    private var panelHeight: CGFloat = 480

    var onClose: (() -> Void)?
    var isActive: Bool { root.parent != nil && !root.isHidden }

    func attach(to scene: SKScene) {
        root.zPosition = 1_700
        root.isHidden = true
        scene.addChild(root)
    }

    func layout(in size: CGSize) {
        panelWidth = min(330, max(280, size.width - 36))
        panelHeight = min(500, max(420, size.height - 104))
        root.position = CGPoint(x: size.width / 2, y: size.height / 2)
    }

    func open(entries: [LoreEntry], completion: @escaping () -> Void) {
        onClose = completion
        root.isHidden = false
        buildContent(entries: entries)
        AudioEngine.shared.playShopOpen()
    }

    func handleTap(at point: CGPoint, in scene: SKScene) -> Bool {
        guard isActive else { return false }
        let local = root.convert(point, from: scene)
        if let btn = root.childNode(withName: "loreClose") as? SKShapeNode, btn.contains(local) {
            close()
            return true
        }
        return true
    }

    // MARK: - Build

    private func buildContent(entries: [LoreEntry]) {
        entryLabels.forEach { $0.removeFromParent() }
        entryLabels.removeAll()

        // Panel
        let panel = SKShapeNode(path: CGPath(
            roundedRect: CGRect(x: -panelWidth/2, y: -panelHeight/2,
                                width: panelWidth, height: panelHeight),
            cornerWidth: 18, cornerHeight: 18, transform: nil))
        panel.fillColor = SKColor(red: 0.04, green: 0.04, blue: 0.08, alpha: 0.97)
        panel.strokeColor = SKColor(red: 0.35, green: 0.55, blue: 0.80, alpha: 0.8)
        panel.lineWidth = 2
        root.addChild(panel)
        entryLabels.append(panel)

        // Titre
        let title = makeLabel(String(localized: "lore.title"), font: "AvenirNext-Bold",
                              size: 20, color: SKColor(red: 0.60, green: 0.78, blue: 1, alpha: 1))
        title.position = CGPoint(x: 0, y: panelHeight/2 - 36)
        root.addChild(title)
        entryLabels.append(title)

        if entries.isEmpty {
            let empty = makeLabel(String(localized: "lore.empty"), font: "AvenirNext-MediumItalic",
                                  size: 13, color: SKColor(white: 0.40, alpha: 1))
            empty.position = CGPoint(x: 0, y: 20)
            root.addChild(empty)
            entryLabels.append(empty)
        } else {
            var y = panelHeight/2 - 72
            for entry in entries {
                let icon = makeLabel(entry.icon, font: "AvenirNext-Medium", size: 16,
                                     color: SKColor(red: 0.55, green: 0.75, blue: 1, alpha: 1))
                icon.horizontalAlignmentMode = .left
                icon.position = CGPoint(x: -panelWidth/2 + 20, y: y)
                root.addChild(icon)
                entryLabels.append(icon)

                let titleL = makeLabel(entry.title, font: "AvenirNext-DemiBold", size: 13,
                                       color: SKColor(white: 0.90, alpha: 1))
                titleL.horizontalAlignmentMode = .left
                titleL.position = CGPoint(x: -panelWidth/2 + 44, y: y)
                root.addChild(titleL)
                entryLabels.append(titleL)

                let bodyL = makeLabel(entry.body, font: "AvenirNext-Regular", size: 11,
                                      color: SKColor(white: 0.55, alpha: 1))
                bodyL.horizontalAlignmentMode = .left
                bodyL.position = CGPoint(x: -panelWidth/2 + 44, y: y - 18)
                bodyL.numberOfLines = 3
                bodyL.preferredMaxLayoutWidth = panelWidth - 60
                root.addChild(bodyL)
                entryLabels.append(bodyL)

                let div = SKShapeNode(rectOf: CGSize(width: panelWidth - 40, height: 1))
                div.fillColor = SKColor(white: 0.16, alpha: 0.5)
                div.strokeColor = .clear
                div.position = CGPoint(x: 0, y: y - 36)
                root.addChild(div)
                entryLabels.append(div)

                y -= 56
                if y < -panelHeight/2 + 60 { break }
            }
        }

        // Close button
        let closeBtn = SKShapeNode(rectOf: CGSize(width: 100, height: 38), cornerRadius: 10)
        closeBtn.fillColor = SKColor(red: 0.10, green: 0.08, blue: 0.18, alpha: 1)
        closeBtn.strokeColor = SKColor(red: 0.40, green: 0.35, blue: 0.65, alpha: 0.8)
        closeBtn.lineWidth = 1.5
        closeBtn.name = "loreClose"
        closeBtn.position = CGPoint(x: 0, y: -panelHeight/2 + 28)
        let closeLbl = makeLabel(String(localized: "lore.close"), font: "AvenirNext-DemiBold",
                                  size: 13, color: .white)
        closeLbl.verticalAlignmentMode = .center
        closeLbl.isUserInteractionEnabled = false
        closeBtn.addChild(closeLbl)
        root.addChild(closeBtn)
        entryLabels.append(closeBtn)

        for (i, node) in entryLabels.enumerated() {
            JuiceEngine.popIn(node, delay: Double(i) * 0.03)
        }
    }

    private func close() {
        root.isHidden = true
        entryLabels.forEach { $0.removeFromParent() }
        entryLabels.removeAll()
        onClose?()
        onClose = nil
    }

    private func makeLabel(_ text: String, font: String, size: CGFloat, color: SKColor) -> SKLabelNode {
        let l = SKLabelNode(fontNamed: font)
        l.text = text
        l.fontSize = size
        l.fontColor = color
        l.horizontalAlignmentMode = .center
        l.verticalAlignmentMode = .baseline
        return l
    }
}

// MARK: - LoreEntry

struct LoreEntry {
    let icon: String
    let title: String
    let body: String
}
