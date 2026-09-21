import SpriteKit

// BattleSprites — les lots d'assets (Pack), les héros qui les portent (Hero), les clips.
extension BattleSprites {
    /// Lot d'assets. Tout ce qui dépend du dessin vit ici.
    enum Pack {
        case wizard, priest, fighter

        var prefix: String {
            switch self {
            case .wizard:  return "battle_kael"
            case .priest:  return "battle_lyra"
            case .fighter: return "battle_eran"
            }
        }

        /// Hauteur du personnage réellement dessiné, en pixels du canevas —
        /// mesurée sur la frame d'idle (boîte englobante alpha).
        ///
        /// Le canevas ne dit rien de la taille du personnage : le fighter a le
        /// plus GRAND canevas (153×127) et le plus PETIT bonhomme (32×54),
        /// parce que ses arcs de FX sont dessinés dans le même cadre. Caler
        /// l'échelle sur le canevas rapetissait donc le fighter d'un cinquième
        /// à l'écran. C'est la hauteur du corps qui fait foi.
        var bodyHeight: CGFloat {
            switch self {
            case .wizard:  return 56    // canevas 109×128, corps 46×56
            case .priest:  return 50    // canevas 111×105, corps 57×50
            case .fighter: return 54    // canevas 153×127, corps 32×54
            }
        }

        /// Largeur du personnage dessiné, en pixels du canevas (même mesure
        /// que `bodyHeight`). Sert à poser une ombre à la bonne largeur : le
        /// fighter est étroit, le priest large (bâton tendu).
        var bodyWidth: CGFloat {
            switch self {
            case .wizard:  return 46
            case .priest:  return 57
            case .fighter: return 32
            }
        }

        /// Décalage du centre du corps par rapport au centre du canevas, en
        /// pixels du canevas (+ = le corps est à droite du centre).
        ///
        /// Un pack ne centre pas son personnage : il réserve la place de ses
        /// FX. Le fighter dessine le sien tout à gauche (x 6…38 d'un canevas de
        /// 153) et garde tout le reste pour ses arcs. Ancré au centre du
        /// canevas, son corps apparaît à 55 px à gauche de sa case — c'est ce
        /// qui « reculait » le porteur du fighter et l'entassait sur ses
        /// voisins. On ancre donc sur le corps.
        var bodyOffsetX: CGFloat {
            switch self {
            case .wizard:  return 6.5     // corps x 38…84, canevas 109
            case .priest:  return -8.0    // corps x 19…76, canevas 111
            case .fighter: return -54.5   // corps x 6…38,  canevas 153
            }
        }

        /// Hauteur de vide sous les pieds, en pixels du canevas. Sans elle, les
        /// trois packs ne posent pas les pieds sur la même ligne de sol.
        var bodyBottomGap: CGFloat {
            switch self {
            case .wizard:  return 9    // pieds y 119, canevas 128
            case .priest:  return 3    // pieds y 102, canevas 105
            case .fighter: return 9    // pieds y 118, canevas 127
            }
        }

        /// Le pack fournit-il trois enchaînements d'attaque (`attack1..3`) ?
        /// Le fighter alterne ses passes ; wizard et priest n'en ont qu'une.
        var hasAttackChain: Bool { self == .fighter }

        /// Nombre de frames réel par clip. 0 = le pack ne fournit pas ce clip.
        func frames(_ clip: Clip) -> Int {
            switch (self, clip) {
            case (.wizard, .idle):    return 5
            case (.wizard, .move):    return 6
            case (.wizard, .attack):  return 7
            case (.wizard, .skill1):  return 7
            case (.wizard, .skill2):  return 14

            case (.priest, .idle):    return 5
            case (.priest, .move):    return 6
            case (.priest, .attack):  return 9
            case (.priest, .skill1):  return 16
            case (.priest, .skill2):  return 10

            case (.fighter, .idle):    return 5
            case (.fighter, .move):    return 6
            case (.fighter, .attack):  return 8    // attack1
            case (.fighter, .attack2): return 8
            case (.fighter, .attack3): return 14
            case (.fighter, .skill1):  return 13
            case (.fighter, .skill2):  return 15

            // Seul le fighter enchaîne.
            case (_, .attack2), (_, .attack3): return 0
            }
        }
    }

    /// Hauteur à l'écran du corps d'un héros, en points. Les trois packs y
    /// sont ramenés : sans ça, chacun apparaît à la taille de son propre
    /// dessin et le groupe n'a aucune unité.
    nonisolated private static let combatBodyHeight: CGFloat = 72
    /// Idem hors combat, à l'échelle du monde (les héros dominent un peu les
    /// PNJ chibi : ce sont eux qu'on suit).
    nonisolated private static let worldBodyHeight: CGFloat = 43

    /// Héros jouables/alliés de l'arène.
    enum Hero {
        case kael, lyra, eran

