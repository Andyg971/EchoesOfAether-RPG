import SpriteKit

final class MainMenuScene: SKScene {

    var safeAreaTop: CGFloat = 0
    var safeAreaBottom: CGFloat = 0
    var safeAreaLeft: CGFloat = 0
    var safeAreaRight: CGFloat = 0

    private var buttonsBuilt = false
    weak var highlightedButton: SKShapeNode?
    /// Slot en attente de confirmation de suppression (nil = aucun).
    var confirmDeleteSlot: Int?

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
        // ⚠️ Tout drapeau d'audit ajouté dans `GameManager.setup` doit AUSSI
        // figurer ici, sinon il ne se déclenche jamais : le jeu reste sur le
        // menu de sélection de sauvegarde et le drapeau n'est jamais lu.
        let debugZoneArgs = ["--combat-test", "--combat-multi", "--boss-test",
                             "--archivist-test",
                             "--zone-forest", "--zone-shrine", "--zone-ruins",
                             "--zone-village", "--zone-threshold", "--zone-voidheart",
                             "--zone-mines", "--zone-desert", "--zone-cave",
                             "--zone-overworld",
                             "--combat-trio", "--interior", "--lyra-death",
                             "--bubble-test"]
        if CommandLine.arguments.contains(where: debugZoneArgs.contains) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                SaveManager.delete(slot: 2)
                self?.transitionToGame(slot: 2, newGame: true)
            }
        }

        // Test New Game+ : --ngplus N démarre une partie NG+ palier N sur le
        // slot 2 (le seed synthétique est construit dans GameManager.setup).
        if CommandLine.arguments.contains("--ngplus") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                SaveManager.delete(slot: 2)
                self?.transitionToGame(slot: 2, newGame: true)
            }
        }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        applySafeAreaLayout()
    }

    /// Reconstruit le menu avec les marges courantes.
    ///
    /// Une rotation paysage gauche ↔ droite garde la même taille de scène —
    /// `didChangeSize` ne se déclenche donc pas — alors que l'encoche passe
    /// d'un bord à l'autre. Le contrôleur appelle cette méthode explicitement,
    /// et seulement quand la géométrie a réellement changé (reconstruire à
    /// chaque passe de layout annulerait la confirmation de suppression).
    func applySafeAreaLayout() {
        guard buttonsBuilt else { return }
        confirmDeleteSlot = nil
        removeAllChildren()
        buildUI()
    }

    // MARK: - Build

    func buildUI() {
        buttonsBuilt = true
        let w = size.width
        let h = size.height
        let safeTop = max(safeAreaTop, 0)
        let safeBottom = max(safeAreaBottom, 0)
        let contentTop = h - safeTop - 20
        let contentBottom = safeBottom + 26

        buildRPGBackdrop(w: w, h: h)
        addChild(ParticleFactory.ambientDust(in: size))
        // Ambiance cinématique : éclats d'Aether qui s'élèvent + oiseaux
        // lointains qui traversent le ciel d'Ébène.
        addChild(ParticleFactory.aetherMotes(in: size))
        let flock = AmbientLife.birds(in: size, flocks: 1)
        flock.zPosition = -13   // derrière les arbres de premier plan
        addChild(flock)

        // Paysage : Kael (art de l'icône) à gauche, titre + slots à droite.
        // Portrait (fallback) : tout centré, héros omis.
        let landscape = w > h
        let heroZoneWidth = landscape ? w * 0.38 : 0
        let columnCenterX = landscape ? heroZoneWidth + (w - heroZoneWidth) / 2 : w / 2

        if landscape {
            buildHeroArt(centerX: max(heroZoneWidth * 0.52, 110),
                         centerY: h * 0.52, maxHeight: h * 0.86)
        }

        // Lueur d'Aether pulsante derrière le titre (halo pixel .nearest).
        let titleGlow = LightingEngine.pointLight(
            radius: landscape ? 150 : 130,
            color: SKColor(red: 0.62, green: 0.42, blue: 0.98, alpha: 1),
            intensity: 2.2)
        titleGlow.position = CGPoint(x: columnCenterX, y: contentTop - 18)
        titleGlow.alpha = 0.5
        titleGlow.zPosition = 15
        addChild(titleGlow)
        titleGlow.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.32, duration: 2.2),
            .fadeAlpha(to: 0.5, duration: 2.2)
        ])))

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

    // MARK: - Transition

    func transitionToGame(slot: Int, newGame: Bool,
                                  seed: NewGamePlusSeed? = nil) {
        guard let view = self.view else { return }
        if newGame {
            // Nouvelle partie dans ce slot : on efface toute sauvegarde résiduelle.
            // (Le seed NG+ a déjà été lu depuis cette save avant l'effacement.)
            SaveManager.delete(slot: slot)
        }

        let gameScene = GameScene(size: Viewport.sceneSize(for: view.bounds.size))
        gameScene.scaleMode = .aspectFill
        gameScene.safeAreaTop = safeAreaTop
        gameScene.safeAreaBottom = safeAreaBottom
        gameScene.safeAreaLeft = safeAreaLeft
        gameScene.safeAreaRight = safeAreaRight
        gameScene.activeSlot = slot
        gameScene.newGamePlusSeed = seed
        view.presentScene(gameScene, transition: .fade(with: .black, duration: 0.5))
    }

}
