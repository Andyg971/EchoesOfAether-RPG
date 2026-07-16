import SpriteKit

/// Mur d'achat de fin d'Acte I. Même grammaire visuelle que ShopOverlay :
/// cadre pixel SNES, VT323, navigation joystick + bouton A, fermeture par B.
///
/// Trois entrées : « Acheter », « Restaurer », « Plus tard ». Jamais de
/// cul-de-sac — « Plus tard » renvoie au jeu, et le menu Pause rouvre l'achat.
@MainActor
final class PaywallOverlay {
    private let root = SKNode()
    private let panel = SKShapeNode()
    private let titleLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
    private let pitchLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
    private let priceLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
    private let statusLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
    private var buttonNodes: [SKShapeNode] = []

    private var selection = 0
    private let buttonNames = ["paywallBuy", "paywallRestore", "paywallLater"]

    private var panelWidth: CGFloat = 300
    private var panelHeight: CGFloat = 260

    var onBuy: (() -> Void)?
    var onRestore: (() -> Void)?
    var onLater: (() -> Void)?

    var isActive: Bool { root.parent != nil && !root.isHidden }

    func attach(to scene: SKScene) {
        root.zPosition = 1_100
        root.isHidden = true
        scene.addChild(root)
        root.addChild(panel)

        titleLabel.fontSize = 20
        titleLabel.fontColor = PixelUI.gold
        titleLabel.horizontalAlignmentMode = .center
        root.addChild(titleLabel)

        pitchLabel.fontSize = 13
        pitchLabel.fontColor = SKColor(white: 0.82, alpha: 1)
        pitchLabel.horizontalAlignmentMode = .center
        pitchLabel.numberOfLines = 3
        pitchLabel.preferredMaxLayoutWidth = 260
        root.addChild(pitchLabel)

        priceLabel.fontSize = 16
        priceLabel.fontColor = SKColor(red: 0.90, green: 0.80, blue: 0.30, alpha: 1)
        priceLabel.horizontalAlignmentMode = .center
        root.addChild(priceLabel)

        statusLabel.fontSize = 12
        statusLabel.fontColor = SKColor(white: 0.60, alpha: 1)
        statusLabel.horizontalAlignmentMode = .center
        statusLabel.numberOfLines = 2
        statusLabel.preferredMaxLayoutWidth = 260
        root.addChild(statusLabel)
    }

    func layout(in size: CGSize, safeBottom: CGFloat = 0) {
        panelWidth = min(320, max(240, size.width * 0.42))
        panelHeight = min(280, max(220, size.height * 0.72))
        root.position = CGPoint(x: size.width / 2, y: (size.height + safeBottom) / 2)

        PixelUI.stylePanel(panel, size: CGSize(width: panelWidth, height: panelHeight),
                           fill: SKColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 0.97),
                           accent: SKColor(red: 0.60, green: 0.50, blue: 0.25, alpha: 1))

        titleLabel.position = CGPoint(x: 0, y: panelHeight / 2 - 26)
        pitchLabel.preferredMaxLayoutWidth = panelWidth - 32
        pitchLabel.position = CGPoint(x: 0, y: panelHeight / 2 - 62)
        priceLabel.position = CGPoint(x: 0, y: panelHeight / 2 - 104)
        statusLabel.preferredMaxLayoutWidth = panelWidth - 32
        statusLabel.position = CGPoint(x: 0, y: -panelHeight / 2 + 18)

