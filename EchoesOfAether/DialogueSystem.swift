import SpriteKit
import UIKit

struct DialogueChoice {
    let title: String
    let responseSpeaker: String
    let response: String
}

enum DialogueStep {
    case line(speaker: String, text: String)
    case choice(prompt: String, options: [DialogueChoice])
}

@MainActor
final class DialogueSystem {
    let root = SKNode()
    let panel = SKShapeNode()
    let separator = SKShapeNode()          // trait fin sous le nom
    let portraitFrame = SKShapeNode()      // cadre pixel du portrait
    let portraitSprite = SKSpriteNode()    // visage du locuteur
    var hasPortrait = false
    let speakerLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
    let bodyLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
    let continueIndicator = SKLabelNode(fontNamed: PixelUI.uiFont)
    var choiceNodes: [SKShapeNode] = []
    /// Hauteur réelle de chaque bouton de choix (28pt, ou plus si le titre
    /// passe sur 2 lignes) — tient le texte au lieu de le laisser déborder
    /// du cadre sur un bouton voisin.
    var choiceHeights: [CGFloat] = []
    var choiceSelection = 0   // curseur sur les choix (A valide)
    private var steps: [DialogueStep] = []
    var index = 0
    /// Index du choix déjà résolu — B (skip) ne doit pas le re-poser.
    var answeredChoiceIndex = -1
    var pendingNPC: (speaker: String, text: String)?
    private var completion: (() -> Void)?
    private var hasAnimatedEntrance = false

    /// Index du dernier choix sélectionné dans une étape `.choice` (nil tant
    /// qu'aucun choix n'a été fait). Permet de rendre un choix déterminant.
    var lastChoiceIndex: Int?
    /// Callback déclenché quand le joueur sélectionne un choix (index 0-based).
    var onChoiceSelected: ((Int) -> Void)?

    let panelHeightLine: CGFloat = 72
    var safeBottom: CGFloat = 0

    var isActive: Bool { root.parent != nil && !root.isHidden }

    func attach(to scene: SKScene) {
        root.zPosition = 1_000
        root.isHidden = true
        scene.addChild(root)

        panel.fillColor = PixelUI.panelFill
        panel.strokeColor = PixelUI.gold
        panel.lineWidth = 2
        root.addChild(panel)

        // Portrait pixel du locuteur : cadre carré à gauche du panneau
        portraitFrame.zPosition = 2
        root.addChild(portraitFrame)
        portraitSprite.texture?.filteringMode = .nearest
        portraitSprite.zPosition = 3
        root.addChild(portraitSprite)

        speakerLabel.horizontalAlignmentMode = .left
        speakerLabel.fontSize = 11
        speakerLabel.fontColor = .white
        root.addChild(speakerLabel)

        separator.strokeColor = PixelUI.goldDim
        separator.lineWidth = 1
        root.addChild(separator)

        bodyLabel.horizontalAlignmentMode = .left
        bodyLabel.verticalAlignmentMode = .top
        bodyLabel.fontSize = 10
        bodyLabel.fontColor = SKColor(white: 0.94, alpha: 1)
        bodyLabel.numberOfLines = 0
        root.addChild(bodyLabel)

        continueIndicator.text = "A ▼"
        continueIndicator.fontSize = 9
        continueIndicator.fontColor = PixelUI.gold
        continueIndicator.horizontalAlignmentMode = .right
        continueIndicator.isHidden = true
        root.addChild(continueIndicator)

        layout(in: scene.size)
    }

    func start(_ steps: [DialogueStep], completion: (() -> Void)? = nil) {
        // Audit visuel : --skip-dialogue court-circuite tout dialogue
        // (utile avec --boss-test/--fx-demo pour filmer les effets).
        if CommandLine.arguments.contains("--skip-dialogue") {
            completion?()
            return
        }
        self.steps = steps
        self.index = 0
        self.answeredChoiceIndex = -1
        self.pendingNPC = nil
        self.lastChoiceIndex = nil
        self.completion = completion
        root.isHidden = false
        // Le contenu d'abord (layout → hauteur/position correctes), puis
        // l'animation d'entrée qui glisse vers cette position au repos.
        showCurrentStep()
        playEntranceAnimation()
    }

