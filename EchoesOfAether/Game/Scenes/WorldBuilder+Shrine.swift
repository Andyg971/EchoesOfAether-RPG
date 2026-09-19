import SpriteKit

// Sanctuaire.
// Extrait de WorldBuilder.swift (découpage du monolithe).
@MainActor
extension WorldBuilder {
    // MARK: - Sanctuaire

    /// SANCTUAIRE DE LA SOURCE (Acte I) — parvis de dalles violettes,
    /// allée de chandeliers vers la chapelle gothique à l'est, portail à
    /// orbe rouge = seuil du boss (trigger gameplay : x > 0.55w).
    func buildShrine(in scene: SKScene) {
        let w = scene.size.width
        let h = scene.size.height

        // Sol : dalles de pierre teintées violet nuit
        addTiledFloor(in: scene,
                      tileNames: ["a2_stone"],
                      fallbackColor: SKColor(red: 0.05, green: 0.04, blue: 0.10, alpha: 1),
                      tileScale: 1.0,
                      tint: SKColor(red: 0.20, green: 0.12, blue: 0.34, alpha: 1),
                      z: -10,
                      overrideSize: CGSize(width: w + 96, height: h + 96))

        // Allée processionnelle ouest→est (dalles plus claires vers le boss)
        let tile: CGFloat = 24
        for c in 0..<Int(ceil(w * 0.70 / tile)) {
            for r in 0..<3 {
                guard let t = PixelArtSprites.still(name: "a2_stone", scale: 0.5,
                                                     anchor: CGPoint(x: 0.5, y: 0.5)) else { continue }
                t.position = CGPoint(x: (CGFloat(c) + 0.5) * tile,
                                      y: h * 0.44 + (CGFloat(r) + 0.5) * tile)
                t.zPosition = -9.5
                t.forEachDescendantSprite { sprite in
                    sprite.color = SKColor(red: 0.42, green: 0.34, blue: 0.58, alpha: 1)
                    sprite.colorBlendFactor = 0.35
                }
                add(t, to: scene)
            }
        }

        // ── CHAPELLE DE LA SOURCE (fond est) + portail ──
        addPixelProp("gy_chapel", in: scene, at: CGPoint(x: w * 0.84, y: h * 0.42), scale: 0.55)
        // Portail teinté pierre-violet : neutralise l'orbe rouge de l'asset
        // (Andy ne veut aucun halo lumineux rouge sur la zone du boss).
        if let gate = PixelArtSprites.still(name: "gy_gate_big", scale: 0.50,
                                            anchor: CGPoint(x: 0.5, y: 0.0)) {
            gate.position = CGPoint(x: w * 0.66, y: h * 0.42)
            gate.zPosition = propLayer(for: h * 0.42, in: scene.size.height)
            gate.forEachDescendantSprite { sprite in
                sprite.color = SKColor(red: 0.42, green: 0.38, blue: 0.54, alpha: 1)
                sprite.colorBlendFactor = 0.6
            }
            // L'orbe rouge est peint dans l'asset (haut-centre, ~y=210 sur
            // 240px de haut, anchor pieds). On le recouvre d'un carré pierre
            // ancré AU SPRITE (position locale → suit le scale sans calcul écran).
            if let sprite = gate.children.compactMap({ $0 as? SKSpriteNode }).first {
                let cap = SKSpriteNode(color: SKColor(red: 0.34, green: 0.31, blue: 0.42, alpha: 1),
                                       size: CGSize(width: 48, height: 46))
                cap.position = CGPoint(x: 0, y: 214)   // coords locales asset
                cap.zPosition = 1
                sprite.addChild(cap)
            }
            add(gate, to: scene)
            registerFootprint(of: gate, widthRatio: 0.86, depthRatio: 0.9, maxDepth: 200)
        }

        // Statues anges gardant le portail
        addPixelProp("me_statue_angel", in: scene, at: CGPoint(x: w * 0.58, y: h * 0.30), scale: 0.22)
        addPixelProp("me_statue_angel", in: scene, at: CGPoint(x: w * 0.58, y: h * 0.58), scale: 0.22, flipped: true)

        // ── ALLÉE DE CHANDELIERS (guident vers l'est) ──
        for x in [0.16, 0.32, 0.48] {
            addPixelProp("gy_candle", in: scene, at: CGPoint(x: w * CGFloat(x), y: h * 0.56), scale: 0.55)
            addPixelProp("gy_candle", in: scene, at: CGPoint(x: w * CGFloat(x), y: h * 0.32), scale: 0.55)
        }

        // ── CIMETIÈRE ANCIEN (sud + nord du parvis) ──
        let graves: [(String, CGFloat, CGFloat, CGFloat)] = [
            ("gy_cross_grey", 0.10, 0.72, 0.55), ("gy_tomb_grey_1", 0.20, 0.78, 0.55),
            ("gy_tomb_black", 0.30, 0.70, 0.55), ("gy_tomb_grey_2", 0.42, 0.76, 0.55),
            ("gy_cross_black", 0.54, 0.72, 0.55), ("gy_tomb_grey_1", 0.66, 0.78, 0.55),
            ("gy_tomb_grey_2", 0.12, 0.14, 0.55), ("gy_cross_grey", 0.26, 0.10, 0.55),
            ("gy_tomb_black", 0.40, 0.14, 0.55), ("gy_tomb_grey_1", 0.52, 0.10, 0.55),
            ("gy_stone_1", 0.35, 0.24, 0.50), ("gy_stone_2", 0.60, 0.68, 0.50),
            ("gy_stone_3", 0.08, 0.40, 0.50)
        ]
        for (asset, x, y, s) in graves {
            addPixelProp(asset, in: scene, at: CGPoint(x: w * x, y: h * y), scale: s)
        }

        // Arbres morts tordus (la Source se meurt)
        addPixelProp("gy_tree", in: scene, at: CGPoint(x: w * 0.06, y: h * 0.80), scale: 0.55)
        addPixelProp("gy_tree", in: scene, at: CGPoint(x: w * 0.30, y: h * 0.86), scale: 0.48, flipped: true)
        addPixelProp("gy_tree", in: scene, at: CGPoint(x: w * 0.10, y: h * 0.04), scale: 0.50)

        // Cristal de sauvegarde (entrée ouest — safe spot avant le boss)
        addSaveCrystal(at: CGPoint(x: w * 0.18, y: h * 0.20), in: scene)

        // Sortie ouest : retour vers la forêt (halo + panneau)
        let exitGlow = SKShapeNode(circleOfRadius: 30)
        exitGlow.fillColor = SKColor(red: 0.45, green: 0.75, blue: 0.55, alpha: 0.12)
        exitGlow.strokeColor = SKColor(red: 0.55, green: 0.85, blue: 0.60, alpha: 0.28)
        exitGlow.lineWidth = 1
        exitGlow.position = CGPoint(x: w * 0.06, y: h * 0.46)
        exitGlow.zPosition = -1
        add(exitGlow, to: scene)
        JuiceEngine.pulse(exitGlow, scale: 1.25)
        let exitLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
        exitLabel.text = String(localized: "world.shrine.exit")
        exitLabel.fontSize = 11
        exitLabel.fontColor = SKColor(white: 0.75, alpha: 0.75)
        exitLabel.position = CGPoint(x: w * 0.06, y: h * 0.40)
        exitLabel.zPosition = -1
        add(exitLabel, to: scene)

        addAtmosphere(ParticleFactory.shrineAura(in: scene.size), to: scene)
        setZoneVignette(in: scene, alpha: 0.40)
        LightingEngine.applyGrade(.shrine, in: scene)
        debugDrawObstacles(in: scene)   // --show-obstacles : audit (shrine)
        AudioEngine.shared.setAmbience(.none)
    }
}
