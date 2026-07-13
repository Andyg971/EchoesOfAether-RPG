import SpriteKit

@MainActor
final class LoreOverlay {
    private let root = SKNode()
    private var entryLabels: [SKNode] = []
    private var panelWidth: CGFloat = 300
    private var panelHeight: CGFloat = 480

    private enum Tab { case chronicles, bestiary }
    private var tab: Tab = .chronicles
    private var entries: [LoreEntry] = []
    private var bestiarySeen: Set<String> = []

    var onClose: (() -> Void)?
    var isActive: Bool { root.parent != nil && !root.isHidden }

    func attach(to scene: SKScene) {
        root.zPosition = 1_700
        root.isHidden = true
        scene.addChild(root)
    }

    func layout(in size: CGSize) {
        panelWidth = min(360, max(280, size.width - 36))
        panelHeight = min(500, max(420, size.height - 104))
        root.position = CGPoint(x: size.width / 2, y: size.height / 2)

        // iPad : agrandit. iPhone paysage : réduit pour tenir en hauteur
        // (root déjà centré → simple mise à l'échelle).
        root.setScale(UIScale.fittingFactor(for: size, contentHeight: panelHeight + 12))
    }

    func open(entries: [LoreEntry], bestiarySeen: Set<String>,
              startOnBestiary: Bool = false,
              completion: @escaping () -> Void) {
        onClose = completion
        self.entries = entries
        self.bestiarySeen = bestiarySeen
        tab = startOnBestiary ? .bestiary : .chronicles
        root.isHidden = false
        buildContent()
        AudioEngine.shared.playShopOpen()
    }

    func handleTap(at point: CGPoint, in scene: SKScene) -> Bool {
        guard isActive else { return false }
        let local = root.convert(point, from: scene)
        if let btn = root.childNode(withName: "loreClose") as? SKShapeNode, btn.contains(local) {
            close()
            return true
        }
        if let btn = root.childNode(withName: "tabChronicles") as? SKShapeNode,
           btn.contains(local), tab != .chronicles {
            tab = .chronicles
            HapticsEngine.light()
            AudioEngine.shared.playSelect()
            buildContent()
            return true
        }
        if let btn = root.childNode(withName: "tabBestiary") as? SKShapeNode,
           btn.contains(local), tab != .bestiary {
            tab = .bestiary
            HapticsEngine.light()
            AudioEngine.shared.playSelect()
            buildContent()
            return true
        }
        return true
    }

    // MARK: - Build

    private func buildContent() {
        entryLabels.forEach { $0.removeFromParent() }
        entryLabels.removeAll()

        // Panel — cadre pixel SNES (coins carrés, double bordure, zéro glow)
        let panel = SKShapeNode()
        PixelUI.stylePanel(panel, size: CGSize(width: panelWidth, height: panelHeight),
                           fill: SKColor(red: 0.04, green: 0.04, blue: 0.08, alpha: 0.97),
                           accent: SKColor(red: 0.35, green: 0.55, blue: 0.80, alpha: 0.8))
        root.addChild(panel)
        entryLabels.append(panel)

        // Titre
        let title = makeLabel(String(localized: "lore.title"),
                              size: 26, color: SKColor(red: 0.60, green: 0.78, blue: 1, alpha: 1))
        title.position = CGPoint(x: 0, y: panelHeight/2 - 36)
        root.addChild(title)
        entryLabels.append(title)

        addTabs()

        switch tab {
        case .chronicles: buildChronicles()
        case .bestiary:   buildBestiary()
        }

        // Close button — carré pixel, zéro glow
        let closeBtn = SKShapeNode(rectOf: CGSize(width: 100, height: 38))
        closeBtn.fillColor = SKColor(red: 0.10, green: 0.08, blue: 0.18, alpha: 1)
        closeBtn.strokeColor = SKColor(red: 0.40, green: 0.35, blue: 0.65, alpha: 0.8)
        closeBtn.lineWidth = 2
        closeBtn.glowWidth = 0
        closeBtn.name = "loreClose"
        closeBtn.position = CGPoint(x: 0, y: -panelHeight/2 + 28)
        let closeLbl = makeLabel(String(localized: "lore.close"),
                                  size: 17, color: .white)
        closeLbl.verticalAlignmentMode = .center
        closeLbl.isUserInteractionEnabled = false
        closeBtn.addChild(closeLbl)
        root.addChild(closeBtn)
        entryLabels.append(closeBtn)

        for (i, node) in entryLabels.enumerated() {
            JuiceEngine.popIn(node, delay: Double(i) * 0.02)
        }
    }

