import XCTest
@testable import EchoesOfAether

/// Verrouille la COURBE DE DIFFICULTÉ.
///
/// Ces tests existent à cause d'une vraie régression : l'Archiviste, boss de
/// fin d'Acte II, avait moins de PV (520) que celui de l'Acte I (620). Rien ne
/// l'avait signalé parce que les chiffres vivaient éparpillés dans quatre
/// fichiers de scène. Maintenant qu'ils sont dans `EncounterBalance`, une
/// courbe qui repart à l'envers casse la suite.
@MainActor
final class EncounterBalanceTests: XCTestCase {

    // MARK: - Courbe des boss d'acte

    /// Le cœur du sujet : chaque acte doit demander plus que le précédent.
    func testActBossHPIsStrictlyIncreasing() {
        let hp = EncounterBalance.actBossHP
        XCTAssertEqual(hp.count, 4, "Quatre actes, quatre boss")
        for (i, pair) in zip(hp, hp.dropFirst()).enumerated() {
            XCTAssertLessThan(pair.0, pair.1,
                              "Le boss de l'acte \(i + 2) doit être plus coriace "
                              + "que celui de l'acte \(i + 1) — c'est exactement "
                              + "l'inversion qu'on a laissée passer.")
        }
    }

    /// Le dernier affrontement du jeu doit rester le plus exigeant.
    func testFinalBossIsTheToughest() {
        XCTAssertEqual(EncounterBalance.VoidAvatar.hp,
                       EncounterBalance.actBossHP.max())
    }

    /// La progression doit être sensible sans être brutale : entre deux actes,
    /// un boss gagne au moins 20 % et au plus 90 % de PV.
    func testActBossProgressionStaysWithinReason() {
        for (a, b) in zip(EncounterBalance.actBossHP,
                          EncounterBalance.actBossHP.dropFirst()) {
            let ratio = Double(b) / Double(a)
            XCTAssertGreaterThan(ratio, 1.20, "Marche trop faible : \(a) → \(b)")
            XCTAssertLessThan(ratio, 1.90, "Mur trop raide : \(a) → \(b)")
        }
    }

    // MARK: - Rage

    /// La rage doit s'enclencher assez tôt pour être une phase, pas un baroud
    /// d'honneur. L'Archiviste était à 35 % : le joueur ne la voyait presque
    /// jamais.
    func testEnrageThresholdsLeaveRoomForAPhase() {
        let thresholds: [(String, CGFloat)] = [
            ("Gardien fêlé", EncounterBalance.Guardian.enrageThreshold),
            ("Archiviste", EncounterBalance.Archivist.enrageThreshold),
            ("Gardien du Seuil", EncounterBalance.ThresholdGuardian.enrageThreshold),
            ("Avatar du Vide", EncounterBalance.VoidAvatar.enrageThreshold)
        ]
        for (name, t) in thresholds {
            XCTAssertGreaterThanOrEqual(t, 0.45, "\(name) : rage trop tardive")
            XCTAssertLessThanOrEqual(t, 0.75, "\(name) : rage trop précoce")
        }
    }

    // MARK: - Dégâts contre PV du joueur

    /// Un grand coup de boss ne doit jamais pouvoir tuer Kael en un tour à son
    /// niveau attendu : c'est la règle « des PV, pas des dégâts » — un coup
    /// fatal transforme le combat en loterie.
    func testBossSpecialNeverOneShotsKaelAtExpectedLevel() {
        let cases: [(String, Int, Int)] = [
            ("Gardien fêlé", EncounterBalance.Guardian.specialDamage, 3),
            ("Archiviste", EncounterBalance.Archivist.specialDamage, 10),
            ("Gardien du Seuil", EncounterBalance.ThresholdGuardian.specialDamage, 20),
            ("Avatar du Vide", EncounterBalance.VoidAvatar.specialDamage, 28)
        ]
        for (name, damage, level) in cases {
            let kael = PlayerState()
            kael.level = level
            // Pire cas raisonnable : aucune armure achetée.
            XCTAssertLessThan(Double(damage), Double(kael.currentMaxHP) * 0.5,
                              "\(name) enlève plus de la moitié des PV de Kael "
                              + "au niveau \(level) — c'est une loterie, pas un combat")
        }
    }

