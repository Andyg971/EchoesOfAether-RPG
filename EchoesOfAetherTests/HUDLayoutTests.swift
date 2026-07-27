import XCTest
import SpriteKit
@testable import EchoesOfAether

/// Placement des boutons du HUD d'exploration.
///
/// Deux régressions visuelles réelles sont verrouillées ici :
///
/// 1. **Les icônes du HUD tombaient dans la zone du joystick.** Le pad flottant
///    capture tout le quart bas-gauche ; la colonne de gauche (pause, journal
///    de quêtes) descend dedans. Poser le doigt sur l'icône du journal faisait
///    donc apparaître le joystick au lieu d'ouvrir le journal — le bouton était
///    inerte. `HUDOverlay.containsButton` rend la priorité au HUD.
///
/// 2. **L'échelle du HUD divergeait de celle du monde.** L'ancienne formule
///    `min(w, h) / 390` supposait un écran ~19,5:9 ; en 4:3 elle envoyait le
///    HUD à 2,14× pendant que les sprites restaient à 1×.
@MainActor
final class HUDLayoutTests: XCTestCase {

    /// Insets d'un iPhone en paysage : encoche sur un côté, indicateur
    /// d'accueil en bas.
    private let encoche: CGFloat = 59

    private func makeHUD(in size: CGSize,
                         safeLeft: CGFloat = 0,
                         safeRight: CGFloat = 0) -> (HUDOverlay, SKScene) {
        let scene = SKScene(size: size)
        let hud = HUDOverlay()
        hud.attach(to: scene)
        hud.layout(in: size, safeTop: 0, safeLeft: safeLeft, safeRight: safeRight)
        return (hud, scene)
    }

    // MARK: - Collision joystick / boutons du HUD

    /// Le constat qui motive le correctif : le journal de quêtes EST dans la
    /// zone du joystick sur un iPhone de référence. Si ce test devient faux un
    /// jour (HUD remonté), le correctif reste inoffensif — mais on veut le
    /// savoir.
    func test_journalDeQuetes_tombeDansLaZoneDuJoystick() {
        let taille = Viewport.sceneSize(for: CGSize(width: 852, height: 393))
        let (hud, _) = makeHUD(in: taille, safeLeft: encoche)

        XCTAssertTrue(GameManager.padCaptureZone(in: taille)
                        .contains(hud.questLogButton.position),
                      "le bouton n'est plus dans la zone du pad : test à revoir")
    }

    /// …et le HUD revendique bien ce point, ce qui fait renoncer le joystick.
    func test_hudRevendiqueSesBoutons() {
        let taille = Viewport.sceneSize(for: CGSize(width: 852, height: 393))
        let (hud, scene) = makeHUD(in: taille, safeLeft: encoche)

        for bouton in [hud.questLogButton, hud.pauseButton, hud.loreButton,
                       hud.inventoryButton] {
            XCTAssertTrue(hud.containsButton(at: bouton.position, in: scene),
                          "bouton non revendiqué : le joystick le mangerait")
        }
    }

    /// Le reste de l'écran doit rester au joystick — sinon on casse le
    /// déplacement.
    func test_zoneVide_laisseeAuJoystick() {
        let taille = Viewport.sceneSize(for: CGSize(width: 852, height: 393))
        let (hud, scene) = makeHUD(in: taille, safeLeft: encoche)

        let plein = CGPoint(x: taille.width * 0.25, y: taille.height * 0.30)
        XCTAssertFalse(hud.containsButton(at: plein, in: scene))
    }

    /// La carte du monde n'est pas toujours disponible : masquée, elle ne doit
    /// pas voler de touches au joystick.
    func test_boutonCarteMasque_neVolePasLaTouche() {
        let taille = Viewport.sceneSize(for: CGSize(width: 852, height: 393))
        let (hud, scene) = makeHUD(in: taille, safeLeft: encoche)
        hud.mapButton.isHidden = true

        XCTAssertFalse(hud.containsButton(at: hud.mapButton.position, in: scene))
    }

    // MARK: - Marges de sécurité

    /// Encoche à droite (une rotation paysage sur deux) : les boutons de
    /// droite doivent rester en deçà.
    func test_boutonsDroite_horsEncoche() {
        let taille = Viewport.sceneSize(for: CGSize(width: 852, height: 393))
        let (hud, _) = makeHUD(in: taille, safeRight: encoche)

        let limite = taille.width - encoche
        for bouton in [hud.inventoryButton, hud.loreButton, hud.mapButton] {
            XCTAssertLessThanOrEqual(bouton.position.x + 23, limite,
                                     "bouton sous l'encoche droite")
        }
    }

    // MARK: - Échelle du HUD

    /// Le HUD garde une échelle quasi constante quel que soit l'appareil :
    /// c'est la scène entière que `Viewport` met à l'échelle, pas le HUD tout
    /// seul. On le mesure via l'écart entre deux boutons de la même colonne
    /// (54 pt de pas nominal).
    func test_echelleDuHUD_stableEntreIPhoneEtIPad() {
        func pas(pour vue: CGSize) -> CGFloat {
            let (hud, _) = makeHUD(in: Viewport.sceneSize(for: vue))
            return hud.pauseButton.position.y - hud.questLogButton.position.y
        }

        let surIPhone = pas(pour: CGSize(width: 852, height: 393))
        let surIPad = pas(pour: CGSize(width: 1210, height: 834))

        XCTAssertEqual(surIPad, surIPhone, accuracy: surIPhone * 0.20,
                       "l'échelle du HUD dérive de plus de 20 % sur iPad")
    }
}
