import SpriteKit

// Sprites monde des notables de Solis : Dorin, Bram, Mara, Garen (fallbacks dessinés en code).
extension WorldNode {
    // MARK: - Dorin (chef du village, armure dorée)

    static func dorin() -> SKNode {
        if let n = pixelNPC("npc_dorin", nodeName: "dorin") { return n }

        let root = SKNode()
        root.name = "dorin"

        let armor = SKShapeNode(rectOf: CGSize(width: 40, height: 48), cornerRadius: 6)
        armor.fillColor = SKColor(red: 0.42, green: 0.35, blue: 0.18, alpha: 1)
        armor.strokeColor = SKColor(red: 0.72, green: 0.58, blue: 0.32, alpha: 0.8)
        armor.lineWidth = 2
        root.addChild(armor)

        let chestPlate = SKShapeNode(rectOf: CGSize(width: 28, height: 20), cornerRadius: 4)
        chestPlate.fillColor = SKColor(red: 0.55, green: 0.45, blue: 0.22, alpha: 1)
        chestPlate.strokeColor = SKColor(red: 0.80, green: 0.65, blue: 0.35, alpha: 0.5)
        chestPlate.lineWidth = 1
        chestPlate.position = CGPoint(x: 0, y: 4)
        root.addChild(chestPlate)

        let head = SKShapeNode(circleOfRadius: 13)
        head.fillColor = SKColor(red: 0.55, green: 0.42, blue: 0.32, alpha: 1)
        head.strokeColor = SKColor(red: 0.72, green: 0.58, blue: 0.40, alpha: 0.6)
        head.lineWidth = 1
        head.position = CGPoint(x: 0, y: 32)
        root.addChild(head)

        let eyes = SKShapeNode(rectOf: CGSize(width: 10, height: 2.5), cornerRadius: 1)
        eyes.fillColor = SKColor(red: 0.82, green: 0.65, blue: 0.30, alpha: 1)
        eyes.strokeColor = .clear
        eyes.glowWidth = 1
        eyes.position = CGPoint(x: 0, y: 33)
        root.addChild(eyes)

        let shoulderL = SKShapeNode(rectOf: CGSize(width: 12, height: 10), cornerRadius: 3)
        shoulderL.fillColor = SKColor(red: 0.50, green: 0.40, blue: 0.20, alpha: 1)
        shoulderL.strokeColor = SKColor(red: 0.72, green: 0.58, blue: 0.32, alpha: 0.5)
        shoulderL.position = CGPoint(x: -22, y: 14)
        root.addChild(shoulderL)

        let shoulderR = SKShapeNode(rectOf: CGSize(width: 12, height: 10), cornerRadius: 3)
        shoulderR.fillColor = shoulderL.fillColor
        shoulderR.strokeColor = shoulderL.strokeColor
        shoulderR.position = CGPoint(x: 22, y: 14)
        root.addChild(shoulderR)

        root.setScale(0.50)
        return root
    }

    // MARK: - Bram (armurier, massif, tablier)

    static func bram() -> SKNode {
        if let n = pixelNPC("npc_bram", nodeName: "bram") { return n }
        let root = SKNode()
        root.name = "bram"

        let body = SKShapeNode(rectOf: CGSize(width: 44, height: 50), cornerRadius: 6)
        body.fillColor = SKColor(red: 0.35, green: 0.25, blue: 0.15, alpha: 1)
        body.strokeColor = SKColor(red: 0.55, green: 0.40, blue: 0.22, alpha: 0.6)
        body.lineWidth = 1.5
        root.addChild(body)

        let apron = SKShapeNode(rectOf: CGSize(width: 36, height: 30), cornerRadius: 3)
        apron.fillColor = SKColor(red: 0.25, green: 0.18, blue: 0.10, alpha: 1)
        apron.strokeColor = SKColor(red: 0.45, green: 0.30, blue: 0.15, alpha: 0.4)
        apron.position = CGPoint(x: 0, y: -8)
        root.addChild(apron)

        let head = SKShapeNode(circleOfRadius: 14)
        head.fillColor = SKColor(red: 0.50, green: 0.38, blue: 0.28, alpha: 1)
        head.strokeColor = SKColor(red: 0.60, green: 0.45, blue: 0.30, alpha: 0.5)
        head.lineWidth = 1
        head.position = CGPoint(x: 0, y: 36)
        root.addChild(head)

        let beard = SKShapeNode(rectOf: CGSize(width: 18, height: 8), cornerRadius: 3)
        beard.fillColor = SKColor(red: 0.30, green: 0.22, blue: 0.15, alpha: 1)
        beard.strokeColor = .clear
        beard.position = CGPoint(x: 0, y: 28)
        root.addChild(beard)

        let hammer = SKNode()
        let hHandle = SKShapeNode(rectOf: CGSize(width: 3, height: 30), cornerRadius: 1)
        hHandle.fillColor = SKColor(red: 0.35, green: 0.25, blue: 0.12, alpha: 1)
        hHandle.strokeColor = .clear
        hammer.addChild(hHandle)
        let hHead = SKShapeNode(rectOf: CGSize(width: 12, height: 10), cornerRadius: 2)
        hHead.fillColor = SKColor(red: 0.45, green: 0.45, blue: 0.50, alpha: 1)
        hHead.strokeColor = SKColor(white: 0.6, alpha: 0.3)
        hHead.position = CGPoint(x: 0, y: 18)
        hammer.addChild(hHead)
        hammer.position = CGPoint(x: 22, y: 0)
        root.addChild(hammer)

        root.setScale(0.48)
        return root
    }

