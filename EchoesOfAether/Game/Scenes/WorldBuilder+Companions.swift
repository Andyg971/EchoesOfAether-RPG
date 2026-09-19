import SpriteKit

// Compagnons dans le monde : Lyra (forêt, sanctuaire, ruines) et Eran (Seuil, Cœur du Vide).
// Extrait de WorldBuilder.swift (découpage du monolithe).
@MainActor
extension WorldBuilder {
    // MARK: - Lyra compagne (forêt, sanctuaire, ruines)

    /// Fait apparaître Lyra aux côtés de Kael (elle l'accompagne dans
    /// les zones du pacte — le scénario la met à ses côtés).
    func showLyraCompanion() {
        lyra.isHidden = false
        lyra.position = CGPoint(x: kael.position.x - 46, y: kael.position.y - 8)
        lyra.zPosition = actorLayer(for: lyra.position.y)
    }

    /// Suivi doux : Lyra marche derrière Kael quand il s'éloigne.
    func updateLyraFollow(deltaTime: TimeInterval) {
        followStep(lyra, behind: kael, hero: .lyra, deltaTime: deltaTime)
    }

    /// Avance un compagnon vers celui qu'il suit, EN RESPECTANT LES OBSTACLES
    /// (l'eau, les maisons, les rochers) : sans ça les compagnons traversaient
    /// le lac de la carte du monde. Glisse le long des murs, et se téléporte
    /// derrière le meneur s'il reste bloqué trop loin (usage RPG classique).
    ///
    /// `hero` : le pack du compagnon, pour jouer son CYCLE DE MARCHE. Seul
    /// Kael y avait droit (`MovementController`) ; les compagnons glissaient
    /// sur le sol, jambes figées sur la frame d'idle.
    func followStep(_ node: SKNode, behind leader: SKNode,
                            hero: BattleSprites.Hero, deltaTime: TimeInterval) {
        guard !node.isHidden, !leader.isHidden, deltaTime > 0 else { return }
        let target = CGPoint(x: leader.position.x - 40, y: leader.position.y - 6)
        let dx = target.x - node.position.x
        let dy = target.y - node.position.y
        let dist = (dx * dx + dy * dy).squareRoot()

        // Décroché (obstacle contourné par Kael, changement de zone…) :
        // le compagnon rejoint directement, plutôt que de rester coincé.
        guard dist < 320 else {
            node.position = target
            node.zPosition = actorLayer(for: node.position.y)
            return
        }
        guard dist > 54 else {
            // À sa place derrière le meneur : il se repose.
            BattleSprites.updateWalk(hero, on: node, velocity: .zero)
            return
        }

        let step = min(CGFloat(deltaTime) * 240, dist - 44)
        let from = node.position
        let straight = CGPoint(x: from.x + dx / dist * step,
                               y: from.y + dy / dist * step)
        if !isBlocked(straight) {
            node.position = straight
        } else {
            // Glissement : tente l'axe horizontal, puis le vertical.
            let slideX = CGPoint(x: from.x + dx / dist * step, y: from.y)
            let slideY = CGPoint(x: from.x, y: from.y + dy / dist * step)
            if !isBlocked(slideX) {
                node.position = slideX
            } else if !isBlocked(slideY) {
                node.position = slideY
            }
        }
        // Vitesse RÉELLEMENT parcourue : bloqué contre un mur, le compagnon
        // s'arrête au lieu de pédaler sur place.
        let moved = CGVector(dx: node.position.x - from.x,
                             dy: node.position.y - from.y)
        BattleSprites.updateWalk(hero, on: node, velocity: moved)
        node.zPosition = actorLayer(for: node.position.y)
    }

    /// Recalcule la profondeur de Kael (déplacement continu au pad).
    func refreshKaelDepth() {
        kael.zPosition = actorLayer(for: kael.position.y)
    }

    // MARK: - Eran compagnon (Seuil, Cœur du Vide — trio)

    /// Fait apparaître Eran en queue du trio, derrière l'Écho de Lyra. Masque
    /// l'Eran décor du Seuil (`addEran`) pour éviter un doublon. Idempotent.
    func showEranCompanion() {
        guard eran.isHidden else { return }
        worldNode.childNode(withName: "eran")?.isHidden = true   // Eran décor
        eran.isHidden = false
        eran.position = CGPoint(x: lyra.position.x - 42, y: lyra.position.y - 6)
        eran.zPosition = actorLayer(for: eran.position.y)
    }

    /// Suivi doux : Eran marche derrière l'Écho de Lyra (Kael → Écho → Eran).
    func updateEranFollow(deltaTime: TimeInterval) {
        followStep(eran, behind: lyra, hero: .eran, deltaTime: deltaTime)
    }
}
