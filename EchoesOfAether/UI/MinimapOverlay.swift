import SpriteKit

/// Minimap en bas-gauche : rectangle semi-transparent + points NPC + point Kael.
@MainActor
final class MinimapOverlay {
    private let root = SKNode()
    private let mapBg = SKShapeNode()
    private let kaelDot = SKShapeNode(circleOfRadius: 3.5)
    private var npcDots: [SKShapeNode] = []

    private let mapW: CGFloat = 80
    private let mapH: CGFloat = 60

    func attach(to scene: SKScene) {
        root.zPosition = 150
        scene.addChild(root)
        buildBase()
        layout(in: scene.size)
    }

    func layout(in size: CGSize, safeBottom: CGFloat = 0) {
        root.position = CGPoint(x: mapW / 2 + 10, y: safeBottom + mapH / 2 + 10)
    }

    /// Appeler à chaque frame depuis GameManager.update (toutes les 0.1s max)
    func update(kaelPosition: CGPoint, sceneSize: CGSize,
                npcs: [(position: CGPoint, color: SKColor)]) {
        // Normaliser Kael
        let nx = (kaelPosition.x / sceneSize.width) * mapW - mapW / 2
        let ny = (kaelPosition.y / sceneSize.height) * mapH - mapH / 2
        kaelDot.position = CGPoint(x: nx, y: ny)

        // Reconstruire points NPC
        npcDots.forEach { $0.removeFromParent() }
        npcDots.removeAll()
        for npc in npcs {
            let dot = SKShapeNode(circleOfRadius: 2)
            dot.fillColor = npc.color
            dot.strokeColor = .clear
            let dx = (npc.position.x / sceneSize.width) * mapW - mapW / 2
            let dy = (npc.position.y / sceneSize.height) * mapH - mapH / 2
            dot.position = CGPoint(x: dx, y: dy)
            dot.zPosition = 2
            root.addChild(dot)
            npcDots.append(dot)
        }
    }

    func setVisible(_ visible: Bool) {
        root.isHidden = !visible
    }

    // MARK: - Private

    private func buildBase() {
        mapBg.path = CGPath(roundedRect: CGRect(x: -mapW/2, y: -mapH/2,
                                                width: mapW, height: mapH),
                            cornerWidth: 6, cornerHeight: 6, transform: nil)
        mapBg.fillColor = SKColor(red: 0, green: 0, blue: 0, alpha: 0.55)
        mapBg.strokeColor = SKColor(red: 0.35, green: 0.30, blue: 0.55, alpha: 0.6)
        mapBg.lineWidth = 1
        mapBg.zPosition = 0
        root.addChild(mapBg)

        kaelDot.fillColor = SKColor(red: 0.65, green: 0.45, blue: 1, alpha: 1)
        kaelDot.strokeColor = .white
        kaelDot.lineWidth = 1
        kaelDot.zPosition = 3
        root.addChild(kaelDot)
        JuiceEngine.pulse(kaelDot, scale: 1.3)
    }
}
