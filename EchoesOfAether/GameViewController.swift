import SpriteKit
import UIKit

final class GameViewController: UIViewController {
    private var didPresentScene = false

    override func loadView() {
        view = SKView(frame: UIScreen.main.bounds)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        guard let skView = view as? SKView else { return }
        let bounds = skView.bounds
        let portraitSize = CGSize(
            width: min(bounds.width, bounds.height),
            height: max(bounds.width, bounds.height)
        )

        if !didPresentScene {
            didPresentScene = true

            let menu = MainMenuScene(size: portraitSize)
            menu.scaleMode = .resizeFill
            menu.safeAreaTop = view.safeAreaInsets.top

            skView.ignoresSiblingOrder = true
            skView.preferredFramesPerSecond = 60
            skView.presentScene(menu)
        } else if let gameScene = skView.scene as? GameScene {
            gameScene.safeAreaTop = view.safeAreaInsets.top
        }
    }

    override var prefersStatusBarHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
}
