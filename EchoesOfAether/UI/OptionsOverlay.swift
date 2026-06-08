import SpriteKit

@MainActor
final class OptionsOverlay {
    private let root = SKNode()
    private var sfxLabel: SKLabelNode?
    private var confirmDelete = false

    var onClose: (() -> Void)?
    var onDeleteSave: (() -> Void)?
    var onVolumeChange: ((Float) -> Void)?

    var isActive: Bool { root.parent != nil && !root.isHidden }

    // Volume 0.0–1.0 (visuel seulement, AudioEngine n'a pas encore de knob global)
    private(set) var sfxVolume: Float = 1.0

    func attach(to scene: SKScene) {
        root.zPosition = 1_600
        root.isHidden = true
        scene.addChild(root)
    }

    func show(in scene: SKScene) {
        root.removeAllChildren()
        root.isHidden = false
        confirmDelete = false

        let w = scene.size.width, h = scene.size.height

        // Fond
        let scrim = SKShapeNode(rectOf: scene.size)
        scrim.fillColor = SKColor(red: 0, green: 0, blue: 0, alpha: 0.80)
        scrim.strokeColor = .clear
        scrim.position = CGPoint(x: w / 2, y: h / 2)
        root.addChild(scrim)

        let panelW: CGFloat = 300, panelH: CGFloat = 440
        let panel = SKShapeNode(path: CGPath(
            roundedRect: CGRect(x: -panelW/2, y: -panelH/2, width: panelW, height: panelH),
            cornerWidth: 20, cornerHeight: 20, transform: nil))
        panel.fillColor = SKColor(red: 0.05, green: 0.05, blue: 0.10, alpha: 0.97)
        panel.strokeColor = SKColor(red: 0.45, green: 0.35, blue: 0.75, alpha: 0.8)
        panel.lineWidth = 2
        panel.position = CGPoint(x: w/2, y: h/2)
        root.addChild(panel)

        // Titre
        let title = label(String(localized: "options.title"), size: 22,
                          color: SKColor(red: 0.78, green: 0.68, blue: 1, alpha: 1))
        title.position = CGPoint(x: w/2, y: h/2 + panelH/2 - 40)
        root.addChild(title)

        // Section SFX Volume
        let sfxTitle = label(String(localized: "options.sfx"), size: 14,
                             color: SKColor(white: 0.65, alpha: 1))
        sfxTitle.position = CGPoint(x: w/2, y: h/2 + 80)
        root.addChild(sfxTitle)

        let sfxRow = makeVolumeRow(value: sfxVolume, at: CGPoint(x: w/2, y: h/2 + 50))
        root.addChild(sfxRow)

        // Séparateur
        let sep = SKShapeNode(rectOf: CGSize(width: panelW - 40, height: 1))
        sep.fillColor = SKColor(white: 0.20, alpha: 0.5)
        sep.strokeColor = .clear
        sep.position = CGPoint(x: w/2, y: h/2 + 18)
        root.addChild(sep)

        // Section Langue — sélecteur FR / EN
        let langTitle = label(String(localized: "options.language"), size: 14,
                              color: SKColor(white: 0.65, alpha: 1))
        langTitle.position = CGPoint(x: w/2, y: h/2 - 4)
        root.addChild(langTitle)

        let current = currentLanguageCode()
        let frBtn = makeLangButton("Français", code: "fr",
                                   selected: current == "fr", name: "langFR")
        frBtn.position = CGPoint(x: w/2 - 64, y: h/2 - 38)
        root.addChild(frBtn)

        let enBtn = makeLangButton("English", code: "en",
                                   selected: current == "en", name: "langEN")
        enBtn.position = CGPoint(x: w/2 + 64, y: h/2 - 38)
        root.addChild(enBtn)

        // Note redémarrage — cachée jusqu'au changement
        let restart = label(String(localized: "options.language.restart"), size: 11,
                            color: SKColor(red: 0.95, green: 0.75, blue: 0.35, alpha: 1))
        restart.position = CGPoint(x: w/2, y: h/2 - 64)
        restart.name = "langRestart"
        restart.isHidden = true
        root.addChild(restart)

        // Séparateur 2
        let sep2 = SKShapeNode(rectOf: CGSize(width: panelW - 40, height: 1))
        sep2.fillColor = SKColor(white: 0.20, alpha: 0.4)
        sep2.strokeColor = .clear
        sep2.position = CGPoint(x: w/2, y: h/2 - 86)
        root.addChild(sep2)

        // Bouton Reset
        let resetBtn = makeButton(String(localized: "options.resetSave"),
            fill: SKColor(red: 0.16, green: 0.05, blue: 0.05, alpha: 1),
            stroke: SKColor(red: 0.65, green: 0.18, blue: 0.18, alpha: 0.9),
            name: "optionsReset")
        resetBtn.position = CGPoint(x: w/2, y: h/2 - 124)
        root.addChild(resetBtn)

        // Bouton Fermer
        let closeBtn = makeButton(String(localized: "options.close"),
            fill: SKColor(red: 0.10, green: 0.10, blue: 0.18, alpha: 1),
            stroke: SKColor(red: 0.40, green: 0.35, blue: 0.65, alpha: 0.8),
            name: "optionsClose")
        closeBtn.position = CGPoint(x: w/2, y: h/2 - 184)
        root.addChild(closeBtn)

        // Animate
        panel.alpha = 0; panel.run(.fadeIn(withDuration: 0.2))
        for (i, child) in root.children.enumerated() where child !== scrim {
            JuiceEngine.popIn(child, delay: Double(i) * 0.04)
        }
    }

