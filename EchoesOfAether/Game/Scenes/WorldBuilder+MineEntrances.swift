import SpriteKit

// Forêt d'Ébène — bouche de mine et entrée de grotte (portes vers les excursions).
extension WorldBuilder {
    /// Bouche de mine effondrée dans le flanc est de la forêt : ouverture
    /// sombre, poutres de bois, lanterne éteinte. Tap → entrer.
    func addMineEntrance(in scene: SKScene) {
        guard worldNode.childNode(withName: "mineEntrance") == nil else { return }
        let w = scene.size.width
        let h = worldHeight > 0 ? worldHeight : scene.size.height

        let entrance = SKNode()
        entrance.name = "mineEntrance"
        entrance.position = CGPoint(x: w * 0.88, y: h * 0.30)
        entrance.zPosition = depthLayer(for: entrance.position.y)

        // Ouverture sombre (bouche de galerie)
        let mouth = SKShapeNode(rect: CGRect(x: -26, y: 0, width: 52, height: 40),
                                cornerRadius: 14)
        mouth.fillColor = SKColor(red: 0.03, green: 0.02, blue: 0.04, alpha: 1)
        mouth.strokeColor = SKColor(red: 0.18, green: 0.14, blue: 0.10, alpha: 1)
        mouth.lineWidth = 3
        entrance.addChild(mouth)

        // Poutres de soutènement en bois
        for (x, rot) in [(-24, 0.06), (24, -0.06)] {
            let beam = SKShapeNode(rectOf: CGSize(width: 7, height: 46), cornerRadius: 2)
            beam.fillColor = SKColor(red: 0.38, green: 0.26, blue: 0.14, alpha: 1)
            beam.strokeColor = SKColor(red: 0.22, green: 0.14, blue: 0.08, alpha: 1)
            beam.lineWidth = 1
            beam.position = CGPoint(x: CGFloat(x), y: 22)
            beam.zRotation = CGFloat(rot)
            entrance.addChild(beam)
        }
        let lintel = SKShapeNode(rectOf: CGSize(width: 62, height: 8), cornerRadius: 2)
        lintel.fillColor = SKColor(red: 0.34, green: 0.23, blue: 0.12, alpha: 1)
        lintel.strokeColor = SKColor(red: 0.20, green: 0.13, blue: 0.07, alpha: 1)
        lintel.lineWidth = 1
        lintel.position = CGPoint(x: 0, y: 44)
        entrance.addChild(lintel)

        // Lueur de lanterne faible pour attirer l'oeil
        let glow = SKShapeNode(circleOfRadius: 8)
        glow.fillColor = SKColor(red: 1.0, green: 0.72, blue: 0.30, alpha: 0.35)
        glow.strokeColor = .clear
        glow.position = CGPoint(x: 30, y: 40)
        entrance.addChild(glow)
        JuiceEngine.pulse(glow, scale: 1.4)

        // Panneau : nom de la galerie
        let label = SKLabelNode(fontNamed: PixelUI.uiFont)
        label.text = String(localized: "world.mines.entrance")
        label.fontSize = 12
        label.fontColor = SKColor(white: 0.75, alpha: 0.75)
        label.position = CGPoint(x: 0, y: 54)
        entrance.addChild(label)

        worldNode.addChild(entrance)
        backdropNodes.append(entrance)
    }

    /// Entrée de la Caverne aux Échos : faille naturelle sombre bordée de
    /// rochers, dans la forêt (flanc ouest). Pixels nets, aucun arrondi.
    func addCaveEntrance(in scene: SKScene) {
        guard worldNode.childNode(withName: "caveEntrance") == nil else { return }
        let w = scene.size.width
        let h = worldHeight > 0 ? worldHeight : scene.size.height

        let entrance = SKNode()
        entrance.name = "caveEntrance"
        entrance.position = CGPoint(x: w * 0.12, y: h * 0.80)
        entrance.zPosition = depthLayer(for: entrance.position.y)

        // Bouche de caverne : trapèze sombre (rect net empilé)
        for (wdt, yy) in [(58, 6), (46, 26), (32, 42)] {
            let slab = SKSpriteNode(color: SKColor(red: 0.02, green: 0.02, blue: 0.04, alpha: 1),
                                    size: CGSize(width: CGFloat(wdt), height: 22))
            slab.position = CGPoint(x: 0, y: CGFloat(yy))
            entrance.addChild(slab)
        }
        worldNode.addChild(entrance)
        backdropNodes.append(entrance)

        // Rochers encadrant l'ouverture (assets pixel)
        addPixelProp("rock_1", in: scene, at: CGPoint(x: w * 0.12 - 40, y: h * 0.80), scale: 1.3)
        addPixelProp("rock_5", in: scene, at: CGPoint(x: w * 0.12 + 40, y: h * 0.80), scale: 1.2)

        // Champignon luisant (sa lueur froide signale l'entrée)
        addPixelProp("mushroom_1", in: scene, at: CGPoint(x: w * 0.12 + 22, y: h * 0.80 + 6),
                     scale: 0.7)

        let label = SKLabelNode(fontNamed: PixelUI.uiFont)
        label.text = String(localized: "world.cave.entrance")
        label.fontSize = 12
        label.fontColor = SKColor(white: 0.72, alpha: 0.75)
        label.position = CGPoint(x: w * 0.12, y: h * 0.80 + 66)
        label.zPosition = 2
        add(label, to: scene)
    }
}
