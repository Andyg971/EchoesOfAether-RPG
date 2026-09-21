import SpriteKit

// WorldMapOverlay — construction du parchemin : routes, jetons de lieux, états.
extension WorldMapOverlay {
    // MARK: - Build

    func panelPoint(_ normalized: CGPoint) -> CGPoint {
        // Marges : titre en haut, légende + bouton en bas.
        let usableW = panelWidth - 56
        let usableH = panelHeight - 148
        return CGPoint(x: (normalized.x - 0.5) * usableW,
                       y: (normalized.y - 0.5) * usableH + 14)
    }

    func buildContent() {
        nodes.forEach { $0.removeFromParent() }
        nodes.removeAll()

        let panel = SKShapeNode()
        PixelUI.stylePanel(panel, size: CGSize(width: panelWidth, height: panelHeight),
                           fill: SKColor(red: 0.05, green: 0.07, blue: 0.10, alpha: 0.97))
        root.addChild(panel)
        nodes.append(panel)

        let title = label(String(localized: "map.title"), size: 22, color: PixelUI.gold)
        title.position = CGPoint(x: 0, y: panelHeight / 2 - 34)
        root.addChild(title)
        nodes.append(title)

        // ── Routes en pointillés pixel entre lieux visibles ──
        let byID = Dictionary(uniqueKeysWithValues: places.map { ($0.id, $0) })
        for (a, b) in roads {
            guard let pa = byID[a], let pb = byID[b],
                  pa.state != .hidden || pb.state != .hidden else { continue }
            drawRoad(from: panelPoint(pa.point), to: panelPoint(pb.point),
                     dimmed: pa.state == .hidden || pb.state == .hidden)
        }

        // ── Lieux ──
        for place in places {
            addPlaceNode(place)
        }

        // ── Légende ──
        let legend = label(String(localized: "map.legend"), size: 12,
                           color: SKColor(white: 0.55, alpha: 1))
        legend.position = CGPoint(x: 0, y: -panelHeight / 2 + 58)
        root.addChild(legend)
        nodes.append(legend)

        let closeBtn = SKShapeNode()
        PixelUI.stylePanel(closeBtn, size: CGSize(width: 120, height: 36),
                           fill: Palette.shadowWarm,
                           accent: PixelUI.gold)
        closeBtn.name = "mapClose"
        closeBtn.position = CGPoint(x: 0, y: -panelHeight / 2 + 26)
        let closeLbl = label(String(localized: "map.close"), size: 15, color: .white)
        closeLbl.verticalAlignmentMode = .center
        closeBtn.addChild(closeLbl)
        root.addChild(closeBtn)
        nodes.append(closeBtn)

        for (i, node) in nodes.enumerated() {
            JuiceEngine.popIn(node, delay: Double(i) * 0.015)
        }
    }

    /// Route pointillée : petits carrés pixel régulièrement espacés.
    func drawRoad(from a: CGPoint, to b: CGPoint, dimmed: Bool) {
        let d = CGFloat(hypot(b.x - a.x, b.y - a.y))
        guard d > 1 else { return }
        let step: CGFloat = 12
        let count = max(2, Int(d / step))
        for i in 1..<count {
            let t = CGFloat(i) / CGFloat(count)
            let dot = SKSpriteNode(
                color: SKColor(white: dimmed ? 0.28 : 0.50, alpha: 1),
                size: CGSize(width: 3, height: 3))
            dot.position = CGPoint(x: a.x + (b.x - a.x) * t,
                                   y: a.y + (b.y - a.y) * t)
            root.addChild(dot)
            nodes.append(dot)
        }
    }

    func addPlaceNode(_ place: WorldMapPlace) {
        let p = panelPoint(place.point)

        // Carré du lieu (16 pt) — couleur du lieu, bordure selon l'état
        let square = SKShapeNode(rectOf: CGSize(width: 18, height: 18))
        square.lineWidth = 1.5
        square.glowWidth = 0
        switch place.state {
        case .current:
            square.fillColor = place.accent
            square.strokeColor = PixelUI.gold
        case .available:
            square.fillColor = place.accent.withAlphaComponent(0.85)
            square.strokeColor = SKColor(white: 0.9, alpha: 0.95)
        case .locked:
            square.fillColor = place.accent.withAlphaComponent(0.30)
            square.strokeColor = SKColor(white: 0.40, alpha: 0.8)
        case .hidden:
            square.fillColor = SKColor(white: 0.12, alpha: 1)
            square.strokeColor = SKColor(white: 0.30, alpha: 0.8)
        }
        square.position = p
        root.addChild(square)
        nodes.append(square)

        // Emblème pixel de la région, posé sur le cadre d'état (sauf non
        // découvert : le « ? » suffit). Grisé si le lieu est scellé.
        if place.state != .hidden, let emblem = regionEmblem(place.id) {
            emblem.position = p
            emblem.zPosition = 1
            if place.state == .locked {
                emblem.forEachDescendantSprite { $0.color = SKColor(white: 0.34, alpha: 1) }
            }
            root.addChild(emblem)
            nodes.append(emblem)
        }

        // Nom du lieu (« ??? » si non découvert)
        let name = place.state == .hidden ? "???" : place.title
        let nameL = label(name, size: 12,
                          color: place.state == .available || place.state == .current
                              ? .white : SKColor(white: 0.5, alpha: 1))
        nameL.position = CGPoint(x: p.x, y: p.y - 26)
        root.addChild(nameL)
        nodes.append(nameL)

        switch place.state {
        case .current:
            // Jeton Kael : losange doré pulsé au-dessus du lieu
            let token = SKShapeNode(rectOf: CGSize(width: 10, height: 10))
            token.fillColor = PixelUI.gold
            token.strokeColor = .white
            token.lineWidth = 1
            token.glowWidth = 0
            token.zRotation = .pi / 4
            token.position = CGPoint(x: p.x, y: p.y + 20)
            root.addChild(token)
            nodes.append(token)
        case .available:
            break
        case .locked:
            // Cadenas minimal : barre + arc carrés
            let lock = SKSpriteNode(color: SKColor(white: 0.55, alpha: 0.9),
                                    size: CGSize(width: 8, height: 6))
            lock.position = CGPoint(x: p.x, y: p.y)
            root.addChild(lock)
            nodes.append(lock)
        case .hidden:
            let q = label("?", size: 12, color: SKColor(white: 0.5, alpha: 1))
            q.verticalAlignmentMode = .center
            q.position = p
            root.addChild(q)
            nodes.append(q)
        }
    }
}
