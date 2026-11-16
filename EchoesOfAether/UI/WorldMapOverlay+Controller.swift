import SpriteKit

// Carte du monde à la manette : le curseur saute de lieu en lieu voyageable.
extension WorldMapOverlay {
    private var travelPlaces: [WorldMapPlace] { places.filter { $0.state == .available } }

    /// Place le curseur sur le lieu voyageable le plus proche de Kael.
    func resetCursor() {
        let origin = places.first { $0.state == .current }?.point ?? CGPoint(x: 0.5, y: 0.5)
        cursorID = travelPlaces.min {
            $0.point.distance(to: origin) < $1.point.distance(to: origin)
        }?.id
        refreshCursor()
    }

    func moveCursor(dx: Int, dy: Int) {
        guard let current = travelPlaces.first(where: { $0.id == cursorID }) else {
            resetCursor(); return
        }
        let target = travelPlaces
            .filter { $0.id != current.id }
            .filter { place in
                let deltaX = place.point.x - current.point.x
                let deltaY = place.point.y - current.point.y
                return dx != 0 ? deltaX * CGFloat(dx) > 0 : deltaY * CGFloat(dy) > 0
            }
            .min { $0.point.distance(to: current.point) < $1.point.distance(to: current.point) }
        guard let target else { return }
        cursorID = target.id
        HapticsEngine.light()
        refreshCursor()
    }

    func confirmCursor(in scene: SKScene) {
        guard let place = travelPlaces.first(where: { $0.id == cursorID }) else { return }
        _ = handleTap(at: scene.convert(panelPoint(place.point), from: root), in: scene)
    }

    private func refreshCursor() {
        nodes.filter { $0.name == "padCursor" }.forEach { $0.removeFromParent() }
        nodes.removeAll { $0.name == "padCursor" }
        guard GameControllerInput.shared.isConnected,
              let place = travelPlaces.first(where: { $0.id == cursorID }) else { return }
        let cursor = SKShapeNode(rectOf: CGSize(width: 46, height: 46))
        cursor.name = "padCursor"
        cursor.fillColor = .clear
        cursor.strokeColor = PixelUI.gold
        cursor.lineWidth = 3
        cursor.glowWidth = 0
        cursor.position = panelPoint(place.point)
        cursor.zPosition = 50
        root.addChild(cursor)
        nodes.append(cursor)
    }
}
