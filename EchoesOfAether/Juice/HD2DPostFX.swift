import SpriteKit
import CoreImage

/// Passe post-process « HD-2D » (look-dev). Réservée pour l'instant à la scène
/// du Seuil, le temps de valider la direction artistique façon Octopath.
///
/// Le reste du moteur est pixel strict : `.nearest`, halos à paliers, zéro
/// flou. Cette passe assume l'inverse — **bloom lisse + lueurs floues** — car
/// c'est précisément ce qui fait le rendu HD-2D. Aucun asset IA : 100 % filtres
/// Core Image et dégradés radiaux générés par code.
@MainActor
enum HD2DPostFX {

    private static let overlayName = "hd2dOverlay"

    // MARK: - Bloom (SKEffectNode enveloppant le monde)

    /// Active le bloom lisse sur le node d'effet qui enveloppe le monde.
    static func enableBloom(on fx: SKEffectNode, intensity: CGFloat, radius: CGFloat) {
        guard let bloom = CIFilter(name: "CIBloom") else { return }
        bloom.setValue(intensity, forKey: kCIInputIntensityKey)
        bloom.setValue(radius, forKey: kCIInputRadiusKey)
        fx.filter = bloom
        fx.shouldRasterize = false
        fx.shouldEnableEffects = true
    }

    /// Repasse le monde en rendu direct (aucun filtre) — état par défaut
    /// hors Seuil. Retire aussi les lueurs émissives ajoutées.
    static func disable(on fx: SKEffectNode) {
        fx.shouldEnableEffects = false
        fx.filter = nil
        fx.childNode(withName: overlayName)?.removeFromParent()
    }

    // MARK: - Lueur émissive lisse (dégradé radial, PAS de paliers)

    /// Sprite de lumière additive à dégradé lisse. Contrairement aux halos
    /// pixel du moteur, celui-ci est volontairement flou : c'est la source
    /// que le bloom va faire « baver ». `filteringMode = .linear` assumé.
    static func emissiveGlow(color: SKColor, diameter: CGFloat, alpha: CGFloat = 1) -> SKSpriteNode {
        let side = 128
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let image = UIGraphicsImageRenderer(
            size: CGSize(width: side, height: side), format: format
        ).image { ctx in
            var r: CGFloat = 1, g: CGFloat = 1, b: CGFloat = 1, a: CGFloat = 1
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            let colors = [
                SKColor(red: r, green: g, blue: b, alpha: 1).cgColor,
                SKColor(red: r, green: g, blue: b, alpha: 0).cgColor
            ] as CFArray
            guard let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: colors, locations: [0, 1]) else { return }
            let c = CGFloat(side) / 2
            ctx.cgContext.drawRadialGradient(
                grad,
                startCenter: CGPoint(x: c, y: c), startRadius: 0,
                endCenter: CGPoint(x: c, y: c), endRadius: c,
                options: [])
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear   // lisse — l'exception HD-2D assumée
        let node = SKSpriteNode(texture: texture)
        node.size = CGSize(width: diameter, height: diameter)
        node.blendMode = .add
        node.alpha = alpha
        return node
    }

    // MARK: - Ambiance complète du Seuil

    /// Habille la scène du Seuil en HD-2D : bloom + portail du Vide pulsé +
    /// bougies incandescentes. Idempotent (nettoie l'ancienne passe).
    ///
    /// Les lueurs vivent SOUS `worldNode` (à l'intérieur du `SKEffectNode`)
    /// pour être happées par le bloom ; elles restent donc calées sur le décor.
    static func applyThreshold(on fx: SKEffectNode, worldNode: SKNode, size: CGSize) {
        worldNode.childNode(withName: overlayName)?.removeFromParent()

        enableBloom(on: fx, intensity: 0.9, radius: 16)

        let w = size.width, h = size.height
        let overlay = SKNode()
        overlay.name = overlayName

        // Portail du Vide (escalier, haut-centre) : grosse lueur violette pulsée.
        let portal = emissiveGlow(
            color: SKColor(red: 0.62, green: 0.42, blue: 0.98, alpha: 1),
            diameter: 360)
        portal.position = CGPoint(x: w * 0.50, y: h * 0.82)
        portal.zPosition = 5
        portal.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.55, duration: 2.4),
            .fadeAlpha(to: 0.95, duration: 2.4)
        ])))
        overlay.addChild(portal)

        // Bougies incandescentes (les 4 flammes latérales existantes du Seuil).
        for (px, py) in [(0.14, 0.40), (0.86, 0.40), (0.14, 0.70), (0.86, 0.70)] {
            let flame = emissiveGlow(
                color: SKColor(red: 1.0, green: 0.72, blue: 0.42, alpha: 1),
                diameter: 90, alpha: 0.85)
            flame.position = CGPoint(x: w * CGFloat(px), y: h * CGFloat(py) + 12)
            flame.zPosition = 6
            let flicker = 0.9 + Double.random(in: 0...0.4)
            flame.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.55, duration: flicker),
                .fadeAlpha(to: 0.90, duration: flicker)
            ])))
            overlay.addChild(flame)
        }

        worldNode.addChild(overlay)
    }
}