    private func playEntranceAnimation() {
        guard let sceneRef = root.scene, !root.isHidden else { return }
        let restY = root.position.y
        // Accessibilité : fondu seul, sans glissement vertical.
        if AccessibilitySettings.reduceMotion {
            root.alpha = 0
            root.run(.fadeIn(withDuration: 0.18))
            hasAnimatedEntrance = true
            return
        }
        root.position = CGPoint(x: root.position.x, y: restY - 40)
        root.alpha = 0
        root.run(.group([
            .fadeIn(withDuration: 0.22),
            .move(to: CGPoint(x: sceneRef.size.width / 2, y: restY), duration: 0.28)
        ]))
        hasAnimatedEntrance = true
    }

    func handleTap(at point: CGPoint, in scene: SKScene) -> Bool {
        guard isActive, !root.isHidden else { return false }
        let local = root.convert(point, from: scene)

        if !choiceNodes.isEmpty {
            for (i, node) in choiceNodes.enumerated() where node.contains(local) {
                choiceSelection = i
                refreshChoiceHighlight()
                confirmChoice()
                return true
            }
            return true   // pas de skip accidentel pendant un choix
        }

        if panel.contains(local) {
            advance()
            return true
        }
        return true   // absorbe le reste (modal)
    }


    /// Bouton A : valide le choix sélectionné s'il y en a, sinon avance
    /// d'une réplique (ou affiche la réaction du PNJ après un choix).
    func advance() {
        guard isActive else { return }
        guard choiceNodes.isEmpty else { confirmChoice(); return }

        if let npc = pendingNPC {
            pendingNPC = nil
            speakerLabel.text = npc.speaker
            applyPortrait(for: npc.speaker)
            bodyLabel.text = npc.text
            continueIndicator.isHidden = false
            AccessibilitySettings.announce("\(npc.speaker). \(npc.text)")
            if let sceneRef = root.scene {
                layout(in: sceneRef.size, safeBottom: safeBottom)
            }
            // index reste sur le choix : le prochain A affiche bien
            // l'étape SUIVANTE (avant, elle était sautée — off-by-one).
            return
        }

        index += 1
        showCurrentStep()
        if let sceneRef = root.scene {
            layout(in: sceneRef.size, safeBottom: safeBottom)
        }
    }

    /// Bouton B : passe les répliques jusqu'au prochain CHOIX (qui exige
    /// une décision du joueur) ou jusqu'à la fin de la conversation.
    func skipToEnd() {
        guard isActive, choiceNodes.isEmpty else { return }
        // Au milieu de la résolution d'un choix (titre/réaction affichés) :
        // le choix courant est déjà répondu, on reprend après lui.
        if index == answeredChoiceIndex { index += 1 }
        pendingNPC = nil
        while index < steps.count {
            if case .choice = steps[index] { break }
            index += 1
        }
        showCurrentStep()
        if let sceneRef = root.scene {
            layout(in: sceneRef.size, safeBottom: safeBottom)
        }
    }

    private func showCurrentStep() {
        clearChoices()

        guard index < steps.count else {
            root.isHidden = true
            // La completion peut relancer un dialogue enchaîné (Lyra → quête) :
            // start() y stocke SA completion. La vider APRÈS l'appel écraserait
            // celle du nouveau dialogue → soft-lock en state .dialogue.
            let done = completion
            completion = nil
            done?()
            return
        }

        switch steps[index] {
        case let .line(speaker, text):
            speakerLabel.text = speaker
            applyPortrait(for: speaker)
            bodyLabel.text = text
            continueIndicator.isHidden = false
            AccessibilitySettings.announce("\(speaker). \(text)")

        case let .choice(prompt, options):
            // Le prompt sert de titre ; pas de body label pour éviter
            // la collision avec les boutons de choix.
            speakerLabel.text = prompt
            applyPortrait(for: prompt)
            bodyLabel.text = ""
            continueIndicator.isHidden = true
            createChoices(options)
            let list = options.enumerated()
                .map { "\($0.offset + 1). \($0.element.title)" }
                .joined(separator: ", ")
            AccessibilitySettings.announce(
                String(localized: "a11y.dialogue.choices \(prompt) \(list)"))
        }

        // Le portrait peut apparaître/disparaître selon le locuteur.
        if let sceneRef = root.scene {
            layout(in: sceneRef.size, safeBottom: safeBottom)
        }
    }

}
