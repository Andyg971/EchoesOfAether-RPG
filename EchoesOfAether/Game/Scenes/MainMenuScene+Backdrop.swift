import SpriteKit

// MainMenuScene — décor : art du héros, toile de fond RPG pixel, braises.
extension MainMenuScene {
    /// Art de Kael (repris de l'icône de l'app) dans un cadre pixel doré.
    func buildHeroArt(centerX: CGFloat, centerY: CGFloat, maxHeight: CGFloat) {
        guard UIImage(named: "menu_hero") != nil else { return }
        let texture = SKTexture(imageNamed: "menu_hero")
        texture.filteringMode = .nearest
        let aspect = texture.size().width / texture.size().height
        let height = maxHeight
        let width = height * aspect

        let frame = SKShapeNode()
        PixelUI.stylePanel(frame, size: CGSize(width: width + 10, height: height + 10),
                           fill: Palette.panelNight,
                           accent: PixelUI.gold)
        frame.position = CGPoint(x: centerX, y: centerY)
        frame.zPosition = 14
        addChild(frame)

        let hero = SKSpriteNode(texture: texture)
        hero.size = CGSize(width: width, height: height)
        hero.position = frame.position
        hero.zPosition = 15
        addChild(hero)
        JuiceEngine.float(hero, distance: 2)

        // Braises d'Aether qui montent devant le cadre
        let embers = ParticleFactory.ambientDust(in: CGSize(width: width, height: height))
        embers.position = CGPoint(x: centerX - width / 2, y: centerY - height / 2)
        embers.zPosition = 16
        addChild(embers)
    }


    // MARK: - Helpers

    func buildRPGBackdrop(w: CGFloat, h: CGFloat) {
        // Ciel nocturne : dégradé en bandes plates (dithering rétro),
        // de l'indigo profond au violet d'Aether.
        let bands: [(CGFloat, CGFloat, CGFloat)] = [
            (0.030, 0.026, 0.052), (0.040, 0.032, 0.068),
            (0.052, 0.038, 0.086), (0.066, 0.046, 0.104)
        ]
        let bandH = h / CGFloat(bands.count)
        for (i, c) in bands.enumerated() {
            let strip = SKSpriteNode(color: SKColor(red: c.0, green: c.1, blue: c.2, alpha: 1),
                                     size: CGSize(width: w + 4, height: bandH + 2))
            strip.position = CGPoint(x: w / 2, y: h - bandH * (CGFloat(i) + 0.5))
            strip.zPosition = -20
            addChild(strip)
        }

        // Étoiles pixel : petits carrés scintillants, densité faible
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<26 {
            let side = CGFloat(Int.random(in: 2...3, using: &rng))
            let star = SKSpriteNode(
                color: Bool.random(using: &rng)
                    ? SKColor(red: 0.85, green: 0.82, blue: 1.0, alpha: 0.8)
                    : SKColor(red: 0.55, green: 0.80, blue: 0.90, alpha: 0.7),
                size: CGSize(width: side, height: side))
            star.position = CGPoint(x: .random(in: 8...(w - 8), using: &rng),
                                    y: .random(in: h * 0.35...(h - 8), using: &rng))
            star.zPosition = -18
            star.alpha = .random(in: 0.3...0.9, using: &rng)
            addChild(star)
            star.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.15, duration: .random(in: 0.8...2.2, using: &rng)),
                .fadeAlpha(to: 0.85, duration: .random(in: 0.8...2.2, using: &rng))
            ])))
        }

        // Lune pixelisée — uniquement en portrait : en paysage elle
        // passait derrière le titre et le sous-titre.
        if h > w {
            let moon = pixelCircleSprite(pixels: 16,
                                         fill: SKColor(red: 0.62, green: 0.58, blue: 0.78, alpha: 0.38),
                                         rim: SKColor(red: 0.82, green: 0.75, blue: 1, alpha: 0.32))
            moon.size = CGSize(width: min(w, h) * 0.16, height: min(w, h) * 0.16)
            moon.position = CGPoint(x: w * 0.82, y: h * 0.82)
            moon.zPosition = -17
            addChild(moon)
            JuiceEngine.pulse(moon, scale: 1.03)
        }

        // Forêt d'Ébène en silhouettes : deux plans de profondeur
        let backTrees: [(CGFloat, CGFloat)] = [(0.06, 0.66), (0.20, 0.72), (0.38, 0.62),
                                               (0.55, 0.70), (0.72, 0.64), (0.90, 0.70)]
        for (x, s) in backTrees {
            addBackdropSprite("tree_medium_2", at: CGPoint(x: w * x, y: h * 0.16),
                              scale: s, alpha: 0.32, z: -14)
        }
        let frontTrees: [(CGFloat, CGFloat)] = [(0.12, 0.9), (0.46, 0.82), (0.82, 0.92)]
        for (x, s) in frontTrees {
            addBackdropSprite("tree_big", at: CGPoint(x: w * x, y: h * 0.04),
                              scale: s, alpha: 0.5, z: -12)
        }

        // Sol : bande sombre en bas
        let ground = SKSpriteNode(color: SKColor(red: 0.020, green: 0.028, blue: 0.024, alpha: 1),
                                  size: CGSize(width: w * 1.2, height: h * 0.14))
        ground.position = CGPoint(x: w / 2, y: h * 0.05)
        ground.zPosition = -10
        addChild(ground)

        // Brume d'Aether : bandes horizontales plates au ras du sol
        let aether = SKNode()
        for (i, alpha) in [0.08, 0.13, 0.18].enumerated() {
            let strip = SKSpriteNode(
                color: SKColor(red: 0.55, green: 0.34, blue: 0.95, alpha: alpha),
                size: CGSize(width: w * (0.9 - CGFloat(i) * 0.15), height: 7))
            strip.position = CGPoint(x: 0, y: CGFloat(i) * 7 - 7)
            aether.addChild(strip)
        }
        aether.position = CGPoint(x: w / 2, y: h * 0.14)
        aether.zPosition = -9
        addChild(aether)
        JuiceEngine.pulse(aether, scale: 1.06)
    }

    /// Sprite cercle pixel art : dessiné à `pixels` px de côté puis
    /// upscalé en `.nearest` — chaque pixel source devient un gros bloc.
    func pixelCircleSprite(pixels: Int, fill: SKColor, rim: SKColor) -> SKSpriteNode {
        let side = CGFloat(pixels)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side),
                                               format: {
            let f = UIGraphicsImageRendererFormat()
            f.scale = 1
            return f
        }())
        let image = renderer.image { ctx in
            rim.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: side, height: side))
            fill.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 1, y: 1, width: side - 2, height: side - 2))
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        return SKSpriteNode(texture: texture)
    }

    func addBackdropSprite(_ name: String, at position: CGPoint,
                                   scale: CGFloat, alpha: CGFloat, z: CGFloat) {
        guard let sprite = PixelArtSprites.still(name: name, scale: scale,
                                                  anchor: CGPoint(x: 0.5, y: 0.0)) else { return }
        sprite.position = position
        sprite.alpha = alpha
        sprite.zPosition = z
        addChild(sprite)
    }
}
