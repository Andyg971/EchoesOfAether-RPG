import SpriteKit

/// Sprites de combat des héros — packs dédiés, vue de profil.
///
/// Le combat réutilisait jusqu'ici les sprites top-down du monde (`kael_idle_*`),
/// simplement agrandis : aucune attaque, aucun sort, un personnage vu de dessus
/// dans une arène vue de côté. Ces packs sont de vrais sprites de bataille,
/// tournés vers la droite, avec leurs animations d'attaque et de sorts.
///
/// Correspondance des packs : wizard → Kael, priest → Lyra, fighter → Eran.
/// Pour Lyra et Eran, les effets sont déjà intégrés aux frames (`char+fx`) :
/// les sorts s'affichent sans FX à coder.
@MainActor
enum BattleSprites {

    /// Héros jouables/alliés de l'arène.
    enum Hero {
        case kael, lyra, eran

        var prefix: String {
            switch self {
            case .kael: return "battle_kael"
            case .lyra: return "battle_lyra"
            case .eran: return "battle_eran"
            }
        }

        /// Échelle en combat. Les canevas diffèrent d'un pack à l'autre
        /// (Kael 109×128, Lyra 111×105, Eran 153×127) : l'échelle compense
        /// pour que les trois fassent la même taille à l'écran.
        var scale: CGFloat {
            switch self {
            case .kael: return 1.30
            case .lyra: return 1.30
            case .eran: return 1.10
            }
        }

        /// Échelle dans le monde. Calée d'abord sur les PNJ chibi (~48 pt),
        /// elle rendait les héros trop menus : dans une zone large ils se
        /// perdaient dans le décor. Remontée d'environ un quart — ils
        /// dominent légèrement les PNJ, ce qui est juste : ce sont eux
        /// qu'on suit.
        var worldScale: CGFloat {
            switch self {
            case .kael: return 0.76
            case .lyra: return 0.76
            case .eran: return 0.65
            }
        }
    }

    /// Animations disponibles, avec leur nombre de frames réel.
    enum Clip {
        case idle, move, attack, skill1, skill2
        /// Eran possède trois enchaînements d'attaque distincts.
        case attack2, attack3

        func frames(for hero: Hero) -> Int {
            switch (hero, self) {
            case (.kael, .idle):    return 5
            case (.kael, .move):    return 6
            case (.kael, .attack):  return 7
            case (.kael, .skill1):  return 7
            case (.kael, .skill2):  return 14

            case (.lyra, .idle):    return 5
            case (.lyra, .move):    return 6
            case (.lyra, .attack):  return 9
            case (.lyra, .skill1):  return 16
            case (.lyra, .skill2):  return 10

            case (.eran, .idle):    return 5
            case (.eran, .move):    return 6
            case (.eran, .attack):  return 8    // attack1
            case (.eran, .attack2): return 8
            case (.eran, .attack3): return 14
            case (.eran, .skill1):  return 13
            case (.eran, .skill2):  return 15

            // Kael et Lyra n'ont qu'un enchaînement d'attaque.
            case (_, .attack2), (_, .attack3): return 0
            }
        }

        /// Suffixe d'asset. Eran nomme sa première attaque `attack1`.
        func assetGroup(for hero: Hero) -> String {
            switch self {
            case .idle:    return "idle"
            case .move:    return "move"
            case .attack:  return hero == .eran ? "attack1" : "attack"
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
        // Ancrage aux pieds : le pack pose le personnage en bas du canevas.
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.0)
        sprite.position = CGPoint(x: 0, y: -32)
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

    // MARK: - FX de sort (pack wizard)

    /// Projectiles et effets fournis avec le pack. Chaque élément a ses trois
    /// étapes (`fire1..3`) : ce sont les frames de l'effet, pas trois variantes.
    enum Effect {
        // Pack wizard — les éléments de Kael.
        case fire, ice, lightning, thunder, blizzard, ward
        // Pack priest — le sacré de Lyra. Ses sorts ne sont pas élémentaires :
        // ni glace ni foudre, mais bénédiction et soin, en vert et or.
        case lyraHeal, lyraBlessing, lyraBolt
        // Pack fighter — les passes d'armes d'Eran : bourrasque et lame ardente.
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
        sprite.position = CGPoint(x: 0, y: -16)   // convention monde : ancré aux pieds
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
            body.xScale = velocity.dx < 0 ? -mag : mag
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
