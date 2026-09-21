import SpriteKit

// InventoryOverlay — fabrique des lignes (section, objet, quête) et noms d'équipement.
extension InventoryOverlay {
    // MARK: - Row Builders

    func addSection(_ text: String, y: CGFloat) -> CGFloat {
        let sectionLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
        sectionLabel.text = text
        sectionLabel.fontSize = 17
        sectionLabel.fontColor = SKColor(red: 0.60, green: 0.50, blue: 0.85, alpha: 0.8)
        sectionLabel.horizontalAlignmentMode = .left
        sectionLabel.position = CGPoint(x: bordGauche + 24, y: y - 6)
        root.addChild(sectionLabel)
        statLabels.append(sectionLabel)

        // Filet sous le titre de section. Il est enfant du label, donc en
        // coordonnées LOCALES : l'ancien `y - 18` y réinjectait une valeur du
        // repère du panneau, ce qui envoyait le filet à `2y - 24` — hors du
        // panneau pour toute section un peu haute, donc invisible. Le décalage
        // voulu était simplement 18 pt sous la ligne de base.
        let div = SKShapeNode(rectOf: CGSize(width: largeurColonne - 40, height: 1))
        div.fillColor = SKColor(white: 0.18, alpha: 0.5)
        div.strokeColor = .clear
        div.position = CGPoint(x: largeurColonne / 2 - 24, y: -12)
        sectionLabel.addChild(div)

        return y - 28
    }

    func addRow(icon: PixelIcons.Kind, label: String, detail: String,
                        y: CGFloat, lineH: CGFloat,
                        color: SKColor = .white) -> CGFloat {
        let iconNode = PixelIcons.node(icon, pixel: 2)
        iconNode.position = CGPoint(x: bordGauche + 32, y: y + 2)
        root.addChild(iconNode)
        statLabels.append(iconNode)
        return addLabels(label: label, detail: detail, y: y, lineH: lineH, color: color)
    }

    /// Libellé + valeur d'une ligne (sans icône) : partagé entre addRow
    /// et addQuestRow.
    func addLabels(label: String, detail: String,
                           y: CGFloat, lineH: CGFloat,
                           color: SKColor) -> CGFloat {
        let nameLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
        nameLabel.text = label
        nameLabel.fontSize = 18
        nameLabel.fontColor = SKColor(white: 0.85, alpha: 1)
        nameLabel.horizontalAlignmentMode = .left
        nameLabel.position = CGPoint(x: bordGauche + 52, y: y - 4)
        root.addChild(nameLabel)
        statLabels.append(nameLabel)

        let detailLabel = SKLabelNode(fontNamed: PixelUI.uiFont)
        detailLabel.text = detail
        detailLabel.fontSize = 18
        detailLabel.fontColor = color
        detailLabel.horizontalAlignmentMode = .right
        detailLabel.position = CGPoint(x: bordGauche + largeurColonne - 24, y: y - 4)
        root.addChild(detailLabel)
        statLabels.append(detailLabel)

        return y - lineH
    }

    func addQuestRow(label: String,
                             state: QuestState, y: CGFloat, lineH: CGFloat) -> CGFloat {
        let color: SKColor
        switch state {
        case .inactive: color = SKColor(white: 0.40, alpha: 1)
        case .active:   color = SKColor(red: 0.90, green: 0.80, blue: 0.35, alpha: 1)
        // Objet en poche, donneur pas encore prévenu : ambre, entre le jaune
        // « en cours » et le vert « terminée ».
        case .found:    color = SKColor(red: 0.95, green: 0.60, blue: 0.25, alpha: 1)
        case .complete: color = SKColor(red: 0.40, green: 0.80, blue: 0.45, alpha: 1)
        }
        let stateLabel: String
        switch state {
        case .inactive: stateLabel = String(localized: "quest.state.inactive")
        case .active:   stateLabel = String(localized: "quest.state.active")
        case .found:    stateLabel = String(localized: "quest.state.found")
        case .complete: stateLabel = String(localized: "quest.state.complete")
        }
        // Puce d'état pixel : carré plein coloré selon l'état (cohérent
        // avec le journal de quêtes).
        let chip = SKSpriteNode(color: color, size: CGSize(width: 8, height: 8))
        chip.position = CGPoint(x: bordGauche + 32, y: y + 2)
        root.addChild(chip)
        statLabels.append(chip)
        return addLabels(label: label, detail: stateLabel,
                         y: y, lineH: lineH, color: color)
    }

    // MARK: - Equipment Names

    func weaponName(_ level: Int) -> String {
        switch level {
        case 0: return String(localized: "inventory.weapon.fists")
        case 1: return String(localized: "inventory.weapon.ironBlade")
        case 2: return String(localized: "inventory.weapon.runicBlade")
        default: return String(localized: "inventory.weapon.aetheriteBlade")
        }
    }

    func armorName(_ level: Int) -> String {
        switch level {
        case 0: return String(localized: "inventory.armor.none")
        case 1: return String(localized: "inventory.armor.chainMail")
        case 2: return String(localized: "inventory.armor.reinforced")
        default: return String(localized: "inventory.armor.aetheritePlate")
        }
    }
}
