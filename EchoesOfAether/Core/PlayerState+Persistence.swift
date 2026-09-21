import SpriteKit

// PlayerState — sérialisation vers SaveData, chargement, graine de New Game+.
extension PlayerState {
    // MARK: - Save / Load

    func toSaveData(phase: GamePhase, resonance: Int) -> SaveData {
        SaveData(
            gold: gold, maxHP: maxHP,
            weaponLevel: weaponLevel, armorLevel: armorLevel,
            potions: potions, aetherShards: aetherShards,
            level: level, xp: xp,
            skillRanks: skillRanks,
            questDelivery: questDelivery, questMushroom: questMushroom,
            questLyraShards: questLyraShards, questChildToy: questChildToy,
            questMedallion: questMedallion,
            questBramOre: questBramOre,
            questSageHerb: questSageHerb,
            questGarenScout: questGarenScout,
            questMines: questMines,
            minesProgress: minesProgress,
            minesGoldTaken: minesGoldTaken,
            questDesert: questDesert,
            desertProgress: desertProgress,
            desertChestTaken: desertChestTaken,
            caveCleared: caveCleared,
            caveChestTaken: caveChestTaken,
            overworldChestsTaken: Array(overworldChestsTaken),
            equippedAccessory: equippedAccessory,
            talkedToSage: talkedToSage, talkedToChild: talkedToChild,
            talkedToVillager: talkedToVillager, innRested: innRested,
            forestProgress: forestProgress, bossDefeated: bossDefeated,
            lyraDeceased: lyraDeceased,
            act2SageConsulted: act2SageConsulted,
            act2Returned: act2Returned,
            ruinsProgress: ruinsProgress,
            act2DorinPassed: act2DorinPassed,
            act2NightmareSeen: act2NightmareSeen,
            act2Vision1Seen: act2Vision1Seen,
            act2EranFound: act2EranFound,
            kaelCorruptionLevel: kaelCorruptionLevel,
            kaelChoseCorruption: kaelChoseCorruption,
            loreDiscovered: Array(loreDiscovered),
            act3EranMet: act3EranMet,
            act3BossDefeated: act3BossDefeated,
            act3EndingChoice: act3EndingChoice,
            bestiarySeen: Array(bestiarySeen),
            act3EchoJoined: act3EchoJoined,
            act3SpiritsCalmed: Array(act3SpiritsCalmed),
            act3StelesRead: Array(act3StelesRead),
            act3ShadesDefeated: act3ShadesDefeated,
            act4MemoriesSeen: Array(act4MemoriesSeen),
            act4ReflectionsFreed: Array(act4ReflectionsFreed),
            act4DevourersDefeated: act4DevourersDefeated,
            act4VoiceConfronted: act4VoiceConfronted,
            act4BossDefeated: act4BossDefeated,
            act4EndingChoice: act4EndingChoice,
            newGamePlus: newGamePlus,
            savedAt: Date(),
            phase: phase, resonanceTotal: resonance
        )
    }

