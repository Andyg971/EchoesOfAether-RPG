import SpriteKit
import UIKit

final class GameViewController: UIViewController {
    private var didPresentScene = false

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

        let sceneSize = bounds.size
        let safeTop = view.safeAreaInsets.top
        let safeBottom = view.safeAreaInsets.bottom
        let safeLeft = view.safeAreaInsets.left
        let safeRight = view.safeAreaInsets.right

        if !didPresentScene {
            didPresentScene = true

            let menu = MainMenuScene(size: sceneSize)
            menu.scaleMode = .resizeFill
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
        } else if let gameScene = skView.scene as? GameScene {
            gameScene.safeAreaTop = safeTop
            gameScene.safeAreaBottom = safeBottom
            gameScene.safeAreaLeft = safeLeft
            gameScene.safeAreaRight = safeRight
            gameScene.size = sceneSize
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
