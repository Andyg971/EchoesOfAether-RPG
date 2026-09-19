import SpriteKit

// Entrées : bouton A, navigation curseur, joystick virtuel.
// Extrait de GameManager.swift (découpage du monolithe).
@MainActor
extension GameManager {
    // MARK: - Bouton d'action « A »

    /// Relief pixel dur sur un bouton carré : biseau clair en haut/gauche,
    /// ombre sombre en bas/droite (look touche de manette rétro, pas badge
    /// web). Bandes de 3px, `.nearest` implicite (SKSpriteNode couleur).
    func addPixelBevel(to node: SKShapeNode, size: CGFloat,
                               light: SKColor, dark: SKColor) {
        let h = size / 2
        let t: CGFloat = 3
        let bands: [(CGPoint, CGSize, SKColor)] = [
            (CGPoint(x: 0, y: h - t / 2), CGSize(width: size, height: t), light),   // haut
            (CGPoint(x: -h + t / 2, y: 0), CGSize(width: t, height: size), light),  // gauche
            (CGPoint(x: 0, y: -h + t / 2), CGSize(width: size, height: t), dark),    // bas
            (CGPoint(x: h - t / 2, y: 0), CGSize(width: t, height: size), dark)      // droite
        ]
        for (pos, sz, color) in bands {
            let band = SKSpriteNode(color: color, size: sz)
            band.position = pos
            band.zPosition = 0.5
            node.addChild(band)
        }
    }

    /// Bouton pixel fixe en bas à droite. Actif (doré, pulsé) quand une
    /// interaction est à portée ; estompé sinon.
    func setupActionButton(in scene: SKScene) {
        PixelUI.stylePanel(actionButton, size: CGSize(width: 54, height: 54),
                           fill: SKColor(red: 0.16, green: 0.13, blue: 0.10, alpha: 0.95),
                           accent: PixelUI.gold)
        addPixelBevel(to: actionButton, size: 54,
                      light: SKColor(red: 0.62, green: 0.50, blue: 0.24, alpha: 0.9),
                      dark: SKColor(red: 0.05, green: 0.04, blue: 0.02, alpha: 0.95))
        actionButton.zPosition = 1_950   // au-dessus des panneaux (dialogue 1000+)
        actionButton.isHidden = true
        scene.addChild(actionButton)

        actionButtonLabel.text = "A"
        actionButtonLabel.fontSize = 30
        actionButtonLabel.fontColor = SKColor(red: 1.0, green: 0.92, blue: 0.62, alpha: 1)
        actionButtonLabel.verticalAlignmentMode = .center
        actionButtonLabel.horizontalAlignmentMode = .center
        actionButtonLabel.position = CGPoint(x: 0, y: -1)
        actionButtonLabel.zPosition = 951
        actionButton.addChild(actionButtonLabel)

        // Bouton B : en dessous-gauche de A, accent cuivré (annuler/passer)
        let bAccent = SKColor(red: 0.80, green: 0.42, blue: 0.30, alpha: 1)
        PixelUI.stylePanel(bButton, size: CGSize(width: 46, height: 46),
                           fill: SKColor(red: 0.18, green: 0.10, blue: 0.08, alpha: 0.95),
                           accent: bAccent)
        addPixelBevel(to: bButton, size: 46,
                      light: SKColor(red: 0.62, green: 0.34, blue: 0.24, alpha: 0.9),
                      dark: SKColor(red: 0.06, green: 0.02, blue: 0.02, alpha: 0.95))
        bButton.zPosition = 1_950
        bButton.isHidden = true
        scene.addChild(bButton)

        bButtonLabel.text = "B"
        bButtonLabel.fontSize = 27
        bButtonLabel.fontColor = bAccent
        bButtonLabel.verticalAlignmentMode = .center
        bButtonLabel.horizontalAlignmentMode = .center
        bButtonLabel.position = CGPoint(x: 0, y: -1)
        bButtonLabel.zPosition = 951
        bButton.addChild(bButtonLabel)

        // Position initiale sans marges : `layout()` est appelé dans la foulée
        // par `GameScene.didMove` avec les vraies safe areas.
        layoutActionButtons(in: scene.size, safeBottom: 0, safeRight: 0)
    }

    /// Place A et B dans le coin bas-droit, en dehors des marges système.
    ///
    /// Ces deux boutons étaient positionnés une seule fois, au `setup()`, en
    /// dur (`width - 58`) : ils ignoraient l'encoche — en paysage l'encoche
    /// passe à droite une rotation sur deux et venait mordre le bouton A — et
    /// ne suivaient aucun redimensionnement de scène.
    func layoutActionButtons(in size: CGSize,
                                     safeBottom: CGFloat,
                                     safeRight: CGFloat) {
        let x = size.width - safeRight - 58
        actionButton.position = CGPoint(x: x, y: safeBottom + 66)
        bButton.position = CGPoint(x: x, y: safeBottom + 128)
    }

