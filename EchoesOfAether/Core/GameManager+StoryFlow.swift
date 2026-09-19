import SpriteKit

// Fil narratif : enchaînement des phases, prologue.
// Extrait de GameManager.swift (découpage du monolithe).
@MainActor
extension GameManager {
    // MARK: - Story Flow

    func startWakeSequence() {
        transition(to: .dialogue)
        phase = .wake
        hud.objectiveText = String(localized: "hud.objective.lyra")
        if let scene {
            world.placeLyraBesideKael(in: scene.size)
            showPrologue(in: scene) { [weak self] in self?.startWakeDialogue() }
        } else {
            startWakeDialogue()
        }
    }

    func startWakeDialogue() {
        dialogue.start(PrototypeContent.wakeDialogue) { [weak self] in
            guard let self else { return }
            phase = .village
            hud.objectiveText = String(localized: "hud.objective.village")
            transition(to: .exploration)
            maybeShowTutorial()
        }
    }

    // MARK: - Prologue (cinématique d'ouverture)

    /// Écran noir + lore de la Source, ligne par ligne. Tap pour passer.
    func showPrologue(in scene: SKScene, completion: @escaping () -> Void) {
        let overlay = SKNode()
        overlay.zPosition = 3_000

        let black = SKSpriteNode(color: .black, size: CGSize(width: scene.size.width + 4,
                                                             height: scene.size.height + 4))
        black.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        overlay.addChild(black)

        let keys = ["prologue.line1", "prologue.line2", "prologue.line3",
                    "prologue.line4", "prologue.line5"]
        var delay: TimeInterval = 0.8
        for key in keys {
            let label = SKLabelNode(fontNamed: PixelUI.uiFont)
            label.text = String(localized: String.LocalizationValue(key))
            label.fontSize = 19
            label.fontColor = SKColor(red: 0.82, green: 0.76, blue: 0.92, alpha: 1)
            label.numberOfLines = 3
            label.preferredMaxLayoutWidth = min(scene.size.width - 96, 560)
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            label.position = CGPoint(x: scene.size.width / 2, y: scene.size.height * 0.52)
            label.alpha = 0
            overlay.addChild(label)
            label.run(.sequence([
                .wait(forDuration: delay),
                .fadeIn(withDuration: 0.8),
                .wait(forDuration: 2.3),
                .fadeOut(withDuration: 0.6)
            ]))
            delay += 3.8
        }

        let skip = SKLabelNode(fontNamed: PixelUI.uiFont)
        skip.text = String(localized: "prologue.skip")
        skip.fontSize = 12
        skip.fontColor = SKColor(white: 0.5, alpha: 0.8)
        skip.horizontalAlignmentMode = .center
        skip.position = CGPoint(x: scene.size.width / 2, y: 26)
        overlay.addChild(skip)

        overlay.run(.sequence([
            .wait(forDuration: delay + 0.4),
            .run { [weak self] in self?.endPrologue() }
        ]))

        scene.addChild(overlay)
        prologueNode = overlay
        prologueCompletion = completion
        AudioEngine.shared.playSelect()
    }

    func endPrologue() {
        guard let node = prologueNode else { return }
        prologueNode = nil
        let done = prologueCompletion
        prologueCompletion = nil
        node.run(.sequence([.fadeOut(withDuration: 0.5), .removeFromParent()]))
        done?()
    }

    /// Affiche le tutoriel à la première partie (flag UserDefaults).
    func maybeShowTutorial() {
        guard let scene else { return }
        guard !UserDefaults.standard.bool(forKey: TutorialOverlay.seenKey) else { return }
        tutorial.show(in: scene)
    }

    /// Relance le tutoriel (depuis les Options), quel que soit le flag.
    func replayTutorial() {
        guard let scene else { return }
        options.hide()
        pause.hide()
        tutorial.show(in: scene)
    }

    /// Re-dispose HUD + dialogue après un changement d'accessibilité (gros texte).
    func relayoutForAccessibility() {
        if let l = lastLayout {
            layout(size: l.size, safeTop: l.top, safeBottom: l.bottom,
                   safeLeft: l.left, safeRight: l.right)
        } else if let scene {
            if let last = lastLayout {
                hud.layout(in: last.size, safeTop: last.top,
                           safeLeft: last.left, safeRight: last.right)
            } else {
                hud.layout(in: scene.size)
            }
            dialogue.layout(in: scene.size)
        }
    }
}
