import Foundation

/// Métadonnées légères d'un slot de sauvegarde — pour l'affichage du menu
/// sans avoir à exposer toute la `SaveData`.
struct SaveSlotInfo {
    let phase: GamePhase
    let level: Int
    let gold: Int
}

enum SaveManager {

    /// Nombre de slots de sauvegarde exposés au joueur.
    static let slotCount = 3

    /// Ancien fichier mono-slot (avant l'introduction des slots multiples).
    /// Migré vers le slot 1 au premier lancement s'il existe encore.
    private static let legacyFileName = "echoes_save.json"

    private static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private static func fileName(slot: Int) -> String {
        "echoes_save_\(slot).json"
    }

    private static func fileURL(slot: Int) -> URL {
        documentsURL.appendingPathComponent(fileName(slot: slot))
    }

    private static var legacyURL: URL {
        documentsURL.appendingPathComponent(legacyFileName)
    }

    // MARK: - Migration rétro-compatible

    /// Migre l'ancienne sauvegarde unique vers le slot 1 au premier lancement.
    /// Idempotent : à appeler tôt (ex. depuis le menu principal).
    static func migrateLegacyIfNeeded() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: legacyURL.path) else { return }
        let slot1 = fileURL(slot: 1)
        if fm.fileExists(atPath: slot1.path) {
            // Slot 1 déjà occupé : on retire simplement le legacy.
            try? fm.removeItem(at: legacyURL)
        } else {
            do {
                try fm.moveItem(at: legacyURL, to: slot1)
            } catch {
                #if DEBUG
                print("[SaveManager] legacy migration failed: \(error)")
                #endif
            }
        }
    }

    // MARK: - Save

    static func save(_ data: SaveData, slot: Int) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let json = try encoder.encode(data)
            try json.write(to: fileURL(slot: slot), options: .atomic)
            // Miroir iCloud (Key-Value Store, 1 Mo/clé max — nos saves
            // font quelques Ko). Silencieux si iCloud indisponible.
            NSUbiquitousKeyValueStore.default.set(json, forKey: cloudKey(slot: slot))
        } catch {
            #if DEBUG
            print("[SaveManager] save failed (slot \(slot)): \(error)")
            #endif
        }
    }

    // MARK: - iCloud (Key-Value Store)

    private static func cloudKey(slot: Int) -> String { "echoes_save_\(slot)" }

    /// À l'ouverture du menu : si iCloud possède une sauvegarde plus
    /// récente que le disque (autre appareil), on la rapatrie. Ne touche
    /// jamais à une save locale plus fraîche.
    static func syncFromCloudIfNewer() {
        let store = NSUbiquitousKeyValueStore.default
        store.synchronize()
        for slot in 1...slotCount {
            guard let cloudJSON = store.data(forKey: cloudKey(slot: slot)),
                  let cloudData = try? JSONDecoder().decode(SaveData.self, from: cloudJSON)
            else { continue }
            let cloudDate = cloudData.savedAt ?? .distantPast
            let localDate = load(slot: slot)?.savedAt ?? .distantPast
            if cloudDate > localDate {
                try? cloudJSON.write(to: fileURL(slot: slot), options: .atomic)
                #if DEBUG
                print("[SaveManager] slot \(slot) restauré depuis iCloud (\(cloudDate))")
                #endif
            }
        }
    }

    // MARK: - Load

    static func load(slot: Int) -> SaveData? {
        let url = fileURL(slot: slot)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let json = try Data(contentsOf: url)
            return try JSONDecoder().decode(SaveData.self, from: json)
        } catch {
            #if DEBUG
            print("[SaveManager] load failed (slot \(slot)): \(error)")
            #endif
            return nil
        }
    }

    // MARK: - Delete

    static func delete(slot: Int) {
        try? FileManager.default.removeItem(at: fileURL(slot: slot))
        NSUbiquitousKeyValueStore.default.removeObject(forKey: cloudKey(slot: slot))
    }

    static func hasSave(slot: Int) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(slot: slot).path)
    }

    /// Métadonnées légères pour l'affichage du slot (nil si vide ou illisible).
    static func metadata(slot: Int) -> SaveSlotInfo? {
        guard let data = load(slot: slot) else { return nil }
        return SaveSlotInfo(phase: data.phase,
                            level: data.level ?? 1,
                            gold: data.gold)
    }
}
