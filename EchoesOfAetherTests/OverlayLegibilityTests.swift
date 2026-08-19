import XCTest
import SpriteKit
@testable import EchoesOfAether

/// Lisibilité des grands panneaux d'interface.
///
/// `UIScale.fittingFactor` fait tenir un panneau trop haut en le RÉDUISANT.
/// C'est un filet de sécurité utile, mais silencieux : le panneau tient
/// toujours, et le texte rétrécit sans que rien ne le signale. Deux écrans y
/// avaient glissé sans qu'on s'en aperçoive —
///
/// - **Options** : 304 × 672 empilés en une colonne sur un écran de 852 × 393.
///   Facteur ×0,55, libellés à **8,5 pt** rendus.
/// - **Inventaire** : 340 × 520. Facteur ×0,72, libellés à **10,7 pt**.
///
/// Apple recommande 11 pt au minimum. Les deux panneaux sont passés en deux
/// colonnes — la place était sur le côté, pas en bas, dans un jeu qui ne se
/// joue qu'en paysage.
///
/// Ces tests gardent l'invariant : **aucun grand panneau ne doit avoir besoin
/// d'être réduit pour tenir**. Ajouter une ligne sans revoir la mise en page
/// fera échouer le test, au lieu de rogner le texte en silence.
@MainActor
final class OverlayLegibilityTests: XCTestCase {

    /// Le plus contraignant des écrans visés : iPhone en paysage, 393 pt de
    /// haut seulement.
    private var scenePhone: CGSize {
        Viewport.sceneSize(for: CGSize(width: 852, height: 393))
    }

    private var sceneIPad: CGSize {
        Viewport.sceneSize(for: CGSize(width: 1210, height: 834))
    }

    // MARK: - Aucune réduction nécessaire

    func test_options_tientSansReduction() {
        for scene in [scenePhone, sceneIPad] {
            let f = UIScale.fittingFactor(for: scene,
                                          contentHeight: OptionsOverlay.panelSize.height + 16)
            XCTAssertEqual(f, 1.0, accuracy: 0.001,
                           "le panneau d'options doit être réduit pour tenir dans \(scene) — le texte va rétrécir")
        }
    }

    func test_inventaire_tientSansReduction() {
        for scene in [scenePhone, sceneIPad] {
            let f = UIScale.fittingFactor(for: scene,
                                          contentHeight: InventoryOverlay.panelSize.height + 12)
            XCTAssertEqual(f, 1.0, accuracy: 0.001,
                           "le panneau d'inventaire doit être réduit pour tenir dans \(scene)")
        }
    }

    // MARK: - Le seuil de lisibilité, exprimé en points rendus

    /// Formulation directe de la règle : un libellé de 15 pt dans le panneau
    /// d'options doit arriver à l'œil du joueur à 11 pt au moins.
    func test_libellesAuDessusDuSeuilDe11pt() {
        let cas: [(String, CGFloat, CGFloat, CGFloat)] = [
            ("Options",    OptionsOverlay.panelSize.height + 16,   15, 11),
            ("Inventaire", InventoryOverlay.panelSize.height + 12, 18, 11),
        ]
        for (nom, hauteur, police, seuil) in cas {
            let vue = CGSize(width: 852, height: 393)
            let scene = Viewport.sceneSize(for: vue)
            // Points ÉCRAN réels : facteur du panneau × facteur global de la scène.
            let rendu = police
                * UIScale.fittingFactor(for: scene, contentHeight: hauteur)
                * Viewport.scale(for: vue)
            XCTAssertGreaterThanOrEqual(rendu, seuil,
                                        "\(nom) : libellés à \(String(format: "%.1f", rendu)) pt rendus")
        }
    }

    // MARK: - Les panneaux qui allaient déjà bien

    /// Lore, Journal et Carte calculent leur hauteur depuis l'écran
    /// (`min(500, max(420, h - 104))`) au lieu de la figer : c'est pour ça
    /// qu'ils tenaient déjà à 13–14 pt. On vérifie que ce calcul reste sain.
    func test_panneauxAdaptatifs_restentLisibles() {
        let scene = scenePhone
        let hauteurAdaptative = min(500, max(420, scene.height - 104))
        let f = UIScale.fittingFactor(for: scene, contentHeight: hauteurAdaptative + 12)

        XCTAssertGreaterThanOrEqual(15 * f * Viewport.scale(for: CGSize(width: 852, height: 393)), 11)
    }

    // MARK: - Le filet reste actif

    /// `fittingFactor` doit CONSERVER sa capacité à réduire : c'est ce qui
    /// évite qu'un panneau déborde sur un écran plus court que le gabarit.
    /// Les tests ci-dessus vérifient qu'on n'en a plus besoin, pas qu'il a
    /// disparu.
    func test_leFiletDeSecuriteFonctionneToujours() {
        let f = UIScale.fittingFactor(for: scenePhone, contentHeight: 900)
        XCTAssertLessThan(f, 1.0)
        XCTAssertGreaterThanOrEqual(f, 0.5)
    }

    // MARK: - Crédits : tout doit tenir DANS l'écran

    /// Les crédits n'ont pas de `fittingFactor` : ils posent leurs libellés à
    /// des positions calculées. Deux formules cohabitaient — 52 pt par entrée
    /// pour la colonne, 26 pt par entrée pour la citation et le bouton — et le
    /// bouton « Fermer » se retrouvait à −221 sur un écran dont le bas est à
    /// −201. Hors champ : l'écran de crédits ne se fermait plus.
    ///
    /// Ce test parcourt les vrais nodes posés par `showCredits`. Ajouter une
    /// ligne aux crédits sans revoir la mise en page le fera échouer.
    func test_credits_tousLesElementsSontDansLEcran() {
        for size in [scenePhone, sceneIPad] {
            let scene = SKScene(size: size)
            TransitionManager.showCredits(in: scene) { }
            defer { _ = TransitionManager.handleCreditsTap(at: .zero, in: scene) }

            guard let overlay = scene.childNode(withName: "creditsOverlay") else {
                return XCTFail("overlay de crédits absent")
            }
            let limite = size.height / 2
            for child in overlay.children {
                let frame = child.calculateAccumulatedFrame()
                XCTAssertLessThanOrEqual(frame.maxY, limite,
                                         "un élément des crédits déborde en haut sur \(size)")
                XCTAssertGreaterThanOrEqual(frame.minY, -limite,
                                            "un élément des crédits déborde en bas sur \(size)")
            }
        }
    }

    /// Le bouton de fermeture est le seul moyen de sortir des crédits : il
    /// doit être posé, nommé, et intégralement visible.
    func test_credits_leBoutonFermerEstAtteignable() {
        let scene = SKScene(size: scenePhone)
        TransitionManager.showCredits(in: scene) { }
        defer { _ = TransitionManager.handleCreditsTap(at: .zero, in: scene) }

        guard let overlay = scene.childNode(withName: "creditsOverlay"),
              let bouton = overlay.childNode(withName: "creditsClose") else {
            return XCTFail("bouton de fermeture des crédits absent")
        }
        let frame = bouton.calculateAccumulatedFrame()
        XCTAssertGreaterThanOrEqual(frame.minY, -scenePhone.height / 2,
                                    "le bouton « Fermer » sort par le bas — crédits impossibles à quitter")
    }
}