    /// Un overlay fermable par B est-il ouvert ?
    var dismissableOverlayActive: Bool {
        inventory.isActive || shop.isActive || lore.isActive
            || questLog.isActive || pause.isActive || options.isActive
            || worldMap.isActive
    }

    /// Bouton B : annule / passe / ferme selon le contexte.
    /// Petit enfoncement du bouton A (retour tactile de touche de manette).
    func popActionButton() {
        actionButton.run(.sequence([
            .scale(to: 0.90, duration: 0.06),
            .scale(to: 1.0, duration: 0.10)
        ]))
    }

    func handleBPress() {
        HapticsEngine.light()
        bButton.run(.sequence([
            .scale(to: 0.90, duration: 0.06),
            .scale(to: 1.0, duration: 0.10)
        ]))
        // Ordre : options au-dessus de pause ; dialogue en dernier.
        // En combat, B annule d'abord un ciblage de soin en cours — sans
        // quoi choisir SOIN par erreur enfermerait le joueur.
        if state == .combat, combat.cancelTargeting() { return }
        if tutorial.isActive { tutorial.skipExternally(); return }
        if paywall.isActive { paywall.dismiss(); return }
        if options.isActive { options.dismiss(); return }
        if skills.isActive { skills.dismiss(); return }
        if pause.isActive { pause.dismiss(); return }
        if worldMap.isActive { worldMap.dismiss(); return }
        if shop.isActive { shop.dismiss(); syncGold(); return }
        if lore.isActive { lore.dismiss(); return }
        if questLog.isActive { questLog.dismiss(); return }
        if inventory.isActive { inventory.dismiss(); return }
        if dialogue.isActive { dialogue.skipToEnd(); return }
    }

    /// Rafraîchit l'état visuel du bouton A selon le POI à portée.
    func updateActionButtonState() {
        let enabled = nearbyActionPoint != nil
        let targetAlpha: CGFloat = enabled ? 1.0 : 0.35
        if abs(actionButton.alpha - targetAlpha) > 0.01 {
            actionButton.run(.fadeAlpha(to: targetAlpha, duration: 0.15))
            if enabled {
                actionButton.run(.sequence([
                    .scale(to: 1.12, duration: 0.10),
                    .scale(to: 1.0, duration: 0.12)
                ]))
            }
        }
    }

    /// Déclenche l'interaction du POI courant (comme un tap parfait dessus).
    func triggerNearbyAction(in scene: SKScene) {
        guard let target = nearbyActionPoint else {
            HapticsEngine.light()
            return
        }
        HapticsEngine.medium()
        actionButton.run(.sequence([
            .scale(to: 0.90, duration: 0.06),
            .scale(to: 1.0, duration: 0.10)
        ]))
        // Bord du lac : A lance une prise.
        if inOverworld, fishingSpotInRange {
            startFishing()
            return
        }
        // Carte du monde : A ouvre le coffre à portée, sinon entre dans le lieu.
        if inOverworld, let chestID = overworldChestTarget {
            openOverworldChest(chestID)
            return
        }
        if inOverworld, let dest = overworldTarget {
            enterZoneFromMap(dest)
            return
        }
        let screenPoint = scene.convert(target, from: world.worldNode)
        handleExplorationTap(screenPoint, in: scene)
    }

    // MARK: - Navigation curseur (joystick → menus)

    /// Convertit le joystick en pas discrets (haut/bas/gauche/droite)
    /// et les route vers le menu actif. Un « flick » = un pas.
    func updateMenuNavigation() {
        let v = padVector
        let magnitude = max(abs(v.dx), abs(v.dy))
        if menuNavLatched {
            if magnitude < 0.30 { menuNavLatched = false }
            return
        }
        guard magnitude > 0.60 else { return }
        menuNavLatched = true
        let dx = abs(v.dx) > abs(v.dy) ? (v.dx > 0 ? 1 : -1) : 0
        let dy = dx == 0 ? (v.dy > 0 ? 1 : -1) : 0
        routeMenuNav(dx: dx, dy: dy)
    }

    func routeMenuNav(dx: Int, dy: Int) {
        if death.isActive { death.moveSelection(dy); return }
        if paywall.isActive { paywall.moveSelection(dy); return }
        if options.isActive { return }              // sliders : tactile assumé
        // Arbre : dx change de voie, dy monte/descend dans la voie.
        if skills.isActive { skills.moveSelection(dx: dx, dy: dy); return }
        if pause.isActive { pause.moveSelection(dy); return }
        if shop.isActive { shop.moveSelection(dy); return }
        if lore.isActive {
            if dx != 0 { lore.navigateTabs(dx) } else { lore.scroll(dy) }
            return
        }
        if questLog.isActive { questLog.scroll(dy); return }
        if state == .combat { combat.menuNav(dx: dx, dy: dy); return }
        if dialogue.isActive { dialogue.moveChoiceSelection(dy); return }
    }

