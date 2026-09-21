import SpriteKit

// Arène — rangée d'infos de la cible et rafraîchissement global des visuels.
extension CombatSystem {

    /// Rangée « faiblesses + bouclier » sous la plate de la cible.
    ///
    /// Losanges de 7 pt, identiques à ceux du menu d'actions (`addButton`), et
    /// dans le même ordre que les commandes : le joueur apparie une couleur,
    /// pas un mot. Le bouclier suit sous forme de pips — plein = encore
    /// debout, éteint = entamé ; à zéro l'ennemi est brisé et la rangée
    /// s'allume en ambre.
    func refreshTargetInfoRow(for foe: EnemyState) {
        // Ordre stable : celui de `CombatElement`, pas celui d'un Set.
        let order: [CombatElement] = [.physical, .fire, .ice, .lightning, .aether]
        let weaknesses = order.filter { foe.weaknesses.contains($0) }
        let broken = foe.brokenTurns > 0
        // Reconstruire des SKNode à chaque frame ferait clignoter la rangée.
        // Clé indépendante de la langue : `icon` est traduit, il n'a rien à
        // faire dans un cache.
        let key = "\(weaknesses.map { String(describing: $0) }.joined(separator: ","))"
            + "|\(foe.shield)/\(foe.shieldMax)|\(broken)"
        guard key != lastTargetInfoKey else { return }
        lastTargetInfoKey = key
        targetInfoRow.removeAllChildren()

        let side: CGFloat = 7, gap: CGFloat = 9, pipW: CGFloat = 5, pipGap: CGFloat = 3
        let shieldW = foe.shieldMax > 0
            ? CGFloat(foe.shieldMax) * (pipW + pipGap) - pipGap + 12 : 0
        let totalW = CGFloat(weaknesses.count) * gap - (weaknesses.isEmpty ? 0 : gap - side)
            + shieldW
        var x = -totalW / 2

        // FOND DE PANNEAU. Sans lui, losanges et pips flottent nus sur ce
        // qu'il y a derrière : chez un ennemi haut comme le Gardien, la
        // rangée tombe en plein sur son torse et se lit comme des carrés de
        // couleur collés au sprite, pas comme de l'interface. Le fond les
        // rattache au HUD.
        if !weaknesses.isEmpty || foe.shieldMax > 0 {
            let plate = SKShapeNode()
            PixelUI.stylePanel(plate, size: CGSize(width: totalW + 16, height: 20),
                               fill: SKColor(red: 0.05, green: 0.04, blue: 0.07, alpha: 0.92),
                               accent: SKColor(white: 0.34, alpha: 0.85))
            plate.zPosition = -1
            targetInfoRow.addChild(plate)
        }

        for element in weaknesses {
            let diamond = SKSpriteNode(color: element.color,
                                       size: CGSize(width: side, height: side))
            diamond.zRotation = .pi / 4
            diamond.position = CGPoint(x: x + side / 2, y: 0)
            // Cible brisée : les faiblesses ont fait leur travail, elles
            // s'effacent au profit des pips éteints.
            diamond.alpha = broken ? 0.45 : 1
            targetInfoRow.addChild(diamond)
            x += gap
        }

        guard foe.shieldMax > 0 else { return }
        x += 12
        for i in 0..<foe.shieldMax {
            let up = i < foe.shield
            let pip = SKSpriteNode(color: up ? PixelUI.gold : SKColor(white: 0.22, alpha: 1),
                                   size: CGSize(width: pipW, height: 10))
            pip.position = CGPoint(x: x + pipW / 2, y: 0)
            targetInfoRow.addChild(pip)
            x += pipW + pipGap
        }
    }

