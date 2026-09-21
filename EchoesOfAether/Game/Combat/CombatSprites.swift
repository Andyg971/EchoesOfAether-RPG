import SpriteKit

/// Factory de sprites pour l'arène de combat. Plus grands et plus expressifs
/// que les nodes monde, optimisés pour la lisibilité en plein écran.
@MainActor
enum CombatSprites {

    // MARK: - Kael

    static func kael() -> SKNode {
        let root = BattleSprites.node(.kael)
        root.name = "combatKael"
        addShadow(to: root, width: BattleSprites.Hero.kael.combatShadowWidth)
        return root
    }

    // MARK: - Alliés en combat

    /// Sprite d'allié selon sa nature. L'écho de Lyra est son sprite teinté de
    /// cyan spectral et translucide ; Eran porte son pack tel quel.
    ///
    /// Les largeurs d'ombre viennent du pack : elles étaient codées en dur
    /// (56 / 52 / 48) pour des sprites qui ont depuis changé de taille.
    static func ally(kind: CombatAllyKind) -> SKNode {
        switch kind {
        case .lyra:
            return lyra()
        case .lyraEcho:
            // L'Écho garde le sprite de Lyra, teinté cyan glacé et translucide
            // (mêmes valeurs spectrales que dans le monde, cf. showLyraEcho).
            let node = lyra()
            node.alpha = 0.7
            node.forEachDescendantSprite { s in
                s.color = SKColor(red: 0.50, green: 0.92, blue: 0.98, alpha: 1)
                s.colorBlendFactor = 0.6
            }
            return node
        case .eran:
            let root = BattleSprites.node(.eran)
            root.name = "combatEran"
            addShadow(to: root, width: BattleSprites.Hero.eran.combatShadowWidth)
            return root
        }
    }

    static func lyra() -> SKNode {
        let root = BattleSprites.node(.lyra)
        root.name = "combatLyra"
        addShadow(to: root, width: BattleSprites.Hero.lyra.combatShadowWidth)
        return root
    }

    // MARK: - Animations d'action (héros et alliés)

    /// Le héros porté par ce node de combat, s'il en porte un.
    static func heroOf(_ node: SKNode) -> BattleSprites.Hero? { hero(of: node) }

    /// Met le combattant en garde (planche bouclier). `false` si son pack
    /// n'en fournit pas — l'appelant garde alors son propre effet de parade.
    @discardableResult
    static func playGuard(on node: SKNode) -> Bool {
        guard let h = hero(of: node) else { return false }
        return BattleSprites.playWard(hero: h, on: node)
    }

    /// Traduit un node de combat en héros de `BattleSprites` d'après son nom.
    private static func hero(of node: SKNode) -> BattleSprites.Hero? {
        switch node.name {
        case "combatKael": return .kael
        case "combatLyra": return .lyra
        case "combatEran": return .eran
        default: return nil
        }
    }

    /// Compteur d'enchaînement par node : le pack fighter fournit trois
    /// attaques, on les alterne au lieu de rejouer la même à chaque coup.
    private static var chainStep: [ObjectIdentifier: Int] = [:]

    /// Joue l'attaque du héros/allié ; retombe sur l'idle à la fin.
    /// Sans effet si le node n'est pas un héros à pack (ennemis, boss).
    static func playHeroAttack(on node: SKNode, completion: (() -> Void)? = nil) {
        guard let h = hero(of: node) else { completion?(); return }
        var clip: BattleSprites.Clip = .attack
        // L'enchaînement appartient au pack, pas au personnage : il suit le
        // fighter chez qui il est dessiné, quel que soit celui qui le porte.
        if h.pack.hasAttackChain {
            // attack1 → attack2 → attack3 → attack1…
            let key = ObjectIdentifier(node)
            let step = (chainStep[key] ?? 0) % 3
            chainStep[key] = step + 1
            clip = [.attack, .attack2, .attack3][step]
        }
        BattleSprites.play(clip, hero: h, on: node, completion: completion)
    }

