import SpriteKit

// Arène — palette par ennemi, ciel et fond, décor de profondeur, silhouettes.
extension CombatSystem {
    struct ArenaPalette {
        let skyColor: SKColor
        let haloColor: SKColor
        let horizonColor: SKColor
        let stageColor: SKColor
        let stageEdgeColor: SKColor
        let stageStrokeColor: SKColor
        let decorColor: SKColor
    }

    /// DÉCOR D'ARÈNE EN COUCHES — ciel, montagnes, deux lignes d'arbres,
    /// pinède au premier plan (planches `arena_<saison>_1..5`, 1024×346).
    ///
    /// L'arène n'avait qu'un aplat de couleur en guise de fond, et cet aplat
    /// était si sombre (ciel à 0,08/0,04/0,05) que tous les combats se
    /// ressemblaient : du noir. Cinq plans à des profondeurs différentes
    /// donnent un horizon, et la saison change avec la zone — la forêt en
    /// vert, les Ruines en automne, le Sanctuaire en hiver violacé.
    ///
    /// Les couches DÉRIVENT à des vitesses croissantes vers l'avant : c'est
    /// ce décalage, et non le dessin, qui fait lire la profondeur.
    func addArenaBackdrop(to parent: SKNode, size: CGSize,
                                  kind: CombatSpriteKind,
                                  palette: ArenaPalette, floorY: CGFloat) {
        let season: String
        let tint: SKColor?
        switch kind {
        case .beast, .wolf, .ghoul, .boneWalker:
            season = "normal"; tint = nil
        case .ruinsGuardian, .archivist:
            season = "autumn"; tint = nil
        case .guardian:
            // Hiver teinté violet : le Sanctuaire n'est pas un lieu du monde.
            season = "winter"; tint = SKColor(red: 0.45, green: 0.20, blue: 0.75, alpha: 1)
        }

        // 5 = le plus lointain. On les pose du fond vers l'avant, la
        // luminosité montant avec la distance pour creuser l'image.
        for depth in stride(from: 5, through: 1, by: -1) {
            let name = "arena_\(season)_\(depth)"
            guard UIImage(named: name) != nil else { continue }
            let texture = SKTexture(imageNamed: name)
            texture.filteringMode = .nearest
            let layer = SKSpriteNode(texture: texture)
            let scale = size.width / texture.size().width
            layer.setScale(scale)
            layer.anchorPoint = CGPoint(x: 0.5, y: 0.0)
            layer.position = CGPoint(x: size.width / 2, y: floorY - 12)
            // Entre le ciel (−20) et le halo/estrade (≥ 0).
            layer.zPosition = -10 - CGFloat(depth)
            // Les plans lointains s'effacent : c'est la perspective aérienne,
            // et ça garde les combattants lisibles au premier plan.
            layer.alpha = 0.55 + 0.10 * CGFloat(5 - depth)
            if let tint {
                layer.color = tint
                layer.colorBlendFactor = 0.55
            }
            parent.addChild(layer)

            // Dérive : imperceptible au fond, nette devant.
            let amplitude = 2.0 + Double(5 - depth) * 3.0
            let period = 11.0 - Double(5 - depth) * 1.2
            let drift = SKAction.sequence([
                .moveBy(x: amplitude, y: 0, duration: period),
                .moveBy(x: -amplitude, y: 0, duration: period)
            ])
            drift.timingMode = .easeInEaseOut
            layer.run(.repeatForever(drift))
        }

        // Le château, entre le ciel et les arbres : il donne une échelle au
        // lointain et dit qu'il y a un monde derrière le combat.
        let castleName = "arena_\(season)_castle"
        if UIImage(named: castleName) != nil {
            let texture = SKTexture(imageNamed: castleName)
            texture.filteringMode = .nearest
            let castle = SKSpriteNode(texture: texture)
            castle.setScale(size.width / texture.size().width)
            castle.anchorPoint = CGPoint(x: 0.5, y: 0.0)
            castle.position = CGPoint(x: size.width * 0.5, y: floorY - 12)
            castle.zPosition = -14.5   // entre les montagnes (−14) et les arbres (−13)
            castle.alpha = 0.6
            if let tint {
                castle.color = tint
                castle.colorBlendFactor = 0.55
            }
            parent.addChild(castle)
        }
    }