        buildButtons()
        UIScale.scaleCentered(root, sceneSize: size)
    }

    // MARK: - Ouverture

    func open() {
        selection = 0
        root.isHidden = false
        statusLabel.text = ""
        refreshTexts()
        AudioEngine.shared.playShopOpen()
        JuiceEngine.popIn(panel)
        refreshSelectionHighlight()
    }

    func hide() { root.isHidden = true }

    /// Bouton B : équivaut à « Plus tard ».
    func dismiss() { onLater?() }

    /// Reflète l'état du store (prix chargé, achat en cours, erreur).
    func refreshTexts() {
        titleLabel.text = String(localized: "paywall.title")
        pitchLabel.text = String(localized: "paywall.pitch")

        let store = StoreManager.shared
        if store.isPurchasing {
            priceLabel.text = String(localized: "paywall.purchasing")
        } else if let price = store.displayPrice {
            priceLabel.text = String(localized: "paywall.price \(price)")
        } else {
            // Sans réseau / produit non chargé : on le dit, on ne ment pas.
            priceLabel.text = String(localized: "paywall.priceUnavailable")
        }
    }

    func showStatus(_ text: String) { statusLabel.text = text }

    // MARK: - Navigation (joystick + A/B)

    func moveSelection(_ dy: Int) {
        guard isActive else { return }
        selection = (selection - dy + buttonNames.count) % buttonNames.count
        HapticsEngine.light()
        AudioEngine.shared.playStep()
        refreshSelectionHighlight()
    }

    func confirmSelection() {
        guard isActive else { return }
        switch buttonNames[selection] {
        case "paywallBuy":     onBuy?()
        case "paywallRestore": onRestore?()
        case "paywallLater":   onLater?()
        default: break
        }
    }

    /// Le panneau absorbe les taps ; un tap direct sur un bouton l'active.
    func handleTap(at point: CGPoint, in scene: SKScene) -> Bool {
        guard isActive else { return false }
        let local = root.convert(point, from: scene)
        for (i, node) in buttonNodes.enumerated() where node.contains(local) {
            selection = i
            refreshSelectionHighlight()
            confirmSelection()
            return true
        }
        return true
    }

    // MARK: - Private

    private func buildButtons() {
        buttonNodes.forEach { $0.removeFromParent() }
        buttonNodes.removeAll()

        let labels = [
            String(localized: "paywall.button.buy"),
            String(localized: "paywall.button.restore"),
            String(localized: "paywall.button.later")
        ]
        let startY: CGFloat = -panelHeight / 2 + 118
        let rowH: CGFloat = 38

        for (i, text) in labels.enumerated() {
            let btn = SKShapeNode(rectOf: CGSize(width: panelWidth - 40, height: 30))
            btn.name = buttonNames[i]
            btn.fillColor = i == 0
                ? SKColor(red: 0.16, green: 0.12, blue: 0.05, alpha: 1)
                : SKColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1)
            btn.strokeColor = i == 0
                ? SKColor(red: 0.65, green: 0.50, blue: 0.20, alpha: 0.8)
                : SKColor(red: 0.40, green: 0.40, blue: 0.45, alpha: 0.7)
            btn.lineWidth = 2
            btn.glowWidth = 0
            btn.position = CGPoint(x: 0, y: startY - CGFloat(i) * rowH)

            let lbl = SKLabelNode(fontNamed: PixelUI.uiFont)
            lbl.text = text
            lbl.fontSize = 14
            lbl.fontColor = i == 0 ? PixelUI.gold : SKColor(white: 0.85, alpha: 1)
            lbl.verticalAlignmentMode = .center
            lbl.isUserInteractionEnabled = false
            btn.addChild(lbl)

            root.addChild(btn)
            buttonNodes.append(btn)
        }
        refreshSelectionHighlight()
    }

    private func refreshSelectionHighlight() {
        for (i, btn) in buttonNodes.enumerated() {
            if btn.userData?["origStroke"] == nil {
                btn.userData = btn.userData ?? [:]
                btn.userData?["origStroke"] = btn.strokeColor
            }
            let selected = i == selection
            btn.lineWidth = selected ? 3 : 2
            btn.setScale(selected ? 1.04 : 1.0)
            if selected {
                btn.strokeColor = PixelUI.gold
            } else if let orig = btn.userData?["origStroke"] as? SKColor {
                btn.strokeColor = orig
            }
        }
    }
}