    func updateVisuals() {
        let kaelHPRatio = max(0.02, CGFloat(kael.hp) / CGFloat(kael.maxHP))
        kaelHPFill.xScale = kaelHPRatio
        kaelHPLabel.text = String(kael.hp) + "/" + String(kael.maxHP)
        updateGhostBar(kaelHPGhost, to: kaelHPRatio)

        // Réserve de Magie
        let mpRatio = kael.maxMP > 0 ? max(0, CGFloat(kael.mp) / CGFloat(kael.maxMP)) : 0
        kaelMPFill.xScale = mpRatio
        kaelMPLabel.text = "MP " + String(kael.mp) + "/" + String(kael.maxMP)

        for ally in allies {
            let c = ally.combatant
            let ratio = max(0.02, CGFloat(c.hp) / CGFloat(c.maxHP))
            ally.hpFill.xScale = ratio
            ally.hpLabel.text = String(c.hp) + "/" + String(c.maxHP)
            updateGhostBar(ally.hpGhost, to: ratio)
            let mpRatio = c.maxMP > 0 ? max(0, CGFloat(c.mp) / CGFloat(c.maxMP)) : 0
            ally.mpFill.xScale = mpRatio
            ally.mpLabel.text = "MP " + String(c.mp) + "/" + String(c.maxMP)
        }

        // Étiquette d'acteur sur le panneau d'actions (qui joue ?)
        if let ally = actingAlly {
            actorTagLabel.text = "◆ " + ally.kind.displayName.uppercased()
            actorTagLabel.fontColor = ally.kind.accentColor
        } else {
            actorTagLabel.text = "◆ KAEL"
            actorTagLabel.fontColor = SKColor(red: 0.62, green: 0.82, blue: 1.00, alpha: 1)
        }
        actorTagLabel.isHidden = allies.isEmpty
            || !(phase == .playerTurn || phase == .playerActing)

        // Plate de droite = cible courante
        if let foe = target {
            let c = foe.combatant
            let enemyRatio = max(0.02, CGFloat(c.hp) / CGFloat(c.maxHP))
            enemyHPFill.xScale = enemyRatio
            // Changement de cible : la barre fantôme saute sans animer
            if lastTargetIndexForGhost != targetIndex {
                lastTargetIndexForGhost = targetIndex
                enemyHPGhost.removeAllActions()
                enemyHPGhost.xScale = enemyRatio
            } else {
                updateGhostBar(enemyHPGhost, to: enemyRatio)
            }
            enemyHPLabel.text = String(c.hp) + "/" + String(c.maxHP)
            targetNameLabel.text = c.name
            refreshTargetInfoRow(for: foe)
            targetInfoRow.isHidden = false
            enemyHPBack.strokeColor = foe.brokenTurns > 0
                ? Palette.goldCombatBright
                : SKColor(white: 0.3, alpha: 1)
            // Marqueur de cible au-dessus du sprite visé.
            // En ciblage de soin il désigne un ALLIÉ : il devient vert et se
            // pose sur le membre du groupe choisi, même s'il n'y a qu'un
            // ennemi — c'est le curseur du joueur.
            if let healIdx = pendingHealSpell != nil ? healTargetIndex : nil,
               healTargets.indices.contains(healIdx) {
                targetMarker.isHidden = false
                targetMarker.strokeColor = Palette.vitality
                let t = healTargets[healIdx]
                targetMarker.position = CGPoint(x: t.home.x, y: t.home.y + 64)
            } else {
                targetMarker.strokeColor = SKColor(red: 1.00, green: 0.85, blue: 0.30, alpha: 1)
                let markerVisible = enemies.count > 1 && c.isAlive && phase != .finished
                targetMarker.isHidden = !markerVisible
                if markerVisible {
                    targetMarker.position = CGPoint(x: foe.homePosition.x,
                                                    y: foe.homePosition.y + 64)
                }
            }
        } else {
            targetMarker.isHidden = true
            targetInfoRow.isHidden = true
        }

        // Les mini-barres rouges qui doublaient la plate de la cible vivaient
        // ici. Deux affichages pour une même vie, et celui-ci n'était qu'un
        // rectangle nu posé sous l'ennemi — sans cadre ni fond, il se lisait
        // comme un débris du décor. La plate porte le nom, la vie, les
        // faiblesses et le bouclier ; le chevron désigne qui la remplit.
        for e in enemies { refreshStatusIcons(for: e) }

        let ready = phase == .playerTurn && kael.isAlive && !aliveEnemies.isEmpty
        for button in [attackButton, blackSlashButton, fireButton, iceButton,
                       lightningButton, healButton, blessingButton,
                       windButton, emberButton, tempestButton] {
            button.alpha = ready ? 1 : 0.36
        }
        selectionCursor.isHidden = !ready || menuRow == 2
        boostButton.alpha = (ready && playerBP > 0 && queuedBoost < 3) ? 1 : 0.34
        let potionCount = _player?.potions ?? 0
        potionButton.alpha = (ready && potionCount > 0) ? 1 : 0.34
        if let label = potionButton.children.compactMap({ $0 as? SKLabelNode }).first {
            label.text = String(localized: "combat.button.potion") + " ×" + String(potionCount)
        }

        let bpPips = (0..<3).map { $0 < playerBP ? "●" : "○" }.joined()
        if queuedBoost > 0 {
            boostLabel.text = "BP " + bpPips + "   "
                + String(localized: "combat.status.boost \(queuedBoost + 1)")
        } else if bpRecharging {
            boostLabel.text = "BP " + bpPips + "   "
                + String(localized: "combat.boost.recharging")
        } else {
            boostLabel.text = "BP " + bpPips
        }

    }
}
