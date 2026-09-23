import SpriteKit

// Collisions : obstacles, zones bloquantes, tests de passage.
// Extrait de WorldBuilder.swift (découpage du monolithe).
@MainActor
extension WorldBuilder {
    // MARK: - Collisions

    /// Le point (pieds de Kael) est-il dans une empreinte solide ?
    func isBlocked(_ p: CGPoint) -> Bool {
        obstacles.contains { $0.contains(p) }
    }

    /// Point libre le plus proche de `p` (spirale de 4 pt, 120 pt au plus).
    ///
    /// Kael peut se retrouver DANS une empreinte : placement de scénario,
    /// sortie de maison, spawn, empreinte posée après lui. L'ancienne règle
    /// coupait alors toutes les collisions tant qu'il y restait — il
    /// traversait les arbres collés aux maisons et les bosquets qui se
    /// chevauchent. On le DÉGAGE à la place (comme tout moteur de jeu :
    /// dépénétration), puis les collisions s'appliquent sans exception.
    func nearestFreePoint(to p: CGPoint) -> CGPoint {
        guard isBlocked(p) else { return p }
        let step: CGFloat = 4
        for ring in 1...30 {
            let r = CGFloat(ring) * step
            var best: CGPoint?
            var bestD = CGFloat.greatestFiniteMagnitude
            for i in -ring...ring {
                for q in [CGPoint(x: p.x + CGFloat(i) * step, y: p.y + r),
                          CGPoint(x: p.x + CGFloat(i) * step, y: p.y - r),
                          CGPoint(x: p.x + r, y: p.y + CGFloat(i) * step),
                          CGPoint(x: p.x - r, y: p.y + CGFloat(i) * step)] where !isBlocked(q) {
                    let d = p.distance(to: q)
                    if d < bestD { bestD = d; best = q }
                }
            }
            if let best { return best }
        }
        return p
    }

