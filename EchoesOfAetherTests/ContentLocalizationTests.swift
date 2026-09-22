import XCTest
@testable import EchoesOfAether

/// TOUT le contenu narratif, pas seulement les dialogues pivots : chaque
/// table de `PrototypeContent` est non vide, chaque texte est résolu (une clé
/// affichée telle quelle = « dialogue.xxx » à l'écran), chaque choix a au
/// moins deux options. Et, en lisant les sources du dépôt quand elles sont
/// là : chaque clé `String(localized:)` du jeu existe dans
/// `Localizable.xcstrings` avec une traduction FR **et** EN non vide — la
/// seule garantie réelle du « zéro string hard-codée ».
///
/// La liste des tables est générée depuis `Content/*.swift` ; le test
/// `test_tableList_isComplete` échoue si une table apparaît sans y être.
final class ContentLocalizationTests: XCTestCase {

    // MARK: - Toutes les tables de dialogues (120)

    private static let tables: [(String, [DialogueStep])] = [
        ("forestGroveDialogue", PrototypeContent.forestGroveDialogue),
        ("forestExitDialogue", PrototypeContent.forestExitDialogue),
        ("blackAetherDialogue", PrototypeContent.blackAetherDialogue),
        ("bossPreDialogue", PrototypeContent.bossPreDialogue),
        ("bossPostDialogue", PrototypeContent.bossPostDialogue),
        ("lyraQuestGiveDialogue", PrototypeContent.lyraQuestGiveDialogue),
        ("lyraQuestActiveDialogue", PrototypeContent.lyraQuestActiveDialogue),
        ("lyraQuestCompleteDialogue", PrototypeContent.lyraQuestCompleteDialogue),
        ("lyraCrystalFoundDialogue", PrototypeContent.lyraCrystalFoundDialogue),
        ("lyraQuestDoneDialogue", PrototypeContent.lyraQuestDoneDialogue),
        ("childQuestDialogue", PrototypeContent.childQuestDialogue),
        ("childQuestActiveDialogue", PrototypeContent.childQuestActiveDialogue),
        ("childQuestDoneDialogue", PrototypeContent.childQuestDoneDialogue),
        ("wakeDialogue", PrototypeContent.wakeDialogue),
        ("lyraVillageDialogue", PrototypeContent.lyraVillageDialogue),
        ("dorinDialogue", PrototypeContent.dorinDialogue),
        ("bramGreeting", PrototypeContent.bramGreeting),
        ("maraFirstMeetDialogue", PrototypeContent.maraFirstMeetDialogue),
        ("maraQuestActiveDialogue", PrototypeContent.maraQuestActiveDialogue),
        ("maraShopGreeting", PrototypeContent.maraShopGreeting),
        ("garenFirstDialogue", PrototypeContent.garenFirstDialogue),
        ("garenDeliveryDialogue", PrototypeContent.garenDeliveryDialogue),
        ("sageFirstDialogue", PrototypeContent.sageFirstDialogue),
        ("sageAfterRestDialogue", PrototypeContent.sageAfterRestDialogue),
        ("act2ReturnVillageDialogue", PrototypeContent.act2ReturnVillageDialogue),
        ("act2LyraAnalysisDialogue", PrototypeContent.act2LyraAnalysisDialogue),
        ("act2SageRevelationDialogue", PrototypeContent.act2SageRevelationDialogue),
        ("bramAct2Dialogue", PrototypeContent.bramAct2Dialogue),
        ("maraAct2Dialogue", PrototypeContent.maraAct2Dialogue),
        ("childAct2Dialogue", PrototypeContent.childAct2Dialogue),
        ("villagerAct2Dialogue", PrototypeContent.villagerAct2Dialogue),
        ("act2DorinDoubtDialogue", PrototypeContent.act2DorinDoubtDialogue),
        ("act2RuinsEnterDialogue", PrototypeContent.act2RuinsEnterDialogue),
        ("act2RuinsCombat1Dialogue", PrototypeContent.act2RuinsCombat1Dialogue),
        ("act2DiscoveryDialogue", PrototypeContent.act2DiscoveryDialogue),
        ("act2CorruptionChoiceDialogue", PrototypeContent.act2CorruptionChoiceDialogue),
        ("act2LyraDeathDialogue", PrototypeContent.act2LyraDeathDialogue),
        ("act2KaelAloneDialogue", PrototypeContent.act2KaelAloneDialogue),
        ("act2KaelAloneResistedDialogue", PrototypeContent.act2KaelAloneResistedDialogue),
        ("act2DorinBlockDialogue", PrototypeContent.act2DorinBlockDialogue),
        ("act2NightmareDialogue", PrototypeContent.act2NightmareDialogue),
        ("act2Vision1Dialogue", PrototypeContent.act2Vision1Dialogue),
        ("act2EranInscriptionDialogue", PrototypeContent.act2EranInscriptionDialogue),
        ("act2ArchivistPreDialogue", PrototypeContent.act2ArchivistPreDialogue),
        ("act2ArchivistPostDialogue", PrototypeContent.act2ArchivistPostDialogue),
        ("act2LyraGiftDialogue", PrototypeContent.act2LyraGiftDialogue),
        ("act2LyraEranLastWordDialogue", PrototypeContent.act2LyraEranLastWordDialogue),
        ("act3PrologueDialogue", PrototypeContent.act3PrologueDialogue),
        ("act3EranMeetDialogue", PrototypeContent.act3EranMeetDialogue),
        ("act3EndingTransitionDialogue", PrototypeContent.act3EndingTransitionDialogue),
        ("act4ThresholdWarningDialogue", PrototypeContent.act4ThresholdWarningDialogue),
        ("act3ResistWarningDialogue", PrototypeContent.act3ResistWarningDialogue),
        ("act3EchoMeetDialogue", PrototypeContent.act3EchoMeetDialogue),
        ("spiritMinerDialogue", PrototypeContent.spiritMinerDialogue),
        ("spiritMotherDialogue", PrototypeContent.spiritMotherDialogue),
        ("spiritGuardDialogue", PrototypeContent.spiritGuardDialogue),
        ("spiritsDoneDialogue", PrototypeContent.spiritsDoneDialogue),
        ("stelesDoneDialogue", PrototypeContent.stelesDoneDialogue),
        ("shadesPreDialogue", PrototypeContent.shadesPreDialogue),
        ("act3EranJoinDialogue", PrototypeContent.act3EranJoinDialogue),
        ("act3GuardianPreDialogue", PrototypeContent.act3GuardianPreDialogue),
        ("act3GuardianPostDialogue", PrototypeContent.act3GuardianPostDialogue),
        ("act3TrueEndingDialogue", PrototypeContent.act3TrueEndingDialogue),
        ("act3ResistEndingDialogue", PrototypeContent.act3ResistEndingDialogue),
        ("act3ResistEpilogueDialogue", PrototypeContent.act3ResistEpilogueDialogue),
        ("act4PrologueDialogue", PrototypeContent.act4PrologueDialogue),
        ("act4MemoriesDoneDialogue", PrototypeContent.act4MemoriesDoneDialogue),
        ("act4ReflectionsDoneDialogue", PrototypeContent.act4ReflectionsDoneDialogue),
        ("act4DevourersPreDialogue", PrototypeContent.act4DevourersPreDialogue),
        ("act4VoiceConfrontDialogue", PrototypeContent.act4VoiceConfrontDialogue),
        ("act4AvatarPreDialogue", PrototypeContent.act4AvatarPreDialogue),
        ("act4AvatarPostDialogue", PrototypeContent.act4AvatarPostDialogue),
        ("act4DestroyChoseDialogue", PrototypeContent.act4DestroyChoseDialogue),
        ("act4DestroyResistedDialogue", PrototypeContent.act4DestroyResistedDialogue),
        ("act4DestroyEndingDialogue", PrototypeContent.act4DestroyEndingDialogue),
        ("act4DestroyEndScreen", PrototypeContent.act4DestroyEndScreen),
        ("act4MergeChoseDialogue", PrototypeContent.act4MergeChoseDialogue),
        ("act4MergeResistedDialogue", PrototypeContent.act4MergeResistedDialogue),
        ("act4MergeEndingDialogue", PrototypeContent.act4MergeEndingDialogue),
        ("act4MergeEndScreen", PrototypeContent.act4MergeEndScreen),
        ("minesEnterDialogue", PrototypeContent.minesEnterDialogue),
        ("minesCombat1PostDialogue", PrototypeContent.minesCombat1PostDialogue),
        ("minesBossPreDialogue", PrototypeContent.minesBossPreDialogue),
        ("minesBossPostDialogue", PrototypeContent.minesBossPostDialogue),
        ("minesInscriptionDialogue", PrototypeContent.minesInscriptionDialogue),
        ("minesGoldDialogue", PrototypeContent.minesGoldDialogue),
        ("desertEnterDialogue", PrototypeContent.desertEnterDialogue),
        ("caveEnterDialogue", PrototypeContent.caveEnterDialogue),
        ("desertCombat1PostDialogue", PrototypeContent.desertCombat1PostDialogue),
        ("desertBossPreDialogue", PrototypeContent.desertBossPreDialogue),
        ("desertBossPostDialogue", PrototypeContent.desertBossPostDialogue),
        ("desertChestDialogue", PrototypeContent.desertChestDialogue),
        ("desertOasisDialogue", PrototypeContent.desertOasisDialogue),
        ("desertAmbushDialogue", PrototypeContent.desertAmbushDialogue),
        ("desertCaravanierDialogue", PrototypeContent.desertCaravanierDialogue),
        ("desertCaravanierResolvedDialogue", PrototypeContent.desertCaravanierResolvedDialogue),
        ("desertMerchantDialogue", PrototypeContent.desertMerchantDialogue),
        ("desertMerchantResolvedDialogue", PrototypeContent.desertMerchantResolvedDialogue),
        ("desertChildDialogue", PrototypeContent.desertChildDialogue),
        ("desertChildResolvedDialogue", PrototypeContent.desertChildResolvedDialogue),
        ("saveCrystalDialogue", PrototypeContent.saveCrystalDialogue),
        ("shrineEnding", PrototypeContent.shrineEnding),
        ("toyFoundDialogue", PrototypeContent.toyFoundDialogue),
        ("childDialogue", PrototypeContent.childDialogue),
        ("villagerQuestOfferDialogue", PrototypeContent.villagerQuestOfferDialogue),
        ("villagerQuestActiveDialogue", PrototypeContent.villagerQuestActiveDialogue),
        ("villagerQuestDoneDialogue", PrototypeContent.villagerQuestDoneDialogue),
        ("medallionFoundDialogue", PrototypeContent.medallionFoundDialogue),
        ("bramOreOfferDialogue", PrototypeContent.bramOreOfferDialogue),
        ("bramOreActiveDialogue", PrototypeContent.bramOreActiveDialogue),
        ("bramOreDoneDialogue", PrototypeContent.bramOreDoneDialogue),
        ("oreFoundDialogue", PrototypeContent.oreFoundDialogue),
        ("sageHerbOfferDialogue", PrototypeContent.sageHerbOfferDialogue),
        ("sageHerbActiveDialogue", PrototypeContent.sageHerbActiveDialogue),
        ("sageHerbDoneDialogue", PrototypeContent.sageHerbDoneDialogue),
        ("herbFoundDialogue", PrototypeContent.herbFoundDialogue),
        ("garenScoutOfferDialogue", PrototypeContent.garenScoutOfferDialogue),
        ("garenScoutActiveDialogue", PrototypeContent.garenScoutActiveDialogue),
        ("garenScoutDoneDialogue", PrototypeContent.garenScoutDoneDialogue),
        ("scoutBadgeFoundDialogue", PrototypeContent.scoutBadgeFoundDialogue)
    ]