    func load(from data: SaveData) {
        gold = data.gold
        maxHP = data.maxHP
        weaponLevel = data.weaponLevel
        armorLevel = data.armorLevel
        potions = data.potions
        aetherShards = data.aetherShards
        // Saves antérieurs au système de niveau : repart à L1/0
        level = max(1, min(Self.maxLevel, data.level ?? 1))
        xp = max(0, data.xp ?? 0)
        // Saves antérieurs à l'Arbre de l'Aether : aucun point investi. Les
        // rangs sont bornés au chargement pour qu'un save trafiqué ou un
        // nœud rééquilibré à la baisse ne donne pas de bonus fantôme.
        skillRanks = (data.skillRanks ?? [:]).reduce(into: [String: Int]()) { acc, entry in
            guard let node = SkillTree.node(id: entry.key), entry.value > 0 else { return }
            acc[entry.key] = min(entry.value, node.maxRank)
        }
        questDelivery = data.questDelivery
        questMushroom = data.questMushroom
        questLyraShards = data.questLyraShards
        questChildToy = data.questChildToy
        questMedallion = data.questMedallion ?? .inactive
        questBramOre = data.questBramOre ?? .inactive
        questSageHerb = data.questSageHerb ?? .inactive
        questGarenScout = data.questGarenScout ?? .inactive
        questMines = data.questMines ?? .inactive
        minesProgress = data.minesProgress ?? 0
        minesGoldTaken = data.minesGoldTaken ?? false
        questDesert = data.questDesert ?? .inactive
        desertProgress = data.desertProgress ?? 0
        desertChestTaken = data.desertChestTaken ?? false
        desertOasisUsed = false
        caveCleared = data.caveCleared ?? false
        caveChestTaken = data.caveChestTaken ?? false
        overworldChestsTaken = Set(data.overworldChestsTaken ?? [])
        equippedAccessory = data.equippedAccessory
        talkedToSage = data.talkedToSage
        talkedToChild = data.talkedToChild
        talkedToVillager = data.talkedToVillager
        innRested = data.innRested
        forestProgress = data.forestProgress
        bossDefeated = data.bossDefeated
        lyraDeceased = data.lyraDeceased
        act2SageConsulted = data.act2SageConsulted
        // Saves antérieures au retour à pied : l'ancien beginAct2 posait
        // act2SageConsulted dès l'entrée en Acte II → on considère Solis
        // déjà regagné pour ne pas rejouer l'arrivée.
        act2Returned = data.act2Returned ?? data.act2SageConsulted
        ruinsProgress = data.ruinsProgress
        act2DorinPassed = data.act2DorinPassed
        act2NightmareSeen = data.act2NightmareSeen
        act2Vision1Seen = data.act2Vision1Seen
        act2EranFound = data.act2EranFound
        kaelCorruptionLevel = data.kaelCorruptionLevel
        kaelChoseCorruption = data.kaelChoseCorruption ?? false
        loreDiscovered = Set(data.loreDiscovered)
        act3EranMet = data.act3EranMet ?? false
        act3BossDefeated = data.act3BossDefeated ?? false
        act3EndingChoice = data.act3EndingChoice
        bestiarySeen = Set(data.bestiarySeen ?? [])
        act3EchoJoined = data.act3EchoJoined ?? false
        act3SpiritsCalmed = Set(data.act3SpiritsCalmed ?? [])
        act3StelesRead = Set(data.act3StelesRead ?? [])
        act3ShadesDefeated = data.act3ShadesDefeated ?? false
        act4MemoriesSeen = Set(data.act4MemoriesSeen ?? [])
        act4ReflectionsFreed = Set(data.act4ReflectionsFreed ?? [])
        act4DevourersDefeated = data.act4DevourersDefeated ?? false
        act4VoiceConfronted = data.act4VoiceConfronted ?? false
        act4BossDefeated = data.act4BossDefeated ?? false
        act4EndingChoice = data.act4EndingChoice
        newGamePlus = data.newGamePlus ?? 0
        currentHP = currentMaxHP   // toujours plein au chargement
    }

    /// Applique une graine New Game+ à un état FRAÎCHEMENT initialisé :
    /// on garde les acquis (niveau, or, équipement), tout le reste (quêtes,
    /// actes, progression) reste à sa valeur de départ.
    func applyNewGamePlusSeed(_ seed: NewGamePlusSeed) {
        level = max(1, min(Self.maxLevel, seed.level))
        xp = max(0, seed.xp)
        gold = seed.gold
        weaponLevel = seed.weaponLevel
        armorLevel = seed.armorLevel
        potions = seed.potions
        aetherShards = seed.aetherShards
        newGamePlus = seed.newGamePlus
        skillRanks = seed.skillRanks.reduce(into: [String: Int]()) { acc, entry in
            guard let node = SkillTree.node(id: entry.key), entry.value > 0 else { return }
            acc[entry.key] = min(entry.value, node.maxRank)
        }
        currentHP = currentMaxHP
    }
}
