import SpriteKit

// PNJ errants du village : promenade, orientation, pauses.
// Extrait de WorldBuilder.swift (découpage du monolithe).
@MainActor
extension WorldBuilder {
    // MARK: - PNJ errants (village)

    /// Vrai si on est à l'intérieur d'une maison.
    var isInsideInterior: Bool { activeInterior != nil }

    /// Lance la promenade libre des PNJ du village : chacun flâne autour
    /// de son poste, en évitant maisons et obstacles.
    /// Garen (sentinelle) fait les cent pas près de la porte nord.
    /// Idempotent : ne relance pas un PNJ déjà en promenade.
    func startVillageWander(in size: CGSize) {
        // Rayons resserrés : à 200-240 pt les PNJ traversaient un tiers du
        // village et finissaient dans le marché ou sous les arbres. Un
        // villageois flâne devant chez lui, il ne fait pas le tour du bourg.
        var walkers: [(SKNode, CGFloat)] = [
            (dorin, 130), (bram, 120), (mara, 120), (sage, 120),
            (child, 160), (villager, 140), (garen, 46)
        ]
        if !lyraKeepsVigil { walkers.append((lyra, 140)) }
        // Les figurants gardent leur porte : rayon plus court encore, sinon
        // huit villageois convergent vers la place et les maisons se vident.
        walkers += villageFolk.filter { $0.parent != nil }.map { ($0, 90) }
        for (npc, radius) in walkers where npc.action(forKey: "wander") == nil {
            scheduleWander(npc, home: npc.position, radius: radius, sceneWidth: size.width)
        }
    }

    /// Stoppe toute promenade (dialogue, combat, intérieur, cinématique).
    func stopVillageWander() {
        for npc in [lyra, dorin, bram, mara, sage, garen, child, villager] + villageFolk {
            npc.removeAction(forKey: "wander")
        }
    }

    /// Un pas de promenade : pause aléatoire, puis marche lente vers un
    /// point libre autour du poste d'origine — et on recommence.
    func scheduleWander(_ npc: SKNode, home: CGPoint,
                                radius: CGFloat, sceneWidth: CGFloat) {
        let wh = worldHeight > 0 ? worldHeight : 402
        // On TIRE plusieurs destinations et on garde la première qui ne
        // tombe pas dans du décor. Le tirage unique d'avant plantait
        // régulièrement un villageois sur un banc ou dans un arbre : la
        // collision autorise le « derrière », l'œil y lit « dessus ».
        // MARCHE HORIZONTALE UNIQUEMENT.
        //
        // Les sprites de village n'ont QU'UN cycle de marche de face : ni dos,
        // ni profil. Dès qu'un PNJ remonte vers le nord, il joue des pas qui
        // avancent vers la caméra tout en s'éloignant — il marche à reculons,
        // et aucun miroir horizontal ne peut le rattraper.
        //
        // Tant qu'il n'existe pas de planche de dos, la seule marche honnête
        // est latérale : on fige la destination sur la LIGNE du poste, à un
        // jitter près (±6 pt) qui reste sous le seuil de perception. Le PNJ
        // flâne alors de gauche à droite devant chez lui, ce qu'un sprite de
        // face rend correctement.
        // L'ordonnée est FIXÉE sur la ligne du poste avant toute validation :
        // la destination testée contre le décor est donc celle où le PNJ ira
        // vraiment. (Écraser `dest.y` après coup rouvrirait la porte aux
        // villageois plantés dans un banc.)
        let lineY = min(max(home.y, 72), wh - 52)
        var dest = npc.position
        for _ in 0..<10 {
            let target = CGPoint(
                x: min(max(home.x + .random(in: -radius...radius), 40), sceneWidth - 40),
                y: lineY)
            guard !isCluttered(target) else { continue }
            let candidate = clampDestination(from: npc.position, to: target)
            guard !isCluttered(candidate) else { continue }
            dest = candidate
            break
        }
        let dist = npc.position.distance(to: dest)

        // Trois familles de sprites, trois façons de marcher :
        // — les héros portent un pack avec cycle de marche, piloté par
        //   `updateWalk` (qui compense aussi le décalage du corps dans son
        //   canevas ; retourner leurs sprites à la main les faisait sauter) ;
        // — les personnages paperdoll ont une planche `{asset}_walk_*` :
        //   on bascule dessus le temps du trajet, sinon ils GLISSENT ;
        // — les sprites qui n'ont qu'un idle (le chevalier de Dorin) se
        //   contentent du miroir, `playCycle` renvoyant false sans rien casser.
        let pack = Self.packHero(for: npc)

        var steps: [SKAction] = [.wait(forDuration: .random(in: 0.8...3.6))]
        if dist > 14, !isBlocked(dest) {
            let dx: CGFloat = dest.x - npc.position.x
            let facing: CGFloat = dx < 0 ? -1 : 1
            steps.append(.run { [weak npc] in
                guard let npc else { return }
                if let pack {
                    BattleSprites.updateWalk(pack, on: npc,
                                             velocity: CGVector(dx: dx, dy: 1))
                } else {
                    PixelArtSprites.playCycle(npc, suffix: "walk", frames: 8,
                                              timePerFrame: 0.11)
                    npc.forEachDescendantSprite { $0.xScale = facing * abs($0.xScale) }
                }
            })
            let duration = TimeInterval(dist / 46)   // flânerie lente
            steps.append(.group([
                .move(to: dest, duration: duration),
                .customAction(withDuration: duration) { [weak self] node, _ in
                    guard let self else { return }
                    node.zPosition = self.actorLayer(for: node.position.y)
                }
            ]))
            steps.append(.run { [weak npc] in
                guard let npc else { return }
                if let pack {
                    BattleSprites.updateWalk(pack, on: npc, velocity: .zero)
                } else {
                    // Retour au repos : sans ça le villageois arrivé à
                    // destination continue de pédaler sur place.
                    PixelArtSprites.playCycle(npc, suffix: "idle", frames: 6,
                                              timePerFrame: 0.16)
                    npc.forEachDescendantSprite { $0.xScale = facing * abs($0.xScale) }
                }
            })
        }
        steps.append(.run { [weak self, weak npc] in
            guard let self, let npc, !npc.isHidden else { return }
            self.scheduleWander(npc, home: home, radius: radius, sceneWidth: sceneWidth)
        })
        npc.run(.sequence(steps), withKey: "wander")
    }

    /// Le héros dont ce node porte le pack de sprites, s'il en porte un.
    /// `nil` = PNJ chibi ou silhouette de secours (pas de cycle de marche).
    static func packHero(for node: SKNode) -> BattleSprites.Hero? {
        guard node.childNode(withName: "body") != nil else { return nil }
        switch node.name {
        case "kael": return .kael
        case "lyra": return .lyra
        case "eran": return .eran
        default:     return nil
        }
    }
}
