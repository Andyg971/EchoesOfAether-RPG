import SpriteKit

// Mise en place : boutons du menu, HUD de combat, curseur, layout.
// Extrait de CombatSystem.swift (découpage du monolithe).
@MainActor
extension CombatSystem {
    // MARK: - Setup

    func setupStatus(scene: SKScene) {
        // Ligne de log, sous la rangée de plates.
        //
        // Elle était à 0.645h, ce qui la faisait passer pile sur le label de
        // Magie de la plate la plus à droite : tant que Kael occupait le
        // premier créneau (à gauche), le centre restait libre par chance.
        // Depuis que les plates suivent l'ordre du terrain, Kael est au
        // créneau central — et la chance a tourné. On descend sous la rangée.
        statusLabel.fontSize = 16
        statusLabel.fontColor = .white
        statusLabel.position = CGPoint(x: scene.size.width / 2, y: scene.size.height * 0.61)
        root.addChild(statusLabel)
    }


    /// UI tour par tour : bannière de tour (haut centre) + file
    /// d'initiative (pips des 4 prochains acteurs).
    func setupTurnUI(scene: SKScene) {
        PixelUI.stylePanel(turnBanner, size: CGSize(width: 240, height: 30),
                           fill: SKColor(red: 0.05, green: 0.04, blue: 0.10, alpha: 0.92),
                           accent: SKColor(red: 0.55, green: 0.80, blue: 1.00, alpha: 0.9))
        turnBanner.position = CGPoint(x: scene.size.width / 2, y: scene.size.height - 26)
        turnBanner.zPosition = 940
        turnBanner.alpha = 0
        root.addChild(turnBanner)

        turnBannerLabel.fontSize = 17
        turnBannerLabel.fontColor = .white
        turnBannerLabel.verticalAlignmentMode = .center
        turnBannerLabel.position = turnBanner.position
        turnBannerLabel.zPosition = 941
        turnBannerLabel.alpha = 0
        root.addChild(turnBannerLabel)

        // Trio : la file d'initiative monte au-dessus des noms pour ne
        // pas traverser les plates HP (4 plates = centre occupé).
        turnPipsRoot.position = CGPoint(x: scene.size.width / 2,
                                        y: scene.size.height * (allies.count == 2 ? 0.87 : 0.745))
        turnPipsRoot.zPosition = 935
        root.addChild(turnPipsRoot)
    }

    /// Anime la bannière au changement de tour.
    func showTurnBanner(_ text: String, color: SKColor) {
        turnBannerLabel.text = text
        AccessibilitySettings.announce(text)
        PixelUI.stylePanel(turnBanner, size: CGSize(width: 240, height: 30),
                           fill: SKColor(red: 0.05, green: 0.04, blue: 0.10, alpha: 0.92),
                           accent: color.withAlphaComponent(0.9))
        let pop: SKAction = .sequence([
            .group([.fadeIn(withDuration: 0.12), .scale(to: 1.06, duration: 0.12)]),
            .scale(to: 1.0, duration: 0.10)
        ])
        turnBanner.setScale(0.92)
        turnBannerLabel.setScale(0.92)
        turnBanner.run(pop)
        turnBannerLabel.run(pop)
    }

    /// Redessine la file d'initiative : manche = [Kael, E1, E2…] répétée.
    /// Acteur courant en grand + glow ; ennemis break/gelés marqués ✕.
    /// `currentEnemyIndex` : nil = tour joueur, sinon index de l'ennemi
    /// en train d'agir.
    /// File d'initiative (pips K L B K) retirée à la demande : elle
    /// alourdissait l'écran de combat. La bannière de tour + le curseur
    /// d'acteur suffisent à savoir qui joue.
    func refreshTurnOrder(currentEnemyIndex: Int?) {
        turnPipsRoot.removeAllChildren()
    }

    /// Petit pulse du panneau d'actions quand la main revient au joueur.
    func pulseActionPanel() {
        for (i, button) in [attackButton, fireButton, iceButton,
                            blackSlashButton, lightningButton, healButton,
                            blessingButton, windButton, emberButton,
                            tempestButton].enumerated() {
            button.run(.sequence([
                .wait(forDuration: Double(i) * 0.03),
                .scale(to: 1.07, duration: 0.10),
                .scale(to: 1.0, duration: 0.12)
            ]))
        }
        HapticsEngine.light()
    }

