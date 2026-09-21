import SpriteKit

// Forêt d'Ébène : interactions, combats de progression et chasses.
// Extrait de GameManager.swift (découpage du monolithe).
@MainActor
extension GameManager {

    // MARK: - Forest Interactions

    func tryForestInteraction(_ point: CGPoint, in scene: SKScene) -> Bool {
        // Trek scrollable : les POI vivent en coordonnées MONDE
        // (fractions de worldHeight, synchronisées avec buildForest).
        let w = scene.size.width
        let h = world.worldHeight > 0 ? world.worldHeight : scene.size.height

        // Les combats de la forêt (bosquet, clairière, chasses) ne se
        // déclenchent plus au tap : des monstres baladeurs chargent Kael
        // (cf. spawnForestRoamers).

        // Zone 3 : Seuil du sanctuaire (nord) — pas en simple visite depuis
        // la carte (inForest) : enterShrine() force phase = .shrine sans
        // condition, ce qui écraserait l'Acte II/III/IV en cours. Le
        // sanctuaire n'a de toute façon plus rien à offrir une fois l'Acte I
        // franchi.
        if player.forestProgress >= 2, !inForest {
            let deepPath = CGPoint(x: w * 0.55, y: h * 0.90)
            if point.distance(to: deepPath) < 70 {
                enterShrine()
                return true
            }
        }

        // Jouet perdu (fourrés à l'est du campement)
        if player.questChildToy == .active {
            let toySpot = CGPoint(x: w * 0.80, y: h * 0.45)
            if point.distance(to: toySpot) < 60 {
                pickupToy()
                return true
            }
        }

        // Talisman perdu (quête de la villageoise, sentier ouest)
        if player.questMedallion == .active {
            let crossSpot = CGPoint(x: w * 0.28, y: h * 0.72)
            if point.distance(to: crossSpot) < 60 {
                pickupMedallion()
                return true
            }
        }

        // Fer corrompu (quête de Bram, sentier ouest sous la clairière)
        if player.questBramOre == .active {
            let oreSpot = CGPoint(x: w * 0.40, y: h * 0.63)
            if point.distance(to: oreSpot) < 60 {
                pickupOre()
                return true
            }
        }

        // Herbe lunaire (quête de Sage, ouest du sentier)
        if player.questSageHerb == .active {
            let herbSpot = CGPoint(x: w * 0.12, y: h * 0.40)
            if point.distance(to: herbSpot) < 60 {
                pickupHerb()
                return true
            }
        }

        // Insigne de l'éclaireur (quête de Garen, sente est)
        if player.questGarenScout == .active {
            let badgeSpot = CGPoint(x: w * 0.68, y: h * 0.18)
            if point.distance(to: badgeSpot) < 60 {
                pickupScoutBadge()
                return true
            }
        }

        // Cristal-mère (quête de Lyra), au cœur mort de la forêt.
        if player.questLyraShards == .active {
            let crystalSpot = CGPoint(x: w * 0.78, y: h * 0.70)
            if point.distance(to: crystalSpot) < 60 {
                pickupMotherCrystal()
                return true
            }
        }

        // Entrée des mines de Cendreval (flanc est)
        let mineEntrance = CGPoint(x: w * 0.88, y: h * 0.30)
        if point.distance(to: mineEntrance) < 65 {
            enterMines()
            return true
        }

        // Entrée de la Caverne aux Échos (donjon optionnel, flanc ouest)
        let caveEntrance = CGPoint(x: w * 0.12, y: h * 0.80)
        if point.distance(to: caveEntrance) < 65 {
            enterCave()
            return true
        }

        return false
    }

    /// Chasse optionnelle : nid de goules (2 ennemis coriaces).
    func startGhoulCombat() {
        guard let scene else { return }
        lastCombatStarter = { [weak self] in self?.startGhoulCombat() }
        transition(to: .combat)
        hud.objectiveText = String(localized: "hud.objective.combat")
        let levelBefore = player.level
        let name = String(localized: "combat.enemy.ghoul")
        combat.attach(
            to: scene,
            enemySpecs: [
                EnemySpec(name: String(localized: "combat.enemy.numbered \(name) \(1)"),
                          hp: 200, kind: .ghoul, baseDamage: 34),
                EnemySpec(name: String(localized: "combat.enemy.numbered \(name) \(2)"),
                          hp: 200, kind: .ghoul, baseDamage: 34)
            ],
            goldReward: 40,
            player: player,
            withLyra: lyraInParty
        ) { [weak self] resonance, gold in
            guard let self else { return }
            if resonance < 0 { showDeathScreen(); return }
            grantLevelUpDisplay(from: levelBefore)
            resonanceTotal += resonance
            player.gold += gold
            syncGold()
            AudioEngine.shared.playGoldGain()
            hud.resonanceValue = resonanceTotal
            // Chasse vaincue : ne recharge plus Kael avant la prochaine visite.
            forestHuntsCleared.insert("ghoul")
            spawnForestRoamers()
            transition(to: .exploration)
        }
    }

    /// Chasse optionnelle : squelette errant escorté d'une goule.
    func startBoneCombat() {
        guard let scene else { return }
        lastCombatStarter = { [weak self] in self?.startBoneCombat() }
        transition(to: .combat)
        hud.objectiveText = String(localized: "hud.objective.combat")
        let levelBefore = player.level
        combat.attach(
            to: scene,
            enemySpecs: [
                EnemySpec(name: String(localized: "combat.enemy.bonewalker"),
                          hp: 320, kind: .boneWalker, baseDamage: 42),
                EnemySpec(name: String(localized: "combat.enemy.ghoul"),
                          hp: 180, kind: .ghoul, baseDamage: 32)
            ],
            goldReward: 55,
            player: player,
            withLyra: lyraInParty
        ) { [weak self] resonance, gold in
            guard let self else { return }
            if resonance < 0 { showDeathScreen(); return }
            grantLevelUpDisplay(from: levelBefore)
            resonanceTotal += resonance
            player.gold += gold
            syncGold()
            AudioEngine.shared.playGoldGain()
            hud.resonanceValue = resonanceTotal
            forestHuntsCleared.insert("bone")
            spawnForestRoamers()
            transition(to: .exploration)
        }
    }

    /// Ramasser le jouet perdu de l'enfant
    func pickupToy() {
        guard let scene else { return }
        player.questChildToy = .complete
        player.gold += 25
        syncGold()
        AudioEngine.shared.playQuestComplete()

        // Remove toy visual from world
        world.removeToyMarker()

        // Sparkle pickup effect (coordonnées monde — la forêt scrolle)
        let wh = world.worldHeight > 0 ? world.worldHeight : scene.size.height
        let toySpot = CGPoint(x: scene.size.width * 0.80, y: wh * 0.45)
        world.worldNode.addChild(ParticleFactory.impactSparks(at: toySpot, color: Palette.goldWorld, count: 12))

        transition(to: .dialogue)
        hud.questText = ""
        dialogue.start(PrototypeContent.toyFoundDialogue) { [weak self] in
            self?.transition(to: .exploration)
        }
    }

}
