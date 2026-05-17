import SpriteKit

final class GameScene: SKScene {
    private let manager = GameManager()
    private var lastUpdate: TimeInterval = 0
    var safeAreaTop: CGFloat = 0

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.07, green: 0.09, blue: 0.11, alpha: 1)
        AudioEngine.shared.start()
        manager.setup(scene: self)

        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.manager.saveGame()
        }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        manager.layout(size: size, safeTop: safeAreaTop)
    }

    override func update(_ currentTime: TimeInterval) {
        let delta = lastUpdate == 0 ? 0 : currentTime - lastUpdate
        lastUpdate = currentTime
        manager.update(deltaTime: delta)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }
        manager.handleTap(at: point, in: self)
    }
}
