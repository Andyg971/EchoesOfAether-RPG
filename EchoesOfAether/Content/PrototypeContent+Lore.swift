import Foundation

// Entrées de lore (clés xcstrings).
// Extrait de PrototypeContent.swift (découpage du monolithe).
extension PrototypeContent {
    // MARK: - Lore entries (noms de clés xcstrings)

    @MainActor
    static func buildLoreEntries(for player: PlayerState) -> [LoreEntry] {
        var entries: [LoreEntry] = []
        if player.loreDiscovered.contains("eran") {
            entries.append(LoreEntry(
                title: String(localized: "lore.eran.title"),
                body: String(localized: "lore.eran.body")
            ))
        }
        if player.loreDiscovered.contains("price") {
            entries.append(LoreEntry(
                title: String(localized: "lore.price.title"),
                body: String(localized: "lore.price.body")
            ))
        }
        if player.loreDiscovered.contains("archivist") {
            entries.append(LoreEntry(
                title: String(localized: "lore.archivist.title"),
                body: String(localized: "lore.archivist.body")
            ))
        }
        if player.loreDiscovered.contains("threshold") {
            entries.append(LoreEntry(
                title: String(localized: "lore.threshold.title"),
                body: String(localized: "lore.threshold.body")
            ))
        }
        if player.loreDiscovered.contains("void") {
            entries.append(LoreEntry(
                title: String(localized: "lore.void.title"),
                body: String(localized: "lore.void.body")
            ))
        }
        if player.loreDiscovered.contains("cendreval") {
            entries.append(LoreEntry(
                title: String(localized: "lore.cendreval.title"),
                body: String(localized: "lore.cendreval.body")
            ))
        }
        if player.loreDiscovered.contains("voidheart") {
            entries.append(LoreEntry(
                title: String(localized: "lore.voidheart.title"),
                body: String(localized: "lore.voidheart.body")
            ))
        }
        if player.loreDiscovered.contains("kaelMemories") {
            entries.append(LoreEntry(
                title: String(localized: "lore.kaelMemories.title"),
                body: String(localized: "lore.kaelMemories.body")
            ))
        }
        if player.loreDiscovered.contains("lostEchoes") {
            entries.append(LoreEntry(
                title: String(localized: "lore.lostEchoes.title"),
                body: String(localized: "lore.lostEchoes.body")
            ))
        }
        if player.loreDiscovered.contains("eranPast") {
            entries.append(LoreEntry(
                title: String(localized: "lore.eranPast.title"),
                body: String(localized: "lore.eranPast.body")
            ))
        }
        return entries
    }
}
