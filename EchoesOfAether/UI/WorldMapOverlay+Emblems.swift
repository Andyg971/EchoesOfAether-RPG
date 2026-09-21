import SpriteKit

// WorldMapOverlay — emblèmes pixel art par région, dessinés en code.
extension WorldMapOverlay {
    /// Emblème pixel art par région, dessiné en code (hutte, arbre, mine…).
    /// nil si l'id est inconnu (le cadre coloré tient alors lieu de jeton).
    func regionEmblem(_ id: String) -> SKNode? {
        let maps: [String: ([String], [Character: SKColor])] = [
            "village": ([
                "...R...",
                "..RRR..",
                ".RRRRR.",
                "RRRRRRR",
                ".WWDWW.",
                ".WWDWW.",
                ".WWDWW."
            ], ["R": .init(red: 0.62, green: 0.28, blue: 0.22, alpha: 1),
                "W": .init(red: 0.78, green: 0.66, blue: 0.44, alpha: 1),
                "D": .init(red: 0.28, green: 0.18, blue: 0.12, alpha: 1)]),
            "forest": ([
                "..GGG..",
                ".GGGGG.",
                "GGGGGGG",
                ".GGGGG.",
                "..GGG..",
                "...T...",
                "...T..."
            ], ["G": .init(red: 0.24, green: 0.55, blue: 0.30, alpha: 1),
                "T": .init(red: 0.40, green: 0.26, blue: 0.16, alpha: 1)]),
            "shrine": ([
                ".SSSSS.",
                "SSSSSSS",
                "..S.S..",
                "..S.S..",
                "..S.S..",
                "SSSSSSS",
                ".SSSSS."
            ], ["S": .init(red: 0.66, green: 0.68, blue: 0.78, alpha: 1)]),
            "mines": ([
                "BBBBBBB",
                "BwwwwwB",
                "BwKKKwB",
                "BwKKKwB",
                "BwKKKwB",
                "BwwwwwB",
                "BBBBBBB"
            ], ["B": .init(red: 0.42, green: 0.40, blue: 0.46, alpha: 1),
                "w": .init(red: 0.46, green: 0.32, blue: 0.18, alpha: 1),
                "K": .init(red: 0.06, green: 0.05, blue: 0.08, alpha: 1)]),
            "desert": ([
                "...P...",
                "..PPP..",
                ".PPPPP.",
                "PPPPPPP",
                "PPPDPPP",
                "PPPDPPP",
                "PPPDPPP"
            ], ["P": .init(red: 0.82, green: 0.68, blue: 0.40, alpha: 1),
                "D": .init(red: 0.34, green: 0.24, blue: 0.14, alpha: 1)]),
            "ruins": ([
                ".CC.C..",
                ".CC.CC.",
                ".CC.CC.",
                ".CC.CC.",
                "CCC.CC.",
                "CCCCCCC",
                "CCCCCCC"
            ], ["C": .init(red: 0.58, green: 0.56, blue: 0.50, alpha: 1)]),
            "threshold": ([
                ".sSSSs.",
                ".sSSSs.",
                ".ssvss.",
                ".svVvs.",
                ".svVvs.",
                ".svVvs.",
                ".ss.ss."
            ], ["s": .init(red: 0.34, green: 0.32, blue: 0.40, alpha: 1),
                "S": .init(red: 0.48, green: 0.46, blue: 0.56, alpha: 1),
                "v": .init(red: 0.34, green: 0.18, blue: 0.55, alpha: 1),
                "V": .init(red: 0.62, green: 0.36, blue: 0.96, alpha: 1)]),
            "voidheart": ([
                ".V...V.",
                "VVV.VVV",
                "VVVVVVV",
                "VVCCCVV",
                ".VCCCV.",
                "..VCV..",
                "...V..."
            ], ["V": .init(red: 0.32, green: 0.14, blue: 0.46, alpha: 1),
                "C": .init(red: 0.72, green: 0.42, blue: 1.0, alpha: 1)])
        ]
        guard let (map, palette) = maps[id] else { return nil }
        return PixelIcons.custom(map: map, palette: palette, pixel: 2)
    }
}
