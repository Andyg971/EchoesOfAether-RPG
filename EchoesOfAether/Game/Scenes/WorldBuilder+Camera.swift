import SpriteKit

// Caméra et fonds de zone.
// Extrait de WorldBuilder.swift (découpage du monolithe).
@MainActor
extension WorldBuilder {
    // MARK: - Camera

    /// Demande un recadrage instantané (changement de zone / téléportation).
    func snapCamera() { snapCameraNextFrame = true }

    func updateCamera(in sceneSize: CGSize) {
        let scrollY = worldHeight > sceneSize.height
        let scrollX = worldWidth > sceneSize.width      // carte du monde (FF7)
        guard scrollY || scrollX else { return }

        var goalY = worldNode.position.y
        if scrollY {
            let clampedY = min(max(kael.position.y - sceneSize.height / 2, 0),
                               worldHeight - sceneSize.height)
            goalY = -clampedY
        }
        var goalX = worldNode.position.x
        if scrollX {
            let clampedX = min(max(kael.position.x - sceneSize.width / 2, 0),
                               worldWidth - sceneSize.width)
            goalX = -clampedX
        }

        if snapCameraNextFrame {
            worldNode.position = CGPoint(x: goalX, y: goalY)
            snapCameraNextFrame = false
        } else {
            // Suivi lissé : la caméra rattrape Kael en douceur (cinématique),
            // au lieu de coller image par image.
            worldNode.position.x += (goalX - worldNode.position.x) * 0.18
            worldNode.position.y += (goalY - worldNode.position.y) * 0.18
        }
    }

    // MARK: - Zone Backgrounds

    func switchToForest(in scene: SKScene) {
        clearBackdrop()
        worldNode.position = .zero
        [lyra, dorin, bram, mara, garen, sage, child, villager].forEach { $0.isHidden = true }
        scene.backgroundColor = SKColor(red: 0.03, green: 0.06, blue: 0.04, alpha: 1)
        buildForest(in: scene)   // définit worldHeight (trek scrollable)
    }
}
