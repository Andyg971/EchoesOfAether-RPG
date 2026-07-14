import SpriteKit

/// Fabrique d'icônes pixel art dessinées en code (grilles de pixels).
/// Remplace tout emoji dans l'UI : chaque icône est une composition de
/// carrés SKSpriteNode sur une grille 8x8, centrée sur (0,0).
@MainActor
enum PixelIcons {

    enum Kind {
        case sword, shield, potion, gem, heart, bolt, darkMoon, coin
        case chat, bag, magnifier, door, skull
    }

    /// Construit l'icône `kind`. `pixel` = taille d'un pixel logique en pt
    /// (2 → icône ~16 pt).
    static func node(_ kind: Kind, pixel: CGFloat = 2) -> SKNode {
        let (map, palette) = spec(for: kind)
        return build(map: map, palette: palette, pixel: pixel)
    }

    /// Grille pixel libre pour les marqueurs du monde (jouet, minerai…) —
    /// même rendu que les icônes, sans passer par un `Kind` dédié.
    static func custom(map: [String], palette: [Character: SKColor],
                       pixel: CGFloat = 2) -> SKNode {
        build(map: map, palette: palette, pixel: pixel)
    }

    // MARK: - Rendu grille

    private static func build(map: [String],
                              palette: [Character: SKColor],
                              pixel: CGFloat) -> SKNode {
        let root = SKNode()
        let rows = map.count
        let cols = map.map(\.count).max() ?? 0
        let totalW = CGFloat(cols) * pixel
        let totalH = CGFloat(rows) * pixel
        for (row, line) in map.enumerated() {
            for (col, ch) in line.enumerated() {
                guard let color = palette[ch] else { continue }
                let px = SKSpriteNode(color: color, size: CGSize(width: pixel, height: pixel))
                px.position = CGPoint(
                    x: CGFloat(col) * pixel - totalW / 2 + pixel / 2,
                    y: totalH / 2 - CGFloat(row) * pixel - pixel / 2
                )
                root.addChild(px)
            }
        }
        return root
    }

    // MARK: - Grilles 8x8

    private static func spec(for kind: Kind) -> ([String], [Character: SKColor]) {
        switch kind {
        case .sword:
            return ([
                "......WW",
                ".....WW.",
                "....WW..",
                "...WW...",
                "G.WW....",
                ".GW.....",
                "GG.G....",
                "H..GG...",
            ], ["W": steel, "G": gold, "H": wood])

        case .shield:
            return ([
                ".BBBBBB.",
                ".BSSSSB.",
                ".BSGGSB.",
                ".BSGGSB.",
                ".BSSSSB.",
                "..BSSB..",
                "...BB...",
                "........",
            ], ["B": ironDark, "S": steel, "G": gold])

        case .potion:
            return ([
                "...WW...",
                "...WW...",
                "..GGGG..",
                ".GPPPPG.",
                ".GPPPPG.",
                ".GPPPPG.",
                "..GGGG..",
                "........",
            ], ["W": steel, "G": glass, "P": pink])

        case .gem:
            return ([
                "........",
                "...CC...",
                "..CCCC..",
                ".CCLLCC.",
                ".CCCCCC.",
                "..CCCC..",
                "...CC...",
                "........",
            ], ["C": cyan, "L": cyanLight])

        case .heart:
            return ([
                "........",
                ".RR..RR.",
                "RRRRRRRR",
                "RRLRRRRR",
                ".RRRRRR.",
                "..RRRR..",
                "...RR...",
                "........",
            ], ["R": red, "L": redLight])

        case .bolt:
            return ([
                "....YY..",
                "...YY...",
                "..YY....",
                ".YYYYY..",
                "...YY...",
                "..YY....",
                ".YY.....",
                "YY......",
            ], ["Y": yellow])

        case .darkMoon:
            return ([
                "..PPPP..",
                ".PP.....",
                "PP......",
                "PP......",
                "PP......",
                "PP......",
                ".PP.....",
                "..PPPP..",
            ], ["P": violet])

        case .coin:
            return ([
                "..YYYY..",
                ".YYYYYY.",
                ".YYDDYY.",
                ".YYDDYY.",
                ".YYDDYY.",
                ".YYYYYY.",
                "..YYYY..",
                "........",
            ], ["Y": gold, "D": goldDark])

        case .chat:
            return ([
                ".WWWWWW.",
                ".W....W.",
                ".W.WW.W.",
                ".W....W.",
                ".WWWWWW.",
                "...WW...",
                "..WW....",
                "........",
            ], ["W": steel])

        case .bag:
            return ([
                "...GG...",
                "..G..G..",
                ".BBBBBB.",
                "BBBBBBBB",
                "BBBGGBBB",
                "BBBBBBBB",
                ".BBBBBB.",
                "........",
            ], ["B": wood, "G": gold])

        case .magnifier:
            return ([
                ".CCCC...",
                "C....C..",
                "C....C..",
                "C....C..",
                ".CCCC...",
                "....HH..",
                ".....HH.",
                "......HH",
            ], ["C": steel, "H": wood])

        case .door:
            return ([
                ".BBBBBB.",
                ".BWWWWB.",
                ".BWWWWB.",
                ".BWWWGB.",
                ".BWWWWB.",
                ".BWWWWB.",
                ".BWWWWB.",
                ".BBBBBB.",
            ], ["B": ironDark, "W": wood, "G": gold])

        case .skull:
            return ([
                "..WWWW..",
                ".WWWWWW.",
                ".WDWWDW.",
                ".WWWWWW.",
                "..WWWW..",
                "..W.W...",
                "..WWWW..",
                "........",
            ], ["W": bone, "D": ironDark])
        }
    }

    // MARK: - Palette pixel art

    private static let steel     = SKColor(red: 0.82, green: 0.85, blue: 0.92, alpha: 1)
    private static let gold      = SKColor(red: 0.95, green: 0.78, blue: 0.30, alpha: 1)
    private static let goldDark  = SKColor(red: 0.72, green: 0.55, blue: 0.18, alpha: 1)
    private static let wood      = SKColor(red: 0.52, green: 0.36, blue: 0.20, alpha: 1)
    private static let ironDark  = SKColor(red: 0.22, green: 0.22, blue: 0.28, alpha: 1)
    private static let glass     = SKColor(red: 0.65, green: 0.85, blue: 0.95, alpha: 0.9)
    private static let pink      = SKColor(red: 0.95, green: 0.35, blue: 0.55, alpha: 1)
    private static let cyan      = SKColor(red: 0.35, green: 0.80, blue: 0.95, alpha: 1)
    private static let cyanLight = SKColor(red: 0.70, green: 0.95, blue: 1.00, alpha: 1)
    private static let red       = SKColor(red: 0.90, green: 0.25, blue: 0.30, alpha: 1)
    private static let redLight  = SKColor(red: 1.00, green: 0.55, blue: 0.60, alpha: 1)
    private static let yellow    = SKColor(red: 1.00, green: 0.85, blue: 0.25, alpha: 1)
    private static let violet    = SKColor(red: 0.60, green: 0.40, blue: 0.90, alpha: 1)
    private static let bone      = SKColor(red: 0.92, green: 0.90, blue: 0.82, alpha: 1)
}