    func hide() {
        root.isHidden = true
        root.removeAllChildren()
        confirmDelete = false
    }

    func handleTap(at point: CGPoint, in scene: SKScene) -> Bool {
        guard isActive else { return false }
        let local = root.convert(point, from: scene)

        if let btn = root.childNode(withName: "sfxDown") as? SKShapeNode, btn.contains(local) {
            sfxVolume = max(0, sfxVolume - 0.25)
            refreshVolumeDisplay()
            HapticsEngine.light()
            onVolumeChange?(sfxVolume)
            return true
        }
        if let btn = root.childNode(withName: "sfxUp") as? SKShapeNode, btn.contains(local) {
            sfxVolume = min(1, sfxVolume + 0.25)
            refreshVolumeDisplay()
            HapticsEngine.light()
            onVolumeChange?(sfxVolume)
            return true
        }
        if let btn = root.childNode(withName: "langFR") as? SKShapeNode, btn.contains(local) {
            selectLanguage("fr")
            return true
        }
        if let btn = root.childNode(withName: "langEN") as? SKShapeNode, btn.contains(local) {
            selectLanguage("en")
            return true
        }
        if let btn = root.childNode(withName: "optionsReset") as? SKShapeNode, btn.contains(local) {
            handleReset(btn: btn)
            return true
        }
        if let btn = root.childNode(withName: "optionsClose") as? SKShapeNode, btn.contains(local) {
            HapticsEngine.light()
            onClose?()
            return true
        }
        return true
    }

    // MARK: - Language

    /// Code langue actif (fr/en) — basé sur la localisation résolue du bundle.
    private func currentLanguageCode() -> String {
        if let override = UserDefaults.standard.stringArray(forKey: "AppleLanguages")?.first {
            return override.hasPrefix("en") ? "en" : "fr"
        }
        return (Bundle.main.preferredLocalizations.first ?? "fr").hasPrefix("en") ? "en" : "fr"
    }

