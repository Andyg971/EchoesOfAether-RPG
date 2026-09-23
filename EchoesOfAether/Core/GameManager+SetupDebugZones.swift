import SpriteKit

// Mise en place — arguments de lancement de debug, seconde moitié : audit
// visuel d'une zone (`--zone-*`, `--cam-y`, `--interior`, `--bubble-test`).
@MainActor
extension GameManager {
    /// Renvoie `true` si un argument a placé Kael dans une zone pour audit.
    func applyDebugZoneArguments(scene: SKScene) -> Bool {
        // `--cam-y <frac>` : fraction de hauteur MONDE où poser Kael pour
        // l'audit d'une zone qui scrolle (la caméra le suit). Chaque zone
        // relisait les arguments à sa façon — le désert et les mines
        // l'ignoraient tout court : tout ce qui vivait au nord de l'écran
        // d'entrée était invisible à l'inspection.
        func camYFraction(default def: Double) -> Double {
            if let idx = launchArguments.firstIndex(of: "--cam-y"),
               launchArguments.indices.contains(idx + 1),
               let f = Double(launchArguments[idx + 1]) {
                return f
            }
            return def
        }

        // Visualisation pure d'une zone (sans combat), pour audit UI.
        if launchArguments.contains("--zone-forest") {
            hud.goldValue = player.gold
            phase = .forest
            showForest(in: scene)
            addSideQuestMarkers(in: scene)
            transition(to: .exploration)
            world.kael.position = CGPoint(
                x: scene.size.width * 0.5,
                y: world.worldHeight * camYFraction(default: 0.05))
            world.refreshKaelDepth()
            return true
        }
        if launchArguments.contains("--zone-mines") {
            hud.goldValue = player.gold
            phase = .forest
            inMines = true
            hud.objectiveText = String(localized: "hud.objective.mines")
            AudioEngine.shared.setMood(.mines)
            world.switchToMines(in: scene, progress: player.minesProgress,
                                goldTaken: player.minesGoldTaken)
            world.kael.position = CGPoint(
                x: scene.size.width * 0.50,
                y: world.worldHeight * camYFraction(default: 0.05))
            world.refreshKaelDepth()
            spawnMineRoamers()
            transition(to: .exploration)
            return true
        }
        if launchArguments.contains("--zone-cave") {
            hud.goldValue = player.gold
            phase = .forest
            inCave = true
            // --cave-cleared : affiche l'état post-combat (coffre visible)
            if launchArguments.contains("--cave-cleared") {
                player.caveCleared = true
            }
            hud.objectiveText = String(localized: "hud.objective.cave")
            world.switchToCave(in: scene, cleared: player.caveCleared,
                               chestTaken: player.caveChestTaken)
            world.kael.position = CGPoint(x: scene.size.width * 0.50,
                                          y: scene.size.height * 0.14)
            spawnCaveRoamer()
            transition(to: .exploration)
            return true
        }
        if launchArguments.contains("--zone-desert") {
            hud.goldValue = player.gold
            phase = .forest
            inDesert = true
            hud.objectiveText = String(localized: "hud.objective.desert")
            AudioEngine.shared.setMood(.tense)
            world.switchToDesert(in: scene, progress: player.desertProgress,
                                 chestTaken: player.desertChestTaken)
            world.kael.position = CGPoint(
                x: scene.size.width * 0.50,
                y: world.worldHeight * camYFraction(default: 0.05))
            world.refreshKaelDepth()
            spawnDesertRoamers()
            transition(to: .exploration)
            return true
        }
        if launchArguments.contains("--zone-overworld") {
            hud.goldValue = player.gold
            inOverworld = true
            world.switchToOverworld(in: scene)
            // `--overworld-at <lieu>` : apparaître sur un lieu canonique
            // (desert, mines, ruins…) au lieu de la plaine de départ. La carte
            // fait 2,7 écrans de large — sans ça, auditer le désert demandait
            // de traverser le continent au joystick.
            var spawn = CGPoint(x: world.worldWidth * 0.20,
                                y: world.worldHeight * 0.24)
            if let idx = launchArguments.firstIndex(of: "--overworld-at"),
               launchArguments.indices.contains(idx + 1) {
                spawn = WorldBuilder.overworldPoint(launchArguments[idx + 1],
                                                    w: world.worldWidth,
                                                    h: world.worldHeight)
            }
            world.kael.position = spawn
            world.kael.isHidden = false
            world.refreshKaelDepth()
            world.snapCamera()
            spawnOverworldRoamers()
            world.addOverworldChests(taken: player.overworldChestsTaken, in: scene)
            transition(to: .exploration)
            return true
        }
        if launchArguments.contains("--zone-shrine") {
            hud.goldValue = player.gold
            phase = .shrine
            world.switchToShrine(in: scene)
            transition(to: .exploration)
            return true
        }
        // Audit de la cinématique de la mort de Lyra : ruines + compagne,
        // la scène se déclenche seule après une seconde.
        if launchArguments.contains("--lyra-death") {
            hud.goldValue = player.gold
            phase = .ruins
            showRuins(in: scene)
            world.showLyraCompanion()
            transition(to: .exploration)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.triggerLyraDeath()
            }
            return true
        }
        if launchArguments.contains("--zone-ruins") {
            hud.goldValue = player.gold
            phase = .ruins
            showRuins(in: scene)
            transition(to: .exploration)
            return true
        }
        // Audit visuel des intérieurs : --interior armory|apothecary|inn
        if let idx = launchArguments.firstIndex(of: "--interior"),
           launchArguments.indices.contains(idx + 1) {
            let kind: HouseInteriorKind? = switch launchArguments[idx + 1] {
            case "armory": .armory
            case "apothecary": .apothecary
            case "inn": .inn
            default: nil
            }
            if let kind {
                hud.goldValue = player.gold
                phase = .village
                enterHouse(kind, in: scene)
                return true
            }
        }
        if launchArguments.contains("--combat-trio") {
            hud.goldValue = player.gold
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard let self, let scene = self.scene else { return }
                self.phase = .act3
                self.player.act3EchoJoined = true
                self.player.act3EranMet = true
                self.showThreshold(in: scene)
                self.startVoidShadesCombat()
            }
            return true
        }
        if launchArguments.contains("--zone-voidheart") {
            hud.goldValue = player.gold
            phase = .act4
            showVoidHeart(in: scene)
            transition(to: .exploration)
            return true
        }
        if launchArguments.contains("--zone-threshold") {
            hud.goldValue = player.gold
            phase = .act3
            showThreshold(in: scene)
            transition(to: .exploration)
            return true
        }
        // Audit visuel du village : --zone-village [--cam-y 0.5] place Kael
        // à la fraction de hauteur demandée (la caméra le suit).
        if launchArguments.contains("--zone-village") {
            hud.goldValue = player.gold
            phase = .village
            transition(to: .exploration)
            if launchArguments.contains("--cam-y") {
                // Différé : le `layout()` initial (GameScene.didMove) replace
                // Kael sur le plan du village juste après ce handler — le
                // placement d'audit doit passer en dernier.
                let frac = camYFraction(default: 0.05)
                DispatchQueue.main.async { [weak self] in
                    guard let self, let scene = self.scene else { return }
                    world.kael.position = CGPoint(
                        x: scene.size.width * 0.5,
                        y: world.worldHeight * CGFloat(frac))
                    world.refreshKaelDepth()
                }
            }
            return true
        }
        // Debug : place Kael près de Lyra dans le village pour audit
        // immédiat de la bulle d'interaction.
        if launchArguments.contains("--bubble-test") {
            hud.goldValue = player.gold
            phase = .village
            transition(to: .exploration)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self else { return }
                // Lyra est à (w*0.20, h*0.58) — placer Kael 50pt en dessous
                let target = CGPoint(x: self.world.lyra.position.x,
                                      y: self.world.lyra.position.y - 50)
                self.world.kael.position = target
            }
            return true
        }
        return false
    }
}
