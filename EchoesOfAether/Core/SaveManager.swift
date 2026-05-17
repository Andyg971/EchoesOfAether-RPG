import Foundation

enum SaveManager {

    private static let fileName = "echoes_save.json"

    private static var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(fileName)
    }

    // MARK: - Save

    static func save(_ data: SaveData) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let json = try encoder.encode(data)
            try json.write(to: fileURL, options: .atomic)
        } catch {
            #if DEBUG
            print("[SaveManager] save failed: \(error)")
            #endif
        }
    }

    // MARK: - Load

    static func load() -> SaveData? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let json = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(SaveData.self, from: json)
        } catch {
            #if DEBUG
            print("[SaveManager] load failed: \(error)")
            #endif
            return nil
        }
    }

    // MARK: - Delete

    static func deleteSave() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    static var hasSave: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }
}
