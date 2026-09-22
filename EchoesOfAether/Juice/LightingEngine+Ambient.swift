import SpriteKit

// LightingEngine — effets d'ambiance : god rays, ombres de nuages, eau vivante, lucioles.
extension LightingEngine {
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

    // MARK: - Ombres de nuages (profondeur top-down)

    /// Blob de nuage pixel : quelques ellipses fusionnées sur une grille
    /// 36×20, rendu `.nearest` — l'ombre garde des bords en escalier.
    static private func cloudTexture() -> SKTexture {
        let cols = 36, rows = 20
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(
            size: CGSize(width: cols, height: rows), format: format
        ).image { ctx in
            let c = ctx.cgContext
            c.setFillColor(SKColor.black.cgColor)
            let lobes: [(cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat)] = [
                (0.35, 0.50, 0.30, 0.42), (0.60, 0.45, 0.34, 0.48),
                (0.48, 0.60, 0.24, 0.36), (0.75, 0.55, 0.20, 0.30)
            ]
            for y in 0..<rows {
                for x in 0..<cols {
                    let nx = (CGFloat(x) + 0.5) / CGFloat(cols)
                    let ny = (CGFloat(y) + 0.5) / CGFloat(rows)
                    let inside = lobes.contains { lobe in
                        let dx = (nx - lobe.cx) / lobe.rx
                        let dy = (ny - lobe.cy) / lobe.ry
                        return dx * dx + dy * dy <= 1
                    }
                    if inside { c.fill(CGRect(x: x, y: y, width: 1, height: 1)) }
                }
            }
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        return texture
    }

    /// Ombres de nuages qui dérivent lentement sur le terrain — LE truc
    /// qui donne de la profondeur à une vue top-down. Espace monde,
    /// au-dessus des acteurs (l'ombre tombe sur tout), sous le grade.
    static func cloudShadows(in size: CGSize, count: Int = 3) -> SKNode {
        let container = SKNode()
        container.zPosition = 58
        let texture = cloudTexture()
        for _ in 0..<count {
            let shadow = SKSpriteNode(texture: texture)
            let w = CGFloat.random(in: 220...360)
            shadow.size = CGSize(width: w, height: w * 0.55)
            shadow.alpha = .random(in: 0.09...0.15)
            let startX = CGFloat.random(in: -w...size.width)
            let y = CGFloat.random(in: size.height * 0.1...size.height * 0.9)
            shadow.position = CGPoint(x: startX, y: y)
            let span = size.width + w * 2
            let speed: CGFloat = .random(in: 14...22)   // pt/s — très lent
            // Traverse, puis retour instantané hors champ à gauche
            let firstLeg = SKAction.moveTo(x: size.width + w, duration:
                TimeInterval((size.width + w - startX) / speed))
            let loop = SKAction.sequence([
                .moveTo(x: -w, duration: 0),
                .moveBy(x: span, y: 0, duration: TimeInterval(span / speed))
            ])
            shadow.run(.sequence([firstLeg, .repeatForever(loop)]))
            container.addChild(shadow)
        }
        return container
    }

    // MARK: - Eau vivante

    /// Scintillements pixel sur un plan d'eau elliptique : étincelles
    /// qui naissent et meurent + nappe additive qui respire.
    static func waterShimmer(center: CGPoint, radiusX: CGFloat, radiusY: CGFloat,
                             count: Int = 12) -> SKNode {
        let container = SKNode()
        container.position = center
        container.zPosition = -9.3   // juste au-dessus des tuiles d'eau (-9.5)

        // Nappe de lumière qui respire
        let sheen = SKSpriteNode(texture: haloTexture(color:
            SKColor(red: 0.70, green: 0.92, blue: 1.0, alpha: 1)))
        sheen.size = CGSize(width: radiusX * 1.6, height: radiusY * 1.6)
        sheen.blendMode = .add
        sheen.alpha = 0.07
        sheen.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.13, duration: 2.6),
            .fadeAlpha(to: 0.05, duration: 2.6)
        ])))
        container.addChild(sheen)

        for _ in 0..<count {
            // Point aléatoire dans l'ellipse (échantillonnage par rejet)
            var p = CGPoint.zero
            for _ in 0..<12 {
                let candidate = CGPoint(x: .random(in: -radiusX...radiusX),
                                        y: .random(in: -radiusY...radiusY))
                let dx = candidate.x / radiusX, dy = candidate.y / radiusY
                if dx * dx + dy * dy <= 0.82 { p = candidate; break }
            }
            let sparkle = SKSpriteNode(color: SKColor(red: 0.82, green: 0.96,
                                                      blue: 1.0, alpha: 1),
                                       size: CGSize(width: 3, height: 2))
            sparkle.position = p
            sparkle.alpha = 0
            sparkle.run(.repeatForever(.sequence([
                .wait(forDuration: .random(in: 0...3.0)),
                .fadeAlpha(to: .random(in: 0.5...0.9), duration: 0.25),
                .wait(forDuration: .random(in: 0.2...0.6)),
                .fadeOut(withDuration: 0.4),
                .wait(forDuration: .random(in: 0.5...2.0))
            ])))
            container.addChild(sparkle)
        }
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
