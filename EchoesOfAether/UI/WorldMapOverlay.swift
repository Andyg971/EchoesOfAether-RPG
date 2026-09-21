import SpriteKit

/// Un lieu sur la carte du monde.
struct WorldMapPlace {
    let id: String            // "village", "forest", "mines", "desert"…
    let title: String
    let point: CGPoint        // position normalisée (0...1) dans le panneau
    let state: State
    let accent: SKColor       // couleur du carré du lieu

    enum State {
        case current      // Kael est ici (jeton doré pulsé)
        case available    // voyage possible (bordure claire)
        case locked       // visible mais scellé par l'histoire (grisé)
        case hidden       // pas encore découvert — « ??? »
    }
}

/// Carte du monde — overlay pixel art façon RPG mobile : Kael quitte le
/// lieu courant, voit la carte, et voyage vers les lieux débloqués
/// (rencontres aléatoires en chemin). Ouverte depuis le bouton HUD.
@MainActor
final class WorldMapOverlay {
    let root = SKNode()
    var nodes: [SKNode] = []
    var panelWidth: CGFloat = 340
    var panelHeight: CGFloat = 470
    var places: [WorldMapPlace] = []

    /// Liaisons dessinées entre lieux (id → id), style pointillé pixel.
    let roads: [(String, String)] = [
        ("village", "forest"), ("forest", "shrine"), ("forest", "mines"),
        ("forest", "desert"), ("village", "ruins"), ("ruins", "threshold"),
        ("threshold", "voidheart")
    ]

    var onTravel: ((String) -> Void)?
    var onClose: (() -> Void)?
    var isActive: Bool { root.parent != nil && !root.isHidden }

    func attach(to scene: SKScene) {
        root.zPosition = 1_700
        root.isHidden = true
        scene.addChild(root)
    }

    func layout(in size: CGSize) {
        panelWidth = min(560, max(320, size.width - 48))
        panelHeight = min(500, max(400, size.height - 64))
        root.position = CGPoint(x: size.width / 2, y: size.height / 2)
        root.setScale(UIScale.fittingFactor(for: size, contentHeight: panelHeight + 12))
    }

    func open(places: [WorldMapPlace], completion: @escaping () -> Void) {
        self.places = places
        onClose = completion
        root.isHidden = false
        buildContent()
        AudioEngine.shared.playShopOpen()
        AccessibilitySettings.announce(String(localized: "map.title"))
    }

    func handleTap(at point: CGPoint, in scene: SKScene) -> Bool {
        guard isActive else { return false }
        let local = root.convert(point, from: scene)
        if let btn = root.childNode(withName: "mapClose") as? SKShapeNode,
           btn.contains(local) {
            close()
            return true
        }
        // Lieux voyageables : tap sur le carré (zone de 30 pt)
        for place in places where place.state == .available {
            if local.distance(to: panelPoint(place.point)) < 30 {
                let id = place.id
                close(silent: true)
                AudioEngine.shared.playSelect()
                onTravel?(id)
                return true
            }
        }
        return true   // capture tous les taps tant que la carte est ouverte
    }

    /// Bouton B : fermeture programmée (contrôles classiques).
    func dismiss() { close() }

    private func close(silent: Bool = false) {
        root.isHidden = true
        nodes.forEach { $0.removeFromParent() }
        nodes.removeAll()
        if silent {
            onClose = nil
        } else {
            onClose?()
            onClose = nil
        }
    }

    func label(_ text: String, size: CGFloat, color: SKColor) -> SKLabelNode {
        let l = SKLabelNode(fontNamed: PixelUI.uiFont)
        l.text = text
        l.fontSize = size
        l.fontColor = color
        l.horizontalAlignmentMode = .center
        l.verticalAlignmentMode = .baseline
        return l
    }
}
