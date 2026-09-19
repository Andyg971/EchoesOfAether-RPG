import SpriteKit

// Briques de construction génériques.
// Extrait de WorldBuilder.swift (découpage du monolithe).
@MainActor
extension WorldBuilder {
    // MARK: - Building Blocks

    func makeBuilding(w: CGFloat, h: CGFloat, wallColor: SKColor, roofColor: SKColor, label: String?) -> SKNode {
        let bld = SKNode()

        let wall = SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: 4)
        wall.fillColor = wallColor
        wall.strokeColor = SKColor(white: 0.22, alpha: 0.5)
        wall.lineWidth = 1
        bld.addChild(wall)

        let roof = SKShapeNode(rectOf: CGSize(width: w + 12, height: 14), cornerRadius: 3)
        roof.fillColor = roofColor
        roof.strokeColor = .clear
        roof.position = CGPoint(x: 0, y: h / 2 + 5)
        bld.addChild(roof)

        let door = SKShapeNode(rectOf: CGSize(width: 12, height: 18), cornerRadius: 2)
        door.fillColor = Palette.shadowWarm
        door.strokeColor = SKColor(white: 0.18, alpha: 0.5)
        door.lineWidth = 1
        door.position = CGPoint(x: 0, y: -h / 2 + 9)
        bld.addChild(door)

        let winL = SKShapeNode(rectOf: CGSize(width: 10, height: 8), cornerRadius: 2)
        winL.fillColor = SKColor(red: 0.60, green: 0.50, blue: 0.25, alpha: 0.2)
        winL.strokeColor = SKColor(white: 0.30, alpha: 0.4)
        winL.position = CGPoint(x: -w * 0.28, y: 4)
        bld.addChild(winL)

        let winR = SKShapeNode(rectOf: CGSize(width: 10, height: 8), cornerRadius: 2)
        winR.fillColor = winL.fillColor
        winR.strokeColor = winL.strokeColor
        winR.position = CGPoint(x: w * 0.28, y: 4)
        bld.addChild(winR)

        if let lbl = label {
            let sign = SKLabelNode(text: lbl)
            sign.fontSize = 16
            sign.position = CGPoint(x: 0, y: h / 2 + 20)
            bld.addChild(sign)
        }

