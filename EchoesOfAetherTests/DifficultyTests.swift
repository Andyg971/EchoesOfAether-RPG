import XCTest
@testable import EchoesOfAether

/// Réglage de difficulté : cycle, persistance, et effet réel sur les ennemis.
///
/// Ce réglage n'est lu qu'au début de chaque combat, jamais gravé dans la
/// sauvegarde — c'est ce qui permet à un joueur bloqué de redescendre devant un
/// boss sans recommencer. Les tests ci-dessous verrouillent les propriétés dont
/// dépend cette promesse.
@MainActor
final class DifficultyTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: Difficulty.storageKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: Difficulty.storageKey)
        super.tearDown()
    }

    // MARK: - Valeur par défaut

    /// Sans réglage écrit, on joue l'équilibrage d'origine. Une partie
    /// existante ne doit pas changer de difficulté à la mise à jour.
    func test_parDefaut_normal() {
        XCTAssertEqual(Difficulty.current, .normal)
    }

    /// `normal` ne modifie rien : ses deux multiplicateurs valent exactement 1.
    /// C'est la garantie de non-régression pour tout l'équilibrage existant.
    func test_normal_neChangeRien() {
        XCTAssertEqual(Difficulty.normal.enemyHPMultiplier, 1.0, accuracy: 0.0001)
        XCTAssertEqual(Difficulty.normal.enemyDamageMultiplier, 1.0, accuracy: 0.0001)
    }

    /// Une valeur brute inconnue (réglages corrompus, downgrade d'une version
    /// future) ne doit pas rendre le jeu injouable.
    func test_valeurInconnue_retombeSurNormal() {
        UserDefaults.standard.set(99, forKey: Difficulty.storageKey)
        XCTAssertEqual(Difficulty.current, .normal)
    }

    // MARK: - Persistance et cycle

    func test_persistance() {
        Difficulty.current = .veteran
        XCTAssertEqual(Difficulty.current, .veteran)
    }

    /// La ligne d'options se tape pour cycler : trois pas doivent revenir au
    /// point de départ, sans état bloquant.
    func test_cycleComplet_revientAuDepart() {
        XCTAssertEqual(Difficulty.story.next, .normal)
        XCTAssertEqual(Difficulty.normal.next, .veteran)
        XCTAssertEqual(Difficulty.veteran.next, .story)
    }

    // MARK: - Effet sur les ennemis

    /// L'ordre doit être strict : Histoire < Normal < Vétéran sur les deux
    /// axes. Sans ça, un palier « plus dur » pourrait être plus facile.
    func test_ordreStrict_surLesDeuxAxes() {
        XCTAssertLessThan(Difficulty.story.enemyHPMultiplier,
                          Difficulty.normal.enemyHPMultiplier)
        XCTAssertLessThan(Difficulty.normal.enemyHPMultiplier,
                          Difficulty.veteran.enemyHPMultiplier)

        XCTAssertLessThan(Difficulty.story.enemyDamageMultiplier,
                          Difficulty.normal.enemyDamageMultiplier)
        XCTAssertLessThan(Difficulty.normal.enemyDamageMultiplier,
                          Difficulty.veteran.enemyDamageMultiplier)
    }

    /// Le mode Histoire allège sans supprimer : un ennemi doit garder assez de
    /// PV pour que le combat existe encore. Un multiplicateur trop bas
    /// transformerait chaque rencontre en formalité — ce n'est pas le but.
    func test_modeHistoire_allegeSansSupprimer() {
        XCTAssertGreaterThan(Difficulty.story.enemyHPMultiplier, 0.5)
        XCTAssertGreaterThan(Difficulty.story.enemyDamageMultiplier, 0.5)
    }

    /// Côté Vétéran, les PV montent plus que les dégâts : gonfler les dégâts
    /// transforme un combat en loterie de premier tour, gonfler les PV laisse
    /// au joueur le temps de jouer son système (BREAK, MP, boost).
    func test_veteran_privilegieLesPVSurLesDegats() {
        XCTAssertGreaterThan(Difficulty.veteran.enemyHPMultiplier,
                             Difficulty.veteran.enemyDamageMultiplier)
    }

    /// Difficulté et New Game+ s'empilent (ils se multiplient dans
    /// `CombatSystem.begin`). On vérifie ici que le calcul reste sain aux
    /// extrêmes : même en Histoire au palier NG+3, les ennemis restent plus
    /// coriaces qu'en Normal sans NG+ — le NG+ doit rester une montée.
    func test_difficulteEtNewGamePlus_sEmpilent() {
        let histoireNGP3 = Difficulty.story.enemyHPMultiplier * (1.0 + 0.45 * 3)
        let normalSansNGP = Difficulty.normal.enemyHPMultiplier

        XCTAssertGreaterThan(histoireNGP3, normalSansNGP)
    }

    // MARK: - Localisation

    /// Le projet n'a aucune chaîne codée en dur : les trois noms doivent être
    /// traduits, donc différents de leur clé.
    func test_nomsLocalises() {
        for palier in Difficulty.allCases {
            let nom = palier.localizedName
            XCTAssertFalse(nom.isEmpty)
            XCTAssertFalse(nom.hasPrefix("options.difficulty"),
                           "clé non traduite : \(nom)")
        }
    }
}