    /// Joue un sort (0 = skill1, 1 = skill2).
    static func playHeroSkill(on node: SKNode, index: Int,
                              completion: (() -> Void)? = nil) {
        guard let h = hero(of: node) else { completion?(); return }
        BattleSprites.play(index == 0 ? .skill1 : .skill2, hero: h, on: node,
                           completion: completion)
    }

    /// Nettoie les compteurs d'enchaînement (fin de combat) — et remet
    /// l'Archiviste au bleu, sinon il rouvrirait le combat suivant dans la
    /// teinte où le précédent s'est arrêté.
    static func resetChains() {
        chainStep.removeAll()
        resetArchivist()
    }

    // MARK: - Enemy factory

    static func enemy(kind: CombatSpriteKind) -> SKNode {
        let root = SKNode()
        root.name = "combatEnemy"
        addShadow(to: root, width: enemyShadowWidth(kind))

        // Sprites pixel art animés (frames 48×96 extraites des sheets
        // Modern Exteriors). Les boss (guardian, archivist) gardent leurs
        // silhouettes programmatiques uniques. Fallback shape si asset
        // manquant.
        if let config = pixelSprite(for: kind),
           let sprite = PixelArtSprites.animated(
               name: config.name,
               frames: frameCount(kind, attack: false),
               scale: targetHeight(kind).map {
                   PixelArtSprites.scale(name: "\(config.name)_idle_1", height: $0)
               } ?? 1.7,
               timePerFrame: 0.16,
               anchor: CGPoint(x: 0.5, y: 0.0)) {
            sprite.name = "enemyBody"
            sprite.position = CGPoint(x: 0, y: -34)
            if let tint = config.tint {
                sprite.forEachDescendantSprite { s in
                    s.color = tint
                    s.colorBlendFactor = 0.38
                }
            }
            root.addChild(sprite)
            return root
        }

        switch kind {
        case .beast, .ghoul: buildBeast(into: root)
        case .wolf, .boneWalker: buildWolf(into: root)
        case .guardian:      buildGuardian(into: root)
        case .ruinsGuardian: buildRuinsGuardian(into: root)
        case .archivist:     buildArchivist(into: root)
        }
        return root
    }

    /// Joue les frames d'attaque (row "marche/agression" des sheets ME)
    /// une fois, puis reprend la boucle idle. Silencieux si pas d'assets.
    static func playAttackFrames(on node: SKNode, kind: CombatSpriteKind) {
        // L'Archiviste vire à l'état suivant AVANT de frapper : le coup part
        // déjà dans la nouvelle couleur, et il la garde ensuite au repos.
        // Virer après l'attaque aurait donné un changement qui arrive « une
        // fois de trop », sans lien lisible avec le coup qu'on vient de voir.
        if kind == .archivist { advanceArchivist() }
        guard let config = pixelSprite(for: kind) else { return }

        func textures(_ clip: String, _ count: Int) -> [SKTexture] {
            (1...count).compactMap { i -> SKTexture? in
                let n = "\(config.name)_\(clip)_\(i)"
                guard UIImage(named: n) != nil else { return nil }
                let t = SKTexture(imageNamed: n)
                t.filteringMode = .nearest
                return t
            }
        }
        let attackCount = frameCount(kind, attack: true)
        let idleCount = frameCount(kind, attack: false)
        let attack = textures("attack", attackCount)
        let idle = textures("idle", idleCount)
        guard attack.count == attackCount, idle.count == idleCount else { return }

        node.forEachDescendantSprite { sprite in
            sprite.removeAllActions()
            sprite.run(.sequence([
                .animate(with: attack, timePerFrame: 0.07, resize: false, restore: false),
                .run {
                    sprite.run(.repeatForever(.animate(with: idle, timePerFrame: 0.16,
                                                       resize: false, restore: true)))
                }
            ]))
        }
    }

