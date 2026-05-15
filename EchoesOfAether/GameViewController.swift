import SpriteKit
import UIKit

final class GameViewController: UIViewController {
    private var didPresentScene = false

    override func loadView() {
        view = SKView(frame: UIScreen.main.bounds)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        guard !didPresentScene, let skView = view as? SKView else { return }
        didPresentScene = true

        let scene = GameScene(size: skView.bounds.size)
        scene.scaleMode = .resizeFill

        skView.ignoresSiblingOrder = true
        skView.preferredFramesPerSecond = 60
        skView.presentScene(scene)
    }

    override var prefersStatusBarHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
}
