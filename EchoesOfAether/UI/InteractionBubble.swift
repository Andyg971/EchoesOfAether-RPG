import SpriteKit

/// Bulle pulsante affichée au-dessus d'un PNJ (ou cible interactive)
/// pour signaler une action disponible : parler, commercer, combattre,
/// examiner, entrer. Visible uniquement quand Kael est dans le rayon.
///
/// Conçue pour rester lisible sur iPhone et iPad (taille fixe en pt,
/// indépendante de la taille de scène).
@MainActor
final class InteractionBubble {
    private let root = SKNode()
    private let bg = SKShapeNode(circleOfRadius: 18)
    private let bgGlow = SKShapeNode(circleOfRadius: 22)
    private let iconHolder = SKNode()
    private var currentAction: Action?

    enum Action: String {
        case talk, shop, fight, examine, enter

        /// Icône pixel art correspondante (aucun emoji dans l'UI).
        var pixelIcon: PixelIcons.Kind {
            switch self {
            case .talk:    return .chat
            case .shop:    return .bag
            case .fight:   return .sword
            case .examine: return .magnifier
            case .enter:   return .door
            }
        }

        /// Détecte l'action depuis une clé i18n existante du projet
        /// (hint.talk, hint.shop, hint.fight, hint.examine, hint.enter).
        init?(hintKey: String) {
            switch hintKey {
            case "hint.talk":    self = .talk
            case "hint.shop":    self = .shop
            case "hint.fight":   self = .fight
            case "hint.examine": self = .examine
            case "hint.enter":   self = .enter
            case "hint.exit":    self = .enter
            default: return nil
            }
        }
    }

    var isVisible: Bool { root.parent != nil && !root.isHidden }

    func attach(to scene: SKScene) {
        root.zPosition = 50
        root.isHidden = true
        scene.addChild(root)

        // Halo extérieur diffus
        bgGlow.fillColor = SKColor(red: 0.55, green: 0.25, blue: 0.85, alpha: 0.25)
        bgGlow.strokeColor = .clear
        root.addChild(bgGlow)

        // Cercle principal
        bg.fillColor = SKColor(red: 0.18, green: 0.10, blue: 0.30, alpha: 0.95)
        bg.strokeColor = SKColor(red: 0.85, green: 0.50, blue: 1, alpha: 1)
        bg.lineWidth = 2
        bg.glowWidth = 3
        root.addChild(bg)

        // Icône pixel art centrée
        root.addChild(iconHolder)

        // Animation idle : float vertical + halo pulse
        let float = SKAction.repeatForever(.sequence([
            .moveBy(x: 0, y: 4, duration: 0.7),
            .moveBy(x: 0, y: -4, duration: 0.7)
        ]))
        float.timingMode = .easeInEaseOut
        root.run(float, withKey: "float")
        JuiceEngine.pulse(bgGlow, scale: 1.25)
    }

    /// Affiche la bulle au-dessus d'une position cible (typiquement la
    /// tête d'un PNJ : `node.position + offset Y`). `action` pilote l'icône.
    /// Idempotent : appels successifs avec mêmes args ne re-anime pas.
    func show(at worldPosition: CGPoint, action: Action) {
        let positionChanged = abs(root.position.x - worldPosition.x) > 0.5
            || abs(root.position.y - worldPosition.y) > 0.5
        let iconChanged = currentAction != action

        if iconChanged {
            currentAction = action
            iconHolder.removeAllChildren()
            iconHolder.addChild(PixelIcons.node(action.pixelIcon, pixel: 2.4))
            // Petit pop quand l'action change
            root.run(.sequence([
                .scale(to: 1.2, duration: 0.08),
                .scale(to: 1.0, duration: 0.12)
            ]))
        }

        if positionChanged {
            // Reset le float-Y pour éviter le drift quand on change de cible
            root.removeAction(forKey: "float")
            root.position = worldPosition
            let float = SKAction.repeatForever(.sequence([
                .moveBy(x: 0, y: 4, duration: 0.7),
                .moveBy(x: 0, y: -4, duration: 0.7)
            ]))
            float.timingMode = .easeInEaseOut
            root.run(float, withKey: "float")
        }

        if root.isHidden {
            root.isHidden = false
            root.alpha = 0
            root.run(.fadeIn(withDuration: 0.18))
        }
    }

    func hide() {
        guard !root.isHidden else { return }
        root.run(.sequence([
            .fadeOut(withDuration: 0.15),
            .run { [weak self] in self?.root.isHidden = true }
        ]))
    }
}