    /// Asset pixel art + teinte optionnelle par type d'ennemi.
    private static func pixelSprite(for kind: CombatSpriteKind)
        -> (name: String, tint: SKColor?)? {
        switch kind {
        case .beast:
            return ("enemy_beast", nil)
        case .wolf:
            // "Loup d'ombre" : même créature, noyée d'ombre violette.
            return ("enemy_shadewolf",
                    SKColor(red: 0.22, green: 0.10, blue: 0.38, alpha: 1))
        case .ruinsGuardian:
            return ("enemy_bone", nil)
        case .ghoul:
            // Goule : chair corrompue, teinte maladive
            return ("enemy_ghoul",
                    SKColor(red: 0.25, green: 0.38, blue: 0.16, alpha: 1))
        case .boneWalker:
            // Mêmes frames que le squelette des ruines, os bleuis d'usure
            return ("enemy_bone",
                    SKColor(red: 0.35, green: 0.42, blue: 0.58, alpha: 1))
        case .archivist:
            // L'Archiviste est une créature d'Aether liquide : il n'a pas de
            // teinte appliquée, il EST de sa couleur, et il en change à
            // chaque assaut (cf. `archivistTint`). Ses planches sont déjà
            // colorées — teinter par-dessus effacerait justement le cycle.
            return (archivistPrefix, nil)
        case .guardian:
            return nil   // boss Acte I → statue d'ange animée (cas dédié)
        }
    }

    // MARK: - Archiviste : le boss qui change d'état

    /// Les trois états de l'Archiviste, dans l'ordre où il les traverse.
    /// Bleu au repos, vert quand il s'échauffe, violet quand il déchaîne
    /// l'Aether — le joueur lit sa montée en puissance à la couleur, sans
    /// une ligne de texte.
    static let archivistTints = ["enemy_archivist_blue",
                                 "enemy_archivist_green",
                                 "enemy_archivist_violet"]
    private static var archivistTint = 0

    /// Préfixe de planches de l'état courant. Interne (et non privé) pour que
    /// les tests puissent constater le cycle sans lire des textures.
    static var archivistPrefix: String {
        archivistTints[archivistTint % archivistTints.count]
    }

    /// Fait virer l'Archiviste à l'état suivant. Appelé à chaque attaque.
    private static func advanceArchivist() { archivistTint += 1 }

    /// Remet le boss au bleu (nouveau combat).
    static func resetArchivist() { archivistTint = 0 }

    /// Nombre de frames par clip. Les ennemis ME en ont six ; l'Archiviste
    /// vient d'un autre pack et en a huit au repos, neuf à l'attaque.
    private static func frameCount(_ kind: CombatSpriteKind,
                                   attack: Bool) -> Int {
        switch kind {
        case .archivist: return attack ? 9 : 8
        default:         return 6
        }
    }

    /// Hauteur visée à l'écran, en points. `nil` = échelle historique 1.7
    /// appliquée au canevas 48×96 des planches ME.
    private static func targetHeight(_ kind: CombatSpriteKind) -> CGFloat? {
        // Canevas 74×80 contre 48×96 pour les autres : à échelle commune
        // l'Archiviste arrivait à mi-hauteur d'une goule. C'est un boss.
        kind == .archivist ? 210 : nil
    }

    // MARK: - Shadow / ground anchor

    private static func enemyShadowWidth(_ kind: CombatSpriteKind) -> CGFloat {
        switch kind {
        case .beast:         return 78
        case .wolf:          return 86
        case .guardian:      return 110
        case .ruinsGuardian: return 84
        case .archivist:     return 90
        case .ghoul:         return 70
        case .boneWalker:    return 70
        }
    }

    private static func addShadow(to root: SKNode, width: CGFloat) {
        let shadow = SKShapeNode(ellipseOf: CGSize(width: width, height: 12))
        shadow.fillColor = SKColor(white: 0, alpha: 0.45)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -34)
        shadow.zPosition = -2
        root.addChild(shadow)
    }

}
