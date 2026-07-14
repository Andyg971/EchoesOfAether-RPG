import SpriteKit

struct ShopItem {
    let nameKey: LocalizedStringResource
    let descKey: LocalizedStringResource
    let price: Int
    let canBuy: (PlayerState) -> Bool
    let onBuy: (PlayerState) -> Void
}

@MainActor
final class ShopOverlay {
    private let root = SKNode()
    private let panel = SKShapeNode()
    private let titleLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
    private let goldLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
    private let closeButton = SKShapeNode(rectOf: CGSize(width: 72, height: 28))
    private var itemNodes: [SKNode] = []

    private var items: [ShopItem] = []
    private var selection = 0          // curseur (contrôles classiques)
    private var playerState: PlayerState?
    private var completion: (() -> Void)?

    private var panelWidth: CGFloat = 240
    private var panelHeight: CGFloat = 300
    private var safeBottom: CGFloat = 0

    var isActive: Bool { root.parent != nil && !root.isHidden }

    func attach(to scene: SKScene) {
        root.zPosition = 1_100
        root.isHidden = true
        scene.addChild(root)

        root.addChild(panel)

        titleLabel.fontSize = 18
        titleLabel.fontColor = SKColor(red: 0.90, green: 0.75, blue: 0.35, alpha: 1)
        titleLabel.horizontalAlignmentMode = .center
        root.addChild(titleLabel)

        goldLabel.fontSize = 13
        goldLabel.fontColor = SKColor(red: 0.90, green: 0.80, blue: 0.30, alpha: 1)
        goldLabel.horizontalAlignmentMode = .center
        root.addChild(goldLabel)

        setupCloseButton()
    }

    func layout(in size: CGSize, safeBottom: CGFloat = 0) {
        self.safeBottom = safeBottom
        panelWidth = min(260, max(200, size.width * 0.35))
        panelHeight = min(320, max(220, size.height * 0.65))
        root.position = CGPoint(x: size.width / 2, y: (size.height + safeBottom) / 2)

        // Cadre pixel SNES : coins carrés, double bordure, zéro glow.
        PixelUI.stylePanel(panel, size: CGSize(width: panelWidth, height: panelHeight),
                           fill: SKColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 0.97),
                           accent: SKColor(red: 0.60, green: 0.50, blue: 0.25, alpha: 1))

        titleLabel.position = CGPoint(x: 0, y: panelHeight / 2 - 24)
        goldLabel.position = CGPoint(x: 0, y: panelHeight / 2 - 42)
        closeButton.position = CGPoint(x: 0, y: -panelHeight / 2 + 22)

