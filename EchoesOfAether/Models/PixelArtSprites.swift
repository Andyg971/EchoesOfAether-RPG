import SpriteKit
import UIKit

/// Habillage UI pixel art commun (cadres RPG rétro : coins carrés,
/// double bordure, coins crantés dorés). Utilisé par les dialogues,
/// les boutons de combat, les bulles et les panneaux.
@MainActor
enum PixelUI {
    static let gold = SKColor(red: 0.86, green: 0.70, blue: 0.38, alpha: 1)
    static let goldDim = SKColor(red: 0.55, green: 0.44, blue: 0.24, alpha: 0.45)
    static let panelFill = SKColor(red: 0.075, green: 0.058, blue: 0.048, alpha: 0.97)

    /// Police pixel art (VT323, embarquée en DataAsset et enregistrée au
    /// lancement par `registerPixelFont`). Fallback Menlo si absente.
    static var uiFont: String {
        UIFont(name: "VT323-Regular", size: 10) != nil ? "VT323-Regular" : "Menlo-Bold"
    }

    /// Enregistre la police pixel du bundle (DataAsset "PixelFont") —
    /// aucun Info.plist requis. À appeler une fois au démarrage.
    static func registerPixelFont() {
        guard UIFont(name: "VT323-Regular", size: 10) == nil,
              let asset = NSDataAsset(name: "PixelFont"),
              let provider = CGDataProvider(data: asset.data as CFData),
              let font = CGFont(provider) else { return }
        CTFontManagerRegisterGraphicsFont(font, nil)
    }

    /// Applique le cadre pixel à un SKShapeNode existant (le path est
    /// remplacé par un rectangle net). Style SNES : liseré sombre
    /// extérieur + bordure accent — pas de coins crantés ni de double
    /// trait intérieur. Ré-applicable : nettoie ses anciennes
    /// décorations avant de les recréer.
    static func stylePanel(_ shape: SKShapeNode, size: CGSize,
                           fill: SKColor = panelFill,
                           accent: SKColor = gold) {
        shape.path = CGPath(rect: CGRect(x: -size.width / 2, y: -size.height / 2,
                                         width: size.width, height: size.height),
                            transform: nil)
        shape.fillColor = fill
        shape.strokeColor = accent
        shape.lineWidth = 2
        shape.glowWidth = 0

        shape.childNode(withName: "pixelInner")?.removeFromParent()
        shape.childNode(withName: "pixelCorners")?.removeFromParent()
        shape.childNode(withName: "pixelOuter")?.removeFromParent()
        let outer = SKShapeNode(rect: CGRect(x: -size.width / 2 - 2,
                                             y: -size.height / 2 - 2,
                                             width: size.width + 4,
                                             height: size.height + 4))
        outer.name = "pixelOuter"
        outer.fillColor = .clear
        outer.strokeColor = SKColor(red: 0.02, green: 0.02, blue: 0.03, alpha: 0.9)
        outer.lineWidth = 2
        outer.zPosition = -0.1
        shape.addChild(outer)
    }
}

extension SKNode {
    /// Parcourt récursivement les SKSpriteNode DESCENDANTS de ce node.
    /// ⚠️ Ne pas remplacer par `enumerateChildNodes(withName: "//*")` :
    /// le préfixe `//` cherche depuis la RACINE de la scène, pas depuis
    /// ce node — ça corrompait des sprites étrangers (ex. le Kael du
    /// monde recevait les textures d'attaque des ennemis).
    func forEachDescendantSprite(_ body: (SKSpriteNode) -> Void) {
        for child in children {
            if let sprite = child as? SKSpriteNode { body(sprite) }
            child.forEachDescendantSprite(body)
        }
    }
}