    private func texts(of steps: [DialogueStep]) -> [(role: String, text: String)] {
        steps.flatMap { step -> [(String, String)] in
            switch step {
            case let .line(speaker, text):
                return [("speaker", speaker), ("text", text)]
            case let .choice(prompt, options):
                return [("prompt", prompt)] + options.flatMap {
                    [("title", $0.title), ("speaker", $0.responseSpeaker), ("response", $0.response)]
                }
            }
        }
    }

    func test_allTables_nonEmpty() {
        for (name, steps) in Self.tables {
            XCTAssertFalse(steps.isEmpty, "\(name) est vide")
        }
    }

    func test_allTexts_resolvedAndNonEmpty() {
        for (name, steps) in Self.tables {
            for (role, text) in texts(of: steps) {
                XCTAssertFalse(text.trimmingCharacters(in: .whitespaces).isEmpty,
                               "\(name) : \(role) vide")
                XCTAssertFalse(text.hasPrefix("dialogue.") || text.hasPrefix("quest.")
                               || text.hasPrefix("lore."),
                               "\(name) : clé non traduite « \(text) »")
            }
        }
    }

    func test_allChoices_haveAtLeastTwoOptions() {
        for (name, steps) in Self.tables {
            for step in steps {
                if case let .choice(_, options) = step {
                    XCTAssertGreaterThanOrEqual(options.count, 2, "\(name) : choix à moins de 2 options")
                }
            }
        }
    }

