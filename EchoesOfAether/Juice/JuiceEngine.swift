import SpriteKit

/// Réglages d'accessibilité persistés dans UserDefaults.
/// Lus à chaud par JuiceEngine (réduction d'animations) et par le HUD /
/// le dialogue (gros texte).
enum AccessibilitySettings {
    static let reduceMotionKey = "reduceMotion"
    static let largeTextKey = "largeText"

    static var reduceMotion: Bool {
        UserDefaults.standard.bool(forKey: reduceMotionKey)
    }
    static var largeText: Bool {
        UserDefaults.standard.bool(forKey: largeTextKey)
    }
    /// Facteur multiplicatif appliqué aux tailles de police quand « gros
    /// texte » est actif.
    static var textScale: CGFloat {
        largeText ? 1.25 : 1.0
    }
}

/// Échelle adaptative des overlays selon la taille d'écran (iPhone → iPad).
/// Sur iPhone le facteur reste 1.0 ; sur grand écran il grandit (borné) pour
/// que les panneaux ne soient ni minuscules ni coupés.
@MainActor
enum UIScale {
    static func factor(for size: CGSize) -> CGFloat {
        let minDim = min(size.width, size.height)
        return max(1.0, min(minDim / 390.0, 1.7))
    }

    /// Applique le facteur à `root` en gardant le centre de l'écran fixe.
    /// Astuce : un enfant placé en coordonnées absolues (ex. centre = w/2,h/2)
    /// reste centré car le centre est le point fixe de la transformation.
    static func apply(to root: SKNode, sceneSize: CGSize) {
        let s = factor(for: sceneSize)
        root.setScale(s)
        let c = CGPoint(x: sceneSize.width / 2, y: sceneSize.height / 2)
        root.position = CGPoint(x: c.x * (1 - s), y: c.y * (1 - s))
    }

    /// Variante pour les overlays dont le `root` est déjà positionné au centre
    /// de l'écran et dont les enfants sont en coordonnées relatives : on se
    /// contente de redimensionner (le pivot est déjà le centre).
    static func scaleCentered(_ root: SKNode, sceneSize: CGSize) {
        root.setScale(factor(for: sceneSize))
    }

    /// Facteur qui garantit qu'un panneau de `contentHeight` pt tient dans
    /// la hauteur de l'écran (marge comprise). Contrairement à `factor`,
    /// il peut descendre SOUS 1.0 — indispensable en paysage iPhone où les
    /// grands panneaux (Options, Inventaire) débordent sinon.
    static func fittingFactor(for size: CGSize, contentHeight: CGFloat) -> CGFloat {
        min(factor(for: size), max(0.5, (size.height - 12) / contentHeight))
    }
}

@MainActor
enum JuiceEngine {

    static func screenShake(_ node: SKNode, intensity: CGFloat = 10, duration: TimeInterval = 0.3) {
        // Accessibilité : « réduire les animations » neutralise le tremblement.
        if AccessibilitySettings.reduceMotion { return }
        let shakes = Int(duration / 0.04)
        var actions: [SKAction] = []
        for i in 0..<shakes {
            let factor = CGFloat(shakes - i) / CGFloat(shakes)
            let dx = CGFloat.random(in: -intensity...intensity) * factor
            let dy = CGFloat.random(in: -intensity...intensity) * factor
            actions.append(.moveBy(x: dx, y: dy, duration: 0.02))
            actions.append(.moveBy(x: -dx, y: -dy, duration: 0.02))
        }
        node.run(.sequence(actions), withKey: "shake")
    }

    static func flash(_ node: SKNode, color: SKColor = .white, duration: TimeInterval = 0.12) {
        guard let shape = node as? SKShapeNode else { return }
        let original = shape.fillColor
        shape.run(.sequence([
            .run { shape.fillColor = color },
            .wait(forDuration: duration),
            .run { shape.fillColor = original }
        ]), withKey: "flash")
    }

