import SpriteKit

struct ShopItem {
    let nameKey: String
    let descKey: String
    let price: Int
    let canBuy: (PlayerState) -> Bool
    let onBuy: (PlayerState) -> Void
}

@MainActor
final class ShopOverlay {
    private let root = SKNode()
    private let panel = SKShapeNode()
    private let titleLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let goldLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let closeButton = SKShapeNode(rectOf: CGSize(width: 100, height: 40), cornerRadius: 10)
    private var itemNodes: [SKNode] = []

    private var items: [ShopItem] = []
    private var playerState: PlayerState?
    private var completion: (() -> Void)?

    private let panelWidth: CGFloat = 320
    private let panelHeight: CGFloat = 480
    private var safeBottom: CGFloat = 0

    var isActive: Bool { root.parent != nil && !root.isHidden }

    func attach(to scene: SKScene) {
        root.zPosition = 1_100
        root.isHidden = true
        scene.addChild(root)

        panel.fillColor = SKColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 0.97)
        panel.strokeColor = SKColor(red: 0.60, green: 0.50, blue: 0.25, alpha: 1)
        panel.lineWidth = 2
        root.addChild(panel)

        titleLabel.fontSize = 20
        titleLabel.fontColor = SKColor(red: 0.90, green: 0.75, blue: 0.35, alpha: 1)
        titleLabel.horizontalAlignmentMode = .center
        root.addChild(titleLabel)

        goldLabel.fontSize = 14
        goldLabel.fontColor = SKColor(red: 0.90, green: 0.80, blue: 0.30, alpha: 1)
        goldLabel.horizontalAlignmentMode = .center
        root.addChild(goldLabel)

        setupCloseButton()
    }

    func layout(in size: CGSize, safeBottom: CGFloat = 0) {
        self.safeBottom = safeBottom
        root.position = CGPoint(x: size.width / 2, y: size.height / 2)

        panel.path = CGPath(
            roundedRect: CGRect(x: -panelWidth / 2, y: -panelHeight / 2, width: panelWidth, height: panelHeight),
            cornerWidth: 18, cornerHeight: 18, transform: nil
        )

        titleLabel.position = CGPoint(x: 0, y: panelHeight / 2 - 36)
        goldLabel.position = CGPoint(x: 0, y: panelHeight / 2 - 62)
        closeButton.position = CGPoint(x: 0, y: -panelHeight / 2 + 32)
    }

    func open(title: String, items: [ShopItem], player: PlayerState, completion: @escaping () -> Void) {
        self.items = items
        self.playerState = player
        self.completion = completion
        titleLabel.text = title
        root.isHidden = false
        refresh()
    }

    func handleTap(at point: CGPoint, in scene: SKScene) -> Bool {
        guard isActive else { return false }
        let local = root.convert(point, from: scene)

        if closeButton.contains(local) {
            close()
            return true
        }

        for node in itemNodes {
            guard node.contains(local),
                  let idx = node.userData?["index"] as? Int,
                  let player = playerState else { continue }
            let item = items[idx]
            if item.canBuy(player) && player.gold >= item.price {
                player.gold -= item.price
                item.onBuy(player)
                refresh()
            }
            return true
        }

        return true
    }

    // MARK: - Private

    private func setupCloseButton() {
        closeButton.fillColor = SKColor(red: 0.20, green: 0.12, blue: 0.08, alpha: 1)
        closeButton.strokeColor = SKColor(red: 0.60, green: 0.45, blue: 0.20, alpha: 0.8)
        closeButton.lineWidth = 1.5

        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.text = String(localized: "shop.close")
        label.fontSize = 14
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        closeButton.addChild(label)
        root.addChild(closeButton)
    }

    private func refresh() {
        guard let player = playerState else { return }
        goldLabel.text = String(localized: "shop.gold \(player.gold)")
        buildItemList(player: player)
    }

    private func buildItemList(player: PlayerState) {
        itemNodes.forEach { $0.removeFromParent() }
        itemNodes.removeAll()

        let startY: CGFloat = panelHeight / 2 - 100
        let rowH: CGFloat = 70

        for (i, item) in items.enumerated() {
            let row = makeItemRow(item: item, index: i, player: player)
            row.position = CGPoint(x: 0, y: startY - CGFloat(i) * rowH)
            root.addChild(row)
            itemNodes.append(row)
            JuiceEngine.popIn(row, delay: Double(i) * 0.05)
        }
    }

    private func makeItemRow(item: ShopItem, index: Int, player: PlayerState) -> SKNode {
        let row = SKShapeNode(rectOf: CGSize(width: panelWidth - 32, height: 58), cornerRadius: 10)
        let affordable = player.gold >= item.price && item.canBuy(player)
        row.fillColor = affordable
            ? SKColor(red: 0.12, green: 0.10, blue: 0.05, alpha: 1)
            : SKColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1)
        row.strokeColor = affordable
            ? SKColor(red: 0.65, green: 0.50, blue: 0.20, alpha: 0.7)
            : SKColor(white: 0.25, alpha: 0.5)
        row.lineWidth = 1.5
        row.userData = ["index": index]

        let nameLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        nameLabel.text = String(localized: String.LocalizationValue(item.nameKey))
        nameLabel.fontSize = 14
        nameLabel.fontColor = affordable ? .white : SKColor(white: 0.4, alpha: 1)
        nameLabel.horizontalAlignmentMode = .left
        nameLabel.position = CGPoint(x: -(panelWidth / 2 - 32) / 2 + 12, y: 10)
        row.addChild(nameLabel)

        let descLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
        descLabel.text = String(localized: String.LocalizationValue(item.descKey))
        descLabel.fontSize = 11
        descLabel.fontColor = SKColor(white: 0.55, alpha: 1)
        descLabel.horizontalAlignmentMode = .left
        descLabel.position = CGPoint(x: -(panelWidth / 2 - 32) / 2 + 12, y: -8)
        row.addChild(descLabel)

        let priceLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        priceLabel.text = String(localized: "shop.price \(item.price)")
        priceLabel.fontSize = 13
        priceLabel.fontColor = affordable
            ? SKColor(red: 0.90, green: 0.75, blue: 0.25, alpha: 1)
            : SKColor(red: 0.60, green: 0.30, blue: 0.20, alpha: 1)
        priceLabel.horizontalAlignmentMode = .right
        priceLabel.position = CGPoint(x: (panelWidth / 2 - 32) / 2 - 12, y: 0)
        row.addChild(priceLabel)

        return row
    }

    private func close() {
        root.isHidden = true
        completion?()
        completion = nil
    }
}
