import SpriteKit

// Minimap, entrée en Acte III, achat du jeu complet, inventaire.
// Extrait de GameManager.swift (découpage du monolithe).
@MainActor
extension GameManager {
    // MARK: - Minimap

    func updateMinimap() {
        guard let scene else { return }
        let npcs: [(position: CGPoint, color: SKColor)] = [
            (world.lyra.position,    SKColor(red: 0.85, green: 0.65, blue: 1.0, alpha: 1)),
            (world.dorin.position,   SKColor(red: 0.55, green: 0.85, blue: 0.55, alpha: 1)),
            (world.bram.position,    SKColor(red: 1.0,  green: 0.75, blue: 0.3,  alpha: 1)),
            (world.mara.position,    SKColor(red: 1.0,  green: 0.75, blue: 0.3,  alpha: 1)),
            (world.garen.position,   SKColor(red: 0.5,  green: 0.8,  blue: 1.0,  alpha: 1)),
            (world.sage.position,    SKColor(red: 0.5,  green: 0.8,  blue: 1.0,  alpha: 1))
        ].filter { !$0.position.equalTo(.zero) }
        let worldSize = CGSize(width: scene.size.width,
                               height: world.worldHeight > 0 ? world.worldHeight : scene.size.height)
        minimap.update(kaelPosition: world.kael.position,
                       sceneSize: worldSize,
                       npcs: npcs)
    }

    // MARK: - Act III

    func tryAct3Interaction(_ point: CGPoint, in scene: SKScene) -> Bool {
        let plan = ThresholdLayout(sceneSize: scene.size)
        let gate = plan.portal   // sommet du couloir = Le Seuil

        // 0) L'Écho de Lyra attend à l'entrée — première rencontre
        if !player.act3EchoJoined,
           let echoPos = world.thresholdEchoPosition,
           point.distance(to: echoPos) < 70 {
            openAct3EchoMeet()
            return true
        }

        // Esprits errants (quête « Les échos égarés »)
        for id in ["miner", "mother", "guard"]
        where !player.act3SpiritsCalmed.contains(id) {
            if let pos = world.spiritPosition(id: id),
               point.distance(to: pos) < 60 {
                openSpiritDialogue(id: id)
                return true
            }
        }

        // Stèles du Vide, au fond de leurs alcôves
        for stele in plan.steles where !player.act3StelesRead.contains(stele.id) {
            if point.distance(to: stele.pos) < 55 {
                openSteleDialogue(id: stele.id)
                return true
            }
        }

        // Les Ombres du Vide chargent Kael (cf. spawnAct3Roamers) : plus de
        // combat au tap.

        // 1) Rencontre Eran sur son palier tant qu'elle n'a pas eu lieu
        if !player.act3EranMet {
            if point.distance(to: plan.eran) < 80 {
                openAct3EranMeet()
                return true
            }
            return false
        }
        // 2) Gardien du Seuil — combat final
        if !player.act3BossDefeated {
            if point.distance(to: gate) < 90 {
                startThresholdBoss()
                return true
            }
            return false
        }
        // 3) Boss vaincu → franchir le Seuil (vraie fin)
        if point.distance(to: gate) < 90 {
            showAct3TrueEnding()
            return true
        }
        return false
    }

    // MARK: - Achat du jeu complet

    /// L'Acte I est gratuit ; la suite est derrière l'achat.
    var isFullGameUnlocked: Bool { StoreManager.shared.isUnlocked }

    /// Point d'entrée unique du mur d'achat. `onUnlocked` n'est appelé que si
    /// le joueur possède (ou vient d'acheter) le jeu complet ; sinon le joueur
    /// reste libre dans l'Acte I et pourra racheter depuis le menu Pause.
    func requireFullGame(onUnlocked: @escaping () -> Void) {
        guard !isFullGameUnlocked else { onUnlocked(); return }
        pendingUnlockAction = onUnlocked
        openPaywall()
    }

    func openPaywall() {
        guard scene != nil else { return }
        transition(to: .shop)   // même verrouillage d'entrées qu'une boutique
        paywall.open()
    }

    func dismissPaywall() {
        paywall.hide()
        pendingUnlockAction = nil
        transition(to: .exploration)
    }

    func buyFullGame() {
        paywall.refreshTexts()
        Task { [weak self] in
            guard let self else { return }
            do {
                let unlocked = try await StoreManager.shared.purchase()
                paywall.refreshTexts()
                if unlocked {
                    completeUnlock()
                } else {
                    // Annulation ou achat en attente : aucun message d'échec,
                    // le joueur n'a rien fait de mal.
                    paywall.showStatus("")
                }
            } catch {
                paywall.showStatus(String(localized: "paywall.status.failed"))
                HapticsEngine.error()
            }
        }
    }

    func restorePurchases() {
        paywall.showStatus(String(localized: "paywall.status.restoring"))
        Task { [weak self] in
            guard let self else { return }
            do {
                try await StoreManager.shared.restore()
                if StoreManager.shared.isUnlocked {
                    completeUnlock()
                } else {
                    paywall.showStatus(String(localized: "paywall.status.nothingToRestore"))
                }
            } catch {
                paywall.showStatus(String(localized: "paywall.status.failed"))
            }
        }
    }

    /// Achat/restauration réussis : on ferme le mur et on reprend exactement
    /// là où le joueur voulait aller.
    func completeUnlock() {
        AudioEngine.shared.playPurchase()
        HapticsEngine.success()
        paywall.hide()
        let resume = pendingUnlockAction
        pendingUnlockAction = nil
        if let resume {
            resume()
        } else {
            transition(to: .exploration)
        }
    }

    // MARK: - Inventory

    func openInventory() {
        guard state == .exploration else { return }
        transition(to: .inventory)
        inventory.onUsePotion = { [weak self] in self?.useHealthPotion() ?? false }
        inventory.open(player: player) { [weak self] in
            self?.transition(to: .exploration)
        }
    }

    /// Boit une potion en exploration : soigne 40 % des PV max. Renvoie true
    /// si une potion a effectivement été consommée (fiole dispo ET PV non
    /// pleins) — le HUD se rafraîchit tout seul depuis `player` dans update().
    @discardableResult
    func useHealthPotion() -> Bool {
        guard player.potions > 0, player.currentHP < player.currentMaxHP else {
            return false
        }
        player.potions -= 1
        let heal = Int(CGFloat(player.currentMaxHP) * 0.40)
        player.currentHP = min(player.currentMaxHP, player.currentHP + heal)
        AudioEngine.shared.playSelect()
        return true
    }
}
