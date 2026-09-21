import SpriteKit

// BattleSprites — FX de sort posés par-dessus le sprite (projectiles, impacts).
extension BattleSprites {
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
}
