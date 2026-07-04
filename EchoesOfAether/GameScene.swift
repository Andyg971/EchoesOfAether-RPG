import SpriteKit

final class GameScene: SKScene {
    private let manager = GameManager()
    private var lastUpdate: TimeInterval = 0
    var safeAreaTop: CGFloat = 0
    var safeAreaBottom: CGFloat = 0
    var safeAreaLeft: CGFloat = 0
    var safeAreaRight: CGFloat = 0
    /// Slot de sauvegarde sélectionné dans le menu (1...SaveManager.slotCount).
    var activeSlot: Int = 1

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.07, green: 0.09, blue: 0.11, alpha: 1)
        HapticsEngine.prepare()
        manager.setup(scene: self, slot: activeSlot)

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
            let menu = MainMenuScene(size: view.bounds.size)
            menu.scaleMode = .resizeFill
            menu.safeAreaTop = self.safeAreaTop
            menu.safeAreaBottom = self.safeAreaBottom
            menu.safeAreaLeft = self.safeAreaLeft
            menu.safeAreaRight = self.safeAreaRight
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
        manager.layout(size: size, safeTop: safeAreaTop, safeBottom: safeAreaBottom, safeLeft: safeAreaLeft, safeRight: safeAreaRight)
    }

    override func update(_ currentTime: TimeInterval) {
        let delta = lastUpdate == 0 ? 0 : currentTime - lastUpdate
        lastUpdate = currentTime
        manager.update(deltaTime: delta)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }
        // Le joystick flottant capture les touches du quart bas-gauche
        // en exploration ; tout le reste passe au tap classique.
        if manager.padTouchBegan(at: point, in: self) { return }
        manager.handleTap(at: point, in: self)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }
        manager.padTouchMoved(to: point)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        manager.padTouchEnded()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        manager.padTouchEnded()
    }
}
