import SpriteKit

final class MainMenuScene: SKScene {

    var safeAreaTop: CGFloat = 0
    var safeAreaBottom: CGFloat = 0
    var safeAreaLeft: CGFloat = 0
    var safeAreaRight: CGFloat = 0

    private var buttonsBuilt = false
    private weak var highlightedButton: SKShapeNode?
    /// Slot en attente de confirmation de suppression (nil = aucun).
    private var confirmDeleteSlot: Int?

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.035, green: 0.030, blue: 0.055, alpha: 1)
        // Thème d'écran-titre (CC0 « A Legend Will Rise »)
        AudioEngine.shared.start()
        AudioEngine.shared.setMood(.title)
        // Migration de l'ancienne sauvegarde unique vers le slot 1 (une fois).
        SaveManager.migrateLegacyIfNeeded()
        // iCloud : rapatrie les saves plus récentes d'un autre appareil.
        SaveManager.syncFromCloudIfNewer()
        buildUI()

        // Auto-tap pour test E2E si lancé avec --auto-tap
        if CommandLine.arguments.contains("--auto-tap") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                NSLog("[E2E] Auto-tap newGame")
                SaveManager.delete(slot: 1)
                self?.transitionToGame(slot: 1, newGame: true)
            }
        }

        // Audit visuel : les args --combat/--boss/--zone-* sautent le menu
        // sur le slot 2 (scratch) sans toucher aux sauvegardes joueur.
        let debugZoneArgs = ["--combat-test", "--combat-multi", "--boss-test",
                             "--zone-forest", "--zone-shrine", "--zone-ruins",
                             "--zone-village", "--zone-threshold", "--zone-voidheart",
                             "--zone-mines", "--combat-trio",
                             "--interior"]
        if CommandLine.arguments.contains(where: debugZoneArgs.contains) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                SaveManager.delete(slot: 2)
                self?.transitionToGame(slot: 2, newGame: true)
            }
        }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard buttonsBuilt else { return }
        confirmDeleteSlot = nil
        removeAllChildren()
        buildUI()
    }

    // MARK: - Build

    private func buildUI() {
        buttonsBuilt = true
        let w = size.width
        let h = size.height
        let safeTop = max(safeAreaTop, 0)
        let safeBottom = max(safeAreaBottom, 0)
        let contentTop = h - safeTop - 20
        let contentBottom = safeBottom + 26

        buildRPGBackdrop(w: w, h: h)
        addChild(ParticleFactory.ambientDust(in: size))

        // Paysage : Kael (art de l'icône) à gauche, titre + slots à droite.
        // Portrait (fallback) : tout centré, héros omis.
        let landscape = w > h
        let heroZoneWidth = landscape ? w * 0.38 : 0
        let columnCenterX = landscape ? heroZoneWidth + (w - heroZoneWidth) / 2 : w / 2

        if landscape {
            buildHeroArt(centerX: max(heroZoneWidth * 0.52, 110),
                         centerY: h * 0.52, maxHeight: h * 0.86)
        }

        // Titre pixel : VT323 + ombre dure décalée (pas de glow flou).
        let titleLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
        titleLabel.text = String(localized: "menu.title")
        titleLabel.fontSize = landscape ? min(46, (w - heroZoneWidth) * 0.105) : min(44, w * 0.11)
        titleLabel.fontColor = SKColor(red: 0.88, green: 0.80, blue: 1, alpha: 1)
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.verticalAlignmentMode = .center
        titleLabel.position = CGPoint(x: columnCenterX, y: contentTop - 18)
        titleLabel.zPosition = 20
        addChild(titleLabel)
        JuiceEngine.float(titleLabel, distance: 3)

        let titleShadow = SKLabelNode(fontNamed: PixelUI.uiFont)
        titleShadow.text = titleLabel.text
        titleShadow.fontSize = titleLabel.fontSize
        titleShadow.fontColor = SKColor(red: 0.20, green: 0.10, blue: 0.38, alpha: 0.95)
        titleShadow.horizontalAlignmentMode = .center
        titleShadow.verticalAlignmentMode = .center
        titleShadow.position = CGPoint(x: titleLabel.position.x + 3, y: titleLabel.position.y - 3)
        titleShadow.zPosition = 19
        addChild(titleShadow)
        JuiceEngine.float(titleShadow, distance: 3)

        // Filet doré sous le titre, façon écran-titre SNES
        let rule = SKSpriteNode(color: PixelUI.gold.withAlphaComponent(0.55),
                                size: CGSize(width: min(w - heroZoneWidth - 60, 300), height: 2))
        rule.position = CGPoint(x: columnCenterX, y: titleLabel.position.y - 22)
        rule.zPosition = 20
        addChild(rule)

        let sub = SKLabelNode(fontNamed: PixelUI.uiFont)
        sub.text = String(localized: "menu.subtitle")
        sub.fontSize = 15
        sub.fontColor = SKColor(red: 0.76, green: 0.72, blue: 0.86, alpha: 0.9)
        sub.horizontalAlignmentMode = .center
        sub.verticalAlignmentMode = .center
        sub.preferredMaxLayoutWidth = landscape ? (w - heroZoneWidth - 48) : min(w - 48, 380)
        sub.numberOfLines = 2
        sub.position = CGPoint(x: columnCenterX, y: rule.position.y - 16)
        sub.zPosition = 20
        addChild(sub)

        // Empilement vertical des slots sous le sous-titre.
        let count = SaveManager.slotCount
        let spacing: CGFloat = 10
        let zoneTop = sub.position.y - 18
        let zoneBottom = contentBottom + 16
        let availH = max(zoneTop - zoneBottom, 120)
        let rowHeight = min(60, max(46, (availH - CGFloat(count - 1) * spacing) / CGFloat(count)))
        let topRowY = zoneTop - rowHeight / 2

        for i in 0..<count {
            let slot = i + 1
            let rowY = topRowY - CGFloat(i) * (rowHeight + spacing)
            let row = makeSlotRow(slot: slot, height: rowHeight,
                                  width: landscape
                                      ? min(w - heroZoneWidth - 44, 380)
                                      : min(max(w - 56, 268), 360))
            row.position = CGPoint(x: columnCenterX, y: rowY)
            row.zPosition = 20
            addChild(row)
            JuiceEngine.popIn(row, delay: 0.1 + Double(i) * 0.08)
        }

        let version = SKLabelNode(fontNamed: PixelUI.uiFont)
        version.text = String(localized: "menu.version")
        version.fontSize = 12
        version.fontColor = SKColor(white: 0.46, alpha: 0.9)
        version.horizontalAlignmentMode = .center
        version.verticalAlignmentMode = .center
        version.position = CGPoint(x: columnCenterX, y: contentBottom - 6)
        version.zPosition = 20
        addChild(version)
    }

    /// Art de Kael (repris de l'icône de l'app) dans un cadre pixel doré.
    private func buildHeroArt(centerX: CGFloat, centerY: CGFloat, maxHeight: CGFloat) {
        guard UIImage(named: "menu_hero") != nil else { return }
        let texture = SKTexture(imageNamed: "menu_hero")
        texture.filteringMode = .nearest
        let aspect = texture.size().width / texture.size().height
        let height = maxHeight
        let width = height * aspect

        let frame = SKShapeNode()
        PixelUI.stylePanel(frame, size: CGSize(width: width + 10, height: height + 10),
                           fill: SKColor(red: 0.10, green: 0.08, blue: 0.18, alpha: 1),
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

    // MARK: - Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }
        highlightedButton = slotRow(at: point)
        highlightedButton?.run(.scale(to: 0.97, duration: 0.06))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else {
            clearHighlight()
            return
        }
        defer { clearHighlight() }

        // 1) Bouton de suppression (prioritaire sur la ligne)
        if let slot = deleteSlot(at: point) {
            handleDeleteTap(slot: slot)
            return
        }

        // 2) Tap sur une ligne de slot
        guard let row = slotRow(at: point), row === highlightedButton,
              let slot = row.userData?["slot"] as? Int else {
            resetDeleteConfirmIfNeeded()
            return
        }
        resetDeleteConfirmIfNeeded()
        HapticsEngine.light()
        if SaveManager.hasSave(slot: slot) {
            transitionToGame(slot: slot, newGame: false)
        } else {
            transitionToGame(slot: slot, newGame: true)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        clearHighlight()
    }

    private func handleDeleteTap(slot: Int) {
        HapticsEngine.heavy()
        if confirmDeleteSlot == slot {
            // Deuxième tap : suppression effective.
            SaveManager.delete(slot: slot)
            confirmDeleteSlot = nil
            HapticsEngine.error()
            rebuild()
        } else {
            confirmDeleteSlot = slot
            rebuild()
        }
    }

    private func resetDeleteConfirmIfNeeded() {
        guard confirmDeleteSlot != nil else { return }
        confirmDeleteSlot = nil
        rebuild()
    }

    private func rebuild() {
        removeAllChildren()
        buildUI()
    }

    // MARK: - Transition

    private func transitionToGame(slot: Int, newGame: Bool) {
        guard let view = self.view else { return }
        if newGame {
            // Nouvelle partie dans ce slot : on efface toute sauvegarde résiduelle.
            SaveManager.delete(slot: slot)
        }

        let gameScene = GameScene(size: view.bounds.size)
        gameScene.scaleMode = .resizeFill
        gameScene.safeAreaTop = safeAreaTop
        gameScene.safeAreaBottom = safeAreaBottom
        gameScene.safeAreaLeft = safeAreaLeft
        gameScene.safeAreaRight = safeAreaRight
        gameScene.activeSlot = slot
        view.presentScene(gameScene, transition: .fade(with: .black, duration: 0.5))
    }

    // MARK: - Slot row

    private func makeSlotRow(slot: Int, height: CGFloat, width: CGFloat) -> SKShapeNode {
        let hasSave = SaveManager.hasSave(slot: slot)

        // Cadre pixel SNES : coins carrés, double bordure, zéro glow.
        let row = SKShapeNode()
        PixelUI.stylePanel(row, size: CGSize(width: width, height: height),
                           fill: hasSave
                               ? SKColor(red: 0.07, green: 0.12, blue: 0.18, alpha: 0.97)
                               : SKColor(red: 0.13, green: 0.09, blue: 0.20, alpha: 0.97),
                           accent: hasSave
                               ? SKColor(red: 0.38, green: 0.68, blue: 0.95, alpha: 0.9)
                               : SKColor(red: 0.62, green: 0.46, blue: 0.92, alpha: 0.85))
        row.name = "slotRow\(slot)"
        row.userData = ["slot": slot]

        let leftX = -width / 2 + 18

        let titleL = SKLabelNode(fontNamed: PixelUI.uiFont)
        titleL.text = String(localized: "menu.slot \(slot)")
        titleL.fontSize = 22
        titleL.fontColor = .white
        titleL.horizontalAlignmentMode = .left
        titleL.verticalAlignmentMode = .center
        titleL.position = CGPoint(x: leftX, y: 11)
        titleL.isUserInteractionEnabled = false
        row.addChild(titleL)

        let subL = SKLabelNode(fontNamed: PixelUI.uiFont)
        if hasSave, let meta = SaveManager.metadata(slot: slot) {
            subL.text = String(localized: "menu.slot.meta \(phaseDisplayName(meta.phase)) \(meta.level) \(meta.gold)")
            subL.fontColor = SKColor(red: 0.70, green: 0.80, blue: 0.92, alpha: 0.95)
        } else {
            subL.text = String(localized: "menu.newGame")
            subL.fontColor = SKColor(red: 0.80, green: 0.72, blue: 0.95, alpha: 0.9)
        }
        subL.fontSize = 15
        subL.horizontalAlignmentMode = .left
        subL.verticalAlignmentMode = .center
        subL.position = CGPoint(x: leftX, y: -12)
        subL.isUserInteractionEnabled = false
        row.addChild(subL)

        // Bouton suppression (uniquement si une sauvegarde existe)
        if hasSave {
            let confirming = confirmDeleteSlot == slot
            // Carré pixel (pas de cercle : le rond casse le style rétro).
            let delBtn = SKShapeNode(rect: CGRect(x: -15, y: -15, width: 30, height: 30))
            delBtn.fillColor = confirming
                ? SKColor(red: 0.55, green: 0.10, blue: 0.10, alpha: 1)
                : SKColor(red: 0.16, green: 0.08, blue: 0.10, alpha: 1)
            delBtn.strokeColor = confirming
                ? SKColor(red: 1.0, green: 0.30, blue: 0.25, alpha: 1)
                : SKColor(red: 0.65, green: 0.25, blue: 0.25, alpha: 0.9)
            delBtn.lineWidth = 2
            delBtn.glowWidth = 0
            delBtn.name = "slotDelete\(slot)"
            delBtn.userData = ["slot": slot]
            delBtn.position = CGPoint(x: width / 2 - 26, y: 0)

            let delLbl = SKLabelNode(fontNamed: PixelUI.uiFont)
            delLbl.text = confirming ? "?" : "✕"
            delLbl.fontSize = confirming ? 20 : 17
            delLbl.fontColor = .white
            delLbl.verticalAlignmentMode = .center
            delLbl.horizontalAlignmentMode = .center
            delLbl.isUserInteractionEnabled = false
            delBtn.addChild(delLbl)
            row.addChild(delBtn)

            if confirming {
                let hint = SKLabelNode(fontNamed: PixelUI.uiFont)
                hint.text = String(localized: "menu.slot.deleteConfirm")
                hint.fontSize = 12
                hint.fontColor = SKColor(red: 1.0, green: 0.45, blue: 0.40, alpha: 1)
                hint.horizontalAlignmentMode = .right
                hint.verticalAlignmentMode = .center
                hint.position = CGPoint(x: width / 2 - 50, y: 0)
                hint.isUserInteractionEnabled = false
                row.addChild(hint)
            }
        }

        return row
    }

    /// Nom court de la phase pour l'affichage du slot.
    private func phaseDisplayName(_ phase: GamePhase) -> String {
        switch phase {
        case .wake:     return String(localized: "menu.phase.wake")
        case .village:  return String(localized: "menu.phase.village")
        case .forest:   return String(localized: "menu.phase.forest")
        case .shrine:   return String(localized: "menu.phase.shrine")
        case .complete: return String(localized: "menu.phase.complete")
        case .act2:     return String(localized: "menu.phase.act2")
        case .ruins:    return String(localized: "menu.phase.ruins")
        case .fallen:   return String(localized: "menu.phase.fallen")
        case .act3:     return String(localized: "menu.phase.act3")
        case .act4:     return String(localized: "menu.phase.act4")
        }
    }

    // MARK: - Helpers

    private func buildRPGBackdrop(w: CGFloat, h: CGFloat) {
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
    private func pixelCircleSprite(pixels: Int, fill: SKColor, rim: SKColor) -> SKSpriteNode {
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

    private func addBackdropSprite(_ name: String, at position: CGPoint,
                                   scale: CGFloat, alpha: CGFloat, z: CGFloat) {
        guard let sprite = PixelArtSprites.still(name: name, scale: scale,
                                                  anchor: CGPoint(x: 0.5, y: 0.0)) else { return }
        sprite.position = position
        sprite.alpha = alpha
        sprite.zPosition = z
        addChild(sprite)
    }

    /// Renvoie la ligne de slot touchée (en remontant au parent si besoin).
    private func slotRow(at point: CGPoint) -> SKShapeNode? {
        for node in nodes(at: point) {
            if let row = node as? SKShapeNode, row.name?.hasPrefix("slotRow") == true {
                return row
            }
            var parent = node.parent
            while let p = parent {
                if let row = p as? SKShapeNode, row.name?.hasPrefix("slotRow") == true {
                    return row
                }
                parent = p.parent
            }
        }
        return nil
    }

    /// Renvoie le slot dont le bouton de suppression a été touché.
    private func deleteSlot(at point: CGPoint) -> Int? {
        for node in nodes(at: point) {
            if let btn = node as? SKShapeNode, btn.name?.hasPrefix("slotDelete") == true,
               let slot = btn.userData?["slot"] as? Int {
                return slot
            }
            if let btn = node.parent as? SKShapeNode, btn.name?.hasPrefix("slotDelete") == true,
               let slot = btn.userData?["slot"] as? Int {
                return slot
            }
        }
        return nil
    }

    private func clearHighlight() {
        highlightedButton?.run(.scale(to: 1.0, duration: 0.08))
        highlightedButton = nil
    }
}
