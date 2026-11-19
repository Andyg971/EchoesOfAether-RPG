import SpriteKit

// ShopOverlay — lignes d'articles, fenêtre de défilement, curseur et toast.
extension ShopOverlay {

    func buildItemList(player: PlayerState) {
        itemNodes.forEach { $0.removeFromParent() }
        itemNodes.removeAll()

        let startY = panelHeight / 2 - Self.listTopInset - Self.rowHeight / 2 + 4
        let window = items.indices.dropFirst(scrollOffset).prefix(visibleRowCount)
        for (slot, index) in window.enumerated() {
            let row = makeItemRow(item: items[index], index: index, player: player)
            row.position = CGPoint(x: 0, y: startY - CGFloat(slot) * Self.rowHeight)
            root.addChild(row)
            itemNodes.append(row)
            JuiceEngine.popIn(row, delay: Double(slot) * 0.05)
        }
        addScrollArrows(listTop: startY + Self.rowHeight / 2,
                        listBottom: startY - CGFloat(window.count - 1) * Self.rowHeight
                            - Self.rowHeight / 2)
    }

    /// Flèches pixel ▲ / ▼ quand des articles sont cachés au-dessus ou dessous.
    private func addScrollArrows(listTop: CGFloat, listBottom: CGFloat) {
        let x = panelWidth / 2 - 22
        if scrollOffset > 0 {
            let up = scrollArrow(pointingUp: true)
            up.position = CGPoint(x: x, y: listTop + 4)
            root.addChild(up)
            itemNodes.append(up)
        }
        if scrollOffset + visibleRowCount < items.count {
            let down = scrollArrow(pointingUp: false)
            down.position = CGPoint(x: x, y: listBottom - 4)
            root.addChild(down)
            itemNodes.append(down)
        }
    }

    private func scrollArrow(pointingUp: Bool) -> SKNode {
        let map = pointingUp
            ? ["..G..", ".GGG.", "GGGGG"]
            : ["GGGGG", ".GGG.", "..G.."]
        let arrow = PixelIcons.custom(map: map, palette: ["G": PixelUI.gold], pixel: 2)
        arrow.zPosition = 5
        return arrow
    }

    private func makeItemRow(item: ShopItem, index: Int, player: PlayerState) -> SKNode {
        let rowW = panelWidth - 28
        let row = SKShapeNode(rectOf: CGSize(width: rowW, height: Self.rowHeight - 6))
        let affordable = player.gold >= item.price && item.canBuy(player)
        row.fillColor = Palette.shadowWarm
        row.strokeColor = affordable
            ? SKColor(red: 0.65, green: 0.50, blue: 0.20, alpha: 0.7)
            : SKColor(white: 0.25, alpha: 0.5)
        row.lineWidth = 1.5
        row.glowWidth = 0
        row.userData = ["index": index, "affordable": affordable]

        // Vignette pixel art de l'article (grisée si non achetable).
        let icon = PixelIcons.node(item.icon, pixel: 2)
        icon.position = CGPoint(x: -rowW / 2 + 18, y: 0)
        if !affordable {
            icon.forEachDescendantSprite { $0.color = SKColor(white: 0.32, alpha: 1) }
        }
        row.addChild(icon)

        let textX = -rowW / 2 + 38
        let nameLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
        nameLabel.text = String(localized: item.nameKey)
        nameLabel.fontSize = 17
        nameLabel.fontColor = affordable ? .white : SKColor(white: 0.45, alpha: 1)
        nameLabel.horizontalAlignmentMode = .left
        nameLabel.verticalAlignmentMode = .baseline
        nameLabel.position = CGPoint(x: textX, y: 3)
        row.addChild(nameLabel)

        let priceLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
        priceLabel.text = String(localized: "shop.price \(item.price)")
        priceLabel.fontSize = 17
        priceLabel.fontColor = affordable
            ? SKColor(red: 0.90, green: 0.75, blue: 0.25, alpha: 1)
            : SKColor(red: 0.60, green: 0.30, blue: 0.20, alpha: 1)
        priceLabel.horizontalAlignmentMode = .right
        priceLabel.verticalAlignmentMode = .baseline
        priceLabel.position = CGPoint(x: rowW / 2 - 12, y: 3)
        row.addChild(priceLabel)

        let descLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
        descLabel.text = item.descriptionText
        descLabel.fontSize = 14
        descLabel.fontColor = SKColor(white: affordable ? 0.62 : 0.42, alpha: 1)
        descLabel.horizontalAlignmentMode = .left
        descLabel.verticalAlignmentMode = .baseline
        descLabel.position = CGPoint(x: textX, y: -14)
        fit(descLabel, maxWidth: rowW - 50)
        row.addChild(descLabel)

        return row
    }

    /// Une ligne de stats ne doit jamais sortir de la carte : on réduit la
    /// police plutôt que de rogner (anglais et français n'ont pas la même
    /// longueur).
    private func fit(_ label: SKLabelNode, maxWidth: CGFloat) {
        while label.frame.width > maxWidth, label.fontSize > 11 {
            label.fontSize -= 1
        }
    }

    func refreshSelectionHighlight() {
        for node in itemNodes {
            guard let row = node as? SKShapeNode,
                  let idx = row.userData?["index"] as? Int else { continue }
            let selected = idx == selection
            let affordable = row.userData?["affordable"] as? Bool ?? false
            row.lineWidth = selected ? 2.5 : 1.5
            row.strokeColor = selected
                ? PixelUI.gold
                : (affordable
                    ? SKColor(red: 0.65, green: 0.50, blue: 0.20, alpha: 0.7)
                    : SKColor(white: 0.25, alpha: 0.5))
            row.setScale(selected ? 1.02 : 1.0)
        }
    }

    /// Toast « Acheté ! » vert, bref, après un achat réussi.
    func showPurchaseToast() {
        root.childNode(withName: "purchaseToast")?.removeFromParent()
        let toast = SKLabelNode(fontNamed: PixelUI.uiFont)
        toast.name = "purchaseToast"
        toast.text = String(localized: "shop.purchased")
        toast.fontSize = 20
        toast.fontColor = SKColor(red: 0.55, green: 0.92, blue: 0.58, alpha: 1)
        toast.verticalAlignmentMode = .center
        toast.horizontalAlignmentMode = .center
        toast.position = CGPoint(x: panelWidth / 2 - 70, y: panelHeight / 2 - 30)
        toast.zPosition = 20
        toast.setScale(0.6)
        toast.alpha = 0
        root.addChild(toast)
        toast.run(.sequence([
            .group([.fadeIn(withDuration: 0.12),
                    .scale(to: 1.0, duration: 0.16)]),
            .wait(forDuration: 0.7),
            .group([.fadeOut(withDuration: 0.3),
                    .moveBy(x: 0, y: 10, duration: 0.3)]),
            .removeFromParent()
        ]))
    }
}
