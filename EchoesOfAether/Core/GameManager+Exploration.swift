import SpriteKit

// Exploration : routage des taps, interactions avec les PNJ du village.
// Extrait de GameManager.swift (découpage du monolithe).
@MainActor
extension GameManager {
    // MARK: - Exploration Tap Routing

    func handleExplorationTap(_ point: CGPoint, in scene: SKScene) {
        let wp = world.worldNode.convert(point, from: scene)

        if activeInterior != nil {
            if tryInteriorInteraction(wp, in: scene) { return }
            tapAndMove(point, in: scene)
            return
        }

        if inMines {
            if tryMinesInteraction(wp, in: scene) { return }
            tapAndMove(point, in: scene)
            return
        }

        if inDesert {
            if tryDesertInteraction(wp, in: scene) { return }
            tapAndMove(point, in: scene)
            return
        }

        if inCave {
            if tryCaveInteraction(wp, in: scene) { return }
            tapAndMove(point, in: scene)
            return
        }

        if inForest {
            if tryForestInteraction(wp, in: scene) { return }
            tapAndMove(point, in: scene)
            return
        }

        if trySaveCrystalTap(wp, in: scene) { return }

        switch phase {
        case .wake:
            return

        case .village:
            if tryVillageInteraction(wp, in: scene) { return }
            tapAndMove(point, in: scene)

        case .forest:
            if tryForestInteraction(wp, in: scene) { return }
            tapAndMove(point, in: scene)

        case .shrine:
            let exit = ShrinePOI.exit.scaled(w: scene.size.width, h: scene.size.height)
            let gate = ShrinePOI.gate.scaled(w: scene.size.width, h: scene.size.height)
            let kaelPos = world.kael.position
            // Sortie ouest → retour forêt (le joueur n'est plus coincé).
            if wp.distance(to: exit) < ShrinePOI.exitReach {
                exitShrine()
            } else if trySaveCrystalTap(wp, in: scene) {
                return   // cristal de sauvegarde fonctionnel
            } else if !player.bossDefeated,
                      wp.distance(to: gate) < ShrinePOI.gateReach,
                      kaelPos.distance(to: gate) < ShrinePOI.gateReach {
                // Même condition que la bulle « A · Combattre » : on vise la
                // porte ET on est devant. Ailleurs sur l'écran, on marche.
                startBossFight()
            } else {
                tapAndMove(point, in: scene)
            }

        case .complete:
            tapAndMove(point, in: scene)

        case .act2:
            if tryAct2VillageInteraction(wp, in: scene) { return }
            tapAndMove(point, in: scene)

        case .ruins:
            if tryRuinsInteraction(wp, in: scene) { return }
            tapAndMove(point, in: scene)

        case .fallen:
            break

        case .act3:
            if tryAct3Interaction(wp, in: scene) { return }
            tapAndMove(point, in: scene)

        case .act4:
            if tryAct4Interaction(wp, in: scene) { return }
            tapAndMove(point, in: scene)
        }
    }

    /// Le cristal vit en espace monde ; `point` est déjà converti en coords
    /// monde par l'appelant. La recherche dans la scène reste en repli pour
    /// les sauvegardes de zones construites avant la bascule.
    func trySaveCrystalTap(_ point: CGPoint, in scene: SKScene) -> Bool {
        guard let crystal = world.worldNode.childNode(withName: "saveCrystal")
                ?? scene.childNode(withName: "saveCrystal") else { return false }
        guard point.distance(to: crystal.position) < 55 else { return false }
        triggerManualSave(crystalPosition: crystal.position, in: scene)
        return true
    }

