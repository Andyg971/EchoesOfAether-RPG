import SpriteKit

// Icônes de l'arsenal : un dessin 8x8 par style d'arme et par accessoire,
// même grille et même palette que les icônes de base.
extension PixelIcons.Kind {
    static func weapon(_ style: WeaponStyle) -> PixelIcons.Kind {
        switch style {
        case .blade: .sword
        case .rapier: .rapier
        case .greatsword: .greatsword
        case .echo: .echoBlade
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
    static func arsenalSpec(for kind: Kind) -> ([String], [Character: SKColor]) {
        switch kind {
        case .rapier:
            // Lame fine d'un pixel, garde en coquille dorée.
            return ([
                ".......W",
                "......W.",
                ".....W..",
                "....W...",
                "..GW....",
                ".GGG....",
                ".HG.....",
                "H.......",
            ], ["W": steel, "G": gold, "H": wood])

        case .greatsword:
            // Lame large de trois pixels, longue garde.
            return ([
                ".....WWW",
                "....WWWS",
                "...WWWS.",
                "G.WWWS..",
                "GGWWS...",
                ".GGS....",
                ".HGGG...",
                "H...G...",
            ], ["W": steel, "S": ironDark, "G": gold, "H": wood])

        case .echoBlade:
            // La lame de Kael, tranchant d'Aether violet.
            return ([
                "......VL",
                ".....VL.",
                "....VL..",
                "...VL...",
                "G.VL....",
                ".GV.....",
                "GG.G....",
                "H..GG...",
            ], ["V": violet, "L": violetLight, "G": gold, "H": wood])

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