        return bld
    }

    func buildNorthGate(at pos: CGPoint, width: CGFloat, in scene: SKScene) {
        let gate = SKNode()
        gate.position = pos
        gate.zPosition = propLayer(for: pos.y, in: scene.size.height)
        addGroundShadow(under: gate, width: width + 32, height: 14)

        // Portail en pierre du pack (fini les piliers programmatiques)
        if let arch = PixelArtSprites.still(name: "gy_gate_big", scale: 0.55,
                                            anchor: CGPoint(x: 0.5, y: 0.0)) {
            arch.position = CGPoint(x: 0, y: -18)
            gate.addChild(arch)
        }

        let northSign = SKLabelNode(fontNamed: PixelUI.uiFont)
        northSign.text = String(localized: "world.northGate")
        northSign.fontSize = 13
        northSign.fontColor = SKColor(red: 0.86, green: 0.80, blue: 0.62, alpha: 1)
        northSign.position = CGPoint(x: 0, y: 118)
        gate.addChild(northSign)

        add(gate, to: scene)
    }

    func buildWell(at pos: CGPoint, in scene: SKScene) {
        let well = SKNode()
        well.position = pos
        well.zPosition = propLayer(for: pos.y, in: scene.size.height)
        addGroundShadow(under: well, width: 42, height: 16)

        let base = SKShapeNode(circleOfRadius: 14)
        base.fillColor = SKColor(red: 0.20, green: 0.16, blue: 0.12, alpha: 1)
        base.strokeColor = SKColor(white: 0.28, alpha: 0.5)
        base.lineWidth = 2
        well.addChild(base)

        let water = SKShapeNode(circleOfRadius: 10)
        water.fillColor = SKColor(red: 0.10, green: 0.25, blue: 0.40, alpha: 0.8)
        water.strokeColor = .clear
        well.addChild(water)

        let glow = SKShapeNode(circleOfRadius: 10)
        glow.fillColor = .clear
        glow.strokeColor = SKColor(red: 0.30, green: 0.55, blue: 0.80, alpha: 0.15)
        glow.lineWidth = 2
        well.addChild(glow)
        JuiceEngine.pulse(glow, scale: 1.3)

        add(well, to: scene)
        registerObstacle(CGRect(x: pos.x - 15, y: pos.y - 15, width: 30, height: 30))
    }

    func makeTorch() -> SKNode {
        let torch = SKNode()
        torch.zPosition = -3

        let pole = SKShapeNode(rectOf: CGSize(width: 3, height: 28), cornerRadius: 1)
        pole.fillColor = SKColor(red: 0.30, green: 0.20, blue: 0.10, alpha: 1)
        pole.strokeColor = .clear
        torch.addChild(pole)

        let flame = SKShapeNode(circleOfRadius: 5)
        flame.fillColor = SKColor(red: 0.90, green: 0.55, blue: 0.15, alpha: 0.9)
        flame.strokeColor = .clear
        flame.glowWidth = 6
        flame.position = CGPoint(x: 0, y: 18)
        torch.addChild(flame)
        JuiceEngine.pulse(flame, scale: 1.4)

        let glow = SKShapeNode(circleOfRadius: 30)
        glow.fillColor = SKColor(red: 0.80, green: 0.50, blue: 0.15, alpha: 0.04)
        glow.strokeColor = .clear
        glow.position = CGPoint(x: 0, y: 18)
        torch.addChild(glow)

        return torch
    }

    func makeTree(height: CGFloat) -> SKNode {
        let tree = SKNode()
        tree.zPosition = -4

        let trunk = SKShapeNode(rectOf: CGSize(width: 8, height: height * 0.4), cornerRadius: 2)
        trunk.fillColor = SKColor(red: 0.18, green: 0.12, blue: 0.06, alpha: 1)
        trunk.strokeColor = .clear
        tree.addChild(trunk)

        let colors: [SKColor] = [
            SKColor(red: 0.08, green: 0.20, blue: 0.10, alpha: 1),
            SKColor(red: 0.06, green: 0.18, blue: 0.08, alpha: 1),
            SKColor(red: 0.10, green: 0.22, blue: 0.12, alpha: 1)
        ]
        for i in 0..<3 {
            let leaf = SKShapeNode(circleOfRadius: CGFloat(18 - i * 4))
            leaf.fillColor = colors[i]
            leaf.strokeColor = .clear
            leaf.position = CGPoint(x: 0, y: height * 0.2 + CGFloat(i) * 14)
            tree.addChild(leaf)
        }

        return tree
    }

    func addGroundShadow(under node: SKNode, width: CGFloat, height: CGFloat) {
        let shadow = SKShapeNode(ellipseOf: CGSize(width: width, height: height))
        shadow.fillColor = SKColor.black.withAlphaComponent(0.22)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: 3)
        shadow.zPosition = -0.5
        node.addChild(shadow)
    }

    /// Profondeur acteurs : plage [20, 40], normalisée par la hauteur du
    /// MONDE (pas de l'écran) — sinon tout y > ~1,3 écran passe sous le sol.
    /// Profondeur d'un acteur — **même échelle que les props** (cf. propLayer).
    ///
    /// Les deux vivaient sur des plages disjointes : acteurs 20→40, props
    /// −8→−2. Résultat, Kael passait devant TOUS les arbres quel que soit
    /// l'endroit — il avait l'air de marcher dessus. Sur une échelle commune,
    /// c'est la position en y qui tranche : ce qui est plus bas est devant.
    func actorLayer(for y: CGFloat) -> CGFloat {
        depthLayer(for: y)
    }

    /// Tri en profondeur unique du monde. Plus bas à l'écran = plus proche =
    /// devant. Le sol (−10), l'allée (−9) et la roche (−8) restent sous tout.
    func depthLayer(for y: CGFloat, sceneHeight: CGFloat = 0) -> CGFloat {
        let span = worldHeight > 0 ? worldHeight : max(sceneHeight, 402)
        return 40 - (y / span) * 40
    }

    /// Profondeur props : plage [-2, -8], même normalisation monde.
    func propLayer(for y: CGFloat, in sceneHeight: CGFloat) -> CGFloat {
        depthLayer(for: y, sceneHeight: sceneHeight)
    }
}
