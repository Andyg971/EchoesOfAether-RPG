import SpriteKit

// Désert d'Ossara : zone optionnelle atteinte via la carte du monde.
// Extrait de GameManager.swift pour alléger le monolithe.
@MainActor
extension GameManager {

    // MARK: - Désert d'Ossara

    /// Voyage vers les dunes : Kael quitte sa zone, le désert se charge.
    func enterDesert() {
        guard let scene else { return }
        transition(to: .transition)
        TransitionManager.fade(in: scene) { [weak self] in
            guard let self else { return }
            inDesert = true
            hud.objectiveText = String(localized: "hud.objective.desert")
            AudioEngine.shared.setMood(.tense)
            world.switchToDesert(in: scene, progress: player.desertProgress,
                                 chestTaken: player.desertChestTaken)
            // Coordonnées MONDE : Ossara scrolle sur trois écrans depuis
            // qu'elle a une cité. `scene.size.height` posait Kael au tiers de
            // la traversée, loin du sable d'entrée.
            world.kael.position = CGPoint(x: scene.size.width * 0.50,
                                          y: world.worldHeight * 0.09)
        } completion: { [weak self] in
            guard let self else { return }
            spawnDesertRoamers()
            if player.questDesert == .inactive {
                player.questDesert = .active
                hud.questText = String(localized: "quest.desert.hud")
                transition(to: .dialogue)
                dialogue.start(PrototypeContent.desertEnterDialogue) { [weak self] in
                    self?.transition(to: .exploration)
                }
            } else if player.desertProgress >= 1, player.questDesert == .active,
                      Int.random(in: 0..<100) < 30 {
                // Rencontre aléatoire en chemin : les dunes ne pardonnent pas.
                transition(to: .dialogue)
                dialogue.start(PrototypeContent.desertAmbushDialogue) { [weak self] in
                    self?.startDesertAmbush()
                }
            } else {
                transition(to: .exploration)
            }
        }
    }

    /// Peuple le désert de monstres baladeurs selon la progression.
    func spawnDesertRoamers() {
        guard let scene, inDesert else { clearRoamers(); return }
        clearRoamers()
        let w = scene.size.width
        let h = world.worldHeight > 0 ? world.worldHeight : scene.size.height
        // Un rôdeur par tronçon : dunes du sud, abords de la cité, canyon du
        // nord. Ils se partageaient le même écran.
        switch player.desertProgress {
        case 0:
            addRoamer("enemy_ghoul", at: CGPoint(x: w * 0.30, y: h * 0.22),
                      wh: h) { [weak self] in self?.startDesertCombat1() }
        case 1:
            addRoamer("enemy_bone", at: CGPoint(x: w * 0.60, y: h * 0.66),
                      wh: h) { [weak self] in self?.startDesertCombat2() }
        case 2 where player.questDesert != .complete:
            addRoamer("enemy_bone", at: CGPoint(x: w * 0.40, y: h * 0.86),
                      wh: h, patrolRadius: 44, chaseSpeed: 78) { [weak self] in
                self?.startDesertBossSequence()
            }
        default:
            break
        }
    }

    /// Retour vers la zone d'origine (la phase n'a pas changé).
    func exitDesert() {
        guard let scene else { return }
        clearRoamers()
        transition(to: .transition)
        TransitionManager.fade(in: scene) { [weak self] in
            guard let self else { return }
            inDesert = false
            AudioEngine.shared.setMood(.forPhase(phase))
            switch phase {
            case .forest:
                hud.objectiveText = String(localized: "hud.objective.forest")
                showForest(in: scene)
            case .act2:
                hud.objectiveText = String(localized: "hud.objective.act2")
                world.switchToVillage(in: scene)
                world.repositionDorinToGate(in: scene)
                world.applyKaelCorruption(level: player.kaelCorruptionLevel)
            default:
                hud.objectiveText = String(localized: "hud.objective.complete")
                world.switchToVillage(in: scene)
            }
        } completion: { [weak self] in
            guard let self, let scene = self.scene else { return }
            let wh = world.worldHeight > 0 ? world.worldHeight : scene.size.height
            if phase == .forest {
                if player.questChildToy == .active { world.addToyMarker(in: scene) }
                if player.questMedallion == .active { world.addMedallionMarker(in: scene) }
                addSideQuestMarkers(in: scene)
                world.kael.position = CGPoint(x: scene.size.width * 0.5, y: wh * 0.05)
            } else {
                world.kael.position = CGPoint(x: scene.size.width * 0.5, y: wh * 0.12)
            }
            transition(to: .exploration)
        }
    }

