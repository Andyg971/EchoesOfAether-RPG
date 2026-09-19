import SpriteKit

// Indice d'interaction : détection du POI à portée, bulle, texte.
// Extrait de GameManager.swift (découpage du monolithe).
@MainActor
extension GameManager {
    // MARK: - Interaction Hint

    func updateInteractionHint() {
        guard let scene else {
            hud.interactionHint = ""
            bubble.hide()
            nearbyActionPoint = nil
            return
        }
        let kaelPos = world.kael.position
        let radius: CGFloat = 90
        var hint = ""
        var bubbleAnchor: CGPoint? = nil
        var bubbleAction: InteractionBubble.Action? = nil
        var actionPoint: CGPoint? = nil   // POI brut pour le bouton A

        if let activeInterior {
            let exit = world.interiorExitPosition(in: scene.size)
            if kaelPos.distance(to: exit) < radius {
                hint = String(localized: "hint.exit")
                bubbleAction = .enter
                bubbleAnchor = CGPoint(x: exit.x, y: exit.y + 34)
                actionPoint = exit
            } else {
                let servicePoint = CGPoint(x: scene.size.width * 0.50, y: scene.size.height * 0.62)
                if kaelPos.distance(to: servicePoint) < radius {
                    switch activeInterior {
                    case .armory: hint = String(localized: "hint.interior.armory")
                    case .apothecary: hint = String(localized: "hint.interior.apothecary")
                    case .inn: hint = String(localized: "hint.interior.inn")
                    }
                    bubbleAction = activeInterior == .inn ? .talk : .shop
                    bubbleAnchor = CGPoint(x: servicePoint.x, y: servicePoint.y + 42)
                    actionPoint = servicePoint
                }
            }
        } else if inMines {
            // POI des mines : plaque, veine, sortie — en coordonnées MONDE
            // via MinesPOI (la descente scrolle sur 2,5 écrans). Les combats
            // n'ont plus de hint : ils partent au contact des rôdeurs.
            let w = scene.size.width
            let h = world.worldHeight > 0 ? world.worldHeight : scene.size.height
            var checkpoints: [(CGPoint, String)] = [
                (MinesPOI.plaque.scaled(w: w, h: h), "hint.examine"),
                (CGPoint(x: w * 0.50, y: h * MinesPOI.exitY), "hint.exit")
            ]
            if !player.minesGoldTaken {
                checkpoints.append((MinesPOI.goldVein.scaled(w: w, h: h), "hint.examine"))
            }
            if let nearest = nearestCheckpoint(from: kaelPos, points: checkpoints, radius: radius) {
                hint = localizedHint(nearest.key)
                bubbleAction = InteractionBubble.Action(hintKey: nearest.key)
                bubbleAnchor = CGPoint(x: nearest.point.x, y: nearest.point.y + 40)
                actionPoint = nearest.point
            }
        } else if inDesert {
            // POI du désert : PNJ, coffre, oasis, sortie. En coordonnées
            // MONDE et par `DesertPOI` : ces points dataient du désert à un
            // écran — depuis qu'Ossara scrolle sur trois, le coffre et
            // l'oasis s'allumaient à un tiers de leur sprite. Les combats
            // n'ont plus de hint : ils partent au contact des rôdeurs.
            let w = scene.size.width
            let h = world.worldHeight > 0 ? world.worldHeight : scene.size.height
            var checkpoints: [(CGPoint, String)] = [
                (CGPoint(x: w * 0.50, y: h * DesertPOI.exitY), "hint.exit"),
                (DesertPOI.npcCaravanier.scaled(w: w, h: h), "hint.talk"),
                (DesertPOI.npcMerchant.scaled(w: w, h: h), "hint.talk"),
                (DesertPOI.npcChild.scaled(w: w, h: h), "hint.talk")
            ]
            if !player.desertChestTaken {
                checkpoints.append((CGPoint(x: w * 0.10, y: h * DesertPOI.chestY),
                                    "hint.examine"))
            }
            if !player.desertOasisUsed {
                checkpoints.append((DesertPOI.oasis.scaled(w: w, h: h), "hint.examine"))
            }
            if let nearest = nearestCheckpoint(from: kaelPos, points: checkpoints, radius: radius) {
                hint = localizedHint(nearest.key)
                bubbleAction = InteractionBubble.Action(hintKey: nearest.key)
                bubbleAnchor = CGPoint(x: nearest.point.x, y: nearest.point.y + 40)
                actionPoint = nearest.point
            }
        } else if inForest {
            // Revisite de la forêt depuis la carte (Acte II+) : mêmes POI
            // qu'en Acte I, sauf le seuil du sanctuaire — cf. le garde
            // `!inForest` de tryForestInteraction, ce bouton ne fait plus
            // rien ici, donc pas de bulle « Entrer » trompeuse.
            let w = scene.size.width
            let h = world.worldHeight > 0 ? world.worldHeight : scene.size.height
            let checkpoints: [(CGPoint, String)] = [
                (CGPoint(x: w*0.88, y: h*0.30), "hint.enter")   // Mines de Cendreval
            ]
            if let nearest = nearestCheckpoint(from: kaelPos, points: checkpoints, radius: radius) {
                hint = localizedHint(nearest.key)
                bubbleAction = InteractionBubble.Action(hintKey: nearest.key)
                bubbleAnchor = CGPoint(x: nearest.point.x, y: nearest.point.y + 40)
                actionPoint = nearest.point
            }
        } else if inOverworld {
            // Carte du monde : à l'approche d'un lieu OUVERT, « A · Entrer … ».
            // Les lieux verrouillés par l'histoire ne proposent rien (anti-saut).
            overworldTarget = nil
            var best: (dist: CGFloat, place: (id: String, pos: CGPoint, title: String))?
            for place in world.overworldPlaces where placeDiscovered(place.id) {
                let d = kaelPos.distance(to: place.pos)
                if d < 130, best == nil || d < best!.dist { best = (d, place) }
            }
            if let hit = best {
                hint = String(localized: "hint.enterPlace \(hit.place.title)")
                bubbleAction = .enter
                bubbleAnchor = CGPoint(x: hit.place.pos.x, y: hit.place.pos.y + 62)
                actionPoint = hit.place.pos
                overworldTarget = hit.place.id
            }
            // Bord du lac : « A · Pêcher » (mini-jeu d'adresse au calme).
            fishingSpotInRange = false
            let shore = WorldBuilder.overworldFishingSpot(
                w: world.worldWidth > 0 ? world.worldWidth : scene.size.width,
                h: world.worldHeight > 0 ? world.worldHeight : scene.size.height)
            if kaelPos.distance(to: shore) < 96 {
                hint = localizedHint("hint.fish")
                bubbleAction = .examine
                bubbleAnchor = CGPoint(x: shore.x, y: shore.y + 44)
                actionPoint = shore
                overworldTarget = nil
                fishingSpotInRange = true
            }
            // Trésor à l'écart des chemins : prioritaire s'il est plus près
            // que le lieu voisin (on ne rate pas un coffre à côté d'une porte).
            overworldChestTarget = nil
            let w = world.worldWidth > 0 ? world.worldWidth : scene.size.width
            let h = world.worldHeight > 0 ? world.worldHeight : scene.size.height
            for chest in WorldBuilder.overworldChests
            where !player.overworldChestsTaken.contains(chest.id) {
                let pos = CGPoint(x: w * chest.at.x, y: h * chest.at.y)
                let d = kaelPos.distance(to: pos)
                guard d < 70, best == nil || d < best!.dist else { continue }
                hint = localizedHint("hint.examine")
                bubbleAction = .examine
                bubbleAnchor = CGPoint(x: pos.x, y: pos.y + 46)
                actionPoint = pos
                overworldTarget = nil
                overworldChestTarget = chest.id
            }
        } else {
            switch phase {
            case .shrine:
                let gate = ShrinePOI.gate.scaled(w: scene.size.width, h: scene.size.height)
                let exit = ShrinePOI.exit.scaled(w: scene.size.width, h: scene.size.height)
                if !player.bossDefeated, kaelPos.distance(to: gate) < ShrinePOI.gateReach {
                    hint = localizedHint("hint.fight")
                    bubbleAction = .fight
                    bubbleAnchor = CGPoint(x: gate.x, y: gate.y + 40)
                    actionPoint = gate
                } else if kaelPos.distance(to: exit) < ShrinePOI.exitReach + 40 {
                    // La sortie avait un panneau mais ni bulle ni bouton A : il
                    // fallait taper pile dessus. Elle s'annonce comme partout.
                    hint = localizedHint("hint.exit")
                    bubbleAction = .enter   // « hint.exit » partage l'icône porte
                    bubbleAnchor = CGPoint(x: exit.x, y: exit.y + 40)
                    actionPoint = exit
                }
            case .village, .act2:
            let npcs: [(SKNode, String)] = [
                (world.lyra,     "hint.talk"),
                (world.dorin,    "hint.talk"),
                (world.bram,     "hint.shop"),
                (world.mara,     "hint.shop"),
                (world.garen,    "hint.talk"),
                (world.sage,     "hint.talk"),
                (world.child,    "hint.talk"),
                (world.villager, "hint.talk")
            ]
            // Portes des maisons : le bouton A permet aussi d'entrer.
            let doors: [(CGPoint, String)] = [.armory, .apothecary, .inn].map {
                (world.houseDoorPosition(for: $0, in: scene.size), "hint.enter")
            }
            let nearestDoor = nearestCheckpoint(from: kaelPos, points: doors, radius: 70)
            if let nearest = nearestNPC(from: kaelPos, npcs: npcs, radius: radius),
               nearestDoor == nil
               || kaelPos.distance(to: nearest.node.position)
                  <= kaelPos.distance(to: nearestDoor!.point) {
                hint = localizedHint(nearest.key)
                bubbleAction = InteractionBubble.Action(hintKey: nearest.key)
                // Ancrer la bulle ~50pt au-dessus de la tête du PNJ
                bubbleAnchor = CGPoint(x: nearest.node.position.x,
                                        y: nearest.node.position.y + 60)
                actionPoint = nearest.node.position
            } else if let door = nearestDoor {
                hint = localizedHint(door.key)
                bubbleAction = .enter
                bubbleAnchor = CGPoint(x: door.point.x, y: door.point.y + 40)
                actionPoint = door.point
            }
        case .ruins:
            // Gardiens et Archiviste chargent Kael : pas de bulle « Combattre ».
            let plan = RuinsLayout(sceneSize: scene.size)
            // Les bulles suivent EXACTEMENT les conditions de
            // `tryRuinsInteraction` : sans ça « A · Examiner » s'affichait sur
            // l'inscription d'Eran déjà lue et sur le mur de la découverte
            // encore scellé — le bouton A ne faisait alors rien.
            var checkpoints: [(CGPoint, String)] = []
            if !player.act2EranFound {
                checkpoints.append((plan.eranInscription, "hint.examine"))
            }
            if player.ruinsProgress >= 2 {
                checkpoints.append((plan.discoveryWall, "hint.examine"))
            }
            if let nearest = nearestCheckpoint(from: kaelPos, points: checkpoints, radius: radius) {
                hint = localizedHint(nearest.key)
                bubbleAction = InteractionBubble.Action(hintKey: nearest.key)
                bubbleAnchor = CGPoint(x: nearest.point.x, y: nearest.point.y + 40)
                actionPoint = nearest.point
            }
        case .forest:
            // POI en coordonnées MONDE (trek scrollable, cf. buildForest)
            let w = scene.size.width
            let h = world.worldHeight > 0 ? world.worldHeight : scene.size.height
            // Combats de forêt = monstres baladeurs (contact) : plus de bulle
            // « A · Combattre ». Elles ne déclenchaient plus rien (le combat au
            // tap a été retiré) → le bouton A semblait « cassé ». Restent les
            // vraies entrées.
            var checkpoints: [(CGPoint, String)] = [
                (CGPoint(x: w*0.88, y: h*0.30), "hint.enter")   // Mines de Cendreval
            ]
            if player.forestProgress >= 2 {
                // Seuil du sanctuaire : ouvert seulement une fois la forêt faite
                // (sinon la bulle « A · Entrer » ne menait à rien).
                checkpoints.append((CGPoint(x: w*0.55, y: h*0.90), "hint.enter"))
            }
            if let nearest = nearestCheckpoint(from: kaelPos, points: checkpoints, radius: radius) {
                hint = localizedHint(nearest.key)
                bubbleAction = InteractionBubble.Action(hintKey: nearest.key)
                bubbleAnchor = CGPoint(x: nearest.point.x, y: nearest.point.y + 40)
                actionPoint = nearest.point
            }
        case .act3:
            let plan = ThresholdLayout(sceneSize: scene.size)
            var checkpoints: [(CGPoint, String)] = []
            if !player.act3EchoJoined, let echoPos = world.thresholdEchoPosition {
                checkpoints.append((echoPos, "hint.talk"))
            }
            for id in ["miner", "mother", "guard"]
            where !player.act3SpiritsCalmed.contains(id) {
                if let pos = world.spiritPosition(id: id) {
                    checkpoints.append((pos, "hint.talk"))
                }
            }
            for stele in plan.steles where !player.act3StelesRead.contains(stele.id) {
                checkpoints.append((stele.pos, "hint.examine"))
            }
            // Les Ombres viennent à Kael : aucune bulle « Combattre ».
            if !player.act3EranMet {
                checkpoints.append((plan.eran, "hint.talk"))
            } else if !player.act3BossDefeated {
                checkpoints.append((plan.portal, "hint.fight"))
            } else {
                checkpoints.append((plan.portal, "hint.enter"))
            }
            if let nearest = nearestCheckpoint(from: kaelPos, points: checkpoints, radius: radius) {
                hint = localizedHint(nearest.key)
                bubbleAction = InteractionBubble.Action(hintKey: nearest.key)
                bubbleAnchor = CGPoint(x: nearest.point.x, y: nearest.point.y + 40)
                actionPoint = nearest.point
            }
        case .act4:
            let plan = VoidHeartLayout(sceneSize: scene.size)
            var checkpoints: [(CGPoint, String)] = []
            for m in plan.memories where !player.act4MemoriesSeen.contains(m.id) {
                checkpoints.append((m.pos, "hint.examine"))
            }
            for id in ["elder", "smith", "lost"]
            where !player.act4ReflectionsFreed.contains(id) {
                if let pos = world.spiritPosition(id: id) {
                    checkpoints.append((pos, "hint.talk"))
                }
            }
            // Les Dévoreurs viennent à Kael : aucune bulle « Combattre ».
            if !player.act4VoiceConfronted {
                checkpoints.append((plan.voiceConfront, "hint.examine"))
            } else if !player.act4BossDefeated {
                checkpoints.append((plan.heart, "hint.fight"))
            } else {
                checkpoints.append((plan.heart, "hint.examine"))
            }
            if let nearest = nearestCheckpoint(from: kaelPos, points: checkpoints, radius: radius) {
                hint = localizedHint(nearest.key)
                bubbleAction = InteractionBubble.Action(hintKey: nearest.key)
                bubbleAnchor = CGPoint(x: nearest.point.x, y: nearest.point.y + 40)
                actionPoint = nearest.point
            }
            default:
                break
            }
        }

        // Save crystal — accessible via A (icône cristal déjà visible)
        if hint.isEmpty, let crystal = world.worldNode.childNode(withName: "saveCrystal")
                                        ?? scene.childNode(withName: "saveCrystal"),
           kaelPos.distance(to: crystal.position) < radius {
            hint = String(localized: "hint.saveCrystal")
            actionPoint = crystal.position
        }

        hud.interactionHint = hint

        // Bouton A : mémorise le POI courant (c'était le chaînon manquant —
        // sans cette ligne, A ne déclenchait jamais rien).
        nearbyActionPoint = actionPoint
        updateActionButtonState()

        if let anchor = bubbleAnchor, let action = bubbleAction {
            let screenAnchor = scene.convert(anchor, from: world.worldNode)
            bubble.show(at: screenAnchor, action: action)
        } else {
            bubble.hide()
        }
    }

