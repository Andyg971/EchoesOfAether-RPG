import SpriteKit

// Utilitaires : textes flottants, effets d'annonce, barres.
// Extrait de CombatSystem.swift (découpage du monolithe).
@MainActor
extension CombatSystem {
    // MARK: - Helpers



    func configureBar(_ back: SKShapeNode, _ fill: SKShapeNode,
                              width: CGFloat, height: CGFloat,
                              color: SKColor, at position: CGPoint,
                              ghost: SKShapeNode? = nil) {
        // Barres rectangulaires nettes — pas de bouts arrondis en pixel art.
        let rect = CGRect(x: -width / 2, y: -height / 2, width: width, height: height)
        let path = CGPath(rect: rect, transform: nil)

        back.path = path
        back.fillColor = SKColor(white: 0.13, alpha: 1)
        back.strokeColor = SKColor(red: 0.02, green: 0.02, blue: 0.03, alpha: 0.9)
        back.lineWidth = 2
        back.position = position
        root.addChild(back)

        // Barre fantôme : blanche, fond après les dégâts (feedback juteux)
        if let ghost {
            ghost.path = path
            ghost.fillColor = SKColor(white: 0.92, alpha: 0.55)
            ghost.strokeColor = .clear
            ghost.position = position
            ghost.xScale = 1.0
            root.addChild(ghost)
        }

        fill.path = path
        fill.fillColor = color
        fill.strokeColor = .clear
        fill.position = position
        fill.xScale = 1.0
        root.addChild(fill)
    }

    /// Barre fantôme : suit la vraie barre avec un temps de retard quand
    /// les PV baissent ; se cale instantanément quand ils remontent.
    func updateGhostBar(_ ghost: SKShapeNode, to ratio: CGFloat) {
        if ratio >= ghost.xScale - 0.001 {
            ghost.removeAllActions()
            ghost.xScale = ratio
            return
        }
        ghost.removeAllActions()
        let melt = SKAction.scaleX(to: ratio, duration: 0.35)
        melt.timingMode = .easeOut
        ghost.run(.sequence([.wait(forDuration: 0.30), melt]))
    }

    /// Pictos de statut persistants au-dessus d'un ennemi : brûlure
    /// (flamme), gel/paralysie (éclair), garde brisée (bouclier fêlé).
    /// Reconstruits à chaque updateVisuals — 3 pictos max, coût nul.
    func refreshStatusIcons(for e: EnemyState) {
        e.statusIcons.removeAllChildren()
        guard e.combatant.isAlive else { return }

        var icons: [SKNode] = []
        if let status = e.combatant.statusEffect {
            let palette: [SKColor] = status == .aetherBurn
                ? [SKColor(red: 1.00, green: 0.58, blue: 0.16, alpha: 1),
                   SKColor(red: 0.88, green: 0.24, blue: 0.06, alpha: 1)]
                : [SKColor(red: 0.45, green: 0.90, blue: 0.40, alpha: 1),
                   SKColor(red: 0.20, green: 0.60, blue: 0.25, alpha: 1)]
            icons.append(Self.makeFlameIcon(palette: palette,
                                            ticks: e.combatant.statusTicks))
        }
        if e.combatant.stunned {
            icons.append(Self.makeBoltIcon())
        }
        if e.brokenTurns > 0 {
            icons.append(Self.makeBrokenShieldIcon())
        }
        guard !icons.isEmpty else { return }

        let spacing: CGFloat = 16
        let x0 = -spacing * CGFloat(icons.count - 1) / 2
        for (i, icon) in icons.enumerated() {
            icon.position = CGPoint(x: x0 + CGFloat(i) * spacing, y: 0)
            e.statusIcons.addChild(icon)
            JuiceEngine.pulse(icon, scale: 1.12)
        }
    }

