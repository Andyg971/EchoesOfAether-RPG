import SpriteKit

/// Sprites de combat des héros — packs dédiés, vue de profil.
///
/// Le combat réutilisait jusqu'ici les sprites top-down du monde (`kael_idle_*`),
/// simplement agrandis : aucune attaque, aucun sort, un personnage vu de dessus
/// dans une arène vue de côté. Ces packs sont de vrais sprites de bataille,
/// tournés vers la droite, avec leurs animations d'attaque et de sorts.
///
/// Deux notions distinctes, à ne pas confondre :
/// - `Pack` — un lot d'assets acheté (canevas, nombre de frames, nommage).
/// - `Hero` — un personnage de l'histoire, qui *porte* un pack.
///
/// Elles étaient mélangées en un seul enum : chaque échelle, chaque compte de
/// frames était indexé sur le personnage alors que ce sont des propriétés du
/// lot d'assets. Résultat, réattribuer un pack demandait de toucher cinq
/// `switch`. Les séparer rend l'attribution triviale — voir `Hero.pack`.
///
/// Les FX sont cuits dans les frames de `skill1`/`skill2` des trois packs
/// (halo violet pour le wizard, arcs orange pour le fighter) : un pack porte
/// donc sa propre couleur, en plus de sa silhouette.
@MainActor
enum BattleSprites {

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

    // MARK: - Textures

    /// Textures d'un clip, en `.nearest` (charte pixel : jamais de lissage).
    /// Vide si le pack ne fournit pas ce clip — l'appelant retombe sur l'idle.
    static func textures(_ hero: Hero, _ clip: Clip) -> [SKTexture] {
        let count = clip.frames(for: hero)
        guard count > 0 else { return [] }
        let group = clip.assetGroup(for: hero)
        return (1...count).compactMap { i in
            let name = "\(hero.prefix)_\(group)_\(i)"
            guard UIImage(named: name) != nil else { return nil }
            let t = SKTexture(imageNamed: name)
            t.filteringMode = .nearest
            return t
        }
    }

    // MARK: - Node

    /// Node de combat d'un héros, en boucle d'idle. Le sprite porte le nom
    /// `body` : `play(_:on:)` le retrouve pour jouer un autre clip.
    static func node(_ hero: Hero) -> SKNode {
        let root = SKNode()
        root.name = "battle_\(hero.prefix)"

        let idle = textures(hero, .idle)
        guard let first = idle.first else { return root }

        let sprite = SKSpriteNode(texture: first)
        sprite.name = "body"
        sprite.setScale(hero.scale)
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.0)
        // Recalé sur le corps : le canevas d'un pack n'est ni centré sur son
        // personnage ni serré sur ses pieds.
        sprite.position = hero.spriteOffset(scale: hero.scale, groundY: -32)
        root.addChild(sprite)

