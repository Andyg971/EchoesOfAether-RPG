import SpriteKit

// Désert d'Ossara : zone optionnelle atteinte via la carte du monde.
// Extrait de GameManager.swift pour alléger le monolithe.
@MainActor
extension GameManager {

    // MARK: - Désert d'Ossara

    /// Peuple le désert de monstres baladeurs selon la progression.
    func spawnDesertRoamers() {
        guard let scene, inDesert else { clearRoamers(); return }
        clearRoamers()
        let w = scene.size.width
        let h = world.worldHeight > 0 ? world.worldHeight : scene.size.height
        // La CITÉ DES CARAVANES est un refuge : les rôdeurs n'y entrent pas et
        // renoncent dès que Kael s'y abrite. Ses habitants s'y terrent pour
        // cette raison — le lieu devient un vrai répit, pas un décor.
        let haven = CGRect(x: w * (DesertPOI.town.x - 0.24),
                           y: h * (DesertPOI.town.y - 0.075),
                           width: w * 0.48, height: h * 0.15)
        // Un rôdeur par tronçon : dunes du sud, abords de la cité, canyon du
        // nord. Ils se partageaient le même écran.
        switch player.desertProgress {
        case 0:
            // À l'est de l'allée : l'oasis (ouest) est un havre, pas un
            // terrain de chasse.
            addRoamer("enemy_ghoul", at: CGPoint(x: w * 0.62, y: h * 0.25),
                      wh: h, sanctuary: haven) { [weak self] in self?.startDesertCombat1() }
        case 1:
            addRoamer("enemy_bone", at: CGPoint(x: w * 0.60, y: h * 0.66),
                      wh: h, sanctuary: haven) { [weak self] in self?.startDesertCombat2() }
        case 2 where player.questDesert != .complete:
            addRoamer("enemy_bone", at: CGPoint(x: w * 0.40, y: h * 0.86),
                      wh: h, patrolRadius: 44, chaseSpeed: 78,
                      sanctuary: haven) { [weak self] in
                self?.startDesertBossSequence()
            }
        default:
            break
        }
    }

    /// Sortie du désert → CARTE DU MONDE (comme toutes les zones).
    /// La corruption d'Acte II reste appliquée à Kael (elle persiste sur son
    /// node à travers les changements de zone).
    func exitDesert() {
        clearRoamers()
        if phase == .act2 {
            world.applyKaelCorruption(level: player.kaelCorruptionLevel)
        }
        enterOverworld(spawnNear: "desert")
    }

    // MARK: - Carte du monde → entrée dans un lieu

    /// Ouvre la carte du monde explorable : Kael y marche entre les lieux.
    /// `spawnNear` : dépose Kael à côté du lieu d'où il vient (ou par défaut).
    func enterOverworld(spawnNear placeID: String? = nil, objective: String? = nil) {
        guard let scene else { return }
        transition(to: .transition)
        TransitionManager.fade(in: scene) { [weak self] in
            guard let self, let scene = self.scene else { return }
            inOverworld = true
            inDesert = false; inMines = false; inCave = false; inForest = false
            hud.objectiveText = objective ?? String(localized: "map.title")
            AudioEngine.shared.setMood(.title)
            world.switchToOverworld(in: scene)
            // Kael apparaît un peu au sud du lieu quitté (ou près du village).
            let spot = world.overworldPlaces.first { $0.id == placeID }?.pos
                ?? world.overworldPlaces.first { $0.id == "village" }?.pos
                ?? CGPoint(x: world.worldWidth * 0.20, y: world.worldHeight * 0.28)
            world.kael.position = CGPoint(x: spot.x, y: max(60, spot.y - 90))
            world.kael.isHidden = false
            world.refreshKaelDepth()
            world.snapCamera()
            // Arrivée fraîche sur la carte : les monstres ont repris leurs
            // postes (petit sursis, Kael apparaît parfois près d'un lieu).
            overworldRoamersCleared.removeAll()
            spawnOverworldRoamers(grace: 1.5)
            world.addOverworldChests(taken: player.overworldChestsTaken, in: scene)
        } completion: { [weak self] in
            self?.transition(to: .exploration)
        }
    }