    // MARK: - Dialogues paramétrés : le contrat layout ↔ contenu

    /// Les stèles du Seuil et les fragments/reflets du Cœur sont posés par
    /// les layouts avec un id ; le contenu doit répondre à CHAQUE id.
    @MainActor
    func test_parametrizedDialogues_resolveForEveryLayoutId() {
        let size = CGSize(width: 844, height: 390)
        for stele in ThresholdLayout(sceneSize: size).steles {
            for (_, text) in texts(of: PrototypeContent.steleDialogue(Int(stele.id) ?? -1)) {
                XCTAssertFalse(text.hasPrefix("dialogue."), "stèle \(stele.id) : « \(text) »")
            }
        }
        let heart = VoidHeartLayout(sceneSize: size)
        for memory in heart.memories {
            for (_, text) in texts(of: PrototypeContent.act4MemoryDialogue(Int(memory.id) ?? -1)) {
                XCTAssertFalse(text.hasPrefix("dialogue."), "mémoire \(memory.id) : « \(text) »")
            }
        }
        for reflection in heart.reflections {
            for (_, text) in texts(of: PrototypeContent.act4ReflectionDialogue(id: reflection.id)) {
                XCTAssertFalse(text.hasPrefix("dialogue."), "reflet \(reflection.id) : « \(text) »")
            }
        }
    }

