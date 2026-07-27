import SpriteKit
import UIKit

final class GameViewController: UIViewController {
    private var didPresentScene = false
    /// Dernière géométrie propagée aux scènes (taille de vue + marges).
    private var lastApplied: (size: CGSize, insets: UIEdgeInsets)?

    override func loadView() {
        let skView = SKView(frame: UIScreen.main.bounds)
        skView.backgroundColor = .black
        skView.ignoresSiblingOrder = true
        skView.preferredFramesPerSecond = 60
        skView.shouldCullNonVisibleNodes = true
        view = skView
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        guard let skView = view as? SKView else { return }
        let bounds = skView.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }

        let insets = view.safeAreaInsets
        // `viewDidLayoutSubviews` est appelé très souvent : on ne repropage que
        // si la géométrie a bougé — sinon le menu principal, qui se reconstruit
        // à chaque passe, perdrait sa confirmation de suppression de slot.
        // Les insets font partie de la comparaison : une rotation paysage
        // gauche ↔ droite garde la MÊME taille mais fait passer l'encoche d'un
        // bord à l'autre.
        if didPresentScene, let dernier = lastApplied,
           dernier.size == bounds.size, dernier.insets == insets {
            return
        }
        lastApplied = (bounds.size, insets)

        // Résolution virtuelle : la scène garde le gabarit iPhone, SpriteKit
        // met tout à l'échelle (cf. Viewport). Les marges de sécurité,
        // exprimées en points de vue, passent dans le même repère.
        let sceneSize = Viewport.sceneSize(for: bounds.size)
        let safeTop = Viewport.sceneInset(insets.top, for: bounds.size)
        let safeBottom = Viewport.sceneInset(insets.bottom, for: bounds.size)
        let safeLeft = Viewport.sceneInset(insets.left, for: bounds.size)
        let safeRight = Viewport.sceneInset(insets.right, for: bounds.size)

        if !didPresentScene {
            didPresentScene = true

            let menu = MainMenuScene(size: sceneSize)
            menu.scaleMode = .aspectFill
            menu.safeAreaTop = safeTop
            menu.safeAreaBottom = safeBottom
            menu.safeAreaLeft = safeLeft
            menu.safeAreaRight = safeRight

            skView.presentScene(menu)
        } else if let menuScene = skView.scene as? MainMenuScene {
            menuScene.safeAreaTop = safeTop
            menuScene.safeAreaBottom = safeBottom
            menuScene.safeAreaLeft = safeLeft
            menuScene.safeAreaRight = safeRight
            menuScene.size = sceneSize
            // `didChangeSize` ne se déclenche pas quand seules les marges
            // changent : on réapplique explicitement.
            menuScene.applySafeAreaLayout()
        } else if let gameScene = skView.scene as? GameScene {
            gameScene.safeAreaTop = safeTop
            gameScene.safeAreaBottom = safeBottom
            gameScene.safeAreaLeft = safeLeft
            gameScene.safeAreaRight = safeRight
            gameScene.size = sceneSize
            gameScene.applySafeAreaLayout()
        }
    }

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { [.bottom] }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .landscape
    }
    override var shouldAutorotate: Bool { true }
}
