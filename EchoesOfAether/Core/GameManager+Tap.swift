import SpriteKit

// Tap à l'écran : priorité aux overlays modaux, puis HUD, puis monde.
extension GameManager {
    func handleTap(at point: CGPoint, in scene: SKScene) {
        // Le tutoriel est modal : il bloque toute autre interaction tant
        // qu'il est visible.
        // Tutoriel : A = suivant, B = passer (contrôles classiques) ; sinon
        // il absorbe le tap direct comme avant.
        if tutorial.isActive {
            if !bButton.isHidden, point.distance(to: bButton.position) < 38 {
                handleBPress(); return
            }
            if !actionButton.isHidden, point.distance(to: actionButton.position) < 42 {
                popActionButton()
                tutorial.advanceExternally(); return
            }
            if tutorial.handleTap(at: point, in: scene) { return }
        }
        // Le level-up est prioritaire : il bloque toute autre interaction
        // tant qu'il est visible.
        if levelUp.handleTap(at: point, in: scene) { return }
        // Mort : A valide le choix au curseur ; sinon tap direct comme avant.
        if death.isActive {
            if !actionButton.isHidden, point.distance(to: actionButton.position) < 42 {
                popActionButton()
                death.confirmSelection(); return
            }
            if death.handleTap(at: point, in: scene) { return }
        }
        if options.handleTap(at: point, in: scene) { return }
        if lore.handleTap(at: point, in: scene) { return }
        if questLog.handleTap(at: point, in: scene) { return }
        // Prologue : n'importe quel tap le passe.
        if prologueNode != nil { endPrologue(); return }
        // Le mur d'achat capture tout tant qu'il est ouvert (fermeture par
        // « Plus tard », par le bouton B, ou après un achat réussi).
        if paywall.isActive, paywall.handleTap(at: point, in: scene) { return }
        if skills.handleTap(at: point, in: scene) { return }
        if pause.handleTap(at: point, in: scene) { return }
        if TransitionManager.handleEndScreenTap(at: point, in: scene) { return }
        if TransitionManager.handleCreditsTap(at: point, in: scene) { return }
        // Boutons A/B : prioritaires sur les panneaux (ils vivent au-dessus)
        if !bButton.isHidden, point.distance(to: bButton.position) < 38 {
            handleBPress()
            return
        }
        // Carte du monde : capture tous les taps tant qu'elle est ouverte
        // (fermeture par son bouton, un lieu voyageable, ou B ci-dessus).
        if worldMap.isActive, worldMap.handleTap(at: point, in: scene) { return }
        if !actionButton.isHidden, point.distance(to: actionButton.position) < 42 {
            actionButton.run(.sequence([
                .scale(to: 0.90, duration: 0.06),
                .scale(to: 1.0, duration: 0.10)
            ]))
            // En combat, A pare le coup ennemi en cours s'il y en a un :
            // c'est la seule action possible pendant le tour adverse, et
            // elle prime sur tout le reste.
            if state == .combat, combat.attemptBlock() {
                return
            }
            // Frappe au timing : pendant l'élan d'une action offensive, A
            // décuple le coup au lieu de piloter le menu.
            if state == .combat, combat.attemptStrike() {
                return
            }
            // Pêche : A ferre le poisson (prioritaire sur tout le reste).
            if attemptHook() { return }
            if paywall.isActive {
                paywall.confirmSelection()
            } else if skills.isActive {
                skills.confirmSelection()
            } else if pause.isActive {
                pause.confirmSelection()
            } else if shop.isActive {
                shop.confirmSelection()
                syncGold()
            } else if state == .combat {
                combat.menuConfirm()
            } else if dialogue.isActive {
                dialogue.advance()
            } else if state == .inventory {
                inventory.useSelectedPotion()
            } else if state == .exploration {
                triggerNearbyAction(in: scene)
            }
            return
        }
        if state == .inventory, inventory.handleTap(at: point, in: scene) { return }
        if state == .shop,      shop.handleTap(at: point, in: scene) { syncGold(); return }
        if state == .dialogue,   dialogue.handleTap(at: point, in: scene) { return }
        if state == .combat,     combat.handleTap(at: point, in: scene) { return }
        guard state == .exploration else { return }
        if hud.handleTap(at: point, in: scene) { return }
        // Contrôles classiques : déplacement = joystick uniquement.
        // Mais toucher directement le PNJ/POI À PORTÉE interagit quand
        // même (équivalent du bouton A) — sinon le tap semble « cassé ».
        if let target = nearbyActionPoint {
            let wp = world.worldNode.convert(point, from: scene)
            if wp.distance(to: target) < 48 {
                triggerNearbyAction(in: scene)
                return
            }
        }
    }
}