    // MARK: - Mara (herboriste, mince, robes vertes)

    static func mara() -> SKNode {
        if let n = pixelNPC("npc_mara", nodeName: "mara") { return n }
        let root = SKNode()
        root.name = "mara"

        let robe = SKShapeNode(rectOf: CGSize(width: 28, height: 48), cornerRadius: 10)
        robe.fillColor = SKColor(red: 0.15, green: 0.28, blue: 0.18, alpha: 1)
        robe.strokeColor = SKColor(red: 0.35, green: 0.60, blue: 0.40, alpha: 0.5)
        robe.lineWidth = 1.5
        root.addChild(robe)

        let head = SKShapeNode(circleOfRadius: 10)
        head.fillColor = SKColor(red: 0.62, green: 0.50, blue: 0.40, alpha: 1)
        head.strokeColor = SKColor(red: 0.40, green: 0.65, blue: 0.45, alpha: 0.5)
        head.lineWidth = 1
        head.position = CGPoint(x: 0, y: 32)
        root.addChild(head)

        let hat = SKShapeNode()
        let hatPath = CGMutablePath()
        hatPath.move(to: CGPoint(x: -14, y: 0))
        hatPath.addLine(to: CGPoint(x: 14, y: 0))
        hatPath.addLine(to: CGPoint(x: 6, y: 20))
        hatPath.addLine(to: CGPoint(x: -6, y: 20))
        hatPath.closeSubpath()
        hat.path = hatPath
        hat.fillColor = SKColor(red: 0.12, green: 0.22, blue: 0.14, alpha: 1)
        hat.strokeColor = SKColor(red: 0.35, green: 0.60, blue: 0.38, alpha: 0.5)
        hat.position = CGPoint(x: 0, y: 40)
        root.addChild(hat)

        let potion = SKShapeNode(circleOfRadius: 4)
        potion.fillColor = SKColor(red: 0.20, green: 0.75, blue: 0.35, alpha: 0.9)
        potion.strokeColor = .clear
        potion.glowWidth = 3
        potion.position = CGPoint(x: -16, y: -8)
        root.addChild(potion)
        JuiceEngine.pulse(potion, scale: 1.3)

        root.setScale(0.48)
        return root
    }

    // MARK: - Garen (garde, porte nord, lance)

    static func garen() -> SKNode {
        if let n = pixelNPC("npc_garen", nodeName: "garen") { return n }
        let root = SKNode()
        root.name = "garen"

        let body = SKShapeNode(rectOf: CGSize(width: 36, height: 52), cornerRadius: 5)
        body.fillColor = SKColor(red: 0.28, green: 0.28, blue: 0.32, alpha: 1)
        body.strokeColor = SKColor(red: 0.45, green: 0.45, blue: 0.55, alpha: 0.6)
        body.lineWidth = 2
        root.addChild(body)

        let chest = SKShapeNode(rectOf: CGSize(width: 28, height: 22), cornerRadius: 4)
        chest.fillColor = SKColor(red: 0.35, green: 0.35, blue: 0.42, alpha: 1)
        chest.strokeColor = SKColor(red: 0.55, green: 0.55, blue: 0.65, alpha: 0.4)
        chest.position = CGPoint(x: 0, y: 6)
        root.addChild(chest)

        let helmet = SKShapeNode(circleOfRadius: 13)
        helmet.fillColor = SKColor(red: 0.32, green: 0.32, blue: 0.38, alpha: 1)
        helmet.strokeColor = SKColor(red: 0.50, green: 0.50, blue: 0.60, alpha: 0.6)
        helmet.lineWidth = 2
        helmet.position = CGPoint(x: 0, y: 36)
        root.addChild(helmet)

        let visor = SKShapeNode(rectOf: CGSize(width: 16, height: 4), cornerRadius: 1)
        visor.fillColor = SKColor(red: 0.20, green: 0.20, blue: 0.25, alpha: 1)
        visor.strokeColor = .clear
        visor.position = CGPoint(x: 0, y: 36)
        root.addChild(visor)

        let spear = SKNode()
        let shaft = SKShapeNode(rectOf: CGSize(width: 3, height: 80), cornerRadius: 1)
        shaft.fillColor = SKColor(red: 0.40, green: 0.30, blue: 0.18, alpha: 1)
        shaft.strokeColor = .clear
        spear.addChild(shaft)
        let tip = SKShapeNode()
        let tipPath = CGMutablePath()
        tipPath.move(to: CGPoint(x: -4, y: 0))
        tipPath.addLine(to: CGPoint(x: 4, y: 0))
        tipPath.addLine(to: CGPoint(x: 0, y: 18))
        tipPath.closeSubpath()
        tip.path = tipPath
        tip.fillColor = SKColor(red: 0.65, green: 0.65, blue: 0.75, alpha: 1)
        tip.strokeColor = .clear
        tip.glowWidth = 1
        tip.position = CGPoint(x: 0, y: 42)
        spear.addChild(tip)
        spear.position = CGPoint(x: 22, y: -6)
        root.addChild(spear)

        root.setScale(0.46)
        return root
    }
}
