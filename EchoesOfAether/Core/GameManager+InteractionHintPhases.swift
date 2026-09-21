import SpriteKit

// Indice d'interaction — les zones lues par PHASE (village, sanctuaire,
// ruines, forêt, Actes III et IV) : PNJ, portes, stèles, échos.
@MainActor
extension GameManager {
    /// Indice selon la phase d'histoire courante (zones à un écran).
    func phaseHint(kaelPos: CGPoint, radius: CGFloat, in scene: SKScene) -> InteractionHint {
        var r = InteractionHint()
        switch phase {
        case .shrine:
            let gate = ShrinePOI.gate.scaled(w: scene.size.width, h: scene.size.height)
            let exit = ShrinePOI.exit.scaled(w: scene.size.width, h: scene.size.height)
            if !player.bossDefeated, kaelPos.distance(to: gate) < ShrinePOI.gateReach {
                r.hint = localizedHint("hint.fight")
                r.bubbleAction = .fight
                r.bubbleAnchor = CGPoint(x: gate.x, y: gate.y + 40)
                r.actionPoint = gate
            } else if kaelPos.distance(to: exit) < ShrinePOI.exitReach + 40 {
                // La sortie avait un panneau mais ni bulle ni bouton A : il
                // fallait taper pile dessus. Elle s'annonce comme partout.
                r.hint = localizedHint("hint.exit")
                r.bubbleAction = .enter   // « hint.exit » partage l'icône porte
                r.bubbleAnchor = CGPoint(x: exit.x, y: exit.y + 40)
                r.actionPoint = exit
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
            r.hint = localizedHint(nearest.key)
            r.bubbleAction = InteractionBubble.Action(hintKey: nearest.key)
            // Ancrer la bulle ~50pt au-dessus de la tête du PNJ
            r.bubbleAnchor = CGPoint(x: nearest.node.position.x,
                                    y: nearest.node.position.y + 60)
            r.actionPoint = nearest.node.position
        } else if let door = nearestDoor {
            r.hint = localizedHint(door.key)
            r.bubbleAction = .enter
            r.bubbleAnchor = CGPoint(x: door.point.x, y: door.point.y + 40)
            r.actionPoint = door.point
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
            r.hint = localizedHint(nearest.key)
            r.bubbleAction = InteractionBubble.Action(hintKey: nearest.key)
            r.bubbleAnchor = CGPoint(x: nearest.point.x, y: nearest.point.y + 40)
            r.actionPoint = nearest.point
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
            r.hint = localizedHint(nearest.key)
            r.bubbleAction = InteractionBubble.Action(hintKey: nearest.key)
            r.bubbleAnchor = CGPoint(x: nearest.point.x, y: nearest.point.y + 40)
            r.actionPoint = nearest.point
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
            r.hint = localizedHint(nearest.key)
            r.bubbleAction = InteractionBubble.Action(hintKey: nearest.key)
            r.bubbleAnchor = CGPoint(x: nearest.point.x, y: nearest.point.y + 40)
            r.actionPoint = nearest.point
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
            r.hint = localizedHint(nearest.key)
            r.bubbleAction = InteractionBubble.Action(hintKey: nearest.key)
            r.bubbleAnchor = CGPoint(x: nearest.point.x, y: nearest.point.y + 40)
            r.actionPoint = nearest.point
        }
        default:
            break
        }
        return r
    }
}
