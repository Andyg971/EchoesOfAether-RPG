import SpriteKit

final class MainMenuScene: SKScene {

    var safeAreaTop: CGFloat = 0
    var safeAreaBottom: CGFloat = 0

    // SaveManager is a static enum — no instance needed
    private var buttonsBuilt = false
    private weak var highlightedButton: SKShapeNode?

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.035, green: 0.030, blue: 0.055, alpha: 1)
        // Pas d'audio dans menu — démarrage dans GameScene seulement
        buildUI()

        // Auto-tap pour test E2E si lancé avec --auto-tap
        if CommandLine.arguments.contains("--auto-tap") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                NSLog("[E2E] Auto-tap newGame")
                SaveManager.deleteSave()
                self?.transitionToGame(newGame: true)
            }
        }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard buttonsBuilt else { return }
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
        let contentTop = h - safeTop - 32
        let contentBottom = safeBottom + 34

        buildRPGBackdrop(w: w, h: h)
        addChild(ParticleFactory.ambientDust(in: size))

        let titleLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        titleLabel.text = String(localized: "menu.title")
        titleLabel.fontSize = min(38, w * 0.095)
        titleLabel.fontColor = SKColor(red: 0.86, green: 0.78, blue: 1, alpha: 1)
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.verticalAlignmentMode = .center
        titleLabel.position = CGPoint(x: w / 2, y: min(h - safeTop - h * 0.22, contentTop - 72))
        titleLabel.zPosition = 20
        addChild(titleLabel)
        JuiceEngine.float(titleLabel, distance: 4)

        let titleGlow = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        titleGlow.text = titleLabel.text
        titleGlow.fontSize = titleLabel.fontSize
        titleGlow.fontColor = SKColor(red: 0.42, green: 0.20, blue: 0.75, alpha: 0.32)
        titleGlow.horizontalAlignmentMode = .center
        titleGlow.position = CGPoint(x: titleLabel.position.x, y: titleLabel.position.y - 2)
        titleGlow.zPosition = 19
        addChild(titleGlow)

        let sub = SKLabelNode(fontNamed: "AvenirNext-MediumItalic")
        sub.text = String(localized: "menu.subtitle")
        sub.fontSize = 13
        sub.fontColor = SKColor(red: 0.74, green: 0.70, blue: 0.82, alpha: 0.78)
        sub.horizontalAlignmentMode = .center
        sub.verticalAlignmentMode = .center
        sub.preferredMaxLayoutWidth = min(w - 48, 360)
        sub.numberOfLines = 2
        sub.position = CGPoint(x: w / 2, y: titleLabel.position.y - 44)
        sub.zPosition = 20
        addChild(sub)

        let primaryY = max(contentBottom + 150, h * (SaveManager.hasSave ? 0.43 : 0.40))
        let newBtn = makeMenuButton(
            label: String(localized: "menu.newGame"),
            fill: SKColor(red: 0.15, green: 0.09, blue: 0.22, alpha: 0.94),
            stroke: SKColor(red: 0.70, green: 0.52, blue: 0.95, alpha: 0.95),
            name: "menuNewGame"
        )
        newBtn.position = CGPoint(x: w / 2, y: primaryY)
        newBtn.zPosition = 20
        addChild(newBtn)
        JuiceEngine.popIn(newBtn, delay: 0.1)

        if SaveManager.hasSave {
            let contBtn = makeMenuButton(
                label: String(localized: "menu.continue"),
                fill: SKColor(red: 0.07, green: 0.12, blue: 0.18, alpha: 0.94),
                stroke: SKColor(red: 0.38, green: 0.68, blue: 0.95, alpha: 0.9),
                name: "menuContinue"
            )
            contBtn.position = CGPoint(x: w / 2, y: max(contentBottom + 78, primaryY - 72))
            contBtn.zPosition = 20
            addChild(contBtn)
            JuiceEngine.popIn(contBtn, delay: 0.2)
        }

        let version = SKLabelNode(fontNamed: "AvenirNext-Regular")
        version.text = String(localized: "menu.version")
        version.fontSize = 10
        version.fontColor = SKColor(white: 0.46, alpha: 0.9)
        version.horizontalAlignmentMode = .center
        version.verticalAlignmentMode = .center
        version.position = CGPoint(x: w / 2, y: contentBottom)
        version.zPosition = 20
        addChild(version)
    }

    // MARK: - Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }
        highlightedButton = menuButton(at: point)
        highlightedButton?.run(.scale(to: 0.96, duration: 0.06))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else {
            clearHighlight()
            return
        }
        defer { clearHighlight() }

        guard let button = highlightedButton, button === menuButton(at: point) else { return }
        HapticsEngine.light()

        switch button.name {
        case "menuNewGame":
            SaveManager.deleteSave()
            transitionToGame(newGame: true)
        case "menuContinue":
            transitionToGame(newGame: false)
        default:
            break
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        clearHighlight()
    }

    // MARK: - Transition

    private func transitionToGame(newGame: Bool) {
        guard let view = self.view else { return }

        let safeTop = safeAreaTop
        let portraitSize = CGSize(
            width: min(view.bounds.width, view.bounds.height),
            height: max(view.bounds.width, view.bounds.height)
        )
        let gameScene = GameScene(size: portraitSize)
        gameScene.scaleMode = .resizeFill
        gameScene.safeAreaTop = safeTop
        gameScene.safeAreaBottom = safeAreaBottom
        view.presentScene(gameScene, transition: .fade(with: .black, duration: 0.5))
    }

    // MARK: - Helpers

    private func buildRPGBackdrop(w: CGFloat, h: CGFloat) {
        let sky = SKShapeNode(rectOf: CGSize(width: w, height: h))
        sky.fillColor = SKColor(red: 0.035, green: 0.030, blue: 0.055, alpha: 1)
        sky.strokeColor = .clear
        sky.position = CGPoint(x: w / 2, y: h / 2)
        sky.zPosition = -20
        addChild(sky)

        let moon = SKShapeNode(circleOfRadius: min(w, h) * 0.105)
        moon.fillColor = SKColor(red: 0.62, green: 0.58, blue: 0.78, alpha: 0.20)
        moon.strokeColor = SKColor(red: 0.82, green: 0.75, blue: 1, alpha: 0.16)
        moon.glowWidth = 12
        moon.position = CGPoint(x: w * 0.74, y: h * 0.80)
        moon.zPosition = -18
        addChild(moon)
        JuiceEngine.pulse(moon, scale: 1.04)

        addBackdropSprite("house_haunted", at: CGPoint(x: w * 0.52, y: h * 0.56), scale: 0.52, alpha: 0.64, z: -12)
        addBackdropSprite("tree_green_72", at: CGPoint(x: w * 0.15, y: h * 0.50), scale: 1.75, alpha: 0.54, z: -11)
        addBackdropSprite("tree_green_100", at: CGPoint(x: w * 0.88, y: h * 0.48), scale: 1.70, alpha: 0.52, z: -11)
        addBackdropSprite("tree_big", at: CGPoint(x: w * 0.03, y: h * 0.30), scale: 1.45, alpha: 0.70, z: -7)
        addBackdropSprite("tree_big", at: CGPoint(x: w * 0.98, y: h * 0.28), scale: 1.55, alpha: 0.72, z: -7)

        let ground = SKShapeNode(rectOf: CGSize(width: w * 1.20, height: h * 0.36), cornerRadius: 0)
        ground.fillColor = SKColor(red: 0.025, green: 0.040, blue: 0.030, alpha: 0.92)
        ground.strokeColor = .clear
        ground.position = CGPoint(x: w / 2, y: h * 0.13)
        ground.zPosition = -6
        addChild(ground)

        let aether = SKShapeNode(ellipseOf: CGSize(width: w * 0.72, height: 34))
        aether.fillColor = SKColor(red: 0.25, green: 0.10, blue: 0.44, alpha: 0.12)
        aether.strokeColor = SKColor(red: 0.68, green: 0.42, blue: 1, alpha: 0.20)
        aether.glowWidth = 8
        aether.position = CGPoint(x: w / 2, y: h * 0.24)
        aether.zPosition = -4
        addChild(aether)
        JuiceEngine.pulse(aether, scale: 1.08)
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

    private func makeMenuButton(label: String,
                                fill: SKColor, stroke: SKColor,
                                name: String) -> SKShapeNode {
        let width = min(max(size.width - 64, 248), 320)
        let btn = SKShapeNode(rectOf: CGSize(width: width, height: 56), cornerRadius: 12)
        btn.fillColor = fill
        btn.strokeColor = stroke
        btn.lineWidth = 2
        btn.glowWidth = 1.5
        btn.name = name

        let inner = SKShapeNode(rectOf: CGSize(width: width - 12, height: 44), cornerRadius: 8)
        inner.fillColor = .clear
        inner.strokeColor = SKColor(white: 1, alpha: 0.10)
        inner.lineWidth = 1
        inner.isUserInteractionEnabled = false
        btn.addChild(inner)

        let lbl = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        lbl.text = label
        lbl.fontSize = 18
        lbl.fontColor = .white
        lbl.verticalAlignmentMode = .center
        lbl.horizontalAlignmentMode = .center
        lbl.isUserInteractionEnabled = false
        btn.addChild(lbl)
        return btn
    }

    private func menuButton(at point: CGPoint) -> SKShapeNode? {
        for node in nodes(at: point) {
            if let button = node as? SKShapeNode, button.name?.hasPrefix("menu") == true {
                return button
            }
            if let button = node.parent as? SKShapeNode, button.name?.hasPrefix("menu") == true {
                return button
            }
        }
        return nil
    }

    private func clearHighlight() {
        highlightedButton?.run(.scale(to: 1.0, duration: 0.08))
        highlightedButton = nil
    }
}