    /// Deux onglets pixel sous le titre : Chroniques / Bestiaire.
    private func addTabs() {
        let tabW = (panelWidth - 52) / 2
        let specs: [(String, String, Tab)] = [
            ("tabChronicles", String(localized: "lore.tab.chronicles"), .chronicles),
            ("tabBestiary", String(localized: "lore.tab.bestiary"), .bestiary)
        ]
        for (i, spec) in specs.enumerated() {
            let selected = tab == spec.2
            let btn = SKShapeNode(rectOf: CGSize(width: tabW, height: 30))
            btn.fillColor = selected
                ? SKColor(red: 0.14, green: 0.20, blue: 0.34, alpha: 1)
                : SKColor(red: 0.06, green: 0.06, blue: 0.11, alpha: 1)
            btn.strokeColor = selected
                ? SKColor(red: 0.55, green: 0.75, blue: 1, alpha: 0.9)
                : SKColor(white: 0.30, alpha: 0.7)
            btn.lineWidth = 2
            btn.glowWidth = 0
            btn.name = spec.0
            btn.position = CGPoint(x: (CGFloat(i) - 0.5) * (tabW + 12),
                                   y: panelHeight/2 - 70)
            let lbl = makeLabel(spec.1, size: 15,
                                color: selected ? .white : SKColor(white: 0.55, alpha: 1))
            lbl.verticalAlignmentMode = .center
            lbl.isUserInteractionEnabled = false
            btn.addChild(lbl)
            root.addChild(btn)
            entryLabels.append(btn)
        }
    }

    // MARK: - Chroniques

