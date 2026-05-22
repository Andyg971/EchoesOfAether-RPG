import SpriteKit

final class MainMenuScene: SKScene {

    var safeAreaTop: CGFloat = 0

    // SaveManager is a static enum — no instance needed
    private var buttonsBuilt = false

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.05, green: 0.04, blue: 0.09, alpha: 1)
        // Pas d'audio dans menu — démarrage dans GameScene seulement
        buildUI()
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

        // --- Particules ambiantes ---
        addChild(ParticleFactory.ambientDust(in: size))

        // --- Titre ---
        let titleLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        titleLabel.text = String(localized: "menu.title")
        titleLabel.fontSize = 32
        titleLabel.fontColor = SKColor(red: 0.78, green: 0.68, blue: 1, alpha: 1)
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.position = CGPoint(x: w / 2, y: h * 0.72)
        titleLabel.zPosition = 10
        addChild(titleLabel)
        JuiceEngine.float(titleLabel, distance: 4)

        // Sous-titre / citation
        let sub = SKLabelNode(fontNamed: "AvenirNext-MediumItalic")
        sub.text = String(localized: "menu.subtitle")
        sub.fontSize = 13
        sub.fontColor = SKColor(white: 0.45, alpha: 1)
        sub.horizontalAlignmentMode = .center
        sub.position = CGPoint(x: w / 2, y: h * 0.65)
        sub.zPosition = 10
        addChild(sub)

        // --- Bouton Nouvelle Partie ---
        let newBtn = makeMenuButton(
            label: String(localized: "menu.newGame"),
            fill: SKColor(red: 0.12, green: 0.08, blue: 0.20, alpha: 1),
            stroke: SKColor(red: 0.55, green: 0.40, blue: 0.85, alpha: 0.9),
            name: "menuNewGame"
        )
        newBtn.position = CGPoint(x: w / 2, y: h * 0.50)
        newBtn.zPosition = 10
        addChild(newBtn)
        JuiceEngine.popIn(newBtn, delay: 0.1)

        // --- Bouton Continuer (si save existe) ---
        if SaveManager.hasSave {
            let contBtn = makeMenuButton(
                label: String(localized: "menu.continue"),
                fill: SKColor(red: 0.06, green: 0.10, blue: 0.18, alpha: 1),
                stroke: SKColor(red: 0.30, green: 0.55, blue: 0.85, alpha: 0.9),
                name: "menuContinue"
            )
            contBtn.position = CGPoint(x: w / 2, y: h * 0.39)
            contBtn.zPosition = 10
            addChild(contBtn)
            JuiceEngine.popIn(contBtn, delay: 0.2)
        }

        // Version
        let version = SKLabelNode(fontNamed: "AvenirNext-Regular")
        version.text = String(localized: "menu.version")
        version.fontSize = 10
        version.fontColor = SKColor(white: 0.30, alpha: 1)
        version.horizontalAlignmentMode = .center
        version.position = CGPoint(x: w / 2, y: 24)
        version.zPosition = 10
        addChild(version)

        // Dégradé décoratif en bas
        addBottomGradient(w: w, h: h)
    }

    // MARK: - Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }

        for node in nodes(at: point) {
            let btnName = node.name ?? node.parent?.name ?? ""
            switch btnName {
            case "menuNewGame":
                SaveManager.deleteSave()
                transitionToGame(newGame: true)
                return
            case "menuContinue":
                transitionToGame(newGame: false)
                return
            default:
                break
            }
        }
    }

    // MARK: - Transition

    private func transitionToGame(newGame: Bool) {
        guard let view = self.view else { return }

        // Capture avant la closure pour éviter les problèmes Swift 6
        let safeTop = safeAreaTop
        let portraitSize = CGSize(
            width: min(view.bounds.width, view.bounds.height),
            height: max(view.bounds.width, view.bounds.height)
        )
        let gameScene = GameScene(size: portraitSize)
        gameScene.scaleMode = .resizeFill
        gameScene.safeAreaTop = safeTop
        view.presentScene(gameScene, transition: .fade(with: .black, duration: 0.5))
    }

    // MARK: - Helpers

    private func makeMenuButton(label: String,
                                fill: SKColor, stroke: SKColor,
                                name: String) -> SKShapeNode {
        let btn = SKShapeNode(rectOf: CGSize(width: 240, height: 52), cornerRadius: 16)
        btn.fillColor = fill
        btn.strokeColor = stroke
        btn.lineWidth = 2
        btn.name = name

        let lbl = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        lbl.text = label
        lbl.fontSize = 17
        lbl.fontColor = .white
        lbl.verticalAlignmentMode = .center
        lbl.horizontalAlignmentMode = .center
        lbl.isUserInteractionEnabled = false
        btn.addChild(lbl)
        return btn
    }

    private func addBottomGradient(w: CGFloat, h: CGFloat) {
        let grad = SKShapeNode(rectOf: CGSize(width: w, height: h * 0.25))
        grad.fillColor = SKColor(red: 0.02, green: 0.02, blue: 0.05, alpha: 0.8)
        grad.strokeColor = .clear
        grad.position = CGPoint(x: w / 2, y: h * 0.125)
        grad.zPosition = 5
        addChild(grad)
    }
}
