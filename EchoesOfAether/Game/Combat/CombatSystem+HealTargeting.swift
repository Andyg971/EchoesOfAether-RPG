import SpriteKit

// Ciblage du soin : choix de la cible parmi le groupe.
// Extrait de CombatSystem.swift (découpage du monolithe).
@MainActor
extension CombatSystem {
    // MARK: - Ciblage du soin

    /// Cibles possibles d'un soin : Kael puis les alliés vivants, dans l'ordre
    /// où ils sont posés à l'écran. Chaque entrée porte sa position pour que le
    /// chevron sache où se placer.
    var healTargets: [(name: String, home: CGPoint, hp: Int, maxHP: Int)] {
    var list: [(String, CGPoint, Int, Int)] = [
        (kael.name, kaelHomePosition, kael.hp, kael.maxHP)
    ]
    for ally in aliveAllies {
        list.append((ally.combatant.name, ally.home,
                     ally.combatant.hp, ally.combatant.maxHP))
    }
    return list.map { (name: $0.0, home: $0.1, hp: $0.2, maxHP: $0.3) }
    }

    /// Applique le soin à la cible choisie par le joueur.
    func applyHeal(_ amount: Int, toIndex index: Int) -> CGPoint {
    if index == 0 {
        kael.hp = min(kael.maxHP, kael.hp + amount)
        return kaelHomePosition
    }
    let allies = aliveAllies
    guard allies.indices.contains(index - 1) else {
        kael.hp = min(kael.maxHP, kael.hp + amount)
        return kaelHomePosition
    }
    let ally = allies[index - 1]
    ally.combatant.hp = min(ally.combatant.maxHP, ally.combatant.hp + amount)
    return ally.home
    }

    /// Boutons de techniques de l'acteur courant — chacun son domaine.
    ///
    /// Kael est le mage élémentaire : son pack fournit feu, glace ET foudre,
    /// il les a toutes, plus l'Aether qui lui est propre. Lyra est prêtresse :
    /// la glace et la foudre ne sont pas à elle — ses sorts sont sacrés (soin,
    /// bénédiction), et ce sont ceux que son pack anime. Eran est un guerrier :
    /// il frappe, et son Aether tranche.
    var currentActorButtons: [SKShapeNode] {
    switch actingAlly?.kind {
    case .lyra:     return [attackButton, healButton, blessingButton]
    // L'Écho garde la Bénédiction. Elle n'apparaissait que chez la Lyra
    // vivante, donc les Actes I-II : le joueur apprenait le soin de groupe,
    // puis le perdait pile pour les Actes III-IV — le trio, trois ennemis,
    // des coups à 60. Le reste de sa fiche disait déjà l'inverse de son
    // menu : l'Écho porte le plus haut multiplicateur de sorts du jeu (1.18).
    case .lyraEcho: return [attackButton, healButton, blessingButton]
    case .eran:     return [attackButton, windButton, emberButton, blackSlashButton]
    // Kael : le brasier au quotidien, la Tempête comme atout (1x), et
    // l'Aether. Glace et foudre ne sont plus des sorts a part - elles
    // vivent fusionnees dans la Tempete.
    case nil:       return [attackButton, fireButton, tempestButton,
                            blackSlashButton]
    }
    }

    /// Dispose les commandes de l'acteur en **liste verticale**, façon Final
    /// Fantasy : une seule boîte sombre, une commande par ligne, le coût en
    /// Magie aligné à droite. La rangée horizontale de boîtes colorées se lisait
    /// comme une barre d'outils — rouge, bleu, jaune côte à côte, sans hiérarchie.
    func layoutActionMenu() {
    guard let scene = parentScene else { return }
    let visible = currentActorButtons
    let hidden = [attackButton, fireButton, iceButton,
                  blackSlashButton, lightningButton, healButton, blessingButton,
                  windButton, emberButton, tempestButton]
        .filter { !visible.contains($0) }
    hidden.forEach { $0.isHidden = true }

    let rowH: CGFloat = 26
    let listW: CGFloat = 152
    let count = CGFloat(visible.count)
    // La liste monte depuis le bas de l'écran, calée à gauche comme un menu
    // de commandes classique. Le reste de l'arène garde sa place.
    let listX = 96 + listW / 2
    let bottomY: CGFloat = 40   // même repère bas que l'ancien panneau
    let topRowY = bottomY + rowH * (count - 1)

    for (i, button) in visible.enumerated() {
        button.isHidden = false
        styleCommandRow(button, width: listW, height: rowH)
        button.position = CGPoint(x: listX, y: topRowY - CGFloat(i) * rowH)
    }

    // Cadre unique autour de la liste : c'est LUI la boîte, plus les lignes.
    PixelUI.stylePanel(actionPanel,
                       size: CGSize(width: listW + 14, height: rowH * count + 14),
                       fill: SKColor(red: 0.05, green: 0.05, blue: 0.09, alpha: 0.96),
                       accent: SKColor(red: 0.58, green: 0.50, blue: 0.30, alpha: 1))
    actionPanel.position = CGPoint(x: listX, y: bottomY + rowH * (count - 1) / 2)
    actionPanel.zPosition = 850
    _ = scene
    }

