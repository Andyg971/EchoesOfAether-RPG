import SpriteKit
import UIKit

// PixelArtSprites — sols : tuiles répétées, planchers et tapis générés (intérieurs).
extension PixelArtSprites {
    /// Recouvre une zone rectangulaire avec des tiles pixel art répétés.
    /// Si plusieurs `tileNames` sont fournis, chaque cellule reçoit un
    /// tile pseudo-aléatoire pour casser l'effet "grille monotone".
    /// Retourne nil si aucun des tiles n'existe.
    /// - tint: assombrir/teinter pour ambiance par zone (color blend 45%)
    static func tiledFloor(tileNames: [String], in size: CGSize,
                            tileScale: CGFloat = 2.0,
                            tint: SKColor? = nil) -> SKNode? {
        let textures: [SKTexture] = tileNames.compactMap { name in
            guard UIImage(named: name) != nil else { return nil }
            let t = SKTexture(imageNamed: name)
            t.filteringMode = .nearest
            return t
        }
        guard !textures.isEmpty else { return nil }

        let firstSize = textures[0].size()
        let tilePtSize = CGSize(width: firstSize.width * tileScale,
                                 height: firstSize.height * tileScale)

        let root = SKNode()
        root.name = "tiledFloor"

        // Random seedé (positions cellule) pour stable inter-frames
        // mais varié spatialement.
        let step = tilePtSize.width - 1
        let cols2 = Int(ceil(size.width / step)) + 1
        let rows2 = Int(ceil(size.height / step)) + 1
        var rng = SystemRandomNumberGenerator()
        for r in 0..<rows2 {
            for c in 0..<cols2 {
                let idx = Int.random(in: 0..<textures.count, using: &rng)
                let sprite = SKSpriteNode(texture: textures[idx])
                sprite.anchorPoint = .zero
                sprite.setScale(tileScale)
                sprite.position = CGPoint(x: CGFloat(c) * step,
                                           y: CGFloat(r) * step)
                if let tint {
                    sprite.color = tint
                    sprite.colorBlendFactor = 0.45
                }
                root.addChild(sprite)
            }
        }
        return root
    }

    /// Surcharge mono-tile pour compatibilité avec les call sites existants.
    static func tiledFloor(tileName: String, in size: CGSize,
                            tileScale: CGFloat = 2.0,
                            tint: SKColor? = nil) -> SKNode? {
        tiledFloor(tileNames: [tileName], in: size,
                    tileScale: tileScale, tint: tint)
    }

    // MARK: - Sols générés (intérieurs)

    /// RNG déterministe (LCG) : le motif du plancher est stable
    /// d'une reconstruction de pièce à l'autre.
    struct SeededRNG: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }
    }

    /// Plancher de bois pixel art généré : planches horizontales,
    /// joints verticaux décalés, nuances et grain par planche.
    /// `palette` : 3+ bruns du plus clair au plus sombre ;
    /// le dernier sert de couleur de joint.
    static func plankFloor(size: CGSize, palette: [UIColor],
                           pixel: CGFloat = 3, seed: UInt64 = 7) -> SKSpriteNode {
        let cols = max(8, Int(ceil(size.width / pixel)))
        let rows = max(8, Int(ceil(size.height / pixel)))
        let plankH = 6                    // hauteur d'une planche en pixels
        let seam = palette.last ?? .black
        // Nuances pondérées : surtout le ton moyen, pour éviter
        // l'effet damier de briques.
        let base = Array(palette.dropLast())
        let shades = base.count >= 3
            ? [base[0], base[1], base[1], base[1], base[2]]
            : base
        var rng = SeededRNG(state: seed)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(
            size: CGSize(width: cols, height: rows), format: format
        ).image { ctx in
            let c = ctx.cgContext
            var rowIdx = 0
            var y = 0
            while y < rows {
                let h = min(plankH, rows - y)
                // Joints verticaux décalés par rangée
                var x = 0
                var jointX = Int.random(in: 24...56, using: &rng)
                    - (rowIdx % 2 == 0 ? 0 : 17)
                while x < cols {
                    let w = min(max(14, jointX - x), cols - x)
                    let shade = shades[Int.random(in: 0..<shades.count, using: &rng)]
                    c.setFillColor(shade.cgColor)
                    c.fill(CGRect(x: x, y: y, width: w, height: h))
                    // Grain : quelques pixels plus sombres dans la planche
                    c.setFillColor(seam.withAlphaComponent(0.35).cgColor)
                    for _ in 0..<max(1, w * h / 26) {
                        let gx = x + Int.random(in: 0..<max(1, w), using: &rng)
                        let gy = y + Int.random(in: 0..<max(1, h), using: &rng)
                        c.fill(CGRect(x: gx, y: gy, width: 1, height: 1))
                    }
                    // Joint vertical
                    c.setFillColor(seam.cgColor)
                    c.fill(CGRect(x: x + w - 1, y: y, width: 1, height: h))
                    x += w
                    jointX = x + Int.random(in: 24...56, using: &rng)
                }
                // Joint horizontal sous la planche
                c.setFillColor(seam.cgColor)
                c.fill(CGRect(x: 0, y: y + h - 1, width: cols, height: 1))
                y += h
                rowIdx += 1
            }
        }

        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        let sprite = SKSpriteNode(texture: texture)
        sprite.anchorPoint = .zero
        sprite.size = CGSize(width: CGFloat(cols) * pixel,
                             height: CGFloat(rows) * pixel)
        return sprite
    }

    /// Tapis tissé pixel art : double bordure + champ à motif de losanges.
    static func wovenRug(size: CGSize, accent: UIColor,
                         pixel: CGFloat = 3) -> SKSpriteNode {
        let cols = max(8, Int(ceil(size.width / pixel)))
        let rows = max(8, Int(ceil(size.height / pixel)))
        var h: CGFloat = 0; var s: CGFloat = 0; var b: CGFloat = 0; var a: CGFloat = 0
        accent.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        let dark = UIColor(hue: h, saturation: min(1, s * 1.1),
                           brightness: b * 0.55, alpha: 1)
        let light = UIColor(hue: h, saturation: s * 0.85,
                            brightness: min(1, b * 1.45), alpha: 1)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(
            size: CGSize(width: cols, height: rows), format: format
        ).image { ctx in
            let c = ctx.cgContext
            // Bord extérieur sombre, liseré clair, champ accent
            c.setFillColor(dark.cgColor)
            c.fill(CGRect(x: 0, y: 0, width: cols, height: rows))
            c.setFillColor(light.cgColor)
            c.fill(CGRect(x: 1, y: 1, width: cols - 2, height: rows - 2))
            c.setFillColor(accent.cgColor)
            c.fill(CGRect(x: 3, y: 3, width: cols - 6, height: rows - 6))
            // Motif : rangées de losanges clairs
            c.setFillColor(light.withAlphaComponent(0.8).cgColor)
            var py = 7
            while py < rows - 7 {
                var px = 7 + ((py / 6) % 2 == 0 ? 0 : 5)
                while px < cols - 7 {
                    c.fill(CGRect(x: px, y: py, width: 1, height: 1))
                    c.fill(CGRect(x: px - 1, y: py + 1, width: 3, height: 1))
                    c.fill(CGRect(x: px, y: py + 2, width: 1, height: 1))
                    px += 10
                }
                py += 6
            }
        }

        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        let sprite = SKSpriteNode(texture: texture)
        sprite.anchorPoint = .zero
        sprite.size = CGSize(width: CGFloat(cols) * pixel,
                             height: CGFloat(rows) * pixel)
        return sprite
    }
}
