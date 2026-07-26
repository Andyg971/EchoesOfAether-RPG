import SpriteKit
import UIKit

/// Couleur pixel — fonction libre (non isolée) pour servir de valeur par
/// défaut dans `TopDownHero.Palette` sans conflit d'acteur (Swift 6).
private func heroColor(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> SKColor {
    SKColor(red: r, green: g, blue: b, alpha: 1)
}

/// Héros vus de dessus (Kael/Lyra/Eran) — **pixel art dessiné en code**, comme
/// `PixelIcons` ou les sols de `PixelArtSprites`. Zéro asset, zéro IA.
///
/// Chaque personnage partage la même silhouette (maps de pixels ci-dessous) et
/// se distingue par sa palette. Le corps se compose de deux calques : le haut
/// (tête + torse + bras, fixe pendant la marche) et les jambes (3 poses :
/// repos / pas gauche / pas droit). On rend chaque calque une fois en
/// `SKTexture` .nearest (mis en cache), puis on ne fait que permuter les
/// textures — pas de redessin par frame.
///
/// Vue top-down 3/4 : 3 orientations dessinées (bas / haut / profil) ; la
/// droite est le miroir du profil (xScale négatif). Le déplacement choisit
/// l'orientation d'après le vecteur vélocité.
@MainActor
enum TopDownHero {

    // MARK: - Personnages

    enum Kind: String { case kael, lyra, eran }

    static func palette(for kind: Kind) -> Palette {
        switch kind {
        case .kael:
            return Palette(id: "kael",
                hair: heroColor(0.20, 0.18, 0.25), hairLight: heroColor(0.34, 0.31, 0.42),
                cloth: heroColor(0.44, 0.13, 0.15), clothDark: heroColor(0.28, 0.08, 0.10),
                accent: heroColor(0.82, 0.64, 0.30), pants: heroColor(0.24, 0.20, 0.28))
        case .lyra:
            return Palette(id: "lyra",
                hair: heroColor(0.16, 0.14, 0.20), hairLight: heroColor(0.27, 0.25, 0.34),
                cloth: heroColor(0.20, 0.44, 0.29), clothDark: heroColor(0.13, 0.30, 0.20),
                accent: heroColor(0.78, 0.70, 0.40), pants: heroColor(0.17, 0.30, 0.22))
        case .eran:
            return Palette(id: "eran",
                hair: heroColor(0.56, 0.56, 0.62), hairLight: heroColor(0.72, 0.72, 0.78),
                cloth: heroColor(0.24, 0.33, 0.47), clothDark: heroColor(0.15, 0.22, 0.34),
                accent: heroColor(0.72, 0.75, 0.82), pants: heroColor(0.22, 0.26, 0.35))
        }
    }

    struct Palette {
        let id: String
        let hair, hairLight, cloth, clothDark, accent, pants: SKColor
        // Communs à tous les héros.
        let outline = heroColor(0.09, 0.08, 0.12)
        let skin = heroColor(0.85, 0.66, 0.50)
        let skinShade = heroColor(0.70, 0.50, 0.38)
        let eye = heroColor(0.11, 0.09, 0.15)
        let boot = heroColor(0.30, 0.21, 0.14)

        func map(_ ch: Character) -> SKColor? {
            switch ch {
            case "o": return outline
            case "H": return hair
            case "h": return hairLight
            case "S": return skin
            case "s": return skinShade
            case "E": return eye
            case "C": return cloth
            case "c": return clothDark
            case "A": return accent
            case "L": return pants
            case "B": return boot
            default:  return nil          // '.' et espaces = transparent
            }
        }
    }

    // MARK: - Construction du node

    private enum Facing {
        case down, up, side
        var key: String {
            switch self {
            case .down: return "down"
            case .up:   return "up"
            case .side: return "side"
            }
        }
        init?(rawStored: String?) {
            switch rawStored {
            case "down": self = .down
            case "up":   self = .up
            case "side": self = .side
            default:     return nil
            }
        }
    }

    /// Taille d'un pixel logique du perso, en points (chunky mais net).
    private static let px: CGFloat = 2.1

    /// Construit un héros top-down. Le node renvoyé s'insère comme les autres
    /// personnages : pieds ancrés vers le bas, prêt pour `update(_:velocity:)`.
    static func node(_ kind: Kind, name: String) -> SKNode {
        let pal = palette(for: kind)
        let root = SKNode()
        root.name = name

        // Ombre portée pixel (petit ovale sombre au sol).
        let shadow = SKShapeNode(ellipseOf: CGSize(width: 22, height: 7))
        shadow.fillColor = SKColor(white: 0, alpha: 0.25)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -16)
        shadow.zPosition = -0.5
        root.addChild(shadow)

        // Conteneur du corps : pieds à y=-16 (même convention que les autres).
        let body = SKNode()
        body.name = "topDownHero"
        body.position = CGPoint(x: 0, y: -16)
        body.userData = ["kind": kind.rawValue, "dir": "down", "moving": false]

        let legs = SKSpriteNode(texture: legTexture(pal, frame: 0))
        legs.name = "legs"
        legs.anchorPoint = CGPoint(x: 0.5, y: 0.0)
        legs.position = .zero
        legs.setScale(px)               // texture native (1px/case) → chunky net
        body.addChild(legs)

        let upper = SKSpriteNode(texture: upperTexture(pal, facing: .down))
        upper.name = "upper"
        upper.anchorPoint = CGPoint(x: 0.5, y: 0.0)
        upper.setScale(px)
        // Le haut chevauche la taille : posé juste au-dessus des jambes.
        upper.position = CGPoint(x: 0, y: legsHeightPt - 2 * px)
        body.addChild(upper)

        root.addChild(body)
        return root
    }

    // MARK: - Mise à jour (déplacement)

    /// Oriente et anime le héros selon la vélocité (`.zero` = idle).
    static func update(_ root: SKNode, velocity: CGVector) {
        guard let body = root.childNode(withName: "topDownHero"),
              let upper = body.childNode(withName: "upper") as? SKSpriteNode,
              let legs = body.childNode(withName: "legs") as? SKSpriteNode,
              let kindRaw = body.userData?["kind"] as? String,
              let kind = Kind(rawValue: kindRaw) else { return }
        let pal = palette(for: kind)

        let moving = abs(velocity.dx) > 0.5 || abs(velocity.dy) > 0.5
        let facing: Facing
        var flip = false
        if abs(velocity.dx) > abs(velocity.dy), moving {
            facing = .side
            flip = velocity.dx < 0                // profil dessiné vers la droite
        } else if velocity.dy > 0.5 {
            facing = .up
        } else if velocity.dy < -0.5 {
            facing = .down
        } else {
            // À l'arrêt : conserve la dernière orientation connue.
            facing = Facing(rawStored: body.userData?["dir"] as? String) ?? .down
            flip = (body.userData?["flip"] as? Bool) ?? false
        }

        // Orientation → texture du haut (permutée seulement si elle change).
        let dirKey = facing.key
        if body.userData?["dir"] as? String != dirKey
            || (body.userData?["flip"] as? Bool) != flip {
            upper.texture = upperTexture(pal, facing: facing)
            upper.xScale = flip ? -px : px       // l'échelle px cohabite avec le miroir
            legs.xScale = flip ? -px : px
            body.userData?["dir"] = dirKey
            body.userData?["flip"] = flip
        }

        // Marche : anime les jambes ; à l'arrêt, pose de repos.
        let wasMoving = (body.userData?["moving"] as? Bool) ?? false
        if moving, !wasMoving {
            let step1 = SKAction.setTexture(legTexture(pal, frame: 1))
            let step2 = SKAction.setTexture(legTexture(pal, frame: 2))
            let wait = SKAction.wait(forDuration: 0.14)
            legs.run(.repeatForever(.sequence([step1, wait, step2, wait])),
                     withKey: "walk")
            body.userData?["moving"] = true
        } else if !moving, wasMoving {
            legs.removeAction(forKey: "walk")
            legs.texture = legTexture(pal, frame: 0)
            body.userData?["moving"] = false
        }
    }

    // MARK: - Rendu des calques (cache)

    private static var cache: [String: SKTexture] = [:]

    private static func upperTexture(_ pal: Palette, facing: Facing) -> SKTexture {
        let key = "\(pal.id)_up_\(facing.key)"
        if let t = cache[key] { return t }
        let t = render(map(for: facing), pal: pal)
        cache[key] = t
        return t
    }

    private static func legTexture(_ pal: Palette, frame: Int) -> SKTexture {
        let key = "\(pal.id)_legs_\(frame)"
        if let t = cache[key] { return t }
        let maps = [legsNeutral, legsStepA, legsStepB]
        let t = render(maps[min(frame, 2)], pal: pal)
        cache[key] = t
        return t
    }

    private static var legsHeightPt: CGFloat { CGFloat(legsNeutral.count) * px }

    /// Rend une grille de caractères en `SKTexture` pixel-net.
    private static func render(_ map: [String], pal: Palette) -> SKTexture {
        let rows = map.count
        let cols = map.map(\.count).max() ?? 0
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(
            size: CGSize(width: cols, height: rows), format: format
        ).image { ctx in
            for (r, line) in map.enumerated() {
                for (c, ch) in line.enumerated() {
                    guard let color = pal.map(ch) else { continue }
                    color.setFill()
                    ctx.cgContext.fill(CGRect(x: c, y: r, width: 1, height: 1))
                }
            }
        }
        let tex = SKTexture(image: image)
        tex.filteringMode = .nearest
        // Taille à l'écran = cols×rows pixels logiques × px.
        return tex
    }

    private static func map(for facing: Facing) -> [String] {
        switch facing {
        case .down: return upperDown
        case .up:   return upperUp
        case .side: return upperSide
        }
    }

    // MARK: - Grilles de pixels (16 de large)

    private static let upperDown = [
        "......oooo......",
        ".....oHHHHo.....",
        "....oHHHHHHo....",
        "....HHhhhhHH....",
        "....HSSSSSSH....",
        "....oSSSSSSo....",
        "....oSEssESo....",
        "....oSSssSSo....",
        ".....oSssSo.....",
        "...oCCCCCCCCo...",
        "...oSCCCCCCSo...",
        "...oSCCCCCCSo...",
        "...oCAAAAAACo...",
        "...oCCCCCCCCo..."
    ]

    private static let upperUp = [
        "......oooo......",
        ".....oHHHHo.....",
        "....oHHHHHHo....",
        "....HHHHHHHH....",
        "....HHHhhHHH....",
        "....oHHHHHHo....",
        "....oHHHHHHo....",
        "....oHHHHHHo....",
        ".....oHHHHo.....",
        "...oCCCCCCCCo...",
        "...oSCCCCCCSo...",
        "...oSCCCCCCSo...",
        "...oCAAAAAACo...",
        "...oCCCCCCCCo..."
    ]

    private static let upperSide = [
        ".....oooo.......",
        "....oHHHHo......",
        "...oHHHHHHo.....",
        "...oHhhhHSSo....",
        "...oHHHSSSSo....",
        "...oHHSSSSSo....",
        "...oHSSESSSo....",
        "...oHSSSSSSo....",
        "....oSSSSSo.....",
        "...oCCCCCCo.....",
        "...oCCCCCCSSo...",
        "...oCCCCCCSSo...",
        "...oCAAAACo.....",
        "...oCCCCCCo....."
    ]

    // Jambes (10 de large sous la taille) — repos / pas gauche / pas droit.
    private static let legsNeutral = [
        "...oLLLLLLLLo...",
        "...oLLLooLLLo...",
        "...oLLo..oLLo...",
        "...oLLo..oLLo...",
        "...oBBo..oBBo...",
        "...ooo....ooo..."
    ]

    private static let legsStepA = [
        "...oLLLLLLLLo...",
        "..oLLLo.oLLLo...",
        "..oLLo...oLLo...",
        "..oBBo...oLLo...",
        "..ooo....oBBo...",
        ".........ooo...."
    ]

    private static let legsStepB = [
        "...oLLLLLLLLo...",
        "...oLLLo.oLLLo..",
        "...oLLo...oLLo..",
        "...oLLo...oBBo..",
        "...oBBo....ooo..",
        "...ooo.........."
    ]
}