    private func buildChronicles() {
        if entries.isEmpty {
            let empty = makeLabel(String(localized: "lore.empty"),
                                  size: 17, color: SKColor(white: 0.40, alpha: 1))
            empty.position = CGPoint(x: 0, y: 0)
            root.addChild(empty)
            entryLabels.append(empty)
            return
        }
        var y = panelHeight/2 - 108
        for entry in entries {
            // Losange pixel art (carré tourné) en guise de puce
            let icon = SKShapeNode(rectOf: CGSize(width: 9, height: 9))
            icon.fillColor = SKColor(red: 0.55, green: 0.75, blue: 1, alpha: 1)
            icon.strokeColor = SKColor(red: 0.75, green: 0.88, blue: 1, alpha: 0.8)
            icon.lineWidth = 1
            icon.zRotation = .pi / 4
            icon.position = CGPoint(x: -panelWidth/2 + 26, y: y + 5)
            root.addChild(icon)
            entryLabels.append(icon)

            let titleL = makeLabel(entry.title, size: 17,
                                   color: SKColor(white: 0.90, alpha: 1))
            titleL.horizontalAlignmentMode = .left
            titleL.position = CGPoint(x: -panelWidth/2 + 44, y: y)
            root.addChild(titleL)
            entryLabels.append(titleL)

            let bodyL = makeLabel(entry.body, size: 14,
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
            if y < -panelHeight/2 + 70 { break }
        }
    }

    // MARK: - Bestiaire

    private func buildBestiary() {
        let rowH: CGFloat = 38
        var y = panelHeight/2 - 102

        for kind in CombatSpriteKind.allCases {
            let seen = bestiarySeen.contains(kind.bestiaryID)

            // Vignette : frame idle du sprite, silhouette noire si inconnue
            if let asset = kind.thumbnailAsset,
               let thumb = PixelArtSprites.still(name: asset, scale: 0.34,
                                                 anchor: CGPoint(x: 0.5, y: 0.5)) {
                thumb.position = CGPoint(x: -panelWidth/2 + 34, y: y - 6)
                if !seen {
                    thumb.forEachDescendantSprite { s in
                        s.color = .black
                        s.colorBlendFactor = 0.92
                    }
                }
                root.addChild(thumb)
                entryLabels.append(thumb)
            } else {
                // Boss programmatiques : losange runique violet
                let rune = SKShapeNode(rectOf: CGSize(width: 14, height: 14))
                rune.fillColor = seen
                    ? SKColor(red: 0.45, green: 0.20, blue: 0.70, alpha: 1)
                    : SKColor(white: 0.12, alpha: 1)
                rune.strokeColor = seen
                    ? SKColor(red: 0.70, green: 0.45, blue: 1, alpha: 0.9)
                    : SKColor(white: 0.25, alpha: 0.8)
                rune.lineWidth = 1.5
                rune.zRotation = .pi / 4
                rune.position = CGPoint(x: -panelWidth/2 + 34, y: y - 4)
                root.addChild(rune)
                entryLabels.append(rune)
            }

            if seen {
                let nameL = makeLabel(kind.speciesName, size: 16,
                                      color: SKColor(white: 0.92, alpha: 1))
                nameL.horizontalAlignmentMode = .left
                nameL.position = CGPoint(x: -panelWidth/2 + 58, y: y)
                root.addChild(nameL)
                entryLabels.append(nameL)

                // Faiblesses (icônes texte colorées) + bouclier
                let tactics = CombatSystem.tactics(for: kind, isBoss: false)
                let weakText = tactics.weaknesses
                    .map { $0.icon }.sorted().joined(separator: " ")
                let detail = makeLabel(
                    String(localized: "bestiary.row.detail \(weakText) \(tactics.shieldMax)"),
                    size: 11, color: SKColor(red: 0.94, green: 0.86, blue: 0.62, alpha: 0.95))
                detail.horizontalAlignmentMode = .left
                detail.position = CGPoint(x: -panelWidth/2 + 58, y: y - 13)
                root.addChild(detail)
                entryLabels.append(detail)

                let desc = makeLabel(kind.bestiaryDescription, size: 10,
                                     color: SKColor(white: 0.52, alpha: 1))
                desc.horizontalAlignmentMode = .left
                desc.numberOfLines = 1
                desc.preferredMaxLayoutWidth = panelWidth - 80
                desc.position = CGPoint(x: -panelWidth/2 + 58, y: y - 24)
                root.addChild(desc)
                entryLabels.append(desc)
            } else {
                let nameL = makeLabel("???", size: 16, color: SKColor(white: 0.35, alpha: 1))
                nameL.horizontalAlignmentMode = .left
                nameL.position = CGPoint(x: -panelWidth/2 + 58, y: y - 8)
                root.addChild(nameL)
                entryLabels.append(nameL)
            }

            y -= rowH
        }
    }

    /// Bouton B : fermeture programmée (contrôles classiques).
    func dismiss() { close() }

    /// Joystick gauche/droite : bascule Chroniques ↔ Bestiaire.
    func navigateTabs(_ dx: Int) {
        guard isActive else { return }
        let target: Tab = dx > 0 ? .bestiary : .chronicles
        guard tab != target else { return }
        tab = target
        HapticsEngine.light()
        AudioEngine.shared.playSelect()
        buildContent()
    }

    private func close() {
        root.isHidden = true
        entryLabels.forEach { $0.removeFromParent() }
        entryLabels.removeAll()
        onClose?()
        onClose = nil
    }

    private func makeLabel(_ text: String, size: CGFloat, color: SKColor) -> SKLabelNode {
        let l = SKLabelNode(fontNamed: PixelUI.uiFont)
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
    let title: String
    let body: String
}
