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
    /// - Parameter startFrame: décalage de phase dans la boucle. Indispensable
    ///   pour les massifs (canopée, foule) : sans lui, cent arbres jouent la
    ///   même frame au même instant et la forêt entière ondule d'un bloc —
    ///   l'œil lit une boucle, pas du vent.
    /// - Returns: `nil` si une frame manque (le caller fait son fallback).
    static func animated(name: String,
                         frames: Int,
                         scale: CGFloat = 1.0,
                         timePerFrame: TimeInterval = 0.12,
                         anchor: CGPoint = CGPoint(x: 0.5, y: 0.0),
                         startFrame: Int = 0) -> SKNode? {
        var textures: [SKTexture] = []
        for i in 1...frames {
            let imageName = "\(name)_idle_\(i)"
            guard UIImage(named: imageName) != nil else { return nil }
            let t = SKTexture(imageNamed: imageName)
            t.filteringMode = .nearest
            textures.append(t)
        }
        guard !textures.isEmpty else { return nil }
        if startFrame > 0 {
            let offset = startFrame % textures.count
            textures = Array(textures[offset...] + textures[..<offset])
        }

        let root = SKNode()
        root.name = name
        // L'asset survit au renommage du node (`node.name = "mara"`) : c'est
        // lui qui permet de retrouver `{asset}_walk_*` au moment de mettre
        // le personnage en marche.
        root.userData = ["pixelAsset": name]
        let sprite = SKSpriteNode(texture: textures[0])
        sprite.anchorPoint = anchor
        sprite.setScale(scale)
        if textures.count > 1 {
            sprite.run(.repeatForever(.animate(with: textures,
                                                timePerFrame: timePerFrame,
                                                resize: false, restore: true)),
                       withKey: cycleKey)
        }
        root.addChild(sprite)
        return root
    }

    /// Clé de l'action de boucle portée par le sprite d'un node `animated`.
    private static let cycleKey = "cycle"

    /// Bascule un node créé par `animated` sur une autre boucle du même
    /// personnage — typiquement `walk` quand il se met en route, `idle`
    /// quand il s'arrête.
    ///
    /// Sans ça, un PNJ qui flâne glisse jambes figées : c'est le détail qui
    /// trahit le plus une foule « animée ».
    ///
    /// - Returns: `false` si la planche demandée n'existe pas — l'appelant
    ///   laisse alors tourner la boucle en cours (cas des sprites qui n'ont
    ///   qu'un idle, comme le chevalier de Dorin).
    @discardableResult
    static func playCycle(_ node: SKNode, suffix: String, frames: Int,
                          timePerFrame: TimeInterval = 0.12) -> Bool {
        guard let asset = node.userData?["pixelAsset"] as? String,
              let sprite = node.children.first as? SKSpriteNode else { return false }
        var textures: [SKTexture] = []
        for i in 1...frames {
            let imageName = "\(asset)_\(suffix)_\(i)"
            guard UIImage(named: imageName) != nil else { return false }
            let t = SKTexture(imageNamed: imageName)
            t.filteringMode = .nearest
            textures.append(t)
        }
        sprite.removeAction(forKey: cycleKey)
        sprite.texture = textures[0]
        sprite.run(.repeatForever(.animate(with: textures,
                                            timePerFrame: timePerFrame,
                                            resize: false, restore: true)),
                   withKey: cycleKey)
        return true
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

    /// Hauteur NATIVE (en pixels) d'un asset, nil s'il n'existe pas.
    /// Sert à normaliser des planches de tailles très différentes à une même
    /// hauteur à l'écran (cf. WorldBuilder.plantMass) : sans ça, un arbre de
    /// 192 px et un de 64 px rendus à la même échelle n'ont rien à voir.
    static func pixelHeight(of name: String) -> CGFloat? {
        guard let image = UIImage(named: name) else { return nil }
        return image.size.height * image.scale
    }

    /// Échelle pour qu'un sprite occupe `height` POINTS à l'écran, quelle
    /// que soit la hauteur native de sa planche.
    ///
    /// Les PNJ refaits au paperdoll font ~46 px de haut là où les anciennes
    /// planches en occupaient 96 : le `scale: 0.5` en dur des appelants les
    /// rendait deux fois trop petits. On vise désormais une taille à
    /// l'écran, pas un facteur.
    static func scale(name: String, height: CGFloat) -> CGFloat {
        guard let native = pixelHeight(of: name), native > 0 else { return 1 }
        return height / native
    }

    /// Hauteur à l'écran d'un PNJ du monde, en points (Kael fait ~50).
    static let npcHeight: CGFloat = 48

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

}