    func tryDesertInteraction(_ point: CGPoint, in scene: SKScene) -> Bool {
        let w = scene.size.width
        // Hauteur MONDE, et repères partagés avec `WorldBuilder` : chaque
        // fichier plaçait les mêmes POI avec sa propre formule.
        let h = world.worldHeight > 0 ? world.worldHeight : scene.size.height

        // Sortie (halo sud) : retour vers la zone d'origine
        if point.distance(to: CGPoint(x: w * 0.50, y: h * DesertPOI.exitY)) < DesertPOI.reach {
            exitDesert()
            return true
        }

        // Les combats du désert se déclenchent au contact d'un monstre
        // baladeur (spawnDesertRoamers), plus au tap.

        // Coffre enfoui (une seule fois)
        if !player.desertChestTaken,
           point.distance(to: CGPoint(x: w * 0.10, y: h * DesertPOI.chestY)) < DesertPOI.reach {
            pickupBuriedChest()
            return true
        }

        // Oasis : restaure tous les PV, une fois par visite
        if !player.desertOasisUsed,
           point.distance(to: DesertPOI.oasis.scaled(w: w, h: h)) < DesertPOI.reach {
            drinkAtOasis()
            return true
        }

        return false
    }

    /// Combat 1 : deux pillards des dunes — les détrousseurs de caravanes.
    func startDesertCombat1() {
        guard let scene else { return }
        lastCombatStarter = { [weak self] in self?.startDesertCombat1() }
        transition(to: .combat)
        hud.objectiveText = String(localized: "hud.objective.combat")
        let levelBefore = player.level
        let name = String(localized: "combat.enemy.dunePillager")
        combat.attach(
            to: scene,
            enemySpecs: [
                EnemySpec(name: String(localized: "combat.enemy.numbered \(name) \(1)"),
                          hp: 260, kind: .ghoul, baseDamage: 40),
                EnemySpec(name: String(localized: "combat.enemy.numbered \(name) \(2)"),
                          hp: 260, kind: .ghoul, baseDamage: 40)
            ],
            goldReward: 60,
            player: player,
            withLyra: lyraInParty
        ) { [weak self] resonance, gold in
            guard let self else { return }
            if resonance < 0 { showDeathScreen(); return }
            grantLevelUpDisplay(from: levelBefore)
            resonanceTotal += resonance
            player.gold += gold
            player.desertProgress = 1
            syncGold()
            AudioEngine.shared.playGoldGain()
            hud.resonanceValue = resonanceTotal
            hud.objectiveText = String(localized: "hud.objective.desert")
            refreshDesertBackdrop()
            transition(to: .dialogue)
            dialogue.start(PrototypeContent.desertCombat1PostDialogue) { [weak self] in
                self?.transition(to: .exploration)
            }
        }
    }

    /// Combat 2 : les charognards d'Ossara — ceux qui suivent les pillards.
    func startDesertCombat2() {
        guard let scene else { return }
        lastCombatStarter = { [weak self] in self?.startDesertCombat2() }
        transition(to: .combat)
        hud.objectiveText = String(localized: "hud.objective.combat")
        let levelBefore = player.level
        let scavenger = String(localized: "combat.enemy.scavenger")
        combat.attach(
            to: scene,
            enemySpecs: [
                EnemySpec(name: String(localized: "combat.enemy.numbered \(scavenger) \(1)"),
                          hp: 240, kind: .boneWalker, baseDamage: 38),
                EnemySpec(name: String(localized: "combat.enemy.numbered \(scavenger) \(2)"),
                          hp: 240, kind: .boneWalker, baseDamage: 38),
                EnemySpec(name: String(localized: "combat.enemy.dunePillager"),
                          hp: 220, kind: .ghoul, baseDamage: 36)
            ],
            goldReward: 80,
            player: player,
            withLyra: lyraInParty
        ) { [weak self] resonance, gold in
            guard let self else { return }
            if resonance < 0 { showDeathScreen(); return }
            grantLevelUpDisplay(from: levelBefore)
            resonanceTotal += resonance
            player.gold += gold
            player.desertProgress = 2
            syncGold()
            AudioEngine.shared.playGoldGain()
            hud.resonanceValue = resonanceTotal
            hud.objectiveText = String(localized: "hud.objective.desert")
            refreshDesertBackdrop()
            transition(to: .exploration)
        }
    }