    /// Une ligne de commande : pas de boîte, pas de couleur de fond. Le nom à
    /// gauche, la pastille d'élément avant lui, le coût en Magie à droite.
    func styleCommandRow(_ node: SKShapeNode, width: CGFloat, height: CGFloat) {
    node.path = CGPath(rect: CGRect(x: -width / 2, y: -height / 2,
                                    width: width, height: height), transform: nil)
    node.fillColor = .clear
    node.strokeColor = .clear
    node.lineWidth = 0
    node.glowWidth = 0
    node.zPosition = 860
    node.childNode(withName: "pixelOuter")?.removeFromParent()

    guard let label = node.children.compactMap({ $0 as? SKLabelNode })
            .first(where: { $0.name != "mpCost" }) else { return }
    // Le nom suit le palier : à 10 et 20, BRASIER devient FOURNAISE puis
    // INFERNO. Le menu doit dire ce que le sort EST devenu.
    if let spell = spellForButton(node) {
        label.text = spell.title(at: _player?.level ?? 1).uppercased()
    }
    // Tempête épuisée : le menu doit le dire sans qu'on ait à essayer.
    let spent = node === tempestButton && tempestSpent
    label.horizontalAlignmentMode = .left
    label.verticalAlignmentMode = .center
    label.fontSize = 13
    label.position = CGPoint(x: -width / 2 + 20, y: 0)

    // Pastille d'élément, avant le nom.
    if let diamond = node.children.compactMap({ $0 as? SKSpriteNode }).first {
        diamond.position = CGPoint(x: -width / 2 + 9, y: 0)
    }

    // Coût en Magie, aligné à droite : dans un menu FF c'est l'information
    // qui décide. Grisé quand la réserve ne suit pas.
    let cost = mpCostForButton(node)
    var mpLabel = node.childNode(withName: "mpCost") as? SKLabelNode
    if cost > 0 {
        if mpLabel == nil {
            let l = SKLabelNode(fontNamed: PixelUI.uiFont)
            l.name = "mpCost"
            l.verticalAlignmentMode = .center
            l.horizontalAlignmentMode = .right
            l.fontSize = 11
            node.addChild(l)
            mpLabel = l
        }
        let mp = actingAlly?.combatant.mp ?? kael.mp
        mpLabel?.text = String(cost)
        mpLabel?.fontColor = mp >= cost
            ? Palette.frost
            : SKColor(red: 0.55, green: 0.30, blue: 0.30, alpha: 1)
        mpLabel?.position = CGPoint(x: width / 2 - 8, y: 0)
        label.fontColor = (mp >= cost && !spent) ? .white : SKColor(white: 0.45, alpha: 1)
    } else {
        mpLabel?.removeFromParent()
        label.fontColor = spent ? SKColor(white: 0.45, alpha: 1) : .white
    }
    }

    /// Sort porté par ce bouton (nil = attaque physique, sans palier).
    func spellForButton(_ node: SKShapeNode) -> CombatSpell? {
    if node === fireButton      { return .ember }
    if node === iceButton       { return .frost }
    if node === lightningButton { return .thunder }
    if node === healButton      { return .mend }
    if node === blessingButton  { return .blessing }
    if node === windButton      { return .windBlade }
    if node === emberButton     { return .emberStrike }
    if node === tempestButton   { return .tempest }
    return nil
    }

    /// Coût en Magie de la commande portée par ce bouton.
    func mpCostForButton(_ node: SKShapeNode) -> Int {
    if node === fireButton      { return CombatSpell.ember.mpCost }
    if node === iceButton       { return CombatSpell.frost.mpCost }
    if node === lightningButton { return CombatSpell.thunder.mpCost }
    if node === healButton      { return CombatSpell.mend.mpCost }
    if node === blessingButton  { return CombatSpell.blessing.mpCost }
    if node === windButton      { return CombatSpell.windBlade.mpCost }
    if node === emberButton     { return CombatSpell.emberStrike.mpCost }
    if node === tempestButton   { return CombatSpell.tempest.mpCost }
    if node === blackSlashButton { return 14 }   // Entaille noire
    return 0   // attaque physique : gratuite
    }

    /// Redimensionne un bouton existant (repasse le style pixel, recadre
    /// la pastille + le label à gauche).
    func resizeButton(_ node: SKShapeNode, width: CGFloat) {
    guard let label = node.children.compactMap({ $0 as? SKLabelNode }).first,
          let diamond = node.children.compactMap({ $0 as? SKSpriteNode }).first
    else { return }
    let stroke = node.strokeColor
    let fill = node.fillColor
    PixelUI.stylePanel(node, size: CGSize(width: width, height: 32),
                       fill: fill, accent: stroke)
    let chipSide: CGFloat = 7
    let contentW = label.frame.width + chipSide + 6
    label.position = CGPoint(x: -contentW / 2 + chipSide + 6, y: 0)
    diamond.position = CGPoint(x: -contentW / 2 + chipSide / 2, y: 0)
    }
}
