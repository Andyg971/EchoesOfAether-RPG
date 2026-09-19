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

    func setupHPBars(scene: SKScene) {
        // Les plates se rangent dans l'ordre des sprites sur le terrain.
        //
        // Elles étaient posées à des fractions écrites en dur (Kael 0.13,
        // alliés 0.335 et 0.54) pendant que la formation place Kael DEVANT,
        // à droite de son groupe (0.34) et les alliés en retrait (0.22, 0.19).
        // L'ordre des plates était donc l'exact inverse de celui des corps :
        // la plate de Kael à gauche, son sprite à droite. Rien ne reliait plus
        // une barre à son porteur.
        //
        // On lit maintenant les positions réelles, posées par
        // `setupCombatants` juste avant. Déplacer un combattant réordonne ses
        // plates toutes seules — les deux ne peuvent plus se contredire.
        let slotFracs: [CGFloat]
        switch allies.count {
        case 0:  slotFracs = [0.28]
        case 1:  slotFracs = [0.18, 0.42]
        default: slotFracs = [0.13, 0.335, 0.54]
        }
        // Chaque combattant avec le x de son sprite ; nil = Kael.
        let members: [(home: CGFloat, ally: AllyState?)] =
            ([(kaelHomePosition.x, nil)] as [(CGFloat, AllyState?)])
            + allies.map { ($0.home.x, $0) }
        let ordered = members.sorted { $0.home < $1.home }
        let slotX: [ObjectIdentifier: CGFloat] = Dictionary(
            uniqueKeysWithValues: ordered.enumerated().compactMap { i, m in
                m.ally.map { (ObjectIdentifier($0), scene.size.width * slotFracs[i]) }
            })
        let kaelX = ordered.firstIndex { $0.ally == nil }
            .map { scene.size.width * slotFracs[$0] } ?? scene.size.width * slotFracs[0]

        let enemyX = scene.size.width * (allies.count == 2 ? 0.80 : 0.72)
        let barY = scene.size.height * 0.78

        configureBar(kaelHPBack, kaelHPFill, width: barWidth, height: barHeight,
                     color: SKColor(red: 0.40, green: 0.78, blue: 0.56, alpha: 1),
                     at: CGPoint(x: kaelX, y: barY), ghost: kaelHPGhost)
        // Plate de droite = CIBLE courante (nom + HP mis à jour au retarget)
        configureBar(enemyHPBack, enemyHPFill, width: barWidth, height: barHeight,
                     color: SKColor(red: 0.82, green: 0.22, blue: 0.24, alpha: 1),
                     at: CGPoint(x: enemyX, y: barY), ghost: enemyHPGhost)

        kaelHPLabel.fontSize = 15
        kaelHPLabel.fontColor = .white
        kaelHPLabel.position = CGPoint(x: kaelX, y: barY - 18)
        root.addChild(kaelHPLabel)

        // Mini-barre de Magie sous la vie de Kael (bleu clair). Le label est
        // remonté de 6 pt (et rétréci) pour dégager la bande où passe la ligne
        // de log — la rangée de plates descendait jusqu'à 262 sur 402.
        configureBar(kaelMPBack, kaelMPFill, width: barWidth * 0.82, height: 7,
                     color: SKColor(red: 0.42, green: 0.62, blue: 1.0, alpha: 1),
                     at: CGPoint(x: kaelX, y: barY - 32))
        kaelMPLabel.fontSize = 10
        kaelMPLabel.fontColor = SKColor(red: 0.70, green: 0.82, blue: 1.0, alpha: 1)
        kaelMPLabel.position = CGPoint(x: kaelX, y: barY - 44)
        root.addChild(kaelMPLabel)

        enemyHPLabel.fontSize = 15
        enemyHPLabel.fontColor = .white
        enemyHPLabel.position = CGPoint(x: enemyX, y: barY - 18)
        root.addChild(enemyHPLabel)

        addCombatantLabel("Kael", at: CGPoint(x: kaelX, y: barY + 16))

        // Plates des alliés : même gabarit, accent de leur couleur.
        let allyBarWidth = allies.count == 2 ? barWidth * 0.86 : barWidth
        for ally in allies {
            let x = slotX[ObjectIdentifier(ally)] ?? kaelX
            configureBar(ally.hpBack, ally.hpFill,
                         width: allyBarWidth, height: barHeight,
                         color: ally.kind.accentColor,
                         at: CGPoint(x: x, y: barY), ghost: ally.hpGhost)
            ally.hpLabel.fontSize = 15
            ally.hpLabel.fontColor = .white
            ally.hpLabel.position = CGPoint(x: x, y: barY - 18)
            root.addChild(ally.hpLabel)
            // Mini-barre de Magie de l'allié (comme Kael).
            configureBar(ally.mpBack, ally.mpFill, width: allyBarWidth * 0.82, height: 7,
                         color: SKColor(red: 0.42, green: 0.62, blue: 1.0, alpha: 1),
                         at: CGPoint(x: x, y: barY - 32))
            ally.mpLabel.fontSize = 10
            ally.mpLabel.fontColor = SKColor(red: 0.70, green: 0.82, blue: 1.0, alpha: 1)
            ally.mpLabel.position = CGPoint(x: x, y: barY - 44)
            root.addChild(ally.mpLabel)
            addCombatantLabel(ally.combatant.name, at: CGPoint(x: x, y: barY + 16))
        }
        targetNameLabel.fontSize = 19
        targetNameLabel.fontColor = .white
        targetNameLabel.position = CGPoint(x: enemyX, y: barY + 16)
        root.addChild(targetNameLabel)

        // Faiblesses et bouclier de la cible, sous sa plate.
        //
        // C'était une phrase posée au centre de l'arène (« Faiblesses: AETHER
        // FOUDRE   Bouclier: 3/3 ») qui tombait pile sur les barres de Magie
        // des alliés — à 2 pt près. Elle nommait les éléments en toutes
        // lettres alors que le menu d'actions les désigne, lui, par un losange
        // de couleur. Le joueur devait traduire « FOUDRE » en « le losange
        // jaune » pour choisir son sort.
        //
        // Ce sont donc les mêmes losanges, à la même taille, que dans le menu :
        // losange violet sur la cible = losange violet dans le menu.
        //
        // PLACÉE AU-DESSUS DU NOM, pas sous la barre de PV. Sous la barre, la
        // place est libre dans le HUD (la cible n'a pas de barre de Magie),
        // mais pas à l'écran : un ennemi haut comme le Gardien remonte
        // jusque-là, et la rangée se lisait comme des pastilles collées sur
        // son torse. Au-dessus du nom, il n'y a que le ciel de l'arène.
        targetInfoRow.position = CGPoint(x: enemyX, y: barY + 42)
        targetInfoRow.zPosition = 900
        root.addChild(targetInfoRow)

        // Marqueur de cible : chevron doré au-dessus de l'ennemi visé
        let chevron = CGMutablePath()
        chevron.move(to: CGPoint(x: -9, y: 9))
        chevron.addLine(to: CGPoint(x: 0, y: 0))
        chevron.addLine(to: CGPoint(x: 9, y: 9))
        targetMarker.path = chevron
        targetMarker.strokeColor = SKColor(red: 1.00, green: 0.85, blue: 0.30, alpha: 1)
        targetMarker.lineWidth = 4
        targetMarker.lineCap = .butt
        targetMarker.lineJoin = .miter
        targetMarker.glowWidth = 0
        targetMarker.zPosition = 870
        root.addChild(targetMarker)
        targetMarker.run(.repeatForever(.sequence([
            .moveBy(x: 0, y: 6, duration: 0.4),
            .moveBy(x: 0, y: -6, duration: 0.4)
        ])))
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

    /// Boutons de la rangée courante du curseur.
    var currentMenuRowButtons: [SKShapeNode] {
    menuRow == 1 ? [boostButton, potionButton] : currentActorButtons
    }

    /// Replace le cadre doré sur le bouton sélectionné (rangée cible :
    /// le chevron au-dessus de l'ennemi sert déjà de curseur).
    func updateSelectionCursor() {
    if menuRow == 2 {
        selectionCursor.isHidden = true
        return
    }
    let row = currentMenuRowButtons
    guard !row.isEmpty else { selectionCursor.isHidden = true; return }
    menuCol = min(menuCol, row.count - 1)
    let button = row[menuCol]

    // Rangée BOOST/POTION : elle reste horizontale, cadre doré comme avant.
    if menuRow == 1 {
        let size = button.frame.size
        PixelUI.stylePanel(selectionCursor,
                           size: CGSize(width: size.width + 6, height: size.height + 6),
                           fill: .clear, accent: PixelUI.gold)
        selectionCursor.position = button.position
        selectionCursor.isHidden = phase != .playerTurn
        selectionCursor.removeAllActions()
        JuiceEngine.pulse(selectionCursor, scale: 1.04)
        return
    }

    // Liste de commandes : chevron ► posé devant la ligne, la signature du
    // menu Final Fantasy. Un cadre autour d'une ligne de liste ferait double
    // emploi avec la boîte qui l'entoure déjà.
    let chevron = CGMutablePath()
    chevron.move(to: CGPoint(x: -3, y: 5))
    chevron.addLine(to: CGPoint(x: 4, y: 0))
    chevron.addLine(to: CGPoint(x: -3, y: -5))
    chevron.closeSubpath()
    selectionCursor.path = chevron
    selectionCursor.fillColor = PixelUI.gold
    selectionCursor.strokeColor = .clear
    selectionCursor.lineWidth = 0
    selectionCursor.glowWidth = 0
    selectionCursor.childNode(withName: "pixelOuter")?.removeFromParent()
    selectionCursor.position = CGPoint(x: button.position.x - button.frame.width / 2 - 8,
                                       y: button.position.y)
    selectionCursor.isHidden = phase != .playerTurn
    selectionCursor.removeAllActions()
    // Battement horizontal : le curseur FF respire vers sa ligne.
    selectionCursor.run(.repeatForever(.sequence([
        .moveBy(x: 3, y: 0, duration: 0.45),
        .moveBy(x: -3, y: 0, duration: 0.45)
    ])))
    }

    /// Navigation joystick dans le menu de combat.
    /// dy : +1 monte (techniques → BOOST → cible), -1 descend.
    /// Bouton B pendant un ciblage de soin : annule et rend la main.
    /// Sans ça, choisir SOIN par erreur enfermerait le joueur dans la rangée.
    @discardableResult
    func cancelTargeting() -> Bool {
    guard pendingHealSpell != nil else { return false }
    pendingHealSpell = nil
    menuRow = 0
    AudioEngine.shared.playTap()
    updateSelectionCursor()
    updateVisuals()
    return true
    }

    func menuNav(dx: Int, dy: Int) {
    // Pendant l'élan d'une frappe, le menu est verrouillé : le joueur n'a
    // qu'une chose à faire, appuyer sur A au bon moment.
    guard phase == .playerTurn, !strikeWindupActive else { return }
    if dy != 0 {
        // En ciblage de soin, le joystick vertical ne quitte pas la rangée :
        // on choisit une cible ou on annule au bouton B, rien d'autre.
        if pendingHealSpell != nil { return }
        if menuRow == 0 {
            // La liste de commandes est verticale : haut/bas la parcourt.
            // dy>0 = vers le haut de l'écran = vers la ligne précédente.
            let count = currentActorButtons.count
            let next = menuCol - dy
            if next < 0 || next >= count {
                // Sorti par le haut/bas de la liste : on passe à BOOST/POTION.
                menuRow = 1
                menuCol = 0
            } else {
                menuCol = next
            }
        } else {
            let maxRow = aliveEnemies.count > 1 ? 2 : 1
            menuRow = min(max(menuRow + dy, 0), maxRow)
            menuCol = min(menuCol, max(0, currentMenuRowButtons.count - 1))
        }
    } else if dx != 0 {
        if menuRow == 2 {
            cycleTarget(direction: dx)
        } else if menuRow == 1 {
            let count = currentMenuRowButtons.count
            menuCol = (menuCol + dx + count) % count
        } else {
            // Liste verticale : gauche/droite change de cible d'ennemi.
            cycleTarget(direction: dx)
        }
    }
    HapticsEngine.light()
    AudioEngine.shared.playStep()
    updateSelectionCursor()
    updateVisuals()
    announceCombatFocus()
    }

    /// VoiceOver : annonce l'action ou la cible sous le curseur de combat.
    func announceCombatFocus() {
    if menuRow == 2 {
        if pendingHealSpell != nil, healTargets.indices.contains(healTargetIndex) {
            AccessibilitySettings.announce(healTargets[healTargetIndex].name)
        } else if enemies.indices.contains(targetIndex) {
            AccessibilitySettings.announce(enemies[targetIndex].combatant.name)
        }
        return
    }
    let row = currentMenuRowButtons
    guard row.indices.contains(menuCol),
          let lbl = row[menuCol].children.compactMap({ $0 as? SKLabelNode }).first
    else { return }
    AccessibilitySettings.announce(lbl.text ?? "")
    }

    /// Bouton A : active le bouton sélectionné (ou valide la cible).
    func menuConfirm() {
    guard phase == .playerTurn else { return }
    if menuRow == 2 {
        // Cible d'un soin validée : le sort part enfin, sur QUI on a choisi.
        if let spell = pendingHealSpell {
            pendingHealSpell = nil
            menuRow = 0
            // La cible voyage jusqu'au cas .mend de perform() : tout le
            // reste (coût MP, Boost, fin de tour) suit le chemin normal.
            chosenHealIndex = healTargetIndex
            execute(.spell(spell))
            return
        }
        // Cible d'attaque choisie : redescend sur les techniques
        menuRow = 0
        updateSelectionCursor()
        return
    }
    let row = currentMenuRowButtons
    guard row.indices.contains(menuCol) else { return }
    let button = row[menuCol]
    if button === boostButton { applyBoost(); return }
    if button === potionButton {
        if (_player?.potions ?? 0) > 0 { execute(.potion) }
        return
    }
    if button === attackButton { execute(.attack); return }
    if button === blackSlashButton { execute(.blackSlash); return }
    if button === fireButton { execute(.spell(.ember)); return }
    if button === iceButton { execute(.spell(.frost)); return }
    if button === lightningButton { execute(.spell(.thunder)); return }
    if button === healButton {
        // Le soin demande une cible : on passe la main au joueur.
        // Les MP sont vérifiés (et dépensés) par perform() à la validation ;
        // ici on refuse juste d'entrer en ciblage si la réserve est vide.
        let mp = actingAlly?.combatant.mp ?? kael.mp
        guard mp >= CombatSpell.mend.mpCost else {
            showEffect(String(localized: "combat.mp.insufficient"),
                       color: Palette.frost)
            AudioEngine.shared.playTap()
            return
        }
        pendingHealSpell = .mend
        // Curseur posé d'emblée sur le plus blessé : le choix par défaut
        // reste le bon, mais il devient un choix.
        healTargetIndex = healTargets.enumerated().min {
            Double($0.element.hp) / Double($0.element.maxHP)
                < Double($1.element.hp) / Double($1.element.maxHP)
        }?.offset ?? 0
        menuRow = 2
        AudioEngine.shared.playSelect()
        updateSelectionCursor()
        updateVisuals()
        announceCombatFocus()
        return
    }
    if button === blessingButton { execute(.spell(.blessing)); return }
    if button === windButton { execute(.spell(.windBlade)); return }
    if button === emberButton { execute(.spell(.emberStrike)); return }
    if button === tempestButton {
        guard !tempestSpent else {
            showEffect(String(localized: "combat.tempest.spent"),
                       color: Palette.frost)
            AudioEngine.shared.playTap()
            HapticsEngine.error()
            return
        }
        tempestUses += 1
        execute(.spell(.tempest))
        return
    }
    }

    /// Fait tourner la cible parmi les ennemis vivants.
    func cycleTarget(direction: Int) {
    // Mode soin : on parcourt le GROUPE, pas les ennemis.
    if pendingHealSpell != nil {
        let count = healTargets.count
        guard count > 1 else { return }
        healTargetIndex = (healTargetIndex + direction + count) % count
        return
    }
    let alive = enemies.indices.filter { enemies[$0].combatant.isAlive }
    guard alive.count > 1, let cur = alive.firstIndex(of: targetIndex) else { return }
    targetIndex = alive[(cur + direction + alive.count) % alive.count]
    }
}
