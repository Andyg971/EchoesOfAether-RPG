import SpriteKit

// Joystick virtuel flottant (quart bas-gauche) : capture, suivi, mouvement de Kael.
extension GameManager {
    // MARK: - Joystick virtuel (flottant, quart bas-gauche)

    /// Quart bas-gauche où poser le pouce fait apparaître le joystick.
    ///
    /// Exposé (et non codé en dur dans `padTouchBegan`) pour que les tests
    /// puissent vérifier qu'aucun bouton du HUD ne tombe dedans.
    static func padCaptureZone(in size: CGSize) -> CGRect {
        CGRect(x: 0, y: 0, width: size.width * 0.42, height: size.height * 0.60)
    }

    /// Le joueur pose le doigt en bas à gauche : le pad apparaît là.
    /// Retourne true si le touch est capturé par le pad.
    func padTouchBegan(at point: CGPoint, in scene: SKScene) -> Bool {
        // Exploration : déplacement. Menus (combat, dialogue, boutique,
        // pause…) : le même joystick navigue le curseur de sélection.
        //
        // Les icônes du HUD (journal de quêtes en tête) descendent dans le
        // quart du joystick : en exploration elles gardent la priorité, sinon
        // poser le doigt dessus sortait le joystick au lieu d'ouvrir le
        // panneau. Hors exploration le HUD ne répond plus aux taps (cf.
        // `handleTap`) : la zone revient entièrement au curseur.
        let hudPrioritaire = state == .exploration
            && hud.containsButton(at: point, in: scene)
        guard state != .transition, !worldMap.isActive,
              Self.padCaptureZone(in: scene.size).contains(point),
              !hudPrioritaire else { return false }
        if padBase.parent == nil {
            padBase.fillColor = SKColor(white: 0.9, alpha: 0.10)
            padBase.strokeColor = PixelUI.gold.withAlphaComponent(0.55)
            padBase.lineWidth = 2
            padBase.zPosition = 950
            scene.addChild(padBase)
            padKnob.fillColor = PixelUI.gold.withAlphaComponent(0.55)
            padKnob.strokeColor = PixelUI.gold
            padKnob.lineWidth = 1.5
            padKnob.zPosition = 951
            scene.addChild(padKnob)
        }
        padActive = true
        padOrigin = point
        padVector = .zero
        padBase.position = point
        padKnob.position = point
        padBase.alpha = 1
        padKnob.alpha = 1
        return true
    }

    func padTouchMoved(to point: CGPoint) {
        guard padActive else { return }
        var dx = point.x - padOrigin.x
        var dy = point.y - padOrigin.y
        let len = (dx * dx + dy * dy).squareRoot()
        let maxR: CGFloat = 34
        if len > maxR {
            dx = dx / len * maxR
            dy = dy / len * maxR
        }
        padKnob.position = CGPoint(x: padOrigin.x + dx, y: padOrigin.y + dy)
        let strength = min(1, len / maxR)
        padVector = len > 6
            ? CGVector(dx: dx / maxR * strength, dy: dy / maxR * strength)
            : .zero
    }

    func padTouchEnded() {
        guard padActive else { return }
        padActive = false
        padVector = .zero
        padBase.run(.fadeOut(withDuration: 0.15))
        padKnob.run(.fadeOut(withDuration: 0.15))
        movement.setManualWalk(world.kael, dx: 0, active: false)
    }

    func updatePadMovement(deltaTime: TimeInterval) {
        guard padActive, state == .exploration, deltaTime > 0,
              padVector != .zero, let scene else { return }
        let speed: CGFloat = 215
        let wh = world.worldHeight > 0 ? world.worldHeight : scene.size.height
        // Carte du monde : le déplacement s'étend aussi en X (scroll 2D).
        let ww = world.worldWidth > 0 ? world.worldWidth : scene.size.width
        // Coincé dans une empreinte : dégagé au point libre le plus proche.
        let current = world.nearestFreePoint(to: world.kael.position)
        var pos = current
        pos.x += padVector.dx * speed * CGFloat(deltaTime)
        pos.y += padVector.dy * speed * CGFloat(deltaTime)
        pos.x = min(max(pos.x, 34), ww - 34)
        pos.y = min(max(pos.y, 86), wh - 44)

        // Collisions : on ne traverse ni maisons ni arbres, sans exception.
        // Glissement le long des murs (axe par axe) pour un contrôle agréable.
        func blocked(_ p: CGPoint) -> Bool { world.isBlocked(p) }
        if blocked(pos) {
            let xOnly = CGPoint(x: pos.x, y: current.y)
            let yOnly = CGPoint(x: current.x, y: pos.y)
            if !blocked(xOnly) {
                pos = xOnly
            } else if !blocked(yOnly) {
                pos = yOnly
            } else {
                world.kael.position = current
                movement.setManualWalk(world.kael, dx: padVector.dx, active: true)
                return
            }
        }
        world.kael.position = pos
        world.refreshKaelDepth()
        movement.setManualWalk(world.kael, dx: padVector.dx, active: true)
    }
}
