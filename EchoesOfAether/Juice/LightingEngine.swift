import SpriteKit

/// Éclairage « HD-2D » : grade couleur plein écran (multiply) + lumières
/// additives pixelisées. Charte pixel art respectée : toutes les textures
/// sont rendues en basse résolution puis upscalées en `.nearest` — les
/// halos restent en gros pixels à paliers, jamais de dégradé lisse.
@MainActor
enum LightingEngine {

    // MARK: - Grade couleur (ambiance de zone)

    /// Teinte multiply plein écran : blanc = neutre, toute autre couleur
    /// colore la zone entière (nuit bleue, forêt froide, désert chaud…).
    struct Grade {
        let color: SKColor

        static let neutral   = Grade(color: SKColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1))
        /// Village : lumière dorée de fin d'après-midi.
        static let villageDay = Grade(color: SKColor(red: 1.00, green: 0.97, blue: 0.90, alpha: 1))
        /// Forêt : sous-bois froid, bleu-vert profond.
        static let forest    = Grade(color: SKColor(red: 0.74, green: 0.86, blue: 0.86, alpha: 1))
        /// Mines : galeries bleu nuit, seules les flammes réchauffent.
        static let mines     = Grade(color: SKColor(red: 0.52, green: 0.58, blue: 0.80, alpha: 1))
        /// Désert : chaleur écrasante, hautes lumières ambrées.
        static let desert    = Grade(color: SKColor(red: 1.00, green: 0.92, blue: 0.76, alpha: 1))
        /// Sanctuaire : aura sarcelle irréelle.
        static let shrine    = Grade(color: SKColor(red: 0.80, green: 0.94, blue: 0.92, alpha: 1))
        /// Ruines : gris délavé, couleur aspirée.
        static let ruins     = Grade(color: SKColor(red: 0.82, green: 0.82, blue: 0.88, alpha: 1))
        /// Seuil : violet crépusculaire du Vide.
        static let threshold = Grade(color: SKColor(red: 0.80, green: 0.72, blue: 0.94, alpha: 1))
        /// Cœur du Vide : pourpre saturé, hors du monde.
        static let voidheart = Grade(color: SKColor(red: 0.72, green: 0.60, blue: 0.90, alpha: 1))
        /// Intérieur : chaleur de feu de cheminée.
        static let interior  = Grade(color: SKColor(red: 1.00, green: 0.93, blue: 0.82, alpha: 1))
    }

    private static let gradeNodeName = "lightGrade"

    /// Applique le grade en espace écran (ne scrolle pas), au-dessus du
    /// monde (acteurs 20-40, rais 60) mais SOUS le HUD (z 100) : la teinte
    /// colore la zone sans dégrader la lisibilité de l'interface.
    static func applyGrade(_ grade: Grade, in scene: SKScene) {
        scene.childNode(withName: gradeNodeName)?.removeFromParent()
        let node = SKSpriteNode(color: grade.color,
                                size: CGSize(width: scene.size.width + 8,
                                             height: scene.size.height + 8))
        node.name = gradeNodeName
        node.blendMode = .multiply
        node.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        node.zPosition = 90
        scene.addChild(node)
    }

    /// Transition douce vers un nouveau grade (voyage, tombée du soir).
    static func crossfadeGrade(to grade: Grade, in scene: SKScene, duration: TimeInterval = 1.2) {
        guard let node = scene.childNode(withName: gradeNodeName) as? SKSpriteNode else {
            applyGrade(grade, in: scene)
            return
        }
        node.run(.colorize(with: grade.color, colorBlendFactor: 1, duration: duration))
    }

    // MARK: - Texture de halo pixel (paliers discrets)

    /// Halo radial en 4 paliers d'alpha sur une grille 24×24 — upscalé en
    /// `.nearest`, le halo garde de gros pixels assumés.
    private static var haloCache: [String: SKTexture] = [:]

    private static func haloTexture(color: SKColor) -> SKTexture {
        let key = color.description
        if let cached = haloCache[key] { return cached }
        let side = 24
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        var r: CGFloat = 1, g: CGFloat = 1, b: CGFloat = 1, a: CGFloat = 1
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        let image = UIGraphicsImageRenderer(
            size: CGSize(width: side, height: side), format: format
        ).image { ctx in
            let c = ctx.cgContext
            let center = CGFloat(side) / 2
            // 4 paliers discrets : cœur brillant → bord éteint
            let steps: [(radius: CGFloat, alpha: CGFloat)] = [
                (1.00, 0.10), (0.72, 0.22), (0.46, 0.40), (0.24, 0.62)
            ]
            for step in steps {
                c.setFillColor(SKColor(red: r, green: g, blue: b,
                                       alpha: step.alpha).cgColor)
                let radius = center * step.radius
                // Cercle « pixelisé » : on remplit cellule par cellule
                for y in 0..<side {
                    for x in 0..<side {
                        let dx = CGFloat(x) + 0.5 - center
                        let dy = CGFloat(y) + 0.5 - center
                        if dx * dx + dy * dy <= radius * radius {
                            c.fill(CGRect(x: x, y: y, width: 1, height: 1))
                        }
                    }
                }
            }
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        haloCache[key] = texture
        return texture
    }

    // MARK: - Lumières ponctuelles

    /// Couleurs standard des sources.
    enum LightColor {
        /// Flamme : torche, lanterne, feu de camp.
        static let flame   = SKColor(red: 1.00, green: 0.72, blue: 0.34, alpha: 1)
        /// Champignons luisants des mines.
        static let fungal  = SKColor(red: 0.45, green: 0.95, blue: 0.85, alpha: 1)
        /// Cristaux / éclats du Vide.
        static let crystal = SKColor(red: 0.72, green: 0.55, blue: 0.98, alpha: 1)
        /// Halo du héros dans le noir.
        static let hero    = SKColor(red: 1.00, green: 0.88, blue: 0.62, alpha: 1)
    }

    /// Lumière additive pixel. `flicker` anime un vacillement de flamme.
    static func pointLight(radius: CGFloat,
                           color: SKColor,
                           flicker: Bool = false) -> SKSpriteNode {
        let light = SKSpriteNode(texture: haloTexture(color: color))
        light.size = CGSize(width: radius * 2, height: radius * 2)
        light.blendMode = .add
        light.zPosition = 45   // au-dessus des acteurs (20-40), sous le grade
        if flicker {
            let wobble = SKAction.repeatForever(.sequence([
                .group([.fadeAlpha(to: 0.82, duration: 0.09),
                        .scale(to: 0.96, duration: 0.09)]),
                .group([.fadeAlpha(to: 1.00, duration: 0.14),
                        .scale(to: 1.03, duration: 0.14)]),
                .group([.fadeAlpha(to: 0.90, duration: 0.11),
                        .scale(to: 1.00, duration: 0.11)])
            ]))
            wobble.timingMode = .easeInEaseOut
            light.run(wobble, withKey: "flicker")
        }
        return light
    }

    // MARK: - Halo du héros

    private static let heroLightName = "kaelLight"

    /// Attache un halo chaud au héros (mines, zones noires).
    static func attachHeroLight(to hero: SKNode, radius: CGFloat = 120) {
        removeHeroLight(from: hero)
        let light = pointLight(radius: radius, color: LightColor.hero)
        light.name = heroLightName
        light.alpha = 0.85
        light.position = CGPoint(x: 0, y: 14)
        light.zPosition = 5
        // Respiration lente — le halo vit sans clignoter
        light.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.72, duration: 1.1),
            .fadeAlpha(to: 0.85, duration: 1.1)
        ])))
        hero.addChild(light)
    }

    static func removeHeroLight(from hero: SKNode) {
        hero.childNode(withName: heroLightName)?.removeFromParent()
    }

    // MARK: - God rays (rais de lumière de la canopée)

    /// Bandes diagonales additives qui pulsent lentement — texture
    /// basse résolution `.nearest`, cohérente pixel art.
    static func godRays(in size: CGSize) -> SKNode {
        let container = SKNode()
        container.zPosition = 60

        let cols = 48, rows = 28
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(
            size: CGSize(width: cols, height: rows), format: format
        ).image { ctx in
            let c = ctx.cgContext
            // 3 rais diagonaux, largeur et intensité variées
            let rays: [(x0: CGFloat, width: CGFloat, alpha: CGFloat)] = [
                (0.18, 3.0, 0.50), (0.47, 4.5, 0.38), (0.76, 2.5, 0.46)
            ]
            for ray in rays {
                for y in 0..<rows {
                    // Pente : le rai descend vers la droite
                    let drift = CGFloat(y) * 0.35
                    let cx = ray.x0 * CGFloat(cols) + drift
                    // S'estompe vers le bas
                    let fade = 1 - CGFloat(y) / CGFloat(rows)
                    let a = ray.alpha * fade * fade
                    guard a > 0.02 else { continue }
                    c.setFillColor(SKColor(red: 1, green: 0.98, blue: 0.85,
                                           alpha: a).cgColor)
                    c.fill(CGRect(x: cx - ray.width / 2, y: CGFloat(y),
                                  width: ray.width, height: 1))
                }
            }
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        let rays = SKSpriteNode(texture: texture)
        rays.size = size
        rays.anchorPoint = .zero
        rays.blendMode = .add
        rays.alpha = 0.7
        // Pulsation très lente : la canopée respire
        rays.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.45, duration: 3.4),
            .fadeAlpha(to: 0.70, duration: 3.4)
        ])))
        container.addChild(rays)
        return container
    }

    // MARK: - Lucioles

    /// Points lumineux qui errent lentement en pulsant — forêt au soir.
    static func fireflies(in size: CGSize, count: Int = 14) -> SKNode {
        let container = SKNode()
        container.zPosition = 55
        for _ in 0..<count {
            let fly = SKSpriteNode(texture: haloTexture(color:
                SKColor(red: 0.85, green: 1.0, blue: 0.55, alpha: 1)))
            fly.size = CGSize(width: 14, height: 14)
            fly.blendMode = .add
            fly.position = CGPoint(x: .random(in: 0...size.width),
                                   y: .random(in: size.height * 0.15...size.height * 0.9))
            fly.alpha = 0
            // Pulsation individuelle désynchronisée
            let pulse = SKAction.repeatForever(.sequence([
                .wait(forDuration: .random(in: 0...2.5)),
                .fadeAlpha(to: .random(in: 0.6...0.95), duration: .random(in: 0.5...1.0)),
                .wait(forDuration: .random(in: 0.3...1.2)),
                .fadeAlpha(to: 0.05, duration: .random(in: 0.6...1.2))
            ]))
            // Errance douce en aller-retour : les deltas d'un
            // repeatForever sont figés, un trajet symétrique évite la
            // dérive hors écran au fil des minutes.
            let dx = CGFloat.random(in: -34...34)
            let dy = CGFloat.random(in: -20...20)
            let wander = SKAction.repeatForever(.sequence([
                .move(by: CGVector(dx: dx, dy: dy),
                      duration: .random(in: 2.2...4.0)),
                .move(by: CGVector(dx: -dx, dy: -dy),
                      duration: .random(in: 2.2...4.0))
            ]))
            fly.run(pulse)
            fly.run(wander)
            container.addChild(fly)
        }
        return container
    }
}