    /// Avance de `a` vers `b` et s'arrête juste avant le premier obstacle
    /// (échantillonnage tous les 6 pt). Retourne la destination atteignable.
    func clampDestination(from a: CGPoint, to b: CGPoint) -> CGPoint {
        let dist = a.distance(to: b)
        guard dist > 1 else { return b }
        let steps = max(1, Int(dist / 6))
        var last = a
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let p = CGPoint(x: a.x + (b.x - a.x) * t,
                            y: a.y + (b.y - a.y) * t)
            if isBlocked(p) { return last }
            last = p
        }
        return b
    }

    func registerObstacle(_ rect: CGRect) {
        obstacles.append(rect)
    }

    /// Audit visuel : --show-obstacles dessine les empreintes en rouge.
    func debugDrawObstacles(in scene: SKScene) {
        guard CommandLine.arguments.contains("--show-obstacles") else { return }
        for rect in obstacles {
            let box = SKShapeNode(rect: rect)
            box.fillColor = SKColor(red: 1, green: 0, blue: 0, alpha: 0.30)
            box.strokeColor = SKColor(red: 1, green: 0.2, blue: 0.2, alpha: 0.9)
            box.lineWidth = 1
            box.zPosition = 500
            add(box, to: scene)
        }
    }

    /// Empreinte au sol d'un node ancré aux pieds (anchor 0.5/0) : bande
    /// horizontale à la base — on peut passer « derrière » (au nord),
    /// jamais au travers.
    func registerFootprint(of node: SKNode,
                                   widthRatio: CGFloat = 0.78,
                                   depthRatio: CGFloat = 0.45,
                                   maxDepth: CGFloat = 34) {
        let f = node.calculateAccumulatedFrame()
        let w = f.width * widthRatio
        guard w > 4 else { return }
        let d = min(f.height * depthRatio, maxDepth)
        registerObstacle(CGRect(x: node.position.x - w / 2,
                                y: node.position.y - 4,
                                width: w, height: max(10, d)))
        // ENCOMBREMENT VISUEL, distinct de l'empreinte solide ci-dessus.
        //
        // L'empreinte est volontairement une mince bande au pied du décor :
        // c'est ce qui laisse Kael passer DERRIÈRE un arbre ou un banc. Mais
        // « derrière », pour un PNJ lâché en promenade au hasard, c'est aussi
        // « pile au milieu du feuillage » ou « debout sur l'assise » — d'où
        // des villageois plantés sur les bancs. Les promeneurs visent donc
        // hors de ce rectangle-là, qui couvre tout le sprite.
        propRects.append(CGRect(x: node.position.x - f.width / 2,
                                y: node.position.y - 6,
                                width: f.width, height: f.height + 6))
    }

    /// Largeur bloquante d'un ARBRE ANIMÉ, lue dans son dessin.
    ///
    /// Les feuillus ronds (`atree_*`) et les sapins (`apine_*`) ont un
    /// feuillage qui descend jusqu'au sol : à hauteur de Kael, il occupe
    /// 86 à 97 % du canevas. Une empreinte au ratio fixe (58–62 %) ne
    /// couvrait que le tronc — Kael s'avançait dans les branches basses
    /// par les côtés, et on le voyait DANS l'arbre. Les arbres fixes, eux,
    /// ont un long tronc nu : leur feuillage passe au-dessus de sa tête.
    ///
    /// Mesure : largeur opaque maximale sur le tiers bas de la première
    /// frame (≈ la hauteur de Kael), × 0,9 pour garder un contact franc
    /// sans accrocher le bout des branches. Jamais sous `minimum`, le ratio
    /// d'origine — un arbre à vrai tronc (`atree_leaf`) garde le sien.
    /// Mis en cache par asset : cinq espèces, une lecture chacune.
    static func foliageFootprintRatio(of asset: String, minimum: CGFloat) -> CGFloat {
        if let cached = foliageRatioCache[asset] { return max(minimum, cached) }
        var ratio: CGFloat = 0
        if let cg = UIImage(named: "\(asset)_idle_1")?.cgImage,
           let ctx = CGContext(data: nil, width: cg.width, height: cg.height,
                               bitsPerComponent: 8, bytesPerRow: cg.width * 4,
                               space: CGColorSpaceCreateDeviceRGB(),
                               bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
           cg.width > 0 {
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
            if let data = ctx.data?.assumingMemoryBound(to: UInt8.self) {
                let w = cg.width, h = cg.height
                var widest = 0
                // Contexte bitmap : la ligne 0 en mémoire est le HAUT de l'image.
                for row in (h - h / 3)..<h {
                    var minX = w, maxX = -1
                    for x in 0..<w where data[(row * w + x) * 4 + 3] > 40 {
                        minX = min(minX, x); maxX = max(maxX, x)
                    }
                    if maxX >= 0 { widest = max(widest, maxX - minX + 1) }
                }
                ratio = CGFloat(widest) / CGFloat(w) * 0.9
            }
        }
        foliageRatioCache[asset] = ratio
        return max(minimum, ratio)
    }

    private static var foliageRatioCache: [String: CGFloat] = [:]

    /// Le décor occupe-t-il ce point à l'écran ? Sert au choix des
    /// destinations de promenade, pas aux collisions de Kael.
    func isCluttered(_ p: CGPoint) -> Bool {
        propRects.contains { $0.contains(p) }
    }

    func layout(in size: CGSize) {
        // Le plan ci-dessous est celui du VILLAGE. Il s'appliquait quelle
        // que soit la zone : au premier `layout()` après un `--zone-…` ou
        // un voyage, Kael était renvoyé au spawn du village (wh * 0.10) —
        // c'est ce qui rendait `--cam-y` inopérant partout sauf au village,
        // où le plan et l'argument coïncidaient.
        guard villagePlanActive else { return }
        let w = size.width
        let wh = worldHeight > 0 ? worldHeight : size.height

        // NPC sur chemin/devant leur lieu de vie selon le plan du village.
        if lyraKeepsVigil {
            placeLyraBesideKael(in: size)                      // réveil : au chevet
        } else {
            lyra.position = CGPoint(x: w * 0.40, y: wh * 0.43) // place, côté marché
        }
        dorin.position   = CGPoint(x: w * 0.56, y: wh * 0.88)  // approche porte nord
        bram.position    = CGPoint(x: w * 0.46, y: wh * 0.60)  // devant l'armurerie
        mara.position    = CGPoint(x: w * 0.27, y: wh * 0.555) // devant l'herboriste
        sage.position    = CGPoint(x: w * 0.73, y: wh * 0.555) // devant l'auberge
        garen.position   = CGPoint(x: w * 0.50, y: wh * 0.925) // porte nord (sentinelle)
        child.position   = CGPoint(x: w * 0.45, y: wh * 0.375) // joue près de la fontaine
        villager.position = CGPoint(x: w * 0.57, y: wh * 0.415) // place centrale
        kael.position    = CGPoint(x: w * 0.485, y: wh * 0.10) // spawn devant sa maison

        [lyra, dorin, bram, mara, sage, garen, child, villager, kael].forEach {
            $0.zPosition = actorLayer(for: $0.position.y)
        }
    }

    /// Réveil (phase wake) : Lyra veille au chevet de Kael devant sa
    /// maison, au lieu d'attendre à son poste de la place centrale.
    func placeLyraBesideKael(in size: CGSize) {
        lyraKeepsVigil = true
        let wh = worldHeight > 0 ? worldHeight : size.height
        lyra.position = CGPoint(x: size.width * 0.44, y: wh * 0.105)
        lyra.zPosition = actorLayer(for: lyra.position.y)
    }

    /// Fin de la veille : Lyra reprend son poste au prochain `layout()`.
    func endLyraVigil() {
        lyraKeepsVigil = false
    }
}
