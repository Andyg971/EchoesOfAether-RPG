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
        /// Pluie : ciel couvert, couleurs éteintes.
        static let rainy     = Grade(color: SKColor(red: 0.70, green: 0.75, blue: 0.86, alpha: 1))
        /// Nuit : bleu profond, les lanternes prennent le relais.
        static let night     = Grade(color: SKColor(red: 0.50, green: 0.58, blue: 0.86, alpha: 1))
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

    // MARK: - Cycle jour/nuit

    /// Cycle cosmétique piloté par SKAction sur le node de grade — zéro
    /// coût par frame. Jour → crépuscule doré → nuit bleue → aube → jour.
    /// `--time-night` fige la nuit (tests/screenshots).
    static func startDayCycle(in scene: SKScene, day: Grade,
                              phaseSeconds: TimeInterval = 75) {
        guard let node = scene.childNode(withName: gradeNodeName) as? SKSpriteNode else { return }
        if CommandLine.arguments.contains("--time-night") {
            node.color = Grade.night.color
            return
        }
        let dusk = SKColor(red: 1.00, green: 0.76, blue: 0.58, alpha: 1)
        let dawn = SKColor(red: 0.94, green: 0.82, blue: 0.80, alpha: 1)
        node.run(.repeatForever(.sequence([
            .wait(forDuration: phaseSeconds),                                  // plein jour
            .colorize(with: dusk, colorBlendFactor: 1, duration: 16),
            .wait(forDuration: phaseSeconds * 0.35),                           // heure dorée
            .colorize(with: Grade.night.color, colorBlendFactor: 1, duration: 16),
            .wait(forDuration: phaseSeconds * 0.75),                           // nuit
            .colorize(with: dawn, colorBlendFactor: 1, duration: 14),
            .colorize(with: day.color, colorBlendFactor: 1, duration: 12)
        ])), withKey: "dayCycle")
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

    /// `intensity` multiplie les paliers d'alpha : 1 = halo de jour discret
    /// (lampadaires, props), >1 = halo appuyé pour les zones noires (le
    /// héros dans les mines). Découple la force du halo héros de celle des
    /// props sans avoir à raviver ces derniers.
    static func haloTexture(color: SKColor, intensity: CGFloat = 1) -> SKTexture {
        let key = "\(color.description)|\(intensity)"
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
            // 4 paliers discrets : cœur brillant → bord éteint. Volontairement
            // discrets — en plein jour les halos doivent rester subtils, jamais
            // dominer l'écran (surtout les lampadaires de village).
            let steps: [(radius: CGFloat, alpha: CGFloat)] = [
                (1.00, 0.03), (0.72, 0.06), (0.46, 0.11), (0.24, 0.18)
            ]
            for step in steps {
                c.setFillColor(SKColor(red: r, green: g, blue: b,
                                       alpha: min(1, step.alpha * intensity)).cgColor)
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
    /// `intensity` > 1 renforce le halo (zones noires — halo du héros).
    static func pointLight(radius: CGFloat,
                           color: SKColor,
                           flicker: Bool = false,
                           intensity: CGFloat = 1) -> SKSpriteNode {
        let light = SKSpriteNode(texture: haloTexture(color: color, intensity: intensity))
        light.size = CGSize(width: radius * 2, height: radius * 2)
        light.blendMode = .add
        light.zPosition = 45   // au-dessus des acteurs (20-40), sous le grade
        if flicker {
            // Vacillement de flamme discret : alpha bas (0.30–0.42) pour que
            // les lanternes/torches éclairent sans éblouir en plein jour.
            let wobble = SKAction.repeatForever(.sequence([
                .group([.fadeAlpha(to: 0.32, duration: 0.09),
                        .scale(to: 0.96, duration: 0.09)]),
                .group([.fadeAlpha(to: 0.42, duration: 0.14),
                        .scale(to: 1.03, duration: 0.14)]),
                .group([.fadeAlpha(to: 0.36, duration: 0.11),
                        .scale(to: 1.00, duration: 0.11)])
            ]))
            wobble.timingMode = .easeInEaseOut
            light.alpha = 0.36
            light.run(wobble, withKey: "flicker")
        }
        return light
    }

    // MARK: - Halo du héros

    private static let heroLightName = "kaelLight"

    /// Attache un halo chaud au héros (mines, zones noires). Intensité
    /// modérée (×1.7) : assez pour lire autour de Kael sans l'éblouir.
    static func attachHeroLight(to hero: SKNode, radius: CGFloat = 104) {
        removeHeroLight(from: hero)
        let light = pointLight(radius: radius, color: LightColor.hero, intensity: 1.7)
        light.name = heroLightName
        light.alpha = 0.55
        light.position = CGPoint(x: 0, y: 14)
        light.zPosition = 5
        // Respiration lente — le halo vit sans clignoter
        light.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.45, duration: 1.1),
            .fadeAlpha(to: 0.55, duration: 1.1)
        ])))
        hero.addChild(light)
    }

    static func removeHeroLight(from hero: SKNode) {
        hero.childNode(withName: heroLightName)?.removeFromParent()
    }

}