    /// Retourne l'action du candidat (PNJ visible) le plus proche de `origin`
    /// dans `radius`. Choisir le plus proche — et non le premier — évite qu'un
    /// tap entre deux PNJ proches déclenche le mauvais.
    func nearestInteraction(from origin: CGPoint,
                                    candidates: [(node: SKNode, action: () -> Void)],
                                    radius: CGFloat) -> (() -> Void)? {
        var best: (action: () -> Void, dist: CGFloat)?
        for candidate in candidates where !candidate.node.isHidden {
            let d = origin.distance(to: candidate.node.position)
            guard d < radius else { continue }
            if best == nil || d < best!.dist {
                best = (candidate.action, d)
            }
        }
        return best?.action
    }

    /// Retourne le PNJ visible le plus proche de `origin` dans `radius`.
    func nearestNPC(from origin: CGPoint,
                             npcs: [(SKNode, String)],
                             radius: CGFloat) -> (node: SKNode, key: String)? {
        var best: (node: SKNode, key: String, dist: CGFloat)? = nil
        for (npc, key) in npcs where !npc.isHidden {
            let d = origin.distance(to: npc.position)
            guard d < radius else { continue }
            if best == nil || d < best!.dist {
                best = (npc, key, d)
            }
        }
        return best.map { ($0.node, $0.key) }
    }

    /// Retourne le checkpoint le plus proche de `origin` dans `radius`.
    func nearestCheckpoint(from origin: CGPoint,
                                    points: [(CGPoint, String)],
                                    radius: CGFloat) -> (point: CGPoint, key: String)? {
        var best: (point: CGPoint, key: String, dist: CGFloat)? = nil
        for (pt, key) in points {
            let d = origin.distance(to: pt)
            guard d < radius else { continue }
            if best == nil || d < best!.dist {
                best = (pt, key, d)
            }
        }
        return best.map { ($0.point, $0.key) }
    }
}
