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

    // MARK: - Textures

    /// Textures d'un clip, en `.nearest` (charte pixel : jamais de lissage).
    /// Vide si le pack ne fournit pas ce clip — l'appelant retombe sur l'idle.
    /// - Parameter prefix: variante de planche à charger à la place de celle
    ///   du pack (le wizard fournit un jeu complet BOUCLIER AU BRAS, cf.
    ///   `Hero.wardPrefix`). Même canevas, mêmes clips : rien d'autre à recaler.
    static func textures(_ hero: Hero, _ clip: Clip,
                         prefix: String? = nil) -> [SKTexture] {
        let count = clip.frames(for: hero)
        guard count > 0 else { return [] }
        let group = clip.assetGroup(for: hero)
        return (1...count).compactMap { i in
            let name = "\(prefix ?? hero.prefix)_\(group)_\(i)"
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

    /// Passe le personnage EN GARDE le temps d'encaisser : il lève son
    /// bouclier (planche `wardPrefix`), puis revient au repos.
    ///
    /// Sans planche bouclier — Kael, Lyra — la fonction ne fait rien et
    /// l'appelant garde son éclat de parade : personne ne mime une garde
    /// avec des mains vides.
    @discardableResult
    static func playWard(hero: Hero, on root: SKNode,
                         duration: TimeInterval = 0.7) -> Bool {
        guard let wardPrefix = hero.wardPrefix,
              let body = root.childNode(withName: "body") as? SKSpriteNode
        else { return false }
        let ward = textures(hero, .idle, prefix: wardPrefix)
        guard !ward.isEmpty else { return false }

        body.removeAction(forKey: "clip")
        // On efface le clip mémorisé, sinon `loop(.idle)` se croit déjà en
        // idle au retour et laisse le bouclier levé pour le reste du combat.
        body.userData?["clip"] = "ward"
        body.run(.sequence([
            .repeat(.animate(with: ward, timePerFrame: 0.12,
                             resize: false, restore: true),
                    count: max(1, Int(duration / (0.12 * Double(ward.count))))),
            .run { [weak root] in
                guard let root else { return }
                body.userData?["clip"] = nil
                loop(.idle, hero: hero, on: root)
            }
        ]), withKey: "clip")
        return true
    }

}
