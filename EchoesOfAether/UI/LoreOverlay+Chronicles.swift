import SpriteKit

// LoreOverlay — l'onglet Chroniques : entrées de lore découvertes.
extension LoreOverlay {
    // MARK: - Chroniques

    func buildChronicles() {
        if entries.isEmpty {
            let empty = makeLabel(String(localized: "lore.empty"),
                                  size: 17, color: SKColor(white: 0.40, alpha: 1))
            empty.position = CGPoint(x: 0, y: 0)
            root.addChild(empty)
            entryLabels.append(empty)
            return
        }
        let top = panelHeight/2 - 108
        let rowH: CGFloat = 56
        let perPage = max(1, Int((top - (-panelHeight/2 + 78)) / rowH))
        let pages = max(1, Int(ceil(Double(entries.count) / Double(perPage))))
        chroniclesPage = min(chroniclesPage, pages - 1)
        let start = chroniclesPage * perPage
        let slice = Array(entries[start ..< min(entries.count, start + perPage)])
        var y = top
        for entry in slice {
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

            y -= rowH
        }
        addPager(page: chroniclesPage, pages: pages)
    }
}
