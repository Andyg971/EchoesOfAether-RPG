import SpriteKit

/// Donne vie au monde sans nouvelle frame d'animation : les PNJ n'ont que
/// des sprites `idle` (6 frames), pas de cycle de marche. On simule la vie
/// avec du mouvement de node — respiration verticale, coups d'œil (flip),
/// petits pas en aller-retour (zéro dérive, donc résilient à `layout()`).
/// Tout est en code : aucun asset, cohérent avec la charte pixel.
@MainActor
enum AmbientLife {

    private static let breatheKey = "ambientBreathe"
    private static let stepKey     = "ambientStep"
    private static let glanceKey   = "ambientGlance"

    /// Anime un PNJ « en vie ». Idempotent : re-appelable à chaque
    /// reconstruction de zone sans empiler les actions.
    static func enliven(_ npc: SKNode, wanderRadius: CGFloat = 14) {
        guard let sprite = npc.children.compactMap({ $0 as? SKSpriteNode }).first
        else { return }

        // Respiration : le sprite (ancré aux pieds) monte/descend d'~1,5px.
        // Phase aléatoire → le village ne respire pas au même rythme.
        sprite.removeAction(forKey: breatheKey)
        let baseY = sprite.position.y
        let breathe = SKAction.sequence([
            .moveTo(y: baseY + 1.5, duration: 0.9),
            .moveTo(y: baseY, duration: 0.9)
        ])
        breathe.timingMode = .easeInEaseOut
        sprite.run(.sequence([
            .wait(forDuration: .random(in: 0...1.2)),
            .repeatForever(breathe)
        ]), withKey: breatheKey)

        // Coups d'œil : retournement horizontal occasionnel (le PNJ
        // « regarde » à gauche puis à droite). Préserve l'échelle.
        npc.removeAction(forKey: glanceKey)
        let mag = abs(sprite.xScale == 0 ? 1 : sprite.xScale)
        let glance = SKAction.sequence([
            .wait(forDuration: .random(in: 4...9)),
            .run { [weak sprite] in sprite?.xScale = mag },
            .wait(forDuration: .random(in: 3...7)),
            .run { [weak sprite] in sprite?.xScale = -mag }
        ])
        sprite.run(.repeatForever(glance), withKey: glanceKey)

        // Micro-déambulation : un pas de côté puis retour. Symétrique →
        // le PNJ revient toujours à son point de layout, jamais de dérive
        // ni de collision (rayon volontairement petit).
        npc.removeAction(forKey: stepKey)
        let step = SKAction.sequence([
            .wait(forDuration: .random(in: 3...8)),
            .moveBy(x: .random(in: -wanderRadius...wanderRadius),
                    y: .random(in: -wanderRadius * 0.4...wanderRadius * 0.4),
                    duration: .random(in: 1.4...2.2))
        ])
        // Chaque aller est suivi de son retour exact (action inverse).
        npc.run(.repeatForever(.sequence([step, step.reversed()])),
                withKey: stepKey)
    }

    /// Coupe la vie (combat, cinématique, changement de zone).
    static func freeze(_ npc: SKNode) {
        npc.removeAction(forKey: stepKey)
        npc.removeAction(forKey: glanceKey)
        npc.children.compactMap { $0 as? SKSpriteNode }.first?
            .removeAction(forKey: breatheKey)
    }

    // MARK: - Oiseaux

    /// Sprite oiseau pixel : silhouette « V » de 5×3 en `.nearest`, avec
    /// battement d'ailes en 2 frames (V ouvert / V refermé).
    private static func birdTextures() -> [SKTexture] {
        func make(_ open: Bool) -> SKTexture {
            let w = 5, h = 3
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let image = UIGraphicsImageRenderer(
                size: CGSize(width: w, height: h), format: format
            ).image { ctx in
                let c = ctx.cgContext
                c.setFillColor(SKColor(white: 0.12, alpha: 0.9).cgColor)
                if open {
                    // Ailes hautes : \  /
                    for (x, y) in [(0, 0), (1, 1), (2, 2), (3, 1), (4, 0)] {
                        c.fill(CGRect(x: x, y: y, width: 1, height: 1))
                    }
                } else {
                    // Ailes basses : —v—
                    for (x, y) in [(0, 1), (1, 1), (2, 2), (3, 1), (4, 1)] {
                        c.fill(CGRect(x: x, y: y, width: 1, height: 1))
                    }
                }
            }
            let t = SKTexture(image: image)
            t.filteringMode = .nearest
            return t
        }
        return [make(true), make(false)]
    }

    /// Volées d'oiseaux qui traversent le ciel en diagonale, en boucle.
    /// Espace écran (ne scrolle pas), tout en haut (zPosition élevé).
    static func birds(in size: CGSize, flocks: Int = 2) -> SKNode {
        let container = SKNode()
        container.zPosition = 70
        let textures = birdTextures()
        let flap = SKAction.repeatForever(
            .animate(with: textures, timePerFrame: 0.18))

        for _ in 0..<flocks {
            let flock = SKNode()
            let birdCount = Int.random(in: 3...5)
            for i in 0..<birdCount {
                let bird = SKSpriteNode(texture: textures[0])
                bird.size = CGSize(width: 15, height: 9)
                // Formation en V décalée
                bird.position = CGPoint(x: CGFloat(i) * -16,
                                        y: CGFloat(abs(i - birdCount / 2)) * 9)
                bird.run(flap)
                flock.addChild(bird)
            }
            // Traversée lente diagonale, longue pause hors champ, reprise
            let startY = CGFloat.random(in: size.height * 0.55...size.height * 0.92)
            flock.position = CGPoint(x: -60, y: startY)
            let cross = SKAction.moveBy(
                x: size.width + 140,
                y: .random(in: -60...20),
                duration: .random(in: 14...20))
            flock.run(.repeatForever(.sequence([
                cross,
                .moveTo(x: -60, duration: 0),
                .run { [weak flock] in
                    flock?.position.y = .random(in: size.height * 0.55...size.height * 0.92)
                },
                .wait(forDuration: .random(in: 8...18))
            ])))
            // Départ désynchronisé
            flock.speed = 1
            flock.isPaused = false
            container.addChild(flock)
        }
        return container
    }
}
