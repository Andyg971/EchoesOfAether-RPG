import SpriteKit

// OptionsOverlay à la manette : un curseur doré parcourt les boutons existants,
// A rejoue le tap sur le bouton visé (aucune logique dupliquée).
extension OptionsOverlay {
    /// Lignes de navigation, dans l'ordre d'affichage. Les deux premières sont
    /// les volumes : gauche/droite y règlent directement le niveau.
    private static let cursorRows: [[String]] = [
        ["musicDown", "musicUp"],
        ["sfxDown", "sfxUp"],
        ["cycleDifficulty"],
        ["toggleReduceMotion"],
        ["toggleLargeText"],
        ["toggleHaptics"],
        ["langFR", "langEN"],
        ["optionsTutorial", "optionsReset", "optionsClose"]
    ]
    private static let volumeRowCount = 2

    func moveCursor(dx: Int, dy: Int, in scene: SKScene) {
        let rows = Self.cursorRows
        if dy != 0 {
            cursorRow = min(max(cursorRow + dy * -1, 0), rows.count - 1)
            cursorColumn = min(cursorColumn, rows[cursorRow].count - 1)
        } else if dx != 0 {
            if cursorRow < Self.volumeRowCount {
                cursorColumn = dx < 0 ? 0 : 1
                confirmCursor(in: scene)
                return
            }
            cursorColumn = min(max(cursorColumn + dx, 0), rows[cursorRow].count - 1)
        }
        HapticsEngine.light()
        refreshCursor()
    }

    func confirmCursor(in scene: SKScene) {
        guard let button = cursorButton, let parent = button.parent else { return }
        _ = handleTap(at: scene.convert(button.position, from: parent), in: scene)
        refreshCursor()
    }

    func refreshCursor() {
        root.childNode(withName: "padCursor")?.removeFromParent()
        guard GameControllerInput.shared.isConnected, isActive,
              let button = cursorButton, let parent = button.parent else { return }
        let size = button.frame.size
        let cursor = SKShapeNode(rectOf: CGSize(width: size.width + 8, height: size.height + 8))
        cursor.name = "padCursor"
        cursor.fillColor = .clear
        cursor.strokeColor = PixelUI.gold
        cursor.lineWidth = 3
        cursor.glowWidth = 0
        cursor.position = root.convert(button.position, from: parent)
        cursor.zPosition = 100
        root.addChild(cursor)
    }

    private var cursorButton: SKNode? {
        let rows = Self.cursorRows
        guard rows.indices.contains(cursorRow),
              rows[cursorRow].indices.contains(cursorColumn) else { return nil }
        return root.childNode(withName: "//" + rows[cursorRow][cursorColumn])
    }
}
