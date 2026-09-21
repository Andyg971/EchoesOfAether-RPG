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