        // iPad : agrandit l'overlay (root déjà centré → simple mise à l'échelle).
        UIScale.scaleCentered(root, sceneSize: size)
    }

    func open(title: String, items: [ShopItem], player: PlayerState, completion: @escaping () -> Void) {
        self.items = items
        self.playerState = player
        self.completion = completion
        titleLabel.text = title
        selection = 0
        root.isHidden = false
        AudioEngine.shared.playShopOpen()
        refresh()
    }

    /// Joystick haut/bas : déplace le curseur sur les articles.
    func moveSelection(_ dy: Int) {
        guard isActive, !items.isEmpty else { return }
        selection = (selection - dy + items.count) % items.count
        HapticsEngine.light()
        AudioEngine.shared.playStep()
        refreshSelectionHighlight()
    }

    /// Bouton A : achète l'article sélectionné (si achetable).
    func confirmSelection() {
        guard isActive, items.indices.contains(selection),
              let player = playerState else { return }
        let item = items[selection]
        guard item.canBuy(player), player.gold >= item.price else {
            HapticsEngine.error()
            return
        }
        player.gold -= item.price
        item.onBuy(player)
        AudioEngine.shared.playPurchase()
        refresh()
    }

    private func refreshSelectionHighlight() {
        for node in itemNodes {
            guard let row = node as? SKShapeNode,
                  let idx = row.userData?["index"] as? Int else { continue }
            let selected = idx == selection
            row.lineWidth = selected ? 2.5 : 1.5
            if selected {
                row.strokeColor = PixelUI.gold
                row.setScale(1.02)
            } else {
                row.setScale(1.0)
            }
        }
    }

    /// Contrôles classiques : le panneau absorbe le tap. Navigation au
    /// joystick, achat au bouton A, fermeture au bouton B.
    func handleTap(at point: CGPoint, in scene: SKScene) -> Bool {
        isActive
    }

    // MARK: - Private

    private func setupCloseButton() {
        closeButton.fillColor = SKColor(red: 0.20, green: 0.12, blue: 0.08, alpha: 1)
        closeButton.strokeColor = SKColor(red: 0.60, green: 0.45, blue: 0.20, alpha: 0.8)
        closeButton.lineWidth = 2
        closeButton.glowWidth = 0

        let label = SKLabelNode(fontNamed: PixelUI.uiFont)
        label.text = String(localized: "shop.close")
        label.fontSize = 13
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        closeButton.addChild(label)
        root.addChild(closeButton)
    }

    private func refresh() {
        guard let player = playerState else { return }
        goldLabel.text = String(localized: "shop.gold \(player.gold)")
        buildItemList(player: player)
        selection = min(selection, max(0, items.count - 1))
        refreshSelectionHighlight()
    }

    private func buildItemList(player: PlayerState) {
        itemNodes.forEach { $0.removeFromParent() }
        itemNodes.removeAll()

        let startY: CGFloat = panelHeight / 2 - 68
        let rowH: CGFloat = 50

        for (i, item) in items.enumerated() {
            let row = makeItemRow(item: item, index: i, player: player)
            row.position = CGPoint(x: 0, y: startY - CGFloat(i) * rowH)
            root.addChild(row)
            itemNodes.append(row)
            JuiceEngine.popIn(row, delay: Double(i) * 0.05)
        }
    }

    private func makeItemRow(item: ShopItem, index: Int, player: PlayerState) -> SKNode {
        let row = SKShapeNode(rectOf: CGSize(width: panelWidth - 24, height: 40))
        let affordable = player.gold >= item.price && item.canBuy(player)
        row.fillColor = affordable
            ? SKColor(red: 0.12, green: 0.10, blue: 0.05, alpha: 1)
            : SKColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1)
        row.strokeColor = affordable
            ? SKColor(red: 0.65, green: 0.50, blue: 0.20, alpha: 0.7)
            : SKColor(white: 0.25, alpha: 0.5)
        row.lineWidth = 1.5
        row.glowWidth = 0
        row.userData = ["index": index]

        let nameLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
        nameLabel.text = String(localized: item.nameKey)
        nameLabel.fontSize = 13
        nameLabel.fontColor = affordable ? .white : SKColor(white: 0.4, alpha: 1)
        nameLabel.horizontalAlignmentMode = .left
        nameLabel.position = CGPoint(x: -(panelWidth - 24) / 2 + 10, y: 6)
        row.addChild(nameLabel)

        let descLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
        descLabel.text = String(localized: item.descKey)
        descLabel.fontSize = 10
        descLabel.fontColor = SKColor(white: 0.55, alpha: 1)
        descLabel.horizontalAlignmentMode = .left
        descLabel.position = CGPoint(x: -(panelWidth - 24) / 2 + 10, y: -8)
        row.addChild(descLabel)

        let priceLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
        priceLabel.text = String(localized: "shop.price \(item.price)")
        priceLabel.fontSize = 13
        priceLabel.fontColor = affordable
            ? SKColor(red: 0.90, green: 0.75, blue: 0.25, alpha: 1)
            : SKColor(red: 0.60, green: 0.30, blue: 0.20, alpha: 1)
        priceLabel.horizontalAlignmentMode = .right
        priceLabel.position = CGPoint(x: (panelWidth - 24) / 2 - 10, y: 0)
        row.addChild(priceLabel)

        return row
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
