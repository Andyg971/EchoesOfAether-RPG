import SpriteKit

// Arène — les plates de PV/PM du groupe et des ennemis.
extension CombatSystem {
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
}
