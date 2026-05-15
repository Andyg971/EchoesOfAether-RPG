import SpriteKit
import UIKit

final class GameViewController: UIViewController {
    private var didPresentScene = false
    private weak var gameScene: GameScene?

    override func loadView() {
        view = SKView(frame: UIScreen.main.bounds)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        guard let skView = view as? SKView else { return }

        if !didPresentScene {
            didPresentScene = true

            let scene = GameScene(size: skView.bounds.size)
            scene.scaleMode = .resizeFill
            scene.safeAreaTop = view.safeAreaInsets.top

            skView.ignoresSiblingOrder = true
            skView.preferredFramesPerSecond = 60
            skView.presentScene(scene)
            gameScene = scene
        } else {
            gameScene?.safeAreaTop = view.safeAreaInsets.top
        }
    }

    override var prefersStatusBarHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
}
