import SpriteKit

// Icônes de l'arsenal : un dessin 8x8 par style d'arme et par accessoire,
// même grille et même palette que les icônes de base. Canon : Kael se bat
// aux poings, Lyra au bâton de prêtresse, Eran au bâton de sorcier.
extension PixelIcons.Kind {
    static func weapon(_ style: WeaponStyle) -> PixelIcons.Kind {
        switch style {
        case .gauntlets: .gauntlets
        case .wraps: .wraps
        case .knuckles: .knuckles
        case .gloves: .echoGloves
        case .sacredStaff: .priestStaff
        case .crook: .crook
        case .arcaneStaff: .sorcererStaff
        case .battleStaff: .battleStaff
        }
    }

    static func accessory(id: String) -> PixelIcons.Kind {
        switch id {
        case "ember": .emberTalisman
        case "shade": .shadeAmulet
        case "resonance": .resonanceSeal
        default: .gem
        }
    }
}

extension PixelIcons {
    /// Poing fermé vu de face : quatre doigts séparés par des traits
    /// verticaux, pouce replié en travers, poignet. (Des points isolés à la
    /// place des traits se lisaient comme deux yeux.)
    private static let fistMap = [
        ".AAAAAA.",
        "AABABABA",
        "AABABABA",
        "AAAAAAAA",
        "ABBBBBAA",
        "AAAAAAA.",
        ".AAAAA..",
        "..CCC...",
    ]

    static func arsenalSpec(for kind: Kind) -> ([String], [Character: SKColor]) {
        switch kind {
        case .fist:
            return (fistMap, ["A": skin, "B": skinShade, "C": wood])
        case .gauntlets:
            // Plaques d'acier, bande dorée au poignet.
            return (fistMap, ["A": steel, "B": ironDark, "C": gold])
        case .wraps:
            // Poing bandé de lin : bandes claires sur la peau.
            return ([
                ".AAAAAA.",
                "AABABABA",
                "LLLLLLLL",
                "AAAAAAAA",
                "LLLLLLLL",
                "AAAAAAA.",
                ".LLLLL..",
                "..LLL...",
            ], ["A": skin, "B": skinShade, "L": linen])
        case .knuckles:
            // Barre de fer sur les phalanges.
            return ([
                "SSSSSSSS",
                "SDSDSDSD",
                "AABABABA",
                "AAAAAAAA",
                "ABBBBBAA",
                "AAAAAAA.",
                ".AAAAA..",
                "..CCC...",
            ], ["A": skin, "B": skinShade, "S": steel, "D": ironDark, "C": wood])
        case .echoGloves:
            return (fistMap, ["A": violet, "B": violetLight, "C": goldDark])
        default:
            return staffSpec(for: kind)
        }
    }

    private static func staffSpec(for kind: Kind) -> ([String], [Character: SKColor]) {
        switch kind {
        case .priestStaff:
            // Bâton d'ivoire, anneau doré et gemme claire au sommet.
            return ([
                "....GGG.",
                "...G.Y.G",
                "...G...G",
                "....GGG.",
                "...I....",
                "..I.....",
                ".I......",
                "I.......",
            ], ["G": gold, "Y": yellow, "I": ivory])
        case .crook:
            // Crosse de pèlerin : crochet en haut, hampe droite.
            return ([
                "..WWWW..",
                ".W....W.",
                ".W....W.",
                "......W.",
                "......W.",
                "......W.",
                "......W.",
                ".....GG.",
            ], ["W": wood, "G": gold])
        case .sorcererStaff:
            // Bois sombre, cristal violet au sommet.
            return ([
                ".....VL.",
                "....VVVL",
                ".....VV.",
                "....D...",
                "...D....",
                "..D.....",
                ".D......",
                "D.......",
            ], ["V": violet, "L": violetLight, "D": darkWood])
        case .battleStaff:
            // Hampe de bois ferrée aux deux bouts.
            return ([
                "......SS",
                "......SS",
                ".....W..",
                "....W...",
                "...W....",
                "..W.....",
                "SS......",
                "SS......",
            ], ["W": wood, "S": steel])
        case .emberTalisman:
            return ([
                "...GG...",
                "..G..G..",
                "...GG...",
                "..ROOR..",
                ".ROYYOR.",
                ".ROYYOR.",
                "..ROOR..",
                "...RR...",
            ], ["G": goldDark, "R": red, "O": ember, "Y": yellow])
        case .shadeAmulet:
            return ([
                "G......G",
                ".G....G.",
                "..G..G..",
                "...GG...",
                "..DVVD..",
                ".DVLLVD.",
                "..DVVD..",
                "...DD...",
            ], ["G": goldDark, "D": ironDark, "V": violet, "L": violetLight])
        case .resonanceSeal:
            return ([
                "..CCCC..",
                ".C....C.",
                "C..LL..C",
                "C.L..L.C",
                "C.L..L.C",
                "C..LL..C",
                ".C....C.",
                "..CCCC..",
            ], ["C": cyan, "L": cyanLight])
        default:
            return ([], [:])
        }
    }
}
