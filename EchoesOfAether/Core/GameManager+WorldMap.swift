import SpriteKit

// Carte du monde : ouverture, voyage, retour.
// Extrait de GameManager.swift (découpage du monolithe).
@MainActor
extension GameManager {
    // MARK: - Carte du monde

    /// Le voyage n'a de sens que dans les phases « libres » : la forêt et
    /// le village post-sanctuaire. Jamais depuis une excursion (mines) ni
    /// un intérieur — sauf pour revenir du désert.
    var worldMapAvailable: Bool {
        if inOverworld { return true }    // sur la carte : bouton = voyage rapide
        if inDesert { return true }
        guard !inMines, activeInterior == nil else { return false }
        return [.forest, .complete, .act2].contains(phase)
    }

    /// Identifiant carte de la zone où se trouve Kael.
    var currentPlaceID: String {
        if inDesert { return "desert" }
        if inMines { return "mines" }
        if inForest { return "forest" }
        switch phase {
        case .wake, .village, .complete, .act2, .fallen: return "village"
        case .forest: return "forest"
        case .shrine: return "shrine"
        case .ruins: return "ruins"
        case .act3: return "threshold"
        case .act4: return "voidheart"
        }
    }

    func openWorldMap() {
        guard state == .exploration, worldMapAvailable else { return }
        HapticsEngine.light()
        if inOverworld {
            // Déjà sur la carte explorable : le bouton ouvre le VOYAGE RAPIDE
            // vers un lieu déjà découvert (saut direct dans la zone).
            transition(to: .inventory)   // fige l'exploration derrière l'overlay
            worldMap.open(places: buildMapPlaces()) { [weak self] in
                self?.transition(to: .exploration)
            }
        } else {
            // Dans une zone : on « sort sur la carte du monde » explorable.
            enterOverworld()
        }
    }

    /// Construit l'état des lieux selon la progression de l'histoire.
    /// Un lieu est « ouvert » (entrable sur l'overworld + voyageable en rapide)
    /// quand l'histoire l'a atteint OU qu'on l'a déjà visité. Empêche de sauter
    /// le scénario (ex. entrer au Sanctuaire avant d'avoir fini la forêt).
    func placeDiscovered(_ id: String) -> Bool {
        if discoveredPlaces.contains(id) { return true }
        let reached = phase.rawValue
        switch id {
        case "village":   return true
        case "forest":    return reached >= GamePhase.forest.rawValue
        case "shrine":    return reached >= GamePhase.shrine.rawValue
                                 || player.forestProgress >= 2
        case "mines":     return reached >= GamePhase.forest.rawValue
        case "desert":    return reached >= GamePhase.forest.rawValue
        case "ruins":     return reached >= GamePhase.ruins.rawValue
        case "threshold": return reached >= GamePhase.act3.rawValue
        default:          return false
        }
    }

    func buildMapPlaces() -> [WorldMapPlace] {
        let current = currentPlaceID
        let reached = phase.rawValue
        // Retour depuis le désert : la zone d'origine redevient voyageable.
        let returnID = inDesert ? (phase == .forest ? "forest" : "village") : ""
        let desertTravel = !inDesert && worldMapAvailable

        func placeState(_ id: String, discovered: Bool,
                        travel: Bool) -> WorldMapPlace.State {
            if id == current { return .current }
            // Voyage rapide : tout lieu DÉCOUVERT (progression d'histoire ou
            // déjà visité) est directement voyageable. Sinon « ??? ».
            let known = discovered || discoveredPlaces.contains(id)
            return known ? .available : .hidden
        }

        return [
            WorldMapPlace(id: "village",
                          title: String(localized: "map.place.village"),
                          point: WorldBuilder.overworldLayout["village"] ?? .zero,
                          state: placeState("village", discovered: true,
                                            travel: returnID == "village"),
                          accent: SKColor(red: 0.35, green: 0.65, blue: 0.35, alpha: 1)),
            WorldMapPlace(id: "forest",
                          title: String(localized: "map.place.forest"),
                          point: WorldBuilder.overworldLayout["forest"] ?? .zero,
                          state: placeState("forest",
                                            discovered: reached >= GamePhase.forest.rawValue,
                                            travel: returnID == "forest"),
                          accent: SKColor(red: 0.15, green: 0.42, blue: 0.22, alpha: 1)),
            WorldMapPlace(id: "mines",
                          title: String(localized: "map.place.mines"),
                          point: WorldBuilder.overworldLayout["mines"] ?? .zero,
                          state: placeState("mines",
                                            discovered: reached >= GamePhase.forest.rawValue,
                                            travel: false),
                          accent: SKColor(red: 0.40, green: 0.38, blue: 0.42, alpha: 1)),
            WorldMapPlace(id: "shrine",
                          title: String(localized: "map.place.shrine"),
                          point: WorldBuilder.overworldLayout["shrine"] ?? .zero,
                          state: placeState("shrine",
                                            discovered: reached >= GamePhase.shrine.rawValue,
                                            travel: false),
                          accent: SKColor(red: 0.30, green: 0.55, blue: 0.85, alpha: 1)),
            WorldMapPlace(id: "desert",
                          title: String(localized: "map.place.desert"),
                          point: WorldBuilder.overworldLayout["desert"] ?? .zero,
                          state: placeState("desert",
                                            discovered: reached >= GamePhase.forest.rawValue,
                                            travel: desertTravel),
                          accent: SKColor(red: 0.85, green: 0.66, blue: 0.30, alpha: 1)),
            WorldMapPlace(id: "ruins",
                          title: String(localized: "map.place.ruins"),
                          point: WorldBuilder.overworldLayout["ruins"] ?? .zero,
                          state: placeState("ruins",
                                            discovered: reached >= GamePhase.ruins.rawValue,
                                            travel: false),
                          accent: SKColor(red: 0.55, green: 0.40, blue: 0.75, alpha: 1)),
            WorldMapPlace(id: "threshold",
                          title: String(localized: "map.place.threshold"),
                          point: WorldBuilder.overworldLayout["threshold"] ?? .zero,
                          state: placeState("threshold",
                                            discovered: reached >= GamePhase.act3.rawValue,
                                            travel: false),
                          accent: SKColor(red: 0.35, green: 0.22, blue: 0.55, alpha: 1)),
            WorldMapPlace(id: "voidheart",
                          title: String(localized: "map.place.voidheart"),
                          point: WorldBuilder.overworldLayout["voidheart"] ?? .zero,
                          state: placeState("voidheart",
                                            discovered: reached >= GamePhase.act4.rawValue,
                                            travel: false),
                          accent: SKColor(red: 0.18, green: 0.12, blue: 0.28, alpha: 1))
        ]
    }
}