    /// Depuis la carte du monde : le bouton A fait entrer Kael dans le lieu
    /// à portée. Chaque zone est chargée comme sa propre entrée connue.
    func enterZoneFromMap(_ id: String) {
        guard let scene else { return }
        guard placeDiscovered(id) else { HapticsEngine.error(); return }  // verrou histoire
        inOverworld = false
        discoveredPlaces.insert(id)   // lieu visité → voyage rapide déverrouillé
        clearRoamers()
        transition(to: .transition)
        AudioEngine.shared.playSelect()
        TransitionManager.fade(in: scene) { [weak self] in
            guard let self, let scene = self.scene else { return }
            let wh = { self.world.worldHeight > 0 ? self.world.worldHeight
                                                  : scene.size.height }
            let midX = scene.size.width * 0.5
            switch id {
            case "village":
                // N'importe quel retour à Solis pendant l'Acte I (avant même
                // d'avoir quitté pour la forêt, ou après, tant que l'Acte II
                // n'a pas commencé) doit redevenir un vrai village : sinon
                // `phase` restait .forest, le tap routait vers
                // tryForestInteraction au lieu de tryVillageInteraction, et
                // les PNJ pourtant visibles ne répondaient plus à rien.
                // L'Acte II garde son traitement à part (Dorin à la porte).
                if phase != .act2 { phase = .village }
                AudioEngine.shared.setMood(.forPhase(phase))
                world.switchToVillage(in: scene)
                if phase == .act2 {
                    // Solis d'après-Sanctuaire : Dorin garde la porte nord,
                    // village figé (corrompu), pas de déambulation.
                    world.repositionDorinToGate(in: scene)
                } else {
                    world.startVillageWander(in: scene.size)
                }
                world.kael.position = CGPoint(x: midX, y: scene.size.height * 0.30)
            case "forest":
                if phase.rawValue >= GamePhase.act2.rawValue {
                    // L'histoire est déjà partie plus loin (Acte II+) : ne
                    // PAS régresser `phase` vers .forest, ça effaçait l'acte
                    // en cours (et la sauvegarde suivante l'enregistrait —
                    // soft-lock). Simple visite, comme mines/désert/caverne.
                    inForest = true
                } else {
                    phase = .forest
                }
                hud.objectiveText = String(localized: "hud.objective.forest")
                AudioEngine.shared.setMood(.forPhase(.forest))
                showForest(in: scene)
                // Marqueurs de quête du village (jouet de l'enfant, médaillon)
                // posés jadis par le trajet direct de Dorin — conservés ici.
                if player.questChildToy == .active { world.addToyMarker(in: scene) }
                if player.questMedallion == .active { world.addMedallionMarker(in: scene) }
                addSideQuestMarkers(in: scene)
                world.kael.position = CGPoint(x: midX, y: wh() * 0.05)
            case "desert":
                inDesert = true
                hud.objectiveText = String(localized: "hud.objective.desert")
                AudioEngine.shared.setMood(.tense)
                world.switchToDesert(in: scene, progress: player.desertProgress,
                                     chestTaken: player.desertChestTaken)
                world.kael.position = CGPoint(x: midX, y: wh() * 0.06)
                spawnDesertRoamers()
            case "mines":
                // Les mines sont une excursion, pas une GamePhase (cf.
                // enterMines()) : forcer phase = .forest ici cassait l'Acte
                // II+ exactement comme "forest" plus haut, en plus sournois
                // (inMines masquait l'effet le temps de la visite).
                inMines = true
                hud.objectiveText = String(localized: "hud.objective.mines")
                AudioEngine.shared.setMood(.mines)
                world.switchToMines(in: scene, progress: player.minesProgress,
                                    goldTaken: player.minesGoldTaken)
                world.kael.position = CGPoint(x: midX, y: wh() * 0.05)
                spawnMineRoamers()
            case "ruins":
                phase = .ruins
                AudioEngine.shared.setMood(.forPhase(.ruins))
                showRuins(in: scene)          // place Kael lui-même
            case "threshold":
                phase = .act3
                AudioEngine.shared.setMood(.forPhase(.act3))
                showThreshold(in: scene)      // place Kael lui-même
            default:                          // sanctuaire
                phase = .shrine
                world.switchToShrine(in: scene)
                world.kael.position = CGPoint(x: midX, y: scene.size.height * 0.28)
            }
            world.kael.isHidden = false
            world.refreshKaelDepth()
            world.snapCamera()
        } completion: { [weak self] in
            guard let self else { return }
            // Première arrivée à Solis en Acte II (retour du Sanctuaire à pied) :
            // les retrouvailles + la révélation du Sage se jouent ICI, à l'entrée
            // du village, au lieu du saut direct d'autrefois.
            if id == "village", phase == .act2, !player.act2Returned {
                playAct2VillageReturn()
            } else if id == "desert", player.questDesert == .inactive {
                // Première arrivée aux dunes : active la quête et joue son
                // dialogue d'ouverture — c'était posé dans `enterDesert()`,
                // une fonction jamais appelée par le vrai chemin d'entrée
                // (carte du monde → ici). La quête ne s'activait donc jamais.
                player.questDesert = .active
                hud.questText = String(localized: "quest.desert.hud")
                transition(to: .dialogue)
                dialogue.start(PrototypeContent.desertEnterDialogue) { [weak self] in
                    self?.transition(to: .exploration)
                }
            } else if id == "desert", player.desertProgress >= 1,
                      player.questDesert == .active, Int.random(in: 0..<100) < 30 {
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

    /// Ouvre un coffre de la carte du monde : or + éclats d'Aether, une seule
    /// fois. C'est la récompense de qui sort des sentiers battus.
    func openOverworldChest(_ id: String) {
        guard let scene,
              let chest = WorldBuilder.overworldChests.first(where: { $0.id == id }),
              !player.overworldChestsTaken.contains(id) else { return }
        player.overworldChestsTaken.insert(id)
        player.gold += chest.gold
        player.aetherShards += chest.shards
        syncGold()
        AudioEngine.shared.playGoldGain()
        HapticsEngine.success()
        world.removeOverworldChest(id)

        let w = world.worldWidth > 0 ? world.worldWidth : scene.size.width
        let h = world.worldHeight > 0 ? world.worldHeight : scene.size.height
        let pos = WorldBuilder.overworldChestPoint(id, w: w, h: h)
        world.worldNode.addChild(ParticleFactory.impactSparks(
            at: pos, color: Palette.gold,
            count: 16))
        let message = chest.shards > 0
            ? String(localized: "chest.rewardWithShards \(chest.gold) \(chest.shards)")
            : String(localized: "chest.reward \(chest.gold)")
        AccessibilitySettings.announce(message)
        hud.objectiveText = message
        saveGame()
    }

    /// Monstres VISIBLES sur la carte : Kael peut les éviter ; les toucher
    /// lance un combat (système RoamingMonster réutilisé).
    /// `grace` : sursis d'aggro (secondes) accordé aux rôdeurs — non nul au
    /// retour d'un combat, pour laisser à Kael le temps de s'éloigner.
    func spawnOverworldRoamers(grace: TimeInterval = 0) {
        guard let scene, inOverworld else { clearRoamers(); return }
        clearRoamers()
        let w = world.worldWidth > 0 ? world.worldWidth : scene.size.width
        let h = world.worldHeight > 0 ? world.worldHeight : scene.size.height
        let spots: [(String, CGFloat, CGFloat)] = [
            ("enemy_beast", 0.34, 0.26), ("enemy_shadewolf", 0.52, 0.62),
            ("enemy_ghoul", 0.60, 0.34)
        ]
        // Un rôdeur vaincu reste mort tant que Kael arpente la carte.
        for (asset, fx, fy) in spots where !overworldRoamersCleared.contains(asset) {
            // Pleine couleur (blend 0) : ces gobelins à l'épée doivent se lire
            // comme des MONSTRES à éviter/affronter, pas des blobs gris.
            addRoamer(asset, at: CGPoint(x: w * fx, y: h * fy), wh: h,
                      patrolRadius: 70, chaseSpeed: 66, blend: 0,
                      graceTime: grace) { [weak self] in
                self?.startOverworldCombat(roamerID: asset)
            }
        }
    }

    /// Rencontre aléatoire sur la carte du monde. Après victoire, on revient
    /// EXACTEMENT là où Kael se trouvait (pas de retour au point de départ).
    func startOverworldCombat(roamerID: String? = nil) {
        guard let scene, inOverworld else { return }
        overworldReturnPos = world.kael.position
        lastCombatStarter = { [weak self] in self?.startOverworldCombat(roamerID: roamerID) }
        transition(to: .combat)
        hud.objectiveText = String(localized: "hud.objective.combat")
        let levelBefore = player.level
        let foe = String(localized: "combat.enemy.beast")
        combat.attach(
            to: scene,
            enemySpecs: [
                EnemySpec(name: String(localized: "combat.enemy.numbered \(foe) \(1)"),
                          hp: 200, kind: .beast, baseDamage: 32),
                EnemySpec(name: String(localized: "combat.enemy.numbered \(foe) \(2)"),
                          hp: 200, kind: .wolf, baseDamage: 32)
            ],
            goldReward: 45,
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
            // Ce rôdeur est vaincu : il ne repeuplera pas la carte.
            if let roamerID { overworldRoamersCleared.insert(roamerID) }
            returnToOverworldAfterCombat()
        }
    }

    private func returnToOverworldAfterCombat() {
        guard let scene else { return }
        transition(to: .transition)
        TransitionManager.fade(in: scene) { [weak self] in
            guard let self, let scene = self.scene else { return }
            inOverworld = true
            hud.objectiveText = String(localized: "map.title")
            AudioEngine.shared.setMood(.title)
            world.switchToOverworld(in: scene)
            world.kael.position = overworldReturnPos
                ?? CGPoint(x: world.worldWidth * 0.2, y: world.worldHeight * 0.3)
            world.kael.isHidden = false
            world.refreshKaelDepth()
            world.snapCamera()
            // Sursis de 2,5 s : les rôdeurs survivants ne rechargent pas Kael
            // à l'instant où il réapparaît sur la carte.
            spawnOverworldRoamers(grace: 2.5)
            world.addOverworldChests(taken: player.overworldChestsTaken, in: scene)
        } completion: { [weak self] in
            self?.transition(to: .exploration)
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

        // Habitants de la cité : trois voix terrées derrière les remparts,
        // qui racontent la même peur — les monstres ont coupé la route.
        // Une fois le colosse abattu (desertProgress 3 / questDesert
        // .complete), ils passent à leur réplique « résolue » : sinon ils
        // répétaient leur plainte alors que Kael venait justement d'y
        // répondre.
        let resolved = player.desertProgress >= 3
        let npcs: [(CGPoint, [DialogueStep])] = [
            (DesertPOI.npcCaravanier, resolved
                ? PrototypeContent.desertCaravanierResolvedDialogue
                : PrototypeContent.desertCaravanierDialogue),
            (DesertPOI.npcMerchant, resolved
                ? PrototypeContent.desertMerchantResolvedDialogue
                : PrototypeContent.desertMerchantDialogue),
            (DesertPOI.npcChild, resolved
                ? PrototypeContent.desertChildResolvedDialogue
                : PrototypeContent.desertChildDialogue)
        ]
        for (poi, steps) in npcs
        where point.distance(to: poi.scaled(w: w, h: h)) < DesertPOI.reach {
            transition(to: .dialogue)
            dialogue.start(steps) { [weak self] in
                self?.transition(to: .exploration)
            }
            return true
        }

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
                          hp: 880, kind: .ruinsGuardian, baseDamage: 52)
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
            at: spot, color: Palette.gold, count: 14))
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