    func triggerManualSave(crystalPosition: CGPoint, in scene: SKScene) {
        player.currentHP = player.currentMaxHP   // Restauration complète au cristal
        saveGame()
        // Flash bleu sur le cristal
        JuiceEngine.flashOverlay(in: scene, size: scene.size,
                                 color: SKColor(red: 0.40, green: 0.70, blue: 1.0, alpha: 1),
                                 duration: 0.25)
        JuiceEngine.screenShake(scene, intensity: 2)
        // Particules de save
        scene.addChild(ParticleFactory.impactSparks(
            at: crystalPosition,
            color: SKColor(red: 0.60, green: 0.85, blue: 1.0, alpha: 1),
            count: 14
        ))
        // Dialogue de confirmation
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.saveCrystalDialogue) { [weak self] in
            self?.transition(to: .exploration)
        }
    }

    // MARK: - Village NPC interactions

    func tryVillageInteraction(_ point: CGPoint, in scene: SKScene) -> Bool {
        if tryHouseDoorInteraction(point, in: scene) { return true }

        let radius: CGFloat = 32
        // PNJ candidats : on choisit le PLUS PROCHE dans le rayon (et non le
        // premier rencontré) pour éviter qu'un tap entre deux PNJ proches en
        // déclenche un autre que celui visé.
        let candidates: [(node: SKNode, action: () -> Void)] = [
            (world.dorin,    { [weak self] in self?.openDorinDialogue(scene: scene) }),
            (world.lyra,     { [weak self] in self?.openLyraDialogue() }),
            (world.bram,     { [weak self] in self?.openBramShop() }),
            (world.mara,     { [weak self] in self?.openMaraInteraction(scene: scene) }),
            (world.garen,    { [weak self] in self?.openGarenDialogue() }),
            (world.sage,     { [weak self] in self?.openSageDialogue() }),
            (world.child,    { [weak self] in self?.openChildDialogue() }),
            (world.villager, { [weak self] in self?.openVillagerDialogue() })
        ]
        if let action = nearestInteraction(from: point, candidates: candidates, radius: radius) {
            action()
            return true
        }
        return false
    }

    func tryHouseDoorInteraction(_ point: CGPoint, in scene: SKScene) -> Bool {
        let doors: [(HouseInteriorKind, CGFloat)] = [
            (.armory, 48), (.apothecary, 44), (.inn, 44)
        ]
        for (kind, radius) in doors {
            let door = world.houseDoorPosition(for: kind, in: scene.size)
            if point.distance(to: door) < radius {
                enterHouse(kind, in: scene)
                return true
            }
        }
        return false
    }

    func enterHouse(_ kind: HouseInteriorKind, in scene: SKScene) {
        activeInterior = kind
        AudioEngine.shared.setMood(.inn)
        transition(to: .transition)
        TransitionManager.fade(in: scene) { [weak self] in
            guard let self else { return }
            world.switchToInterior(kind, in: scene)
            hud.objectiveText = interiorObjective(for: kind)
        } completion: { [weak self] in
            self?.transition(to: .exploration)
        }
    }

    func leaveHouse(in scene: SKScene) {
        AudioEngine.shared.setMood(.forPhase(phase))
        transition(to: .transition)
        TransitionManager.fade(in: scene) { [weak self] in
            guard let self else { return }
            world.returnToVillageFromInterior(in: scene)
            hud.objectiveText = phase == .act2
                ? String(localized: "hud.objective.act2")
                : String(localized: "hud.objective.village")
            activeInterior = nil
        } completion: { [weak self] in
            self?.transition(to: .exploration)
        }
    }

    func tryInteriorInteraction(_ point: CGPoint, in scene: SKScene) -> Bool {
        guard let activeInterior else { return false }
        if point.distance(to: world.interiorExitPosition(in: scene.size)) < 72 {
            leaveHouse(in: scene)
            return true
        }

        let servicePoint = CGPoint(x: scene.size.width * 0.50, y: scene.size.height * 0.62)
        if point.distance(to: servicePoint) < 105 {
            switch activeInterior {
            case .armory:
                openBramShop()
            case .apothecary:
                openMaraInteraction(scene: scene)
            case .inn:
                openSageDialogue()
            }
            return true
        }
        return false
    }

    func interiorObjective(for kind: HouseInteriorKind) -> String {
        switch kind {
        case .armory:
            return String(localized: "hud.objective.interior.armory")
        case .apothecary:
            return String(localized: "hud.objective.interior.apothecary")
        case .inn:
            return String(localized: "hud.objective.interior.inn")
        }
    }
}
