import SpriteKit

// Indice d'interaction : détection du POI à portée, bulle, texte, bouton A.
// Les détections par zone vivent dans `+InteractionHintZones` et
// `+InteractionHintPhases` ; ici l'orchestration et les helpers de proximité.
@MainActor
extension GameManager {
    /// Ce qu'une zone a trouvé à portée de Kael : le texte du HUD, la bulle
    /// (ancre + icône) et le POI brut que le bouton A déclenchera.
    struct InteractionHint {
        var hint = ""
        var bubbleAnchor: CGPoint? = nil
        var bubbleAction: InteractionBubble.Action? = nil
        var actionPoint: CGPoint? = nil   // POI brut pour le bouton A
    }

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
        var r: InteractionHint
        if activeInterior != nil {
            r = interiorHint(kaelPos: kaelPos, radius: radius, in: scene)
        } else if inMines {
            r = minesHint(kaelPos: kaelPos, radius: radius, in: scene)
        } else if inDesert {
            r = desertHint(kaelPos: kaelPos, radius: radius, in: scene)
        } else if inForest {
            r = forestHint(kaelPos: kaelPos, radius: radius, in: scene)
        } else if inOverworld {
            r = overworldHint(kaelPos: kaelPos, radius: radius, in: scene)
        } else {
            r = phaseHint(kaelPos: kaelPos, radius: radius, in: scene)
        }
        var hint = r.hint
        var actionPoint = r.actionPoint

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

        if let anchor = r.bubbleAnchor, let action = r.bubbleAction {
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