/// Helpers d'import pixel art avec fallback automatique. Permet de migrer
/// progressivement les personnages/décors shape vers de vraies textures
/// PNG sans casser le rendu actuel : tant que l'image n'est pas ajoutée
/// à `Assets.xcassets`, le code retourne `nil` et l'appelant utilise sa
/// shape historique.
///
/// ## Convention de nommage (dans Assets.xcassets)
///
/// ```
/// {entity}_idle_1.png        ← frame 1 idle
/// {entity}_idle_2.png        ← frame 2 idle (boucle)
/// ...
/// {entity}_walk_1.png        ← marche frame 1 (optionnel)
/// ```
///
/// Exemples : `lyra_idle_1`, `dorin_idle_1`, `wolf_idle_1`,
/// `tree_pixel_1`, `pillar_sanctuary`.
///
/// ## Format recommandé
///
/// - PNG transparent
/// - Tailles : 32×32 (PNJ) / 48×48 (Kael, boss) / 16×16 (objets)
/// - Palette limitée (16–32 couleurs) pour cohérence
/// - `Render As : Original Image` dans Xcode Asset Catalog
/// - Scales : 1x uniquement (mode preserve current pixel size)
///   → `filteringMode = .nearest` appliqué par le helper pour garder
///   le pixel crisp à toutes les tailles d'écran.
@MainActor
enum PixelArtSprites {

    /// Charge un sprite animé en boucle depuis `Assets.xcassets`.
    /// - Returns: `nil` si une frame manque (le caller fait son fallback).
    static func animated(name: String,
                         frames: Int,
                         scale: CGFloat = 1.0,
                         timePerFrame: TimeInterval = 0.12,
                         anchor: CGPoint = CGPoint(x: 0.5, y: 0.0)) -> SKNode? {
        var textures: [SKTexture] = []
        for i in 1...frames {
            let imageName = "\(name)_idle_\(i)"
            guard UIImage(named: imageName) != nil else { return nil }
            let t = SKTexture(imageNamed: imageName)
            t.filteringMode = .nearest
            textures.append(t)
        }
        guard !textures.isEmpty else { return nil }

        let root = SKNode()
        root.name = name
        let sprite = SKSpriteNode(texture: textures[0])
        sprite.anchorPoint = anchor
        sprite.setScale(scale)
        if textures.count > 1 {
            sprite.run(.repeatForever(.animate(with: textures,
                                                timePerFrame: timePerFrame,
                                                resize: false, restore: true)))
        }
        root.addChild(sprite)
        return root
    }

    /// Charge un sprite statique unique (utilisé pour décor : arbres,
    /// piliers, objets posés au sol).
    static func still(name: String,
                      scale: CGFloat = 1.0,
                      anchor: CGPoint = CGPoint(x: 0.5, y: 0.0)) -> SKNode? {
        guard UIImage(named: name) != nil else { return nil }
        let t = SKTexture(imageNamed: name)
        t.filteringMode = .nearest

        let root = SKNode()
        root.name = name
        let sprite = SKSpriteNode(texture: t)
        sprite.anchorPoint = anchor
        sprite.setScale(scale)
        root.addChild(sprite)
        return root
    }

    /// Vérifie rapidement si un asset pixel art existe dans le bundle.
    /// Pratique pour les helpers de scène qui veulent log les assets
    /// manquants en debug.
    static func exists(_ name: String) -> Bool {
        UIImage(named: name) != nil
    }

    /// Extrait une frame depuis un spritesheet pixel art (RPG Maker MV
    /// format : grille `cols × rows` de frames `frameSize×frameSize`).
    /// Y est indexé depuis le haut (row 0 = première ligne).
    /// Retourne nil si l'asset n'existe pas.
    static func frame(from sheetName: String,
                       frameSize: CGSize,
                       col: Int, row: Int,
                       scale: CGFloat = 1.0,
                       anchor: CGPoint = CGPoint(x: 0.5, y: 0.0)) -> SKNode? {
        guard UIImage(named: sheetName) != nil else { return nil }
        let sheet = SKTexture(imageNamed: sheetName)
        sheet.filteringMode = .nearest
        let sheetPx = sheet.size()

        // Coords normalisées (0…1). Y inversé : SpriteKit origin = bottom.
        let x = CGFloat(col) * frameSize.width / sheetPx.width
        let y = (sheetPx.height - CGFloat(row + 1) * frameSize.height) / sheetPx.height
        let wN = frameSize.width / sheetPx.width
        let hN = frameSize.height / sheetPx.height
        let rect = CGRect(x: x, y: y, width: wN, height: hN)

        let tex = SKTexture(rect: rect, in: sheet)
        tex.filteringMode = .nearest

        let sprite = SKSpriteNode(texture: tex)
        sprite.anchorPoint = anchor
        sprite.setScale(scale)
        let root = SKNode()
        root.name = "\(sheetName)_f\(col)_\(row)"
        root.addChild(sprite)
        return root
    }

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
    private struct SeededRNG: RandomNumberGenerator {
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
