import SpriteKit

// Briques de construction de la forêt.
// Extrait de WorldBuilder.swift (découpage du monolithe).
@MainActor
extension WorldBuilder {
    // MARK: - Forest Building Blocks

    /// Allée usée : la MÊME pierre que le sol, teintée plus clair. Pas de
    /// tuile dédiée (`me_path_*` sont des cailloux épars, pas un dallage) —
    /// le contraste de teinte suffit à lire le chemin, et reste pixel-net.
    /// Purement visuel : ne bloque rien.
    func addPathStrip(in scene: SKScene, rect: CGRect) {
        guard rect.width > 1, rect.height > 1 else { return }
        // Bord DÉCHIRÉ, pas au cordeau. L'allée était une plaque rectangulaire
        // de pierre éclaircie posée sur la pierre : à l'écran, un rectangle
        // plus clair aux quatre angles nets, et le sol des Ruines, du Seuil et
        // du Cœur du Vide se lisait comme du ruban adhésif collé sur la roche.
        // Ici le tracé se dessine cellule par cellule, ses rives ondulant d'un
        // pas — une dalle descellée par les siècles, pas un marquage au sol.
        let cell: CGFloat = 24
        var strip = VillageTileMap(width: rect.maxX + cell * 2,
                                   height: rect.maxY + cell * 2, tile: cell)
        if rect.height >= rect.width {
            var y = rect.minY
            while y < rect.maxY {
                let n = Self.tileHash(Int(y / cell), 7)
                let x0 = rect.minX + CGFloat(n % 2) * cell
                let x1 = rect.maxX - CGFloat((n >> 4) % 2) * cell
                strip.stamp(rect: CGRect(x: x0, y: y,
                                         width: max(cell, x1 - x0), height: cell))
                y += cell
            }
        } else {
            var x = rect.minX
            while x < rect.maxX {
                let n = Self.tileHash(11, Int(x / cell))
                let y0 = rect.minY + CGFloat(n % 2) * cell
                let y1 = rect.maxY - CGFloat((n >> 4) % 2) * cell
                strip.stamp(rect: CGRect(x: x, y: y0,
                                         width: cell, height: max(cell, y1 - y0)))
                x += cell
            }
        }
        renderTileMap(strip, fullTile: "a2_stone", edgePrefix: nil,
                      in: scene, z: -9,   // au-dessus du sol (-10), sous les props
                      tint: SKColor(red: 0.52, green: 0.46, blue: 0.74, alpha: 1),
                      tintBlend: 0.62)
    }

    /// Paroi pleine : masse de roche + **une seule** empreinte de collision
    /// couvrant tout le bloc.
    ///
    /// La version précédente alignait des colonnes espacées de 46 pt : chaque
    /// empreinte ne faisait que 25 pt de large, laissant 21 pt de trou entre
    /// deux. Le joueur traversait la « paroi », et visuellement ça se lisait
    /// comme des tombes alignées, pas comme un mur. Ici le couloir est creusé
    /// dans la roche : ce qui n'est pas marchable est plein, sans interstice.
    func addWall(in scene: SKScene, rect: CGRect) {
        guard rect.width > 2, rect.height > 2 else { return }

        // Masse : la même pierre que le sol, noyée d'ombre → la roche.
        if let mass = PixelArtSprites.tiledFloor(
            tileNames: ["a2_stone"], in: rect.size, tileScale: 1.0,
            tint: SKColor(red: 0.05, green: 0.04, blue: 0.11, alpha: 1)) {
            mass.position = CGPoint(x: rect.minX, y: rect.minY)
            mass.zPosition = -8   // au-dessus du sol et de l'allée, sous les props
            add(mass, to: scene)
        }

        // Arête éclairée côté couloir : sans elle, la roche et le sol se
        // confondent dans le noir et le couloir cesse d'être lisible.
        let onLeftSide = rect.minX < 1
        let edge = SKShapeNode(rect: CGRect(
            x: onLeftSide ? rect.maxX - 3 : rect.minX,
            y: rect.minY, width: 3, height: rect.height))
        edge.fillColor = SKColor(red: 0.34, green: 0.28, blue: 0.52, alpha: 1)
        edge.strokeColor = .clear
        edge.zPosition = -7
        add(edge, to: scene)

        // Silhouettes de ruine posées SUR l'arête, denses (pas d'alignement
        // régulier lisible comme une frise). Purement décoratives : la
        // collision est déjà portée par le bloc.
        let pieces: [(String, CGFloat)] = [
            ("column_broken_1", 2.0), ("pillar_grey_1", 1.6),
            ("column_broken_1", 2.0), ("pillar_grey_2", 1.6)
        ]
        var i = Int(abs(rect.minX) / 29) % pieces.count
        var y = rect.minY + 12
        while y < rect.maxY - 12 {
            let (asset, scale) = pieces[i % pieces.count]
            // Le pas était irrégulier, mais l'ABSCISSE était fixe : toutes les
            // pièces tombaient sur une même verticale, et les trois zones du
            // Vide alignaient leurs stèles comme un papier peint. Ce qui casse
            // une frise, c'est la profondeur, pas l'espacement.
            let h = Self.tileHash(i, Int(y / 29))
            let inset = 4 + CGFloat(h % 22)
            let x = onLeftSide ? rect.maxX - inset : rect.minX + inset
            let jitter = 0.86 + CGFloat((h >> 5) % 30) / 100      // gabarit ±14 %
            if PixelArtSprites.exists(asset),
               let node = PixelArtSprites.still(name: asset, scale: scale * jitter,
                                                anchor: CGPoint(x: 0.5, y: 0.0)) {
                node.position = CGPoint(x: x, y: y)
                node.zPosition = propLayer(for: y, in: scene.size.height)
                add(node, to: scene)   // pas de registerFootprint : bloc déjà solide
            }
            y += 54 + CGFloat((i * 13) % 17)   // pas irrégulier
            i += 1
        }

        // Collision : un seul rectangle, continu, infranchissable.
        registerObstacle(rect)
    }

    /// Eran Solace, le Premier Gardien, debout au centre du Seuil. Vieil homme
    /// marqué par le Vide : sprite de sage, teinté du violet du Seuil.
    func addEran(in scene: SKScene, at pos: CGPoint) {
        // Le sprite de son pack (fighter) — le même qu'en combat.
        let eran = BattleSprites.worldNode(.eran, name: "eran")
            ?? PixelArtSprites.animated(
                name: "npc_sage", frames: 6,
                scale: PixelArtSprites.scale(name: "npc_sage_idle_1", height: 58),
                timePerFrame: 0.24,
                anchor: CGPoint(x: 0.5, y: 0.0))
        guard let eran else { return }
        eran.name = "eran"
        eran.position = pos
        eran.zPosition = actorLayer(for: pos.y)
        // Marqué par le Vide : teinte violette légère.
        eran.forEachDescendantSprite { s in
            s.color = SKColor(red: 0.55, green: 0.45, blue: 0.85, alpha: 1)
            s.colorBlendFactor = 0.30
        }
        add(eran, to: scene)
    }

    /// Position d'Eran au Seuil (nil s'il n'est pas dans la scène).
    var eranPosition: CGPoint? {
        worldNode.childNode(withName: "eran")?.position
    }
}
