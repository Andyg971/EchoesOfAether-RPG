import SpriteKit

// Pause, options, lore, mort et relance.
// Extrait de GameManager.swift (découpage du monolithe).
@MainActor
extension GameManager {
    // MARK: - Pause / Options / Lore

    func openPause() {
        guard state == .exploration || state == .dialogue else { return }
        guard let scene else { return }
        // Le joueur qui a dit « plus tard » doit pouvoir revenir à l'achat.
        pause.showsUnlockButton = !isFullGameUnlocked
        pause.pendingSkillPoints = player.skillPointsAvailable
        pause.show(in: scene)
        pause.resetSelection()
    }

    func closePause() {
        pause.hide()
    }

    func openOptions() {
        guard let scene else { return }
        pause.hide()
        options.show(in: scene)
    }

    /// ARBRE DE L'AETHER, ouvert depuis la pause. À la fermeture on
    /// resynchronise le HUD : investir en PV/Magie change les jauges max.
    func openSkillTree() {
        guard let scene else { return }
        pause.hide()
        skills.onRespec = { [weak self] in self?.performSkillRespec() ?? false }
        skills.onClose = { [weak self] in
            guard let self else { return }
            player.currentHP = min(player.currentHP, player.currentMaxHP)
            syncLevelHUD()
            openPause()
        }
        skills.show(player: player, in: scene)
    }

    /// Refonte à la forge de Bram : débite l'or puis remet les points à zéro.
    /// Retourne false si la bourse ne suit pas (l'overlay affiche le refus).
    func performSkillRespec() -> Bool {
        let cost = SkillTree.respecCost(level: player.level)
        guard player.gold >= cost else { return false }
        player.gold -= cost
        player.respecSkills()
        syncGold()
        syncLevelHUD()
        return true
    }

    func closeOptions() {
        options.hide()
    }

    func openLore() {
        guard state == .exploration else { return }
        // reuse inventory state to block exploration taps; transition() masque
        // aussi la bulle d'interaction et le hint.
        transition(to: .inventory)
        let entries = PrototypeContent.buildLoreEntries(for: player)
        lore.open(entries: entries, bestiarySeen: player.bestiarySeen) { [weak self] in
            self?.transition(to: .exploration)
        }
    }

    func openQuestLog() {
        guard state == .exploration else { return }
        transition(to: .inventory)
        questLog.open(entries: buildQuestEntries()) { [weak self] in
            self?.transition(to: .exploration)
        }
    }

    /// Compile les quêtes visibles (actives + terminées) pour le journal.
    func buildQuestEntries() -> [QuestEntry] {
        let all: [(QuestState, String, String, PixelIcons.Kind)] = [
            (player.questChildToy,   "questlog.toy.title",       "questlog.toy.desc",       .bag),
            (player.questDelivery,   "questlog.delivery.title",  "questlog.delivery.desc",  .bag),
            (player.questLyraShards, "questlog.shards.title",    "questlog.shards.desc",    .gem),
            (player.questMedallion,  "questlog.medallion.title", "questlog.medallion.desc", .coin),
            (player.questBramOre,    "questlog.bramOre.title",   "questlog.bramOre.desc",   .gem),
            (player.questSageHerb,   "questlog.sageHerb.title",  "questlog.sageHerb.desc",  .potion),
            (player.questGarenScout, "questlog.garenScout.title", "questlog.garenScout.desc", .magnifier),
            (player.questMines,      "questlog.mines.title",      "questlog.mines.desc",     .skull),
            (player.questDesert,     "questlog.desert.title",     "questlog.desert.desc",    .skull)
        ]
        let active = all.filter { $0.0 == .active }
        let done   = all.filter { $0.0 == .complete }
        return (active + done).map {
            QuestEntry(title: String(localized: String.LocalizationValue($0.1)),
                       desc: String(localized: String.LocalizationValue($0.2)),
                       state: $0.0, icon: $0.3)
        }
    }

    // MARK: - Death / Retry

    func showDeathScreen() {
        guard let scene else { return }
        death.show(in: scene)
    }

    func retryLastCombat() {
        death.hide()
        player.currentHP = player.currentMaxHP   // full HP on retry
        lastCombatStarter?()
    }
}
