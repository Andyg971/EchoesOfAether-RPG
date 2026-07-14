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
    private let bg = SKShapeNode(rect: CGRect(x: -15, y: -13, width: 30, height: 26))
    private let bgOuter = SKShapeNode(rect: CGRect(x: -17, y: -15, width: 34, height: 30))
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
        root.zPosition = 520   // au-dessus de la vignette de zone (480)
        root.isHidden = true
        scene.addChild(root)

        // Bulle de parole RPG classique : petit rectangle BLANC à bord
        // sombre, avec une queue en escalier pixel vers le PNJ.
        bgOuter.fillColor = .clear
        bgOuter.strokeColor = SKColor(red: 0.10, green: 0.09, blue: 0.12, alpha: 0.95)
        bgOuter.lineWidth = 2
        root.addChild(bgOuter)

        bg.fillColor = SKColor(red: 0.96, green: 0.95, blue: 0.92, alpha: 0.98)
        bg.strokeColor = SKColor(red: 0.10, green: 0.09, blue: 0.12, alpha: 1)
        bg.lineWidth = 2
        bg.glowWidth = 0
        root.addChild(bg)

        // Queue : deux marches pixel sous la bulle, pointant vers le PNJ
        let tailBig = SKSpriteNode(color: SKColor(red: 0.96, green: 0.95, blue: 0.92, alpha: 0.98),
                                   size: CGSize(width: 10, height: 6))
        tailBig.position = CGPoint(x: -4, y: -18)
        root.addChild(tailBig)
        let tailSmall = SKSpriteNode(color: SKColor(red: 0.96, green: 0.95, blue: 0.92, alpha: 0.98),
                                     size: CGSize(width: 5, height: 5))
        tailSmall.position = CGPoint(x: -7, y: -23)
        root.addChild(tailSmall)

        // Icône pixel art centrée (redessinée sombre sur fond blanc)
        root.addChild(iconHolder)

        // Animation idle : flottement discret
        let float = SKAction.repeatForever(.sequence([
            .moveBy(x: 0, y: 3, duration: 0.7),
            .moveBy(x: 0, y: -3, duration: 0.7)
        ]))
        float.timingMode = .easeInEaseOut
        root.run(float, withKey: "float")
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
            // Glyphe RPG classique : « … » parle, « ! » danger, « ? » examine
            let glyph = SKLabelNode(fontNamed: PixelUI.uiFont)
            switch action {
            case .talk, .shop: glyph.text = "…"
            case .fight:       glyph.text = "!"
            case .examine:     glyph.text = "?"
            case .enter:       glyph.text = "»"
            }
            glyph.fontSize = action == .talk || action == .shop ? 30 : 24
            glyph.fontColor = SKColor(red: 0.12, green: 0.10, blue: 0.14, alpha: 1)
            glyph.verticalAlignmentMode = .center
            glyph.horizontalAlignmentMode = .center
            glyph.position = CGPoint(x: 0, y: action == .talk || action == .shop ? 4 : 0)
            iconHolder.addChild(glyph)
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