    // MARK: - Joystick virtuel (flottant, quart bas-gauche)

    /// Quart bas-gauche où poser le pouce fait apparaître le joystick.
    ///
    /// Exposé (et non codé en dur dans `padTouchBegan`) pour que les tests
    /// puissent vérifier qu'aucun bouton du HUD ne tombe dedans.
    static func padCaptureZone(in size: CGSize) -> CGRect {
        CGRect(x: 0, y: 0, width: size.width * 0.42, height: size.height * 0.60)
    }

    /// Le joueur pose le doigt en bas à gauche : le pad apparaît là.
    /// Retourne true si le touch est capturé par le pad.
    func padTouchBegan(at point: CGPoint, in scene: SKScene) -> Bool {
        // Exploration : déplacement. Menus (combat, dialogue, boutique,
        // pause…) : le même joystick navigue le curseur de sélection.
        //
        // Les icônes du HUD (journal de quêtes en tête) descendent dans le
        // quart du joystick : en exploration elles gardent la priorité, sinon
        // poser le doigt dessus sortait le joystick au lieu d'ouvrir le
        // panneau. Hors exploration le HUD ne répond plus aux taps (cf.
        // `handleTap`) : la zone revient entièrement au curseur.
        let hudPrioritaire = state == .exploration
            && hud.containsButton(at: point, in: scene)
        guard state != .transition, !worldMap.isActive,
              Self.padCaptureZone(in: scene.size).contains(point),
              !hudPrioritaire else { return false }
        if padBase.parent == nil {
            padBase.fillColor = SKColor(white: 0.9, alpha: 0.10)
            padBase.strokeColor = PixelUI.gold.withAlphaComponent(0.55)
            padBase.lineWidth = 2
            padBase.zPosition = 950
            scene.addChild(padBase)
            padKnob.fillColor = PixelUI.gold.withAlphaComponent(0.55)
            padKnob.strokeColor = PixelUI.gold
            padKnob.lineWidth = 1.5
            padKnob.zPosition = 951
            scene.addChild(padKnob)
        }
        padActive = true
        padOrigin = point
        padVector = .zero
        padBase.position = point
        padKnob.position = point
        padBase.alpha = 1
        padKnob.alpha = 1
        return true
    }

    func padTouchMoved(to point: CGPoint) {
        guard padActive else { return }
        var dx = point.x - padOrigin.x
        var dy = point.y - padOrigin.y
        let len = (dx * dx + dy * dy).squareRoot()
        let maxR: CGFloat = 34
        if len > maxR {
            dx = dx / len * maxR
            dy = dy / len * maxR
        }
        padKnob.position = CGPoint(x: padOrigin.x + dx, y: padOrigin.y + dy)
        let strength = min(1, len / maxR)
        padVector = len > 6
            ? CGVector(dx: dx / maxR * strength, dy: dy / maxR * strength)
            : .zero
    }

    func padTouchEnded() {
        guard padActive else { return }
        padActive = false
        padVector = .zero
        padBase.run(.fadeOut(withDuration: 0.15))
        padKnob.run(.fadeOut(withDuration: 0.15))
        movement.setManualWalk(world.kael, dx: 0, active: false)
    }

    func updatePadMovement(deltaTime: TimeInterval) {
        guard padActive, state == .exploration, deltaTime > 0,
              padVector != .zero, let scene else { return }
        let speed: CGFloat = 215
        let wh = world.worldHeight > 0 ? world.worldHeight : scene.size.height
        // Carte du monde : le déplacement s'étend aussi en X (scroll 2D).
        let ww = world.worldWidth > 0 ? world.worldWidth : scene.size.width
        let current = world.kael.position
        var pos = current
        pos.x += padVector.dx * speed * CGFloat(deltaTime)
        pos.y += padVector.dy * speed * CGFloat(deltaTime)
        pos.x = min(max(pos.x, 34), ww - 34)
        pos.y = min(max(pos.y, 86), wh - 44)

        // Collisions : on ne traverse ni maisons ni arbres. Glissement le
        // long des murs (axe par axe) pour un contrôle agréable.
        // Si Kael est déjà dans une empreinte (spawn/scénario), on le
        // laisse sortir librement.
        if world.isBlocked(pos), !world.isBlocked(current) {
            let xOnly = CGPoint(x: pos.x, y: current.y)
            let yOnly = CGPoint(x: current.x, y: pos.y)
            if !world.isBlocked(xOnly) {
                pos = xOnly
            } else if !world.isBlocked(yOnly) {
                pos = yOnly
            } else {
                movement.setManualWalk(world.kael, dx: padVector.dx, active: true)
                return
            }
        }
        world.kael.position = pos
        world.refreshKaelDepth()
        movement.setManualWalk(world.kael, dx: padVector.dx, active: true)
    }

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