    @MainActor
    func test_loreEntries_allResolvedWhenEverythingDiscovered() {
        let player = PlayerState()
        player.loreDiscovered = ["eran", "price", "archivist", "threshold", "void",
                                 "cendreval", "voidheart", "kaelMemories", "lostEchoes", "eranPast"]
        let entries = PrototypeContent.buildLoreEntries(for: player)
        XCTAssertEqual(entries.count, player.loreDiscovered.count, "une entrée par découverte")
        for e in entries {
            XCTAssertFalse(e.title.hasPrefix("lore."), "titre non traduit « \(e.title) »")
            XCTAssertFalse(e.body.hasPrefix("lore."), "corps non traduit « \(e.body) »")
        }
    }

    // MARK: - Sources du dépôt : complétude et FR + EN

    /// Racine du projet, déduite du chemin de ce fichier. `nil` hors du dépôt
    /// (ex. bundle de tests déplacé) : les tests source s'ignorent alors.
    private var repoRoot: URL? {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let catalog = root.appendingPathComponent("EchoesOfAether/Localizable.xcstrings").path
        return FileManager.default.fileExists(atPath: catalog) ? root : nil
    }

    private func swiftSources(under dir: URL) -> [URL] {
        guard let e = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil) else { return [] }
        return e.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }

    func test_tableList_isComplete() throws {
        guard let root = repoRoot else { throw XCTSkip("hors du dépôt") }
        let regex = try NSRegularExpression(pattern: #"static let (\w+): \[DialogueStep\]"#)
        var declared: Set<String> = []
        for file in swiftSources(under: root.appendingPathComponent("EchoesOfAether/Content")) {
            let s = try String(contentsOf: file, encoding: .utf8)
            for m in regex.matches(in: s, range: NSRange(s.startIndex..., in: s)) {
                declared.insert(String(s[Range(m.range(at: 1), in: s)!]))
            }
        }
        let listed = Set(Self.tables.map { $0.0 })
        XCTAssertEqual(declared.subtracting(listed), [],
                       "tables absentes de ContentLocalizationTests.tables — à ajouter")
        XCTAssertEqual(listed.subtracting(declared), [], "tables listées qui n'existent plus")
    }

    /// Chaque clé littérale `String(localized: "…")` du jeu existe dans le
    /// catalogue avec FR et EN non vides. Les clés interpolées
    /// (`"x.y \(n)"`) sont vérifiées par préfixe (`x.y %…`).
    func test_everyLocalizedKey_hasFrenchAndEnglish() throws {
        guard let root = repoRoot else { throw XCTSkip("hors du dépôt") }
        let data = try Data(contentsOf: root.appendingPathComponent("EchoesOfAether/Localizable.xcstrings"))
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try XCTUnwrap(json["strings"] as? [String: Any])

        func translated(_ key: String, _ lang: String) -> Bool {
            guard let entry = strings[key] as? [String: Any],
                  let locs = entry["localizations"] as? [String: Any],
                  let loc = locs[lang] as? [String: Any] else { return false }
            if loc["variations"] != nil { return true }
            let value = (loc["stringUnit"] as? [String: Any])?["value"] as? String ?? ""
            return !value.trimmingCharacters(in: .whitespaces).isEmpty
        }

        // Groupe 1 : la clé littérale ; groupe 2 : `"` (fin) ou `\(` (interpolation).
        let regex = try NSRegularExpression(pattern: #"String\(localized: "([^"\\]*)("|\\\()"#)
        var checked = 0
        var problems: [String] = []
        for file in swiftSources(under: root.appendingPathComponent("EchoesOfAether")) {
            // Les commentaires citent des exemples (`"key \(value)"`) : ignorés.
            let s = try String(contentsOf: file, encoding: .utf8)
                .split(separator: "\n", omittingEmptySubsequences: false)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .joined(separator: "\n")
            for m in regex.matches(in: s, range: NSRange(s.startIndex..., in: s)) {
                let literal = String(s[Range(m.range(at: 1), in: s)!])
                let interpolated = String(s[Range(m.range(at: 2), in: s)!]) != "\""
                let key: String
                if interpolated {
                    let prefix = literal.trimmingCharacters(in: .whitespaces)
                    guard let full = strings.keys.first(where: { $0.hasPrefix(prefix + " %") }) else {
                        problems.append("\(file.lastPathComponent): clé interpolée introuvable « \(prefix) … »")
                        continue
                    }
                    key = full
                } else {
                    key = literal
                }
                checked += 1
                if !translated(key, "fr") { problems.append("\(file.lastPathComponent): « \(key) » sans FR") }
                if !translated(key, "en") { problems.append("\(file.lastPathComponent): « \(key) » sans EN") }
            }
        }
        XCTAssertGreaterThan(checked, 800, "le balayage a trouvé trop peu de clés : regex cassée ?")
        XCTAssertEqual(problems, [], problems.joined(separator: "\n"))
    }
}
