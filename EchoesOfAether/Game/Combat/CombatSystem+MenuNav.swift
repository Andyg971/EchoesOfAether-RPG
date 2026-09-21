import SpriteKit

// Menu de combat — curseur, navigation joystick, validation, ciblage, VoiceOver.
extension CombatSystem {
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
