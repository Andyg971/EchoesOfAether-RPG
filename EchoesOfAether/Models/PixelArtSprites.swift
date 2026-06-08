import SpriteKit
import UIKit

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
}
