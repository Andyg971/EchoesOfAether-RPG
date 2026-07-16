import XCTest
import SpriteKit
@testable import EchoesOfAether

/// Géométrie des packs de sprites.
///
/// Un pack ne centre pas son personnage dans son canevas : il réserve la place
/// de ses FX. Le fighter dessine le sien tout à gauche d'un canevas deux fois
/// trop large. Toute la mise en place repose donc sur un décalage — et un
/// décalage, ça se trompe de signe en silence. D'où ces tests.
@MainActor
final class BattleSpritesTests: XCTestCase {

    private typealias Hero = BattleSprites.Hero

    /// Centre du corps à l'écran, relatif au node, pour une orientation donnée.
    /// Reproduit ce que fait SpriteKit : le miroir `xScale` retourne le sprite
    /// autour de son propre centre, pas autour du corps.
    private func bodyCentre(_ hero: Hero, scale: CGFloat,
                            spriteX: CGFloat, facingLeft: Bool) -> CGFloat {
        let sign: CGFloat = facingLeft ? -1 : 1
        return spriteX + hero.pack.bodyOffsetX * scale * sign
    }

    // MARK: - Taille

    /// Les trois héros doivent faire la même taille à l'écran : c'est tout
    /// l'objet du calage sur la hauteur du corps plutôt que sur le canevas.
    func test_lesTroisHeros_fontLaMemeTailleEnCombat() {
        let heights = [Hero.kael, .lyra, .eran].map { $0.pack.bodyHeight * $0.scale }
        for h in heights {
            XCTAssertEqual(h, heights[0], accuracy: 0.01)
        }
    }

    func test_lesTroisHeros_fontLaMemeTailleDansLeMonde() {
        let heights = [Hero.kael, .lyra, .eran].map { $0.pack.bodyHeight * $0.worldScale }
        for h in heights {
            XCTAssertEqual(h, heights[0], accuracy: 0.01)
        }
    }

    // MARK: - Ancrage horizontal

    /// Le corps tombe sur la position du node, pas le centre du canevas.
    func test_corpsCentreSurLeNode_tourneVersLaDroite() {
        for hero in [Hero.kael, .lyra, .eran] {
            let dx = hero.spriteOffset(scale: hero.scale, groundY: 0).x
            XCTAssertEqual(bodyCentre(hero, scale: hero.scale, spriteX: dx,
                                      facingLeft: false),
                           0, accuracy: 0.01,
                           "\(hero) décalé de sa case")
        }
    }

    /// Le demi-tour ne doit pas déplacer le personnage. Sans le miroir du
    /// décalage, le porteur du fighter sautait de ~87 pt sur le côté à chaque
    /// fois que le joueur marchait vers la gauche.
    func test_demiTour_neDeplacePasLePersonnage() {
        for hero in [Hero.kael, .lyra, .eran] {
            let dx = hero.spriteOffset(scale: hero.worldScale, groundY: 0).x
            let droite = bodyCentre(hero, scale: hero.worldScale,
                                    spriteX: dx, facingLeft: false)
            // `updateWalk` pose -dx quand le héros regarde à gauche.
            let gauche = bodyCentre(hero, scale: hero.worldScale,
                                    spriteX: -dx, facingLeft: true)
            XCTAssertEqual(gauche, droite, accuracy: 0.01,
                           "\(hero) saute de côté en se retournant")
        }
    }

    /// Le vrai node produit par `worldNode`, pas seulement l'arithmétique :
    /// `updateWalk` doit reposer le sprite au bon endroit dans les deux sens.
    func test_updateWalk_reposeLeSpriteDansLesDeuxSens() {
        for hero in [Hero.kael, .lyra, .eran] {
            guard let root = BattleSprites.worldNode(hero, name: "t"),
                  let body = root.childNode(withName: "body") as? SKSpriteNode else {
                XCTFail("pack \(hero) introuvable"); continue
            }
            let attendu = bodyCentre(hero, scale: hero.worldScale,
                                     spriteX: body.position.x, facingLeft: false)

            BattleSprites.updateWalk(hero, on: root, velocity: CGVector(dx: -10, dy: 0))
            XCTAssertLessThan(body.xScale, 0, "\(hero) ne regarde pas à gauche")
            XCTAssertEqual(bodyCentre(hero, scale: hero.worldScale,
                                      spriteX: body.position.x, facingLeft: true),
                           attendu, accuracy: 0.01,
                           "\(hero) saute en marchant à gauche")

            BattleSprites.updateWalk(hero, on: root, velocity: CGVector(dx: 10, dy: 0))
            XCTAssertGreaterThan(body.xScale, 0, "\(hero) ne regarde pas à droite")
            XCTAssertEqual(bodyCentre(hero, scale: hero.worldScale,
                                      spriteX: body.position.x, facingLeft: false),
                           attendu, accuracy: 0.01,
                           "\(hero) saute en revenant à droite")
        }
    }

    // MARK: - Attribution des packs

    /// Kael porte le fighter et Eran le wizard — Kael est le jeune amnésique,
    /// Eran le « vieil homme » qui l'appelle « gamin ». L'inverse était à
    /// l'écran pendant tout le développement.
    func test_attributionDesPacks() {
        XCTAssertEqual(Hero.kael.pack, .fighter)
        XCTAssertEqual(Hero.lyra.pack, .priest)
        XCTAssertEqual(Hero.eran.pack, .wizard)
    }

    /// L'enchaînement à trois passes est une propriété du dessin : il doit
    /// suivre le pack fighter chez celui qui le porte.
    func test_enchainementSuitLePackFighter() {
        XCTAssertTrue(Hero.kael.pack.hasAttackChain)
        XCTAssertFalse(Hero.eran.pack.hasAttackChain)
        XCTAssertEqual(BattleSprites.Clip.attack.assetGroup(for: .kael), "attack1")
        XCTAssertEqual(BattleSprites.Clip.attack.assetGroup(for: .eran), "attack")
    }

    /// Chaque clip annoncé par un pack doit avoir ses assets. Un compte de
    /// frames faux ne casse rien au build : l'animation se joue juste tronquée.
    func test_chaqueClipAnnonce_aSesAssets() {
        let clips: [BattleSprites.Clip] = [.idle, .move, .attack, .skill1, .skill2,
                                           .attack2, .attack3]
        for hero in [Hero.kael, .lyra, .eran] {
            for clip in clips where clip.frames(for: hero) > 0 {
                XCTAssertEqual(BattleSprites.textures(hero, clip).count,
                               clip.frames(for: hero),
                               "\(hero)/\(clip) : assets manquants")
            }
        }
    }
}
