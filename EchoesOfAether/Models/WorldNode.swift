import SpriteKit

@MainActor
enum WorldNode {

    // MARK: - Kael (sombre, froid, marque sur la main)

    static func kael() -> SKNode {
        let root = SKNode()
        root.name = "kael"

        let cloak = SKShapeNode(rectOf: CGSize(width: 38, height: 52), cornerRadius: 6)
        cloak.fillColor = SKColor(red: 0.10, green: 0.08, blue: 0.14, alpha: 1)
        cloak.strokeColor = SKColor(red: 0.30, green: 0.20, blue: 0.48, alpha: 0.7)
        cloak.lineWidth = 1.5
        cloak.position = .zero
        root.addChild(cloak)

        let head = SKShapeNode(circleOfRadius: 12)
        head.fillColor = SKColor(red: 0.22, green: 0.20, blue: 0.28, alpha: 1)
        head.strokeColor = SKColor(red: 0.40, green: 0.35, blue: 0.55, alpha: 0.8)
        head.lineWidth = 1
        head.position = CGPoint(x: 0, y: 34)
        root.addChild(head)

        let eyes = SKShapeNode(rectOf: CGSize(width: 10, height: 2), cornerRadius: 1)
        eyes.fillColor = SKColor(red: 0.72, green: 0.55, blue: 1.0, alpha: 1)
        eyes.strokeColor = .clear
        eyes.glowWidth = 2
        eyes.position = CGPoint(x: 0, y: 35)
        root.addChild(eyes)

        let mark = SKShapeNode(circleOfRadius: 3)
        mark.fillColor = SKColor(red: 0.58, green: 0.20, blue: 0.90, alpha: 1)
        mark.strokeColor = .clear
        mark.glowWidth = 5
        mark.position = CGPoint(x: 14, y: -8)
        root.addChild(mark)
        JuiceEngine.pulse(mark, scale: 1.6)

        let aura = SKShapeNode(circleOfRadius: 30)
        aura.fillColor = SKColor(red: 0.20, green: 0.05, blue: 0.35, alpha: 0.12)
        aura.strokeColor = SKColor(red: 0.50, green: 0.20, blue: 0.80, alpha: 0.15)
        aura.lineWidth = 1
        aura.zPosition = -1
        root.addChild(aura)
        JuiceEngine.pulse(aura, scale: 1.2)

        return root
    }

    // MARK: - Lyra (chaleureuse, nature, baton)

    static func lyra() -> SKNode {
        let root = SKNode()
        root.name = "lyra"

        let body = SKShapeNode(rectOf: CGSize(width: 30, height: 44), cornerRadius: 8)
        body.fillColor = SKColor(red: 0.12, green: 0.36, blue: 0.30, alpha: 1)
        body.strokeColor = SKColor(red: 0.30, green: 0.65, blue: 0.50, alpha: 0.6)
        body.lineWidth = 1.5
        root.addChild(body)

        let head = SKShapeNode(circleOfRadius: 11)
        head.fillColor = SKColor(red: 0.60, green: 0.45, blue: 0.35, alpha: 1)
        head.strokeColor = SKColor(red: 0.40, green: 0.68, blue: 0.52, alpha: 0.7)
        head.lineWidth = 1
        head.position = CGPoint(x: 0, y: 30)
        root.addChild(head)

        let eyes = SKShapeNode(rectOf: CGSize(width: 8, height: 2), cornerRadius: 1)
        eyes.fillColor = SKColor(red: 0.45, green: 0.82, blue: 0.60, alpha: 1)
        eyes.strokeColor = .clear
        eyes.glowWidth = 1
        eyes.position = CGPoint(x: 0, y: 31)
        root.addChild(eyes)

        let staff = SKShapeNode(rectOf: CGSize(width: 3, height: 56), cornerRadius: 1)
        staff.fillColor = SKColor(red: 0.40, green: 0.30, blue: 0.18, alpha: 1)
        staff.strokeColor = .clear
        staff.position = CGPoint(x: -18, y: 4)
        root.addChild(staff)

        let staffGem = SKShapeNode(circleOfRadius: 4)
        staffGem.fillColor = SKColor(red: 0.30, green: 0.80, blue: 0.55, alpha: 1)
        staffGem.strokeColor = .clear
        staffGem.glowWidth = 3
        staffGem.position = CGPoint(x: -18, y: 34)
        root.addChild(staffGem)
        JuiceEngine.pulse(staffGem, scale: 1.3)

        return root
    }

    // MARK: - Dorin (large, mefiant, armure doree)

    static func dorin() -> SKNode {
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

        return root
    }
}