    /// Même en mode Vétéran, un grand coup ne doit pas devenir fatal.
    func testBossSpecialSurvivesVeteranScaling() {
        let kael = PlayerState()
        kael.level = 28
        let scaled = Double(EncounterBalance.VoidAvatar.specialDamage)
            * Difficulty.veteran.enemyDamageMultiplier
        XCTAssertLessThan(scaled, Double(kael.currentMaxHP))
    }

    // MARK: - Ennemis ordinaires de fin de partie

    /// Le défaut inverse du précédent : les rencontres ordinaires devenaient
    /// TRIVIALES en fin de jeu. Un ennemi tardif doit encore demander deux
    /// tours, comme une goule d'Acte I en demandait deux.
    func testLateEnemiesStillTakeTwoTurns() {
        let kael = PlayerState()
        kael.level = 28
        kael.weaponLevel = 2
        let perTurn = kael.blackSlashDamage
        for hp in [EncounterBalance.LateEnemy.devourerStrong,
                   EncounterBalance.LateEnemy.devourerSwift] {
            XCTAssertGreaterThan(hp, perTurn,
                                 "Un ennemi d'Acte IV tombe en un seul coup "
                                 + "(\(hp) PV contre \(perTurn) de dégâts)")
        }
    }

    /// … mais pas au point de transformer chaque rencontre en boss.
    func testLateEnemiesDoNotBecomeBosses() {
        let strongest = EncounterBalance.LateEnemy.devourerStrong
        XCTAssertLessThan(strongest, EncounterBalance.actBossHP.min() ?? 0,
                          "Un ennemi ordinaire ne doit pas dépasser le plus "
                          + "faible des boss")
    }

    /// Les ennemis de l'Acte IV doivent rester au-dessus de ceux de l'Acte III.
    func testLateEnemyCurveFollowsTheActs() {
        XCTAssertGreaterThan(EncounterBalance.LateEnemy.devourerStrong,
                             EncounterBalance.LateEnemy.voidShadeStrong)
        XCTAssertGreaterThan(EncounterBalance.LateEnemy.devourerSwift,
                             EncounterBalance.LateEnemy.voidShadeSwift)
    }

    // MARK: - Boss de donjons optionnels

    /// Contenu facultatif : chaque donjon doit rester sous le boss de l'acte
    /// où on l'atteint, sinon le détour devient plus dur que l'histoire.
    ///
    /// La comparaison se fait acte par acte, pas contre le boss le plus
    /// faible du jeu : la Caverne et les mines s'ouvrent depuis la forêt de
    /// l'Acte I, tandis que le désert d'Ossara ne s'atteint que par la CARTE
    /// DU MONDE, donc à partir de l'Acte II. Les mesurer tous à l'aune de
    /// l'Acte I obligerait à brider le désert sans raison.
    func testSideBossesStayBelowTheActTheyBelongTo() {
        // Atteints depuis l'Acte I.
        for hp in [EncounterBalance.SideBoss.ruinsSentinel,
                   EncounterBalance.SideBoss.ashGolem] {
            XCTAssertLessThan(hp, EncounterBalance.Guardian.hp)
        }
        // Atteint par la carte du monde (Acte II et au-delà).
        XCTAssertLessThan(EncounterBalance.SideBoss.sandColossus,
                          EncounterBalance.Archivist.hp)
        // Aucun contenu annexe ne rivalise avec la fin du jeu.
        XCTAssertLessThan(EncounterBalance.SideBoss.sandColossus,
                          EncounterBalance.VoidAvatar.hp)
    }

    // MARK: - Composition avec la difficulté

    /// Le mode Histoire doit vraiment alléger, le mode Vétéran vraiment durcir.
    func testDifficultyScalesTheWholeCurve() {
        for hp in EncounterBalance.actBossHP {
            let story = Double(hp) * Difficulty.story.enemyHPMultiplier
            let veteran = Double(hp) * Difficulty.veteran.enemyHPMultiplier
            XCTAssertLessThan(story, Double(hp))
            XCTAssertGreaterThan(veteran, Double(hp))
        }
    }
}