    /// Persiste la langue choisie. iOS charge le bundle au lancement :
    /// effectif au prochain démarrage (on l'indique au joueur).
    private func selectLanguage(_ code: String) {
        HapticsEngine.light()
        guard code != currentLanguageCode() else { return }
        UserDefaults.standard.set([code], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
        // Met à jour la sélection visuelle + affiche la note de redémarrage
        refreshLangSelection(selected: code)
        if let restart = root.childNode(withName: "langRestart") {
            restart.isHidden = false
            JuiceEngine.popIn(restart, delay: 0)
        }
    }

    private func refreshLangSelection(selected: String) {
        for (name, code) in [("langFR", "fr"), ("langEN", "en")] {
            guard let btn = root.childNode(withName: name) as? SKShapeNode else { continue }
            styleLangButton(btn, selected: code == selected)
        }
    }

    private func makeLangButton(_ text: String, code: String,
                                selected: Bool, name: String) -> SKShapeNode {
        let btn = SKShapeNode(rectOf: CGSize(width: 112, height: 40), cornerRadius: 12)
        btn.name = name
        let lbl = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        lbl.text = text
        lbl.fontSize = 14
        lbl.verticalAlignmentMode = .center
        lbl.horizontalAlignmentMode = .center
        lbl.isUserInteractionEnabled = false
        lbl.name = "label"
        btn.addChild(lbl)
        styleLangButton(btn, selected: selected)
        return btn
    }

    private func styleLangButton(_ btn: SKShapeNode, selected: Bool) {
        if selected {
            btn.fillColor = SKColor(red: 0.30, green: 0.22, blue: 0.50, alpha: 1)
            btn.strokeColor = SKColor(red: 0.70, green: 0.58, blue: 1.0, alpha: 1)
            btn.lineWidth = 2
        } else {
            btn.fillColor = SKColor(red: 0.10, green: 0.08, blue: 0.16, alpha: 1)
            btn.strokeColor = SKColor(red: 0.40, green: 0.35, blue: 0.60, alpha: 0.7)
            btn.lineWidth = 1.5
        }
        (btn.childNode(withName: "label") as? SKLabelNode)?.fontColor =
            selected ? .white : SKColor(white: 0.60, alpha: 1)
    }

    // MARK: - Private

    private func handleReset(btn: SKShapeNode) {
        if confirmDelete {
            HapticsEngine.error()
            onDeleteSave?()
        } else {
            confirmDelete = true
            HapticsEngine.heavy()
            // Change bouton en rouge confirmation
            btn.strokeColor = SKColor(red: 0.90, green: 0.15, blue: 0.10, alpha: 1)
            if let lbl = btn.children.first as? SKLabelNode {
                lbl.text = String(localized: "options.resetSave.confirm")
                lbl.fontColor = SKColor(red: 1, green: 0.3, blue: 0.2, alpha: 1)
            }
        }
    }

    private func refreshVolumeDisplay() {
        guard let lbl = sfxLabel else { return }
        lbl.text = volumeString(sfxVolume)
    }

    private func volumeString(_ v: Float) -> String {
        let filled = Int(v * 4)
        let blocks = String(repeating: "█", count: filled) + String(repeating: "░", count: 4 - filled)
        return blocks
    }

    private func makeVolumeRow(value: Float, at pos: CGPoint) -> SKNode {
        let container = SKNode()
        container.position = pos

        let downBtn = makeSmallButton("◀", name: "sfxDown")
        downBtn.position = CGPoint(x: -70, y: 0)
        container.addChild(downBtn)

        let upBtn = makeSmallButton("▶", name: "sfxUp")
        upBtn.position = CGPoint(x: 70, y: 0)
        container.addChild(upBtn)

        let volLabel = SKLabelNode(fontNamed: "Courier-Bold")
        volLabel.text = volumeString(value)
        volLabel.fontSize = 18
        volLabel.fontColor = SKColor(red: 0.55, green: 0.80, blue: 0.55, alpha: 1)
        volLabel.horizontalAlignmentMode = .center
        volLabel.verticalAlignmentMode = .center
        container.addChild(volLabel)
        sfxLabel = volLabel

        return container
    }

    private func makeSmallButton(_ text: String, name: String) -> SKShapeNode {
        let btn = SKShapeNode(circleOfRadius: 18)
        btn.fillColor = SKColor(red: 0.10, green: 0.08, blue: 0.18, alpha: 1)
        btn.strokeColor = SKColor(red: 0.45, green: 0.35, blue: 0.70, alpha: 0.8)
        btn.lineWidth = 1.5
        btn.name = name
        let lbl = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        lbl.text = text
        lbl.fontSize = 14
        lbl.fontColor = .white
        lbl.verticalAlignmentMode = .center
        lbl.horizontalAlignmentMode = .center
        lbl.isUserInteractionEnabled = false
        btn.addChild(lbl)
        return btn
    }

    private func makeButton(_ text: String, fill: SKColor, stroke: SKColor, name: String) -> SKShapeNode {
        let btn = SKShapeNode(rectOf: CGSize(width: 220, height: 46), cornerRadius: 14)
        btn.fillColor = fill
        btn.strokeColor = stroke
        btn.lineWidth = 1.8
        btn.name = name
        let lbl = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        lbl.text = text
        lbl.fontSize = 14
        lbl.fontColor = .white
        lbl.verticalAlignmentMode = .center
        lbl.horizontalAlignmentMode = .center
        lbl.isUserInteractionEnabled = false
        btn.addChild(lbl)
        return btn
    }

    private func label(_ text: String, size: CGFloat, color: SKColor) -> SKLabelNode {
        let l = SKLabelNode(fontNamed: "AvenirNext-Medium")
        l.text = text
        l.fontSize = size
        l.fontColor = color
        l.horizontalAlignmentMode = .center
        return l
    }
}
