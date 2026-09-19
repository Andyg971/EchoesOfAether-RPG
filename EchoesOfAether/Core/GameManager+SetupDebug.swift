import SpriteKit

// Mise en place — seconde moitié : arguments de debug (--zone-*, --overlay-test, --combat-*), niveau/HUD.
// Extrait de GameManager.swift (découpage du monolithe).
@MainActor
extension GameManager {
    func layout(size: CGSize, safeTop: CGFloat, safeBottom: CGFloat = 0, safeLeft: CGFloat = 0, safeRight: CGFloat = 0) {
        lastLayout = (size, safeTop, safeBottom, safeLeft, safeRight)
        if activeInterior == nil {
            world.layout(in: size)
        }
        hud.layout(in: size, safeTop: safeTop, safeLeft: safeLeft, safeRight: safeRight)
        layoutActionButtons(in: size, safeBottom: safeBottom, safeRight: safeRight)
        dialogue.layout(in: size, safeBottom: safeBottom)
        shop.layout(in: size, safeBottom: safeBottom)
        inventory.layout(in: size, safeBottom: safeBottom)
        lore.layout(in: size)
        questLog.layout(in: size)
        minimap.layout(in: size, safeBottom: safeBottom, safeLeft: safeLeft)
        levelUp.layout(in: size)
        worldMap.layout(in: size)
        paywall.layout(in: size, safeBottom: safeBottom)
    }

    /// Pousse l'état niveau/XP du joueur vers le HUD. À appeler après
    /// chargement, level-up, ou tout changement de stats.
    func syncLevelHUD() {
        let isMax = player.level >= PlayerState.maxLevel
        hud.setLevel(player.level,
                     xp: player.xp,
                     xpToNext: isMax ? 0 : player.xpToNextLevel,
                     progress: player.xpProgress,
                     isMax: isMax)
    }

    /// Sync HUD + affiche overlay si level a augmenté. Non bloquant :
    /// l'overlay s'affiche par-dessus le dialogue post-combat ; le joueur
    /// tape pour fermer et continuer.
    func grantLevelUpDisplay(from levelBefore: Int) {
        syncLevelHUD()
        guard player.level > levelBefore else { return }
        levelUp.show(newLevel: player.level,
                     isMax: player.level >= PlayerState.maxLevel) {}
    }

    func update(deltaTime: TimeInterval) {
        combat.update(deltaTime: deltaTime)

        hud.hpValue = "\u{2665} \(player.currentHP)/\(player.currentMaxHP)"

        hintUpdateTimer += deltaTime
        if hintUpdateTimer >= 0.15, state == .exploration {
            hintUpdateTimer = 0
            updateInteractionHint()
        }

        // Bouton A : exploration (interagir), dialogue (avancer/valider),
        // combat (activer la sélection), boutique et pause (valider).
        // Bouton B : dialogue (passer) + overlays fermables.
        // A visible aussi sur les modaux navigables au curseur (mort,
        // tutoriel) pour valider le choix sélectionné au bouton.
        let showActionButton = actionButton.parent != nil
            && !worldMap.isActive
            && (state == .exploration || state == .dialogue
                || state == .combat || state == .shop
                || (state == .inventory && inventory.canUsePotion)
                || pause.isActive || death.isActive || tutorial.isActive)
        if actionButton.isHidden == showActionButton {
            actionButton.isHidden = !showActionButton
        }
        if state != .exploration || death.isActive || tutorial.isActive,
           actionButton.alpha < 0.99 {
            actionButton.alpha = 1
        }
        let showBButton = bButton.parent != nil
            && (dialogue.isActive || dismissableOverlayActive || tutorial.isActive)
        if bButton.isHidden == showBButton {
            bButton.isHidden = !showBButton
        }

        minimapTimer += deltaTime
        if minimapTimer >= 0.10, state == .exploration {
            minimapTimer = 0
            updateMinimap()
        }

        // Bouton carte du monde : visible seulement là où le voyage
        // a un sens (désert accessible, ou retour depuis le désert).
        let showMap = worldMapAvailable && state == .exploration
        if hud.mapButton.isHidden == showMap {
            hud.mapButton.isHidden = !showMap
        }

        // Déplacement continu au joystick virtuel (exploration)
        // La mort et le tutoriel passent par-dessus l'exploration : le
        // joystick y navigue le curseur au lieu de déplacer Kael.
        if state == .exploration && !death.isActive && !tutorial.isActive && !isFishing {
            updatePadMovement(deltaTime: deltaTime)
            updateRoamers(deltaTime: deltaTime)
        } else {
            updateMenuNavigation()
        }

        // Lyra accompagne Kael dans les zones du pacte (tant qu'elle vit) ;
        // au Seuil, c'est son Écho spectral qui suit (une fois rejoint).
        if state == .exploration || state == .dialogue {
            if lyraInParty {
                if world.lyra.isHidden { world.showLyraCompanion() }
                world.updateLyraFollow(deltaTime: deltaTime)
            } else if phase == .act3 || phase == .act4 {
                if player.act3EchoJoined {
                    world.updateLyraFollow(deltaTime: deltaTime)
                }
                // Eran ferme la marche du trio, derrière l'Écho de Lyra —
                // ou marche seul si elle n'a pas encore rejoint : son
                // recrutement (act3EranMet) n'exige pas l'Écho. Il restait
                // sinon planté sur son palier au Seuil, invisible, alors
                // qu'il combattait déjà dans act3Party.
                if player.act3EranMet {
                    if world.eran.isHidden { world.showEranCompanion() }
                    world.updateEranFollow(deltaTime: deltaTime)
                }
            }
        }

        if state == .exploration, let s = scene {
            world.updateCamera(in: s.size)
        }
    }
}