    func setupButtons(scene: SKScene) {
    // Panneau compact façon menu SNES : une rangée de techniques par
    // acteur. Kael : ATTAQUE + FEU + AETHER. Lyra : ATTAQUE + GLACE +
    // FOUDRE + SOIN. `layoutActionMenu` répartit à chaque tour.
    let panelWidth = min(scene.size.width - 18, 288)
    actionPanelWidth = panelWidth
    let panelHeight: CGFloat = 54
    let panelY: CGFloat = 62

    PixelUI.stylePanel(actionPanel, size: CGSize(width: panelWidth, height: panelHeight),
                       fill: SKColor(red: 0.045, green: 0.038, blue: 0.045, alpha: 0.96),
                       accent: PixelUI.goldDim)
    actionPanel.position = CGPoint(x: scene.size.width / 2, y: panelY)
    actionPanel.zPosition = 850
    root.addChild(actionPanel)

    // Étiquette de l'acteur courant, posée sur le bord haut du panneau.
    actorTagLabel.fontSize = 12
    actorTagLabel.horizontalAlignmentMode = .left
    actorTagLabel.verticalAlignmentMode = .center
    actorTagLabel.position = CGPoint(x: scene.size.width / 2 - panelWidth / 2 + 8,
                                     y: panelY + panelHeight / 2)
    actorTagLabel.zPosition = 856
    actorTagLabel.isHidden = true
    root.addChild(actorTagLabel)

    // Création des 6 boutons (positions posées par layoutActionMenu)
    let buttonH: CGFloat = 32
    addButton(attackButton, title: String(localized: "combat.button.attack"), at: .zero, width: 80, height: buttonH,
              fill: SKColor(red: 0.13, green: 0.13, blue: 0.16, alpha: 1), stroke: SKColor(white: 0.62, alpha: 1), fontSize: 12,
              chip: CombatElement.physical.color)
    addButton(fireButton, title: String(localized: "combat.button.fire"), at: .zero, width: 80, height: buttonH,
              fill: SKColor(red: 0.26, green: 0.07, blue: 0.03, alpha: 1), stroke: SKColor(red: 0.85, green: 0.38, blue: 0.18, alpha: 1), fontSize: 12,
              chip: CombatElement.fire.color)
    addButton(iceButton, title: String(localized: "combat.button.ice"), at: .zero, width: 80, height: buttonH,
              fill: SKColor(red: 0.03, green: 0.14, blue: 0.23, alpha: 1), stroke: SKColor(red: 0.42, green: 0.72, blue: 0.90, alpha: 1), fontSize: 12,
              chip: CombatElement.ice.color)
    addButton(blackSlashButton, title: String(localized: "combat.button.aether"), at: .zero, width: 80, height: buttonH,
              fill: SKColor(red: 0.17, green: 0.06, blue: 0.26, alpha: 1), stroke: SKColor(red: 0.62, green: 0.40, blue: 0.85, alpha: 1), fontSize: 12,
              chip: CombatElement.aether.color)
    addButton(lightningButton, title: String(localized: "combat.button.lightning"), at: .zero, width: 80, height: buttonH,
              fill: SKColor(red: 0.24, green: 0.18, blue: 0.03, alpha: 1), stroke: SKColor(red: 0.85, green: 0.70, blue: 0.25, alpha: 1), fontSize: 12,
              chip: CombatElement.lightning.color)
    addButton(healButton, title: String(localized: "combat.button.heal"), at: .zero, width: 80, height: buttonH,
              fill: SKColor(red: 0.03, green: 0.20, blue: 0.09, alpha: 1), stroke: SKColor(red: 0.38, green: 0.80, blue: 0.48, alpha: 1), fontSize: 12,
              chip: Palette.vitalityDim)
    // Bénédiction : or et vert sacré, les couleurs de ses propres FX.
    addButton(blessingButton, title: String(localized: "combat.button.blessing"), at: .zero, width: 80, height: buttonH,
              fill: SKColor(red: 0.16, green: 0.16, blue: 0.05, alpha: 1), stroke: SKColor(red: 0.85, green: 0.78, blue: 0.35, alpha: 1), fontSize: 12,
              chip: SKColor(red: 0.60, green: 0.98, blue: 0.70, alpha: 1))
    // Tempête : cyan et violet mêlés — la glace et la foudre fondues.
    addButton(tempestButton, title: String(localized: "combat.button.tempest"), at: .zero, width: 80, height: buttonH,
              fill: SKColor(red: 0.08, green: 0.14, blue: 0.26, alpha: 1), stroke: SKColor(red: 0.45, green: 0.75, blue: 0.95, alpha: 1), fontSize: 12,
              chip: SKColor(red: 0.60, green: 0.85, blue: 1.00, alpha: 1))
    // Techniques d'Eran : acier pour la bourrasque, braise pour la lame ardente.
    addButton(windButton, title: String(localized: "combat.button.windBlade"), at: .zero, width: 80, height: buttonH,
              fill: SKColor(red: 0.14, green: 0.16, blue: 0.14, alpha: 1), stroke: SKColor(red: 0.72, green: 0.80, blue: 0.68, alpha: 1), fontSize: 12,
              chip: SKColor(red: 0.85, green: 0.92, blue: 0.80, alpha: 1))
    addButton(emberButton, title: String(localized: "combat.button.emberStrike"), at: .zero, width: 80, height: buttonH,
              fill: SKColor(red: 0.24, green: 0.09, blue: 0.03, alpha: 1), stroke: SKColor(red: 0.90, green: 0.45, blue: 0.20, alpha: 1), fontSize: 12,
              chip: CombatElement.fire.color)

    // BOOST et POTION en CHROME NEUTRE, pas en couleur d'élément. Dans ce
    // combat la couleur dit une seule chose — feu, glace, foudre, aether —
    // et c'est ce qui permet d'apparier une commande à une faiblesse d'un
    // coup d'œil. Un cadre violet et un cadre vert qui ne désignent aucun
    // élément diluent ce code : l'œil cherche un sens qui n'existe pas.
    // Leur état actif/inactif passe déjà par l'alpha, et le curseur doré
    // marque la sélection.
    let neutralFill = SKColor(red: 0.09, green: 0.08, blue: 0.12, alpha: 1)
    let neutralStroke = SKColor(white: 0.46, alpha: 0.9)
    addButton(boostButton, title: String(localized: "combat.button.boost"), at: CGPoint(x: scene.size.width / 2 - 46, y: panelY + 56), width: 84, height: 22,
              fill: neutralFill, stroke: neutralStroke, fontSize: 12)
    addButton(potionButton, title: String(localized: "combat.button.potion"), at: CGPoint(x: scene.size.width / 2 + 46, y: panelY + 56), width: 84, height: 22,
              fill: neutralFill, stroke: neutralStroke, fontSize: 12)

    layoutActionMenu()

    // Curseur : cadre doré posé sur le bouton sélectionné
    PixelUI.stylePanel(selectionCursor, size: CGSize(width: 84, height: 36),
                       fill: .clear, accent: PixelUI.gold)
    selectionCursor.zPosition = 866
    root.addChild(selectionCursor)
    updateSelectionCursor()
    }

}
