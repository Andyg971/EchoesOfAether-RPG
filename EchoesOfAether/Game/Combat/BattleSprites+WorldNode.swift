import SpriteKit

// BattleSprites — le même héros à l'échelle du monde : marche, orientation, clips hors combat.
extension BattleSprites {
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

        let shadow = PixelShape.ellipse(size: CGSize(width: 24, height: 8),
                                        fill: SKColor(white: 0, alpha: 0.25), pixel: 2)
        shadow.position = CGPoint(x: 0, y: -15)
        shadow.zPosition = -1
        root.addChild(shadow)

        loop(.idle, hero: hero, on: root)
        return root
    }

    /// Met à jour la marche d'un node monde : `velocity` nul → idle.
    /// Ne fait rien si le node n'a pas de corps (silhouette de secours).
    static func updateWalk(_ hero: Hero, on root: SKNode, velocity: CGVector) {
        guard root.childNode(withName: "body") is SKSpriteNode else { return }
        let moving = abs(velocity.dx) > 0.5 || abs(velocity.dy) > 0.5
        loop(moving ? .move : .idle, hero: hero, on: root)
        // Orientation : seul un déplacement horizontal franc la change.
        if abs(velocity.dx) > 0.5 {
            face(hero, on: root, left: velocity.dx < 0)
        }
    }

    /// Tourne un node monde vers la gauche ou la droite, SANS le déplacer.
    ///
    /// Le miroir se fait autour du centre du CANEVAS ; comme le corps y est
    /// décalé, il faut retourner le décalage avec lui — sinon le personnage
    /// saute de côté à chaque demi-tour. Les cinématiques qui retournaient
    /// les sprites à la main (`xScale` seul) le faisaient bondir d'une
    /// centaine de points : c'est par ici qu'elles doivent passer.
    /// Renvoie `false` si le node n'a pas de corps de pack (repli à la main).
    @discardableResult
    static func face(_ hero: Hero, on root: SKNode, left: Bool) -> Bool {
        guard let body = root.childNode(withName: "body") as? SKSpriteNode else { return false }
        let mag = abs(body.xScale == 0 ? hero.worldScale : body.xScale)
        body.xScale = left ? -mag : mag
        let dx = hero.spriteOffset(scale: hero.worldScale, groundY: 0).x
        body.position.x = left ? -dx : dx
        return true
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
