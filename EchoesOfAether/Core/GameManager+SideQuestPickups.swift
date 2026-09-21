import SpriteKit

// Ramassages de quêtes annexes : talisman, fer, herbe, insigne, cristal.
extension GameManager {
    /// Ramassage du talisman (quête villageoise) — récompense immédiate.
    func pickupMedallion() {
        guard let scene else { return }
        player.questMedallion = .complete
        player.gold += 60
        syncGold()
        hud.questText = ""
        AudioEngine.shared.playQuestComplete()
        world.removeMedallionMarker()
        let wh = world.worldHeight > 0 ? world.worldHeight : scene.size.height
        let spot = CGPoint(x: scene.size.width * 0.28, y: wh * 0.72)
        world.worldNode.addChild(ParticleFactory.impactSparks(
            at: spot, color: Palette.goldWorld, count: 12))
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.medallionFoundDialogue) { [weak self] in
            self?.transition(to: .exploration)
        }
    }

    /// Ramassage du fer corrompu (quête de Bram) — récompense immédiate.
    func pickupOre() {
        guard let scene else { return }
        player.questBramOre = .complete
        player.gold += 90
        syncGold()
        hud.questText = ""
        AudioEngine.shared.playQuestComplete()
        world.removeOreMarker()
        let wh = world.worldHeight > 0 ? world.worldHeight : scene.size.height
        let spot = CGPoint(x: scene.size.width * 0.40, y: wh * 0.63)
        world.worldNode.addChild(ParticleFactory.impactSparks(
            at: spot, color: SKColor(red: 0.55, green: 0.30, blue: 0.85, alpha: 1), count: 12))
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.oreFoundDialogue) { [weak self] in
            self?.transition(to: .exploration)
        }
    }

    /// Cueillette de l'herbe lunaire (quête de Sage) — or + soin complet.
    func pickupHerb() {
        guard let scene else { return }
        player.questSageHerb = .complete
        player.gold += 50
        player.currentHP = player.currentMaxHP   // son parfum seul redonne des forces
        syncGold()
        hud.questText = ""
        AudioEngine.shared.playQuestComplete()
        world.removeHerbMarker()
        let wh = world.worldHeight > 0 ? world.worldHeight : scene.size.height
        let spot = CGPoint(x: scene.size.width * 0.12, y: wh * 0.40)
        world.worldNode.addChild(ParticleFactory.impactSparks(
            at: spot, color: SKColor(red: 0.70, green: 0.95, blue: 0.85, alpha: 1), count: 12))
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.herbFoundDialogue) { [weak self] in
            self?.transition(to: .exploration)
        }
    }

    /// Découverte de l'insigne de Tomm (quête de Garen) — beat sombre.
    func pickupScoutBadge() {
        guard let scene else { return }
        player.questGarenScout = .complete
        player.gold += 70
        syncGold()
        hud.questText = ""
        AudioEngine.shared.playQuestComplete()
        world.removeBadgeMarker()
        let wh = world.worldHeight > 0 ? world.worldHeight : scene.size.height
        let spot = CGPoint(x: scene.size.width * 0.68, y: wh * 0.18)
        world.worldNode.addChild(ParticleFactory.impactSparks(
            at: spot, color: SKColor(red: 0.60, green: 0.70, blue: 0.90, alpha: 1), count: 10))
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.scoutBadgeFoundDialogue) { [weak self] in
            self?.transition(to: .exploration)
        }
    }

    /// Découverte du cristal-mère (quête de Lyra), au cœur mort de la forêt.
    ///
    /// Ne clôt pas la quête : le cristal part dans les mains de Kael, et c'est
    /// Lyra qui en tirera la chute. D'où `.found` et non `.complete`.
    func pickupMotherCrystal() {
        guard let scene else { return }
        player.questLyraShards = .found
        hud.questText = ""
        AudioEngine.shared.playQuestComplete()
        world.removeCrystalMarker()
        let wh = world.worldHeight > 0 ? world.worldHeight : scene.size.height
        let spot = CGPoint(x: scene.size.width * 0.78, y: wh * 0.70)
        world.worldNode.addChild(ParticleFactory.impactSparks(
            at: spot, color: SKColor(red: 0.68, green: 0.45, blue: 1.00, alpha: 1), count: 14))
        transition(to: .dialogue)
        dialogue.start(PrototypeContent.lyraCrystalFoundDialogue) { [weak self] in
            self?.transition(to: .exploration)
        }
    }
}
