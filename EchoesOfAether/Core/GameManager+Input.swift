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


}
