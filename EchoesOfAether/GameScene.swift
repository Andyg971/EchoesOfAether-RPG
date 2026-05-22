import SpriteKit

final class GameScene: SKScene {
    private let manager = GameManager()
    private var lastUpdate: TimeInterval = 0
    var safeAreaTop: CGFloat = 0

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.07, green: 0.09, blue: 0.11, alpha: 1)
        HapticsEngine.prepare()
        manager.setup(scene: self)

        // Audio démarré après transition complète (fade 0.5s + marge)
        // évite crash AURemoteIO::IOThread pendant changement de scène
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            AudioEngine.shared.start()
        }

        // GameCenter auth via root view controller
        if let vc = view.window?.rootViewController {
            GameCenterManager.shared.authenticate(from: vc)
        }

        // Retour menu principal (depuis pause ou mort)
        manager.onReturnToMenu = { [weak self, weak view] in
            guard let self, let view else { return }
            let portraitSize = CGSize(
                width: min(view.bounds.width, view.bounds.height),
                height: max(view.bounds.width, view.bounds.height)
            )
            let menu = MainMenuScene(size: portraitSize)
            menu.scaleMode = .resizeFill
            menu.safeAreaTop = self.safeAreaTop
            view.presentScene(menu, transition: .fade(with: .black, duration: 0.5))
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.manager.saveGame() }
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