    /// Boss du désert : dialogue d'approche puis le colosse des sables.
    func startDesertBossSequence() {
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.desertBossPreDialogue) { [weak self] in
            self?.startDesertBossCombat()
        }
    }

    func startDesertBossCombat() {
        guard let scene else { return }
        lastCombatStarter = { [weak self] in self?.startDesertBossCombat() }
        transition(to: .combat)
        hud.objectiveText = String(localized: "hud.objective.combat")
        let levelBefore = player.level
        combat.attach(
            to: scene,
            enemySpecs: [
                EnemySpec(name: String(localized: "combat.enemy.sandColossus"),
                          hp: 640, kind: .ruinsGuardian, baseDamage: 52)
            ],
            goldReward: 180,
            player: player,
            withLyra: lyraInParty
        ) { [weak self] resonance, gold in
            guard let self else { return }
            if resonance < 0 { showDeathScreen(); return }
            grantLevelUpDisplay(from: levelBefore)
            resonanceTotal += resonance
            player.gold += gold
            player.desertProgress = 3
            player.questDesert = .complete
            syncGold()
            hud.questText = ""
            AudioEngine.shared.playQuestComplete()
            hud.resonanceValue = resonanceTotal
            hud.objectiveText = String(localized: "hud.objective.desert")
            refreshDesertBackdrop()
            transition(to: .dialogue)
            dialogue.start(PrototypeContent.desertBossPostDialogue) { [weak self] in
                self?.transition(to: .exploration)
            }
        }
    }

    /// Embuscade de voyage : deux pillards surgissent des dunes.
    func startDesertAmbush() {
        guard let scene else { return }
        lastCombatStarter = { [weak self] in self?.startDesertAmbush() }
        transition(to: .combat)
        hud.objectiveText = String(localized: "hud.objective.combat")
        let levelBefore = player.level
        let name = String(localized: "combat.enemy.dunePillager")
        combat.attach(
            to: scene,
            enemySpecs: [
                EnemySpec(name: String(localized: "combat.enemy.numbered \(name) \(1)"),
                          hp: 220, kind: .ghoul, baseDamage: 36),
                EnemySpec(name: String(localized: "combat.enemy.numbered \(name) \(2)"),
                          hp: 220, kind: .ghoul, baseDamage: 36)
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
            hud.objectiveText = String(localized: "hud.objective.desert")
            transition(to: .exploration)
        }
    }

    /// Reconstruit le décor du désert après un combat (les monstres
    /// vaincus disparaissent, la zone suivante s'allume).
    func refreshDesertBackdrop() {
        guard let scene, inDesert else { return }
        let kaelPos = world.kael.position
        world.switchToDesert(in: scene, progress: player.desertProgress,
                             chestTaken: player.desertChestTaken)
        world.kael.position = kaelPos
        spawnDesertRoamers()
    }

    /// Coffre enfoui : +120 or, une seule fois.
    func pickupBuriedChest() {
        guard let scene else { return }
        player.desertChestTaken = true
        player.gold += 120
        syncGold()
        AudioEngine.shared.playGoldGain()
        world.removeBuriedChest()
        let spot = CGPoint(x: scene.size.width * 0.10,
                           y: world.worldHeight * DesertPOI.chestY)
        world.worldNode.addChild(ParticleFactory.impactSparks(
            at: spot, color: SKColor(red: 0.98, green: 0.82, blue: 0.32, alpha: 1), count: 14))
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.desertChestDialogue) { [weak self] in
            self?.transition(to: .exploration)
        }
    }

    /// Oasis : restaure tous les PV, une fois par visite.
    func drinkAtOasis() {
        guard let scene else { return }
        player.desertOasisUsed = true
        player.currentHP = player.currentMaxHP
        HapticsEngine.medium()
        JuiceEngine.flashOverlay(in: scene, size: scene.size,
                                 color: SKColor(red: 0.30, green: 0.75, blue: 0.85, alpha: 1),
                                 duration: 0.25)
        let spot = DesertPOI.oasis.scaled(w: scene.size.width, h: world.worldHeight)
        world.worldNode.addChild(ParticleFactory.impactSparks(
            at: spot, color: SKColor(red: 0.55, green: 0.90, blue: 1.0, alpha: 1), count: 12))
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.desertOasisDialogue) { [weak self] in
            self?.transition(to: .exploration)
        }
    }
}
