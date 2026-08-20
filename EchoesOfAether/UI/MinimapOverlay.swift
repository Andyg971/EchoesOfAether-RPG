import SpriteKit

/// Minimap en bas-gauche : rectangle semi-transparent + points NPC + point Kael.
@MainActor
final class MinimapOverlay {
    private let root = SKNode()
    private let mapBg = SKShapeNode()
    // Losange pixel (carré tourné) pour Kael — plus de cercle en pixel art.
    private let kaelDot = SKShapeNode(rectOf: CGSize(width: 6, height: 6))
    private var npcDots: [SKSpriteNode] = []

    private let mapW: CGFloat = 80
    private let mapH: CGFloat = 60

    func attach(to scene: SKScene) {
        root.zPosition = 150
        scene.addChild(root)
        buildBase()
        layout(in: scene.size)
    }

    func layout(in size: CGSize, safeBottom: CGFloat = 0, safeLeft: CGFloat = 0) {
        root.position = CGPoint(x: safeLeft + mapW / 2 + 10, y: safeBottom + mapH / 2 + 10)
    }

    /// Appeler à chaque frame depuis GameManager.update (toutes les 0.1s max)
    func update(kaelPosition: CGPoint, sceneSize: CGSize,
                npcs: [(position: CGPoint, color: SKColor)]) {
        // Normaliser Kael
        let nx = (kaelPosition.x / sceneSize.width) * mapW - mapW / 2
        let ny = (kaelPosition.y / sceneSize.height) * mapH - mapH / 2
        kaelDot.position = CGPoint(x: nx, y: ny)

        // Pool de points NPC : on ajuste juste la taille du pool et on
        // repositionne — plus de removeFromParent/recréation à chaque frame.
        while npcDots.count < npcs.count {
            let dot = SKSpriteNode(color: .white, size: CGSize(width: 4, height: 4))
            dot.zPosition = 2
            root.addChild(dot)
            npcDots.append(dot)
        }
        while npcDots.count > npcs.count {
            npcDots.removeLast().removeFromParent()
        }
        for (i, npc) in npcs.enumerated() {
            let dot = npcDots[i]
            dot.color = npc.color
            let dx = (npc.position.x / sceneSize.width) * mapW - mapW / 2
            let dy = (npc.position.y / sceneSize.height) * mapH - mapH / 2
            dot.position = CGPoint(x: dx, y: dy)
        }
    }

    func setVisible(_ visible: Bool) {
        root.isHidden = !visible
    }

    // MARK: - Private

    private func buildBase() {
        // Cadre rectangulaire net (coins carrés) — cohérent pixel art.
        mapBg.path = CGPath(rect: CGRect(x: -mapW/2, y: -mapH/2,
                                         width: mapW, height: mapH), transform: nil)
        mapBg.fillColor = SKColor(red: 0, green: 0, blue: 0, alpha: 0.55)
        mapBg.strokeColor = SKColor(red: 0.35, green: 0.30, blue: 0.55, alpha: 0.6)
        mapBg.lineWidth = 1
        mapBg.glowWidth = 0
        mapBg.zPosition = 0
        root.addChild(mapBg)

        // Losange pixel pour Kael (carré tourné à 45°).
        kaelDot.fillColor = SKColor(red: 0.65, green: 0.45, blue: 1, alpha: 1)
        kaelDot.strokeColor = .white
        kaelDot.lineWidth = 1
        kaelDot.glowWidth = 0
        kaelDot.zRotation = .pi / 4
        kaelDot.zPosition = 3
        root.addChild(kaelDot)
    }
}
