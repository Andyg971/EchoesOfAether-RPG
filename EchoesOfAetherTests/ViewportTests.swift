import XCTest
import CoreGraphics
@testable import EchoesOfAether

/// Invariants de la résolution virtuelle (`Viewport`).
///
/// Tout le jeu est composé en fractions de `scene.size` : les zones font des
/// multiples de la hauteur de scène, les arènes de combat placent leurs slots
/// en pourcentages, le HUD s'ancre aux bords. Trois propriétés doivent tenir,
/// sans quoi l'image se casse — d'où ces tests.
///
/// 1. **Sur iPhone, rien ne change.** Le facteur vaut exactement 1 et la scène
///    garde la taille de la vue : l'appareil de référence ne peut pas régresser.
/// 2. **Le rapport d'aspect est conservé.** La scène virtuelle a exactement les
///    proportions de la vue, sinon `.aspectFill` recadrerait (HUD hors écran)
///    ou déformerait les sprites pixel.
/// 3. **Sur iPad, la largeur de composition reste celle du gabarit.** Les
///    panneaux (dialogue, boutique, arène) sont dimensionnés en points sur une
///    largeur d'écran supposée : la préserver garantit qu'aucun texte long ne
///    déborde.
@MainActor
final class ViewportTests: XCTestCase {

    // Tailles réelles en points, en paysage.
    private let iPhoneSE = CGSize(width: 667, height: 375)
    private let iPhone15Pro = CGSize(width: 852, height: 393)
    private let iPhone15ProMax = CGSize(width: 932, height: 430)
    private let iPadM4_11 = CGSize(width: 1210, height: 834)
    private let iPadM4_13 = CGSize(width: 1376, height: 1032)

    // MARK: - Non-régression iPhone

    /// Le gabarit lui-même : facteur 1, scène identique à la vue.
    func test_iPhoneDeReference_facteurUn_sceneInchangee() {
        XCTAssertEqual(Viewport.scale(for: iPhone15Pro), 1, accuracy: 0.0001)
        XCTAssertEqual(Viewport.sceneSize(for: iPhone15Pro).width, 852, accuracy: 0.0001)
        XCTAssertEqual(Viewport.sceneSize(for: iPhone15Pro).height, 393, accuracy: 0.0001)
    }

    /// Un écran plus PETIT que le gabarit ne doit pas rétrécir le jeu : le
    /// plancher à 1 conserve le rendu 1:1 historique.
    func test_petitIPhone_pasDeReductionSousUn() {
        XCTAssertEqual(Viewport.scale(for: iPhoneSE), 1, accuracy: 0.0001)
        XCTAssertEqual(Viewport.sceneSize(for: iPhoneSE), iPhoneSE)
    }

    /// Un grand iPhone reste sous le gabarit en hauteur (430 / 393 = 1,09 mais
    /// 932 / 852 = 1,09 aussi) : facteur modeste, aucun bouleversement.
    func test_grandIPhone_facteurProcheDeUn() {
        let k = Viewport.scale(for: iPhone15ProMax)
        XCTAssertGreaterThanOrEqual(k, 1)
        XCTAssertLessThan(k, 1.15)
    }

    // MARK: - Rapport d'aspect (aucun recadrage, aucune déformation)

    func test_rapportDAspectConserve_surTousLesAppareils() {
        for taille in [iPhoneSE, iPhone15Pro, iPhone15ProMax, iPadM4_11, iPadM4_13] {
            let scene = Viewport.sceneSize(for: taille)
            XCTAssertEqual(scene.width / scene.height,
                           taille.width / taille.height,
                           accuracy: 0.0001,
                           "aspect modifié pour \(taille) — .aspectFill recadrerait")
        }
    }

    // MARK: - iPad

    /// Sur iPad, c'est la largeur qui contraint : la scène virtuelle garde
    /// exactement la largeur du gabarit, et gagne en hauteur (format 4:3).
    func test_iPad_largeurDeCompositionPreservee() {
        for taille in [iPadM4_11, iPadM4_13] {
            let scene = Viewport.sceneSize(for: taille)
            XCTAssertEqual(scene.width, Viewport.designWidth, accuracy: 0.5,
                           "largeur de composition perdue pour \(taille)")
            XCTAssertGreaterThan(scene.height, Viewport.designHeight,
                                 "l'iPad doit montrer plus de monde en hauteur")
        }
    }

    /// Le facteur d'agrandissement est bien supérieur à 1 : c'est lui qui
    /// corrige les sprites minuscules de l'ancien `.resizeFill`.
    func test_iPad_agrandissementEffectif() {
        XCTAssertEqual(Viewport.scale(for: iPadM4_11), 1.42, accuracy: 0.02)
        XCTAssertEqual(Viewport.scale(for: iPadM4_13), 1.61, accuracy: 0.02)
    }

    /// La hauteur virtuelle reste dans une plage raisonnable : au-delà d'un
    /// rapport ~1,8 sur le gabarit, les zones scrollables (worldHeight =
    /// 2,4× à 4,2× la hauteur d'écran) cesseraient de scroller.
    func test_iPad_hauteurVirtuelleRaisonnable() {
        for taille in [iPadM4_11, iPadM4_13] {
            let ratio = Viewport.sceneSize(for: taille).height / Viewport.designHeight
            XCTAssertLessThan(ratio, 1.8, "trop de monde visible d'un coup sur \(taille)")
        }
    }

    // MARK: - Marges de sécurité

    /// Les insets viennent de la vue (points réels) et sont consommés dans le
    /// repère de la scène : ils doivent être divisés par le facteur, sinon
    /// l'encoche est surcompensée.
    func test_margesConvertiesDansLeRepereDeLaScene() {
        // iPhone : facteur 1, la marge passe telle quelle.
        XCTAssertEqual(Viewport.sceneInset(59, for: iPhone15Pro), 59, accuracy: 0.0001)

        // iPad : la marge rétrécit d'autant que la scène.
        let k = Viewport.scale(for: iPadM4_11)
        XCTAssertEqual(Viewport.sceneInset(24, for: iPadM4_11), 24 / k, accuracy: 0.0001)
    }

    // MARK: - Robustesse

    /// `viewDidLayoutSubviews` peut passer une taille nulle avant la première
    /// passe de layout : ne jamais diviser par zéro ni renvoyer NaN.
    func test_tailleDegeneree_pasDeNaN() {
        XCTAssertEqual(Viewport.scale(for: .zero), 1, accuracy: 0.0001)
        XCTAssertEqual(Viewport.sceneSize(for: .zero), .zero)
        XCTAssertEqual(Viewport.scale(for: CGSize(width: 800, height: 0)), 1, accuracy: 0.0001)
    }

    /// Le plafond protège d'un écran hypothétiquement immense.
    func test_ecranGeant_facteurPlafonne() {
        let enorme = CGSize(width: 4000, height: 2400)
        XCTAssertEqual(Viewport.scale(for: enorme), Viewport.maxScale, accuracy: 0.0001)
    }
}