    func arenaPalette(for kind: CombatSpriteKind, isBoss: Bool) -> ArenaPalette {
        switch kind {
        // ⚠️ Ces teintes servent de FOND aux couches de décor
        // (`addArenaBackdrop`). Descendues trop bas, le décor ne se détache
        // plus et l'arène redevient le trou noir qu'elle était : le ciel
        // était à 0,05/0,09/0,07, soit du noir à 7 %.
        case .beast, .wolf, .ghoul, .boneWalker:
            // Forêt d'Ébène : verts profonds, mais un ciel qui existe
            return ArenaPalette(
                skyColor: SKColor(red: 0.11, green: 0.20, blue: 0.16, alpha: 1),
                haloColor: SKColor(red: 0.18, green: 0.30, blue: 0.22, alpha: 0.35),
                horizonColor: SKColor(red: 0.30, green: 0.55, blue: 0.38, alpha: 0.4),
                stageColor: SKColor(red: 0.13, green: 0.19, blue: 0.15, alpha: 1),
                stageEdgeColor: SKColor(red: 0.06, green: 0.10, blue: 0.08, alpha: 1),
                stageStrokeColor: SKColor(red: 0.25, green: 0.45, blue: 0.30, alpha: 0.5),
                decorColor: SKColor(red: 0.04, green: 0.08, blue: 0.05, alpha: 1)
            )
        case .guardian:
            // Sanctuaire de l'Aether : violets profonds
            return ArenaPalette(
                skyColor: SKColor(red: 0.14, green: 0.09, blue: 0.26, alpha: 1),
                haloColor: SKColor(red: 0.40, green: 0.18, blue: 0.65, alpha: 0.45),
                horizonColor: SKColor(red: 0.55, green: 0.25, blue: 0.85, alpha: 0.55),
                stageColor: SKColor(red: 0.18, green: 0.12, blue: 0.28, alpha: 1),
                stageEdgeColor: SKColor(red: 0.08, green: 0.05, blue: 0.13, alpha: 1),
                stageStrokeColor: SKColor(red: 0.55, green: 0.25, blue: 0.85, alpha: 0.6),
                decorColor: SKColor(red: 0.08, green: 0.05, blue: 0.14, alpha: 1)
            )
        case .ruinsGuardian, .archivist:
            // Ruines de la Source : marron-rouge délavé
            let bossBoost: CGFloat = isBoss ? 1.2 : 1.0
            return ArenaPalette(
                skyColor: SKColor(red: 0.20 * bossBoost, green: 0.11, blue: 0.12, alpha: 1),
                haloColor: SKColor(red: 0.45, green: 0.18, blue: 0.15, alpha: 0.4),
                horizonColor: SKColor(red: 0.80, green: 0.35, blue: 0.20, alpha: 0.45),
                stageColor: SKColor(red: 0.20, green: 0.13, blue: 0.11, alpha: 1),
                stageEdgeColor: SKColor(red: 0.09, green: 0.05, blue: 0.05, alpha: 1),
                stageStrokeColor: SKColor(red: 0.60, green: 0.28, blue: 0.18, alpha: 0.55),
                decorColor: SKColor(red: 0.10, green: 0.06, blue: 0.05, alpha: 1)
            )
        }
    }

    /// Silhouettes d'arrière-plan adaptées à la zone. Tente d'abord les
    /// sprites pixel art importés depuis `Assets.xcassets` (Modern Exteriors) ;
    /// fallback automatique sur les shapes programmatiques si l'asset manque.
    func addBackgroundDecor(to floor: SKNode, size: CGSize,
                                     kind: CombatSpriteKind, palette: ArenaPalette) {
        let baseY = size.height * 0.48
        let decorColor = palette.decorColor
        let edgeColor = palette.stageStrokeColor.withAlphaComponent(0.25)

        switch kind {
        case .beast, .wolf, .ghoul, .boneWalker:
            // Forêt : 6 arbres répartis en profondeur (mix tree_medium_1/2/3/big)
            let treeAssets = ["tree_medium_1", "tree_medium_2", "tree_medium_3",
                               "tree_big", "tree_medium_1", "tree_medium_2"]
            let positions: [(x: CGFloat, h: CGFloat, scale: CGFloat)] = [
                (0.08, 130, 0.9), (0.22, 95, 0.7), (0.40, 150, 1.0),
                (0.60, 105, 0.8), (0.78, 140, 0.95), (0.92, 100, 0.75)
            ]
            for (i, p) in positions.enumerated() {
                let pos = CGPoint(x: size.width * p.x, y: baseY)
                let node = decorSprite(name: treeAssets[i], pixelScale: p.scale * 3.5)
                    ?? makeTreeSilhouette(height: p.h, color: decorColor, edge: edgeColor)
                node.position = pos
                if PixelArtSprites.exists(treeAssets[i]) == false {
                    node.setScale(p.scale)
                }
                node.alpha = 0.85
                floor.addChild(node)
            }
        case .guardian:
            // Sanctuaire : 4 piliers (marble tombstone → pilier pierre)
            let assets = ["pillar_grey_1", "pillar_grey_2", "pillar_grey_1", "pillar_grey_2"]
            for (i, x) in [CGFloat(0.12), 0.32, 0.68, 0.88].enumerated() {
                let pos = CGPoint(x: size.width * x, y: baseY - 30)
                let node = decorSprite(name: assets[i], pixelScale: 4.0)
                    ?? makePillarSilhouette(height: 200, color: decorColor, edge: edgeColor)
                node.position = pos
                node.alpha = 0.9
                floor.addChild(node)
            }
        case .ruinsGuardian, .archivist:
            // Ruines : colonnes brisées + ossements épars
            let columnSpecs: [(x: CGFloat, h: CGFloat)] = [(0.12, 130), (0.50, 90), (0.86, 160)]
            for c in columnSpecs {
                let pos = CGPoint(x: size.width * c.x, y: baseY - 20)
                let node = decorSprite(name: "column_broken_1", pixelScale: 4.0)
                    ?? makeBrokenColumn(height: c.h, color: decorColor, edge: edgeColor)
                node.position = pos
                node.alpha = 0.9
                floor.addChild(node)
            }
            if let bones = decorSprite(name: "bones_1", pixelScale: 2.5) {
                bones.position = CGPoint(x: size.width * 0.30, y: baseY - 70)
                bones.alpha = 0.85
                floor.addChild(bones)
            }
        }
    }