    static func flashOverlay(in parent: SKNode, size: CGSize, color: SKColor, duration: TimeInterval = 0.15) {
        // Accessibilité : atténue fortement les flashs (notamment rouges agressifs).
        let reduce = AccessibilitySettings.reduceMotion
        let overlay = SKShapeNode(rectOf: size)
        overlay.fillColor = color
        overlay.strokeColor = .clear
        overlay.alpha = reduce ? 0.18 : 0.6
        overlay.zPosition = 950
        parent.addChild(overlay)
        overlay.run(.sequence([
            .fadeOut(withDuration: reduce ? min(duration, 0.12) : duration),
            .removeFromParent()
        ]))
    }

    static func slowMotion(scene: SKScene, duration: TimeInterval = 0.15, factor: CGFloat = 0.3) {
        // Accessibilité : pas de ralenti quand « réduire les animations » est actif.
        if AccessibilitySettings.reduceMotion { return }
        scene.speed = factor
        scene.run(.sequence([
            .wait(forDuration: duration * factor),
            .run { scene.speed = 1.0 }
        ]), withKey: "slowmo")
    }

    /// Micro-zoom de caméra centré sur `center` : le nœud racine grossit
    /// brièvement puis revient. Impact « caméra qui encaisse le coup ».
    static func zoomPunch(_ node: SKNode, around center: CGPoint,
                          scale: CGFloat = 1.035, duration: TimeInterval = 0.24) {
        let dx = center.x * (1 - scale)
        let dy = center.y * (1 - scale)
        let zoomIn = SKAction.group([
            .scale(to: scale, duration: duration * 0.35),
            .move(to: CGPoint(x: dx, y: dy), duration: duration * 0.35)
        ])
        zoomIn.timingMode = .easeOut
        let zoomOut = SKAction.group([
            .scale(to: 1.0, duration: duration * 0.65),
            .move(to: .zero, duration: duration * 0.65)
        ])
        zoomOut.timingMode = .easeIn
        node.run(.sequence([zoomIn, zoomOut]), withKey: "zoomPunch")
    }

    static func popIn(_ node: SKNode, delay: TimeInterval = 0) {
        node.setScale(0)
        node.alpha = 0
        let appear = SKAction.group([
            .scale(to: 1.15, duration: 0.2),
            .fadeIn(withDuration: 0.15)
        ])
        appear.timingMode = .easeOut
        node.run(.sequence([
            .wait(forDuration: delay),
            appear,
            .scale(to: 1.0, duration: 0.1)
        ]))
    }

    static func popOut(_ node: SKNode, completion: (@Sendable () -> Void)? = nil) {
        let shrink = SKAction.group([
            .scale(to: 0, duration: 0.2),
            .fadeOut(withDuration: 0.2)
        ])
        if let completion {
            node.run(.sequence([shrink, .removeFromParent()]), completion: completion)
        } else {
            node.run(.sequence([shrink, .removeFromParent()]))
        }
    }

    static func pulse(_ node: SKNode, scale: CGFloat = 1.15) {
        let up = SKAction.scale(to: scale, duration: 0.5)
        let down = SKAction.scale(to: 1.0, duration: 0.5)
        up.timingMode = .easeInEaseOut
        down.timingMode = .easeInEaseOut
        node.run(.repeatForever(.sequence([up, down])), withKey: "pulse")
    }

    static func float(_ node: SKNode, distance: CGFloat = 6) {
        let up = SKAction.moveBy(x: 0, y: distance, duration: 1)
        let down = SKAction.moveBy(x: 0, y: -distance, duration: 1)
        up.timingMode = .easeInEaseOut
        down.timingMode = .easeInEaseOut
        node.run(.repeatForever(.sequence([up, down])), withKey: "float")
    }

    static func squashAndStretch(_ node: SKNode, duration: TimeInterval = 0.2) {
        let squash = SKAction.scaleX(to: 1.3, y: 0.7, duration: duration * 0.3)
        let stretch = SKAction.scaleX(to: 0.8, y: 1.3, duration: duration * 0.3)
        let reset = SKAction.scale(to: 1.0, duration: duration * 0.4)
        squash.timingMode = .easeOut
        reset.timingMode = .easeInEaseOut
        node.run(.sequence([squash, stretch, reset]))
    }
}
