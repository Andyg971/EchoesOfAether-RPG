import SpriteKit

@MainActor
final class LoreOverlay {
    let root = SKNode()
    var entryLabels: [SKNode] = []
    var panelWidth: CGFloat = 300
    var panelHeight: CGFloat = 480

    private enum Tab { case chronicles, bestiary }
    private var tab: Tab = .chronicles
    var entries: [LoreEntry] = []
    var bestiarySeen: Set<String> = []

    // Pagination (le contenu long se feuillette au joystick haut/bas).
    var chroniclesPage = 0
    var bestiaryPage = 0

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
        chroniclesPage = 0
        bestiaryPage = 0
        root.isHidden = false
        buildContent()
        AudioEngine.shared.playShopOpen()
        AccessibilitySettings.announce(String(localized: "lore.title"))
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
        closeBtn.fillColor = Palette.panelNight
        closeBtn.strokeColor = Palette.panelBorder
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

    func scroll(_ dy: Int) {
        guard isActive, dy != 0 else { return }
        switch tab {
        case .chronicles: chroniclesPage = max(0, chroniclesPage - dy)
        case .bestiary:   bestiaryPage = max(0, bestiaryPage - dy)
        }
        HapticsEngine.light()
        AudioEngine.shared.playStep()
        buildContent()
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

    func makeLabel(_ text: String, size: CGFloat, color: SKColor) -> SKLabelNode {
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