        loop(.idle, hero: hero, on: root)
        return root
    }

    /// Boucle un clip indéfiniment (idle, marche). Sans effet si le clip
    /// tourne déjà : rejouer `move` à chaque frame figerait la marche sur
    /// sa première image.
    static func loop(_ clip: Clip, hero: Hero, on root: SKNode) {
        guard let body = root.childNode(withName: "body") as? SKSpriteNode else { return }
        guard body.userData?["clip"] as? String != String(describing: clip) else { return }
        let frames = textures(hero, clip)
        guard !frames.isEmpty else { return }
        body.userData = body.userData ?? [:]
        body.userData?["clip"] = String(describing: clip)
        body.removeAction(forKey: "clip")
        body.run(.repeatForever(.animate(with: frames, timePerFrame: clip.timePerFrame,
                                         resize: false, restore: true)),
                 withKey: "clip")
    }

    // MARK: - FX de sort (assets overlay)

    /// Projectiles et effets posés PAR-DESSUS le sprite. Chaque élément a ses
    /// trois étapes (`fire1..3`) : ce sont les frames de l'effet, pas trois
    /// variantes.
    ///
    /// Ils suivent le personnage, pas son pack : c'est ce qui donne son élément
    /// à un sort. Le pack n'apporte que la gestuelle et sa couleur cuite.
    enum Effect {
        // Les éléments de Kael.
        case fire, ice, lightning, thunder, blizzard, ward
        // Le sacré de Lyra. Ses sorts ne sont pas élémentaires : ni glace ni
        // foudre, mais bénédiction et soin, en vert et or.
        case lyraHeal, lyraBlessing, lyraBolt
        // Les passes d'armes d'Eran : bourrasque et lame ardente.
        case eranWind, eranEmber

        var frameNames: [String] {
            switch self {
            case .fire:      return ["fx_fire1", "fx_fire2", "fx_fire3"]
            case .ice:       return ["fx_ice1", "fx_ice2", "fx_ice3"]
            case .lightning: return ["fx_lightning1", "fx_lightning2", "fx_lightning3"]
            case .thunder:   return ["fx_thunder1", "fx_thunder2", "fx_thunder3"]
            case .blizzard:  return ["fx_blizzard", "fx_blizzard2"]
            case .ward:      return ["fx_guard"]
            case .lyraHeal:  return ["fx_lyra_skill1_fx1", "fx_lyra_skill1_fx2",
                                     "fx_lyra_skill1_fx3", "fx_lyra_skill1_fx4"]
            case .lyraBlessing: return ["fx_lyra_skill2_fx1", "fx_lyra_skill2_fx2",
                                        "fx_lyra_skill2_fx3"]
            case .lyraBolt:  return ["fx_lyra_attack_bolt", "fx_lyra_attack_fx",
                                     "fx_lyra_attack_hit"]
            case .eranWind:  return ["fx_eran_wind1", "fx_eran_wind2", "fx_eran_skill1"]
            case .eranEmber: return ["fx_eran_skill2", "fx_eran_attack2"]
            }
        }

        /// Projectile = traverse l'arène vers la cible. Les autres éclosent
        /// sur place : la foudre tombe du ciel, les sorts sacrés s'épanouissent
        /// autour du soigné.
        var isProjectile: Bool {
            switch self {
            case .thunder, .ward, .lyraHeal, .lyraBlessing: return false
            default: return true
            }
        }
    }

    static func effectTextures(_ fx: Effect) -> [SKTexture] {
        fx.frameNames.compactMap { name in
            guard UIImage(named: name) != nil else { return nil }
            let t = SKTexture(imageNamed: name)
            t.filteringMode = .nearest
            return t
        }
    }

    /// Joue un effet du pack de `from` vers `to`, dans `parent`.
    /// Sans asset, ne fait rien — l'appelant garde ses propres particules.
    static func playEffect(_ fx: Effect, from: CGPoint, to: CGPoint,
                           in parent: SKNode, scale: CGFloat = 1.6) {
        let frames = effectTextures(fx)
        guard let first = frames.first else { return }

        let node = SKSpriteNode(texture: first)
        node.setScale(scale)
        node.zPosition = 60

        if fx.isProjectile {
            // Le projectile part de la main du lanceur et file vers la cible.
            node.position = CGPoint(x: from.x + 40, y: from.y + 30)
            let dx = to.x - node.position.x
            node.xScale = dx < 0 ? -abs(node.xScale) : abs(node.xScale)
            parent.addChild(node)
            if frames.count > 1 {
                node.run(.repeatForever(.animate(with: frames, timePerFrame: 0.06,
                                                 resize: false, restore: false)))
            }
            node.run(.sequence([
                .move(to: CGPoint(x: to.x, y: to.y + 30), duration: 0.22),
                .fadeOut(withDuration: 0.10),
                .removeFromParent()
            ]))
        } else {
            // Foudre / garde : l'effet éclôt sur place.
            node.position = CGPoint(x: to.x, y: to.y + 40)
            parent.addChild(node)
            let anim: SKAction = frames.count > 1
                ? .animate(with: frames, timePerFrame: 0.07, resize: false, restore: false)
                : .wait(forDuration: 0.24)
            node.run(.sequence([anim, .fadeOut(withDuration: 0.12), .removeFromParent()]))
        }
    }

    // MARK: - Node monde

    /// Node d'exploration : même personnage que dans l'arène, à l'échelle du
    /// monde. Les packs sont de profil (tournés vers la droite) : hors combat
    /// on retourne le sprite selon le sens de marche, et on garde la dernière
    /// orientation horizontale quand Kael monte ou descend.
    static func worldNode(_ hero: Hero, name: String) -> SKNode? {
        let idle = textures(hero, .idle)
        guard let first = idle.first else { return nil }

        let root = SKNode()
        root.name = name

        let sprite = SKSpriteNode(texture: first)
        sprite.name = "body"
        sprite.setScale(hero.worldScale)
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.0)
        // Convention monde : pieds à -16, corps centré sur le node.
        sprite.position = hero.spriteOffset(scale: hero.worldScale, groundY: -16)
        sprite.zPosition = 1
        root.addChild(sprite)

        let shadow = SKShapeNode(ellipseOf: CGSize(width: 24, height: 7))
        shadow.fillColor = SKColor(white: 0, alpha: 0.25)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -15)
        shadow.zPosition = -1
        root.addChild(shadow)

        loop(.idle, hero: hero, on: root)
        return root
    }

    /// Met à jour la marche d'un node monde : `velocity` nul → idle.
    /// Ne fait rien si le node n'a pas de corps (silhouette de secours).
    static func updateWalk(_ hero: Hero, on root: SKNode, velocity: CGVector) {
        guard let body = root.childNode(withName: "body") as? SKSpriteNode else { return }
        let moving = abs(velocity.dx) > 0.5 || abs(velocity.dy) > 0.5
        loop(moving ? .move : .idle, hero: hero, on: root)
        // Orientation : seul un déplacement horizontal franc la change.
        if abs(velocity.dx) > 0.5 {
            let mag = abs(body.xScale == 0 ? hero.worldScale : body.xScale)
            let facingLeft = velocity.dx < 0
            body.xScale = facingLeft ? -mag : mag
            // Le miroir se fait autour du centre du CANEVAS ; comme le corps y
            // est décalé, il faut retourner le décalage avec lui — sinon le
            // personnage saute de côté à chaque demi-tour.
            let dx = hero.spriteOffset(scale: hero.worldScale, groundY: 0).x
            body.position.x = facingLeft ? -dx : dx
        }
    }

    /// Joue un clip une fois puis revient à l'idle. `completion` est appelée
    /// à la fin du clip — de quoi caler l'impact d'un coup sur son anim.
    static func play(_ clip: Clip, hero: Hero, on root: SKNode,
                     completion: (() -> Void)? = nil) {
        guard let body = root.childNode(withName: "body") as? SKSpriteNode else {
            completion?(); return
        }
        let frames = textures(hero, clip)
        guard !frames.isEmpty else {
            // Pack sans ce clip : on n'immobilise pas le combat pour autant.
            completion?(); return
        }
        body.removeAction(forKey: "clip")
        body.run(.sequence([
            .animate(with: frames, timePerFrame: clip.timePerFrame,
                     resize: false, restore: true),
            .run { completion?() }
        ]), withKey: "clip")
        // Retour à l'idle une fois le clip fini.
        let total = clip.timePerFrame * Double(frames.count)
        root.run(.sequence([
            .wait(forDuration: total),
            .run { loop(.idle, hero: hero, on: root) }
        ]))
    }
}
