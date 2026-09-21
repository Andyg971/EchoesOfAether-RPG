import SpriteKit

@MainActor
enum WorldNode {

    // MARK: - Kael (protagoniste — sprite pixel art animé)

    /// Kael dans le monde — le sprite du pack, celui de l'arène.
    ///
    /// Il utilisait avant `kael_idle_*` : un cowboy vu de face, sans cycle de
    /// marche, alors que le Kael du combat sort d'un pack. Deux personnages
    /// différents pour un seul héros. Le pack règle les deux défauts d'un
    /// coup : même visage partout, et une vraie marche. Quel pack Kael porte
    /// se décide dans `BattleSprites.Hero.pack`.
    static func kael() -> SKNode {
        if let node = BattleSprites.worldNode(.kael, name: "kael") { return node }
        return legacyKael()
    }

    /// Repli si le pack manque à l'appel (asset absent) : l'ancien sprite.
    private static func legacyKael() -> SKNode {
        let root = SKNode()
        root.name = "kael"
        let textures: [SKTexture] = (1...6).map { i in
            let t = SKTexture(imageNamed: "kael_idle_\(i)")
            t.filteringMode = .nearest
            return t
        }
        let sprite = SKSpriteNode(texture: textures[0])
        sprite.name = "kaelSprite"
        sprite.setScale(0.85)
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.0)
        sprite.position = CGPoint(x: 0, y: -16)
        sprite.zPosition = 1
        sprite.run(.repeatForever(.animate(with: textures, timePerFrame: 0.11,
                                           resize: false, restore: true)))
        root.addChild(sprite)
        return root
    }

    // MARK: - Lyra (alliée, nature, bâton)


    /// PNJ pixel art (6 frames idle) à l'échelle de Kael. `height` fixe la
    /// taille À L'ÉCRAN : les planches n'ont plus toutes la même hauteur
    /// native depuis que les PNJ sont composés au paperdoll, et l'enfant
    /// doit rester une tête sous les adultes.
    /// Fallback : la silhouette programmatique historique.
    static func pixelNPC(_ asset: String, nodeName: String,
                                 height: CGFloat = PixelArtSprites.npcHeight) -> SKNode? {
        guard let node = PixelArtSprites.animated(
            name: asset, frames: 6,
            scale: PixelArtSprites.scale(name: "\(asset)_idle_1", height: height),
            timePerFrame: 0.16,
            anchor: CGPoint(x: 0.5, y: 0.0)) else { return nil }
        node.name = nodeName
        // Même convention que Kael : sprite ancré aux pieds, décalé pour
        // que la position du node reste le centre du personnage.
        if let sprite = node.children.first as? SKSpriteNode {
            sprite.position = CGPoint(x: 0, y: -16)
        }
        let shadow = SKShapeNode(ellipseOf: CGSize(width: 24, height: 7))
        shadow.fillColor = SKColor(white: 0, alpha: 0.25)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -15)
        shadow.zPosition = -1
        node.addChild(shadow)
        return node
    }

    /// Lyra dans le monde — le sprite de son pack (prêtresse), le même qu'en
    /// combat. Replis successifs : pack → sprite PNJ → silhouette.
    static func lyra() -> SKNode {
        if let n = BattleSprites.worldNode(.lyra, name: "lyra") { return n }
        if let n = pixelNPC("npc_lyra", nodeName: "lyra") { return n }

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

        root.setScale(0.55)
        return root
    }

    // MARK: - Sage (vieux sage à l'auberge)

    static func sage() -> SKNode {
        if let n = pixelNPC("npc_sage", nodeName: "sage") { return n }
        let root = SKNode()
        root.name = "sage"

        let robe = SKShapeNode(rectOf: CGSize(width: 32, height: 44), cornerRadius: 12)
        robe.fillColor = SKColor(red: 0.18, green: 0.15, blue: 0.25, alpha: 1)
        robe.strokeColor = SKColor(red: 0.40, green: 0.35, blue: 0.55, alpha: 0.4)
        robe.lineWidth = 1
        root.addChild(robe)

        let head = SKShapeNode(circleOfRadius: 11)
        head.fillColor = SKColor(red: 0.65, green: 0.58, blue: 0.50, alpha: 1)
        head.strokeColor = .clear
        head.position = CGPoint(x: 0, y: 30)
        root.addChild(head)

        let beard = SKShapeNode(rectOf: CGSize(width: 16, height: 14), cornerRadius: 4)
        beard.fillColor = SKColor(white: 0.80, alpha: 0.9)
        beard.strokeColor = .clear
        beard.position = CGPoint(x: 0, y: 21)
        root.addChild(beard)

        let cane = SKShapeNode(rectOf: CGSize(width: 3, height: 50), cornerRadius: 1)
        cane.fillColor = SKColor(red: 0.50, green: 0.38, blue: 0.22, alpha: 1)
        cane.strokeColor = .clear
        cane.position = CGPoint(x: -18, y: -2)
        root.addChild(cane)

        let glow = SKShapeNode(circleOfRadius: 22)
        glow.fillColor = SKColor(red: 0.30, green: 0.20, blue: 0.50, alpha: 0.06)
        glow.strokeColor = .clear
        glow.zPosition = -1
        root.addChild(glow)
        JuiceEngine.pulse(glow, scale: 1.15)

        root.setScale(0.55)
        return root
    }

    // MARK: - Enfant (PNJ enfant, petit, curieux)

    static func child() -> SKNode {
        // Une tête de moins que les adultes : c'est ce qui le fait lire
        // comme un enfant, le paperdoll n'ayant pas de morphologie enfant.
        if let n = pixelNPC("npc_child", nodeName: "child", height: 34) { return n }
        let root = SKNode()
        root.name = "child"

        let body = SKShapeNode(rectOf: CGSize(width: 20, height: 30), cornerRadius: 6)
        body.fillColor = SKColor(red: 0.55, green: 0.35, blue: 0.20, alpha: 1)
        body.strokeColor = SKColor(red: 0.70, green: 0.50, blue: 0.30, alpha: 0.4)
        body.lineWidth = 1
        root.addChild(body)

        let head = SKShapeNode(circleOfRadius: 9)
        head.fillColor = SKColor(red: 0.70, green: 0.55, blue: 0.42, alpha: 1)
        head.strokeColor = .clear
        head.position = CGPoint(x: 0, y: 22)
        root.addChild(head)

        let eyes = SKShapeNode(rectOf: CGSize(width: 6, height: 2), cornerRadius: 1)
        eyes.fillColor = SKColor(red: 0.30, green: 0.55, blue: 0.80, alpha: 1)
        eyes.strokeColor = .clear
        eyes.position = CGPoint(x: 0, y: 23)
        root.addChild(eyes)

        root.setScale(0.70)
        JuiceEngine.float(root, distance: 3)
        return root
    }

    // MARK: - Villageois effrayé

    static func scaredVillager() -> SKNode {
        if let n = pixelNPC("npc_villager", nodeName: "villager") { return n }
        let root = SKNode()
        root.name = "villager"

        let body = SKShapeNode(rectOf: CGSize(width: 28, height: 42), cornerRadius: 7)
        body.fillColor = SKColor(red: 0.30, green: 0.22, blue: 0.18, alpha: 1)
        body.strokeColor = SKColor(red: 0.45, green: 0.32, blue: 0.22, alpha: 0.4)
        body.lineWidth = 1
        root.addChild(body)

        let head = SKShapeNode(circleOfRadius: 11)
        head.fillColor = SKColor(red: 0.58, green: 0.44, blue: 0.34, alpha: 1)
        head.strokeColor = .clear
        head.position = CGPoint(x: 0, y: 28)
        root.addChild(head)

        let eyes = SKShapeNode(rectOf: CGSize(width: 8, height: 3), cornerRadius: 1)
        eyes.fillColor = SKColor(white: 0.9, alpha: 1)
        eyes.strokeColor = .clear
        eyes.position = CGPoint(x: 0, y: 29)
        root.addChild(eyes)

        root.setScale(0.58)
        return root
    }
}