    /// Charge un sprite pixel art comme décor avec ancre centrée bas.
    /// Le facteur `pixelScale` upscale les pixels 16×16 vers une taille
    /// lisible à l'écran (×3.5 = ~56pt, équivalent silhouette précédente).
    func decorSprite(name: String, pixelScale: CGFloat) -> SKNode? {
        PixelArtSprites.still(name: name, scale: pixelScale,
                              anchor: CGPoint(x: 0.5, y: 0))
    }

    func makeTreeSilhouette(height: CGFloat, color: SKColor, edge: SKColor) -> SKNode {
        let node = SKNode()
        // Tronc
        let trunk = SKShapeNode(rectOf: CGSize(width: 8, height: height * 0.4), cornerRadius: 2)
        trunk.fillColor = color
        trunk.strokeColor = edge
        trunk.lineWidth = 1
        trunk.position = CGPoint(x: 0, y: height * 0.2)
        node.addChild(trunk)
        // Couronne triangulaire
        let crown = SKShapeNode()
        let p = CGMutablePath()
        p.move(to: CGPoint(x: -28, y: 0))
        p.addLine(to: CGPoint(x: 28, y: 0))
        p.addLine(to: CGPoint(x: 0, y: height * 0.85))
        p.closeSubpath()
        crown.path = p
        crown.fillColor = color
        crown.strokeColor = edge
        crown.lineWidth = 1
        crown.position = CGPoint(x: 0, y: height * 0.25)
        node.addChild(crown)
        return node
    }

    func makePillarSilhouette(height: CGFloat, color: SKColor, edge: SKColor) -> SKNode {
        let node = SKNode()
        let shaft = SKShapeNode(rectOf: CGSize(width: 22, height: height), cornerRadius: 2)
        shaft.fillColor = color
        shaft.strokeColor = edge
        shaft.lineWidth = 1
        node.addChild(shaft)
        // Chapiteau
        let cap = SKShapeNode(rectOf: CGSize(width: 32, height: 10), cornerRadius: 1)
        cap.fillColor = color
        cap.strokeColor = edge
        cap.position = CGPoint(x: 0, y: height / 2 + 4)
        node.addChild(cap)
        // Base
        let base = SKShapeNode(rectOf: CGSize(width: 30, height: 8), cornerRadius: 1)
        base.fillColor = color
        base.strokeColor = edge
        base.position = CGPoint(x: 0, y: -height / 2 - 2)
        node.addChild(base)
        return node
    }

    func makeBrokenColumn(height: CGFloat, color: SKColor, edge: SKColor) -> SKNode {
        let node = SKNode()
        let shaft = SKShapeNode(rectOf: CGSize(width: 26, height: height), cornerRadius: 1)
        shaft.fillColor = color
        shaft.strokeColor = edge
        shaft.lineWidth = 1
        node.addChild(shaft)
        // Sommet brisé : triangle inversé
        let top = SKShapeNode()
        let p = CGMutablePath()
        p.move(to: CGPoint(x: -13, y: height / 2))
        p.addLine(to: CGPoint(x: 13, y: height / 2))
        p.addLine(to: CGPoint(x: -5, y: height / 2 + 12))
        p.closeSubpath()
        top.path = p
        top.fillColor = color
        top.strokeColor = edge
        node.addChild(top)
        // Base trapézoïdale
        let base = SKShapeNode(rectOf: CGSize(width: 34, height: 10), cornerRadius: 1)
        base.fillColor = color
        base.strokeColor = edge
        base.position = CGPoint(x: 0, y: -height / 2 - 4)
        node.addChild(base)
        return node
    }
}
