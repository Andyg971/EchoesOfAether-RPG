import SpriteKit

// LoreOverlay — l'onglet Bestiaire : vignettes d'espèces, pagination, emblème de boss.
extension LoreOverlay {
    // MARK: - Bestiaire

    func buildBestiary() {
        let rowH: CGFloat = 38
        let top = panelHeight/2 - 102
        let perPage = max(1, Int((top - (-panelHeight/2 + 60)) / rowH))
        let all = Array(CombatSpriteKind.allCases)
        let pages = max(1, Int(ceil(Double(all.count) / Double(perPage))))
        bestiaryPage = min(bestiaryPage, pages - 1)
        let start = bestiaryPage * perPage
        let slice = Array(all[start ..< min(all.count, start + perPage)])
        var y = top

        for kind in slice {
            let seen = bestiarySeen.contains(kind.bestiaryID)

            // Vignette : frame idle du sprite, silhouette noire si inconnue
            if let asset = kind.thumbnailAsset,
               let thumb = PixelArtSprites.still(name: asset, scale: 0.34,
                                                 anchor: CGPoint(x: 0.5, y: 0.5)) {
                thumb.position = CGPoint(x: -panelWidth/2 + 34, y: y - 6)
                if !seen {
                    thumb.forEachDescendantSprite { s in
                        s.color = .black
                        s.colorBlendFactor = 0.92
                    }
                }
                root.addChild(thumb)
                entryLabels.append(thumb)
            } else {
                // Boss programmatiques : visage pixel (cornes + yeux ardents),
                // silhouette noire tant qu'il n'a pas été rencontré.
                let boss = bossEmblem(seen: seen)
                boss.position = CGPoint(x: -panelWidth/2 + 34, y: y - 4)
                root.addChild(boss)
                entryLabels.append(boss)
            }

            if seen {
                let nameL = makeLabel(kind.speciesName, size: 16,
                                      color: SKColor(white: 0.92, alpha: 1))
                nameL.horizontalAlignmentMode = .left
                nameL.position = CGPoint(x: -panelWidth/2 + 58, y: y)
                root.addChild(nameL)
                entryLabels.append(nameL)

                // Faiblesses (icônes texte colorées) + bouclier
                let tactics = CombatSystem.tactics(for: kind, isBoss: false)
                let weakText = tactics.weaknesses
                    .map { $0.icon }.sorted().joined(separator: " ")
                let detail = makeLabel(
                    String(localized: "bestiary.row.detail \(weakText) \(tactics.shieldMax)"),
                    size: 11, color: SKColor(red: 0.94, green: 0.86, blue: 0.62, alpha: 0.95))
                detail.horizontalAlignmentMode = .left
                detail.position = CGPoint(x: -panelWidth/2 + 58, y: y - 13)
                root.addChild(detail)
                entryLabels.append(detail)

                let desc = makeLabel(kind.bestiaryDescription, size: 10,
                                     color: SKColor(white: 0.52, alpha: 1))
                desc.horizontalAlignmentMode = .left
                desc.numberOfLines = 1
                desc.preferredMaxLayoutWidth = panelWidth - 80
                desc.position = CGPoint(x: -panelWidth/2 + 58, y: y - 24)
                root.addChild(desc)
                entryLabels.append(desc)
            } else {
                let nameL = makeLabel("???", size: 16, color: SKColor(white: 0.35, alpha: 1))
                nameL.horizontalAlignmentMode = .left
                nameL.position = CGPoint(x: -panelWidth/2 + 58, y: y - 8)
                root.addChild(nameL)
                entryLabels.append(nameL)
            }

            y -= rowH
        }
        addPager(page: bestiaryPage, pages: pages)
    }

    /// Indicateur de page « ◄ page X/Y ► » au bas du panneau, quand il y a
    /// plus d'une page à feuilleter (joystick haut/bas).
    func addPager(page: Int, pages: Int) {
        guard pages > 1 else { return }
        let arrows = (page > 0 ? "▲ " : "  ")
            + String(localized: "lore.pager \(page + 1) \(pages)")
            + (page < pages - 1 ? " ▼" : "  ")
        let l = makeLabel(arrows, size: 13, color: PixelUI.gold)
        l.position = CGPoint(x: 0, y: -panelHeight/2 + 56)
        root.addChild(l)
        entryLabels.append(l)
    }

    /// Joystick haut/bas : feuillette la page de l'onglet courant.


    /// Visage de boss générique en pixel art (cornes, yeux ardents, crocs).
    /// `seen == false` → silhouette encrée noire, comme les vignettes d'ennemis.
    func bossEmblem(seen: Bool) -> SKNode {
        let map = [
            "H.....H",
            "HHHHHHH",
            "HKKKKKH",
            "EKKKKKE",
            "HKKKKKH",
            "HKfKfKH",
            ".HHHHH."
        ]
        let palette: [Character: SKColor] = seen
            ? ["H": .init(red: 0.40, green: 0.18, blue: 0.52, alpha: 1),
               "K": .init(red: 0.10, green: 0.07, blue: 0.14, alpha: 1),
               "E": .init(red: 1.0, green: 0.42, blue: 0.30, alpha: 1),
               "f": .init(red: 0.88, green: 0.86, blue: 0.78, alpha: 1)]
            : ["H": .init(white: 0.14, alpha: 1),
               "K": .init(white: 0.10, alpha: 1),
               "E": .init(white: 0.22, alpha: 1),
               "f": .init(white: 0.20, alpha: 1)]
        return PixelIcons.custom(map: map, palette: palette, pixel: 2)
    }
}