    /// Flamme pixel (3 carrés étagés) + pips de tours restants.
    static func makeFlameIcon(palette: [SKColor], ticks: Int) -> SKNode {
        let icon = SKNode()
        let base = SKSpriteNode(color: palette[1], size: CGSize(width: 8, height: 6))
        icon.addChild(base)
        let mid = SKSpriteNode(color: palette[0], size: CGSize(width: 6, height: 5))
        mid.position = CGPoint(x: 0, y: 5)
        icon.addChild(mid)
        let tip = SKSpriteNode(color: palette[0], size: CGSize(width: 3, height: 4))
        tip.position = CGPoint(x: 1, y: 9)
        icon.addChild(tip)
        // Pips : tours de statut restants (1 pixel par tick)
        for t in 0..<min(ticks, 3) {
            let pip = SKSpriteNode(color: .white, size: CGSize(width: 2, height: 2))
            pip.position = CGPoint(x: CGFloat(t) * 3 - 3, y: -6)
            icon.addChild(pip)
        }
        return icon
    }

    /// Éclair pixel jaune : gel / paralysie (tour sauté).
    static func makeBoltIcon() -> SKNode {
        let icon = SKNode()
        let yellow = SKColor(red: 1.00, green: 0.88, blue: 0.30, alpha: 1)
        for (dx, dy, w, h) in [(1.5, 6.0, 5.0, 4.0), (-0.5, 2.0, 5.0, 4.0),
                               (1.0, -2.0, 5.0, 4.0), (-1.5, -6.0, 4.0, 4.0)] {
            let seg = SKSpriteNode(color: yellow, size: CGSize(width: w, height: h))
            seg.position = CGPoint(x: dx, y: dy)
            icon.addChild(seg)
        }
        return icon
    }

    /// Bouclier fêlé doré : garde brisée (BREAK).
    static func makeBrokenShieldIcon() -> SKNode {
        let icon = SKNode()
        let gold = Palette.goldCombatBright
        let dark = SKColor(red: 0.35, green: 0.25, blue: 0.05, alpha: 1)
        let body = SKSpriteNode(color: gold, size: CGSize(width: 10, height: 10))
        icon.addChild(body)
        let point = SKSpriteNode(color: gold, size: CGSize(width: 6, height: 3))
        point.position = CGPoint(x: 0, y: -6)
        icon.addChild(point)
        // Fissure : marches sombres en diagonale
        for (dx, dy) in [(-2.0, 3.0), (0.0, 0.0), (2.0, -3.0)] {
            let crack = SKSpriteNode(color: dark, size: CGSize(width: 2, height: 4))
            crack.position = CGPoint(x: dx, y: dy)
            icon.addChild(crack)
        }
        return icon
    }

    func addCombatantLabel(_ text: String, at position: CGPoint) {
        let label = SKLabelNode(fontNamed: PixelUI.uiFont)
        label.text = text
        label.fontSize = 19
        label.fontColor = .white
        label.position = position
        root.addChild(label)
    }

    func addSmallLabel(_ text: String, at position: CGPoint) {
        let label = SKLabelNode(fontNamed: PixelUI.uiFont)
        label.text = text
        label.fontSize = 13
        label.fontColor = SKColor(white: 0.6, alpha: 1)
        label.position = position
        root.addChild(label)
    }

    func addButton(_ node: SKShapeNode, title: String, at position: CGPoint,
                           width: CGFloat, height: CGFloat,
                           fill: SKColor, stroke: SKColor,
                           fontSize: CGFloat = 14,
                           chip: SKColor? = nil) {
        node.removeAllChildren()
        PixelUI.stylePanel(node, size: CGSize(width: width, height: height),
                           fill: fill, accent: stroke)
        node.position = position
        node.zPosition = 860

        let label = SKLabelNode(fontNamed: PixelUI.uiFont)
        label.text = title
        label.fontSize = fontSize
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        node.addChild(label)

        // Pastille d'élément : losange pixel net à gauche du texte.
        if let chip {
            label.horizontalAlignmentMode = .left
            let textW = label.frame.width
            let chipSide: CGFloat = 7
            let contentW = textW + chipSide + 6
            label.position = CGPoint(x: -contentW / 2 + chipSide + 6, y: 0)

            let diamond = SKSpriteNode(color: chip,
                                       size: CGSize(width: chipSide, height: chipSide))
            diamond.zRotation = .pi / 4
            diamond.position = CGPoint(x: -contentW / 2 + chipSide / 2, y: 0)
            node.addChild(diamond)
        }

        root.addChild(node)
    }

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