        /// Attribution des packs. **C'est ici, et nulle part ailleurs, qu'on
        /// change l'apparence d'un personnage.**
        ///
        /// Kael porte le fighter et Eran le wizard : le scénario fait de Kael un
        /// jeune amnésique ramassé sur un chemin et d'Eran un « vieil homme »
        /// qui garde le Seuil et appelle Kael « gamin ». Les packs disaient
        /// exactement l'inverse — le vieux grisonnant jouait le héros, le jeune
        /// torse nu jouait le vieillard.
        ///
        /// Les kits de sorts ne suivent PAS : ils appartiennent au personnage,
        /// pas au dessin. Kael garde Brasier / Tempête / Black Slash, Eran
        /// garde Bourrasque / Lame ardente.
        var pack: Pack {
            switch self {
            case .kael: return .fighter
            case .lyra: return .priest
            case .eran: return .wizard
            }
        }

        var prefix: String { pack.prefix }

        /// Planche « bouclier au bras » du même personnage, s'il en a une.
        /// Seul le wizard en fournit une — donc seul Eran se met en garde
        /// pour de vrai au lieu d'encaisser en position de repos.
        var wardPrefix: String? {
            pack == .wizard ? "battle_kaelward" : nil
        }

        /// Les effets que ce personnage projette pour une action donnée.
        ///
        /// Ils suivent le PACK, pas le nom : chacun jette les éléments
        /// dessinés dans son propre lot d'assets. Eran porte le wizard, il
        /// commande donc la glace, la foudre, le feu, le tonnerre et le
        /// blizzard ; Kael porte le fighter et garde bourrasque et braise ;
        /// Lyra son sacré. Ces planches existaient TOUTES dans le catalogue
        /// sans qu'aucune ne soit jamais jouée — `playEffect` n'avait aucun
        /// appelant.
        ///
        /// Plusieurs effets pour une action = enchaînement (le tonnerre tombe,
        /// le blizzard suit). Pour l'attaque simple, la liste est un CYCLE :
        /// un lanceur qui ouvre toujours sur le même élément n'a pas l'air
        /// d'en maîtriser cinq.
        func spells(for clip: Clip) -> [Effect] {
            switch (pack, clip) {
            case (.wizard, .attack):  return [.ice, .lightning]
            case (.wizard, .skill1):  return [.fire]
            case (.wizard, .skill2):  return [.thunder, .blizzard]

            case (.fighter, .attack): return [.eranWind]
            case (.fighter, .skill1): return [.eranWind]
            case (.fighter, .skill2): return [.eranEmber]

            case (.priest, .attack):  return [.lyraBolt]
            case (.priest, .skill1):  return [.lyraHeal]
            case (.priest, .skill2):  return [.lyraBlessing]

            default: return []
            }
        }

        /// L'effet de garde, joué quand le personnage pare un coup.
        var wardEffect: Effect { .ward }

        /// Échelle en combat — dérivée de la hauteur du corps, pas du canevas.
        var scale: CGFloat { combatBodyHeight / pack.bodyHeight }

        /// Échelle dans le monde, même principe.
        var worldScale: CGFloat { worldBodyHeight / pack.bodyHeight }

        /// Largeur de l'ombre en combat, calée sur la largeur réelle du
        /// personnage une fois mis à l'échelle.
        var combatShadowWidth: CGFloat { pack.bodyWidth * scale }

        /// Position à donner au sprite pour que le CORPS — et non le centre du
        /// canevas — tombe sur la position du node, pieds sur `groundY`.
        func spriteOffset(scale: CGFloat, groundY: CGFloat) -> CGPoint {
            CGPoint(x: -pack.bodyOffsetX * scale,
                    y: groundY - pack.bodyBottomGap * scale)
        }
    }

    /// Animations disponibles.
    enum Clip {
        case idle, move, attack, skill1, skill2
        /// Trois enchaînements d'attaque distincts (packs qui les fournissent).
        case attack2, attack3

        func frames(for hero: Hero) -> Int { hero.pack.frames(self) }

        /// Suffixe d'asset. Les packs qui enchaînent nomment leur première
        /// attaque `attack1` ; les autres, simplement `attack`.
        func assetGroup(for hero: Hero) -> String {
            switch self {
            case .idle:    return "idle"
            case .move:    return "move"
            case .attack:  return hero.pack.hasAttackChain ? "attack1" : "attack"
            case .attack2: return "attack2"
            case .attack3: return "attack3"
            case .skill1:  return "skill1"
            case .skill2:  return "skill2"
            }
        }

        /// Cadence. Les sorts respirent, les attaques claquent.
        var timePerFrame: TimeInterval {
            switch self {
            case .idle:   return 0.16
            case .move:   return 0.10
            case .attack, .attack2, .attack3: return 0.06
            case .skill1, .skill2: return 0.08
            }
        }
    }
}
