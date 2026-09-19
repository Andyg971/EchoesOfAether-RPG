import SpriteKit

// Cristal de sauvegarde.
// Extrait de WorldBuilder.swift (découpage du monolithe).
@MainActor
extension WorldBuilder {
    // MARK: - Save Crystal

    /// Cristal d'Aether — point de sauvegarde. Présent dans **toutes** les
    /// zones : c'est le repère qui dit « ici on souffle et on sauvegarde ».
    ///
    /// Entièrement en pixel art (grille de pixels + socle de pierre), là où
    /// il était un losange vectoriel cerclé d'une aura lisse — le halo flou
    /// que la charte proscrit. Il vit maintenant dans le monde et non dans la
    /// scène : posé en espace écran, il ne scrollait pas et restait planté
    /// devant le HUD dans les zones hautes.
    @discardableResult
    func addSaveCrystal(at position: CGPoint, in scene: SKScene) -> CGPoint {
        let crystal = SKNode()
        crystal.position = position
        crystal.zPosition = actorLayer(for: position.y)
        crystal.name = "saveCrystal"

        // Socle de pierre : ancre le cristal au sol, il ne flotte pas.
        let base = PixelIcons.custom(map: [
            "..####..",
            ".######.",
            "########",
            ".######."
        ], palette: [
            "#": SKColor(red: 0.30, green: 0.32, blue: 0.42, alpha: 1)
        ], pixel: 3)
        base.position = CGPoint(x: 0, y: -14)
        crystal.addChild(base)

        // Gemme : facettes claires/sombres pour le volume, contour net.
        let gem = PixelIcons.custom(map: [
            "...ll...",
            "..lLLc..",
            ".lLLccd.",
            "lLLccdd.",
            "lLccddd.",
            ".Lccdd..",
            "..cdd...",
            "...d...."
        ], palette: [
            "l": SKColor(red: 0.80, green: 0.95, blue: 1.00, alpha: 1),   // reflet
            "L": SKColor(red: 0.58, green: 0.86, blue: 1.00, alpha: 1),   // clair
            "c": SKColor(red: 0.32, green: 0.62, blue: 0.92, alpha: 1),   // corps
            "d": SKColor(red: 0.18, green: 0.36, blue: 0.68, alpha: 1)    // ombre
        ], pixel: 3)
        gem.position = CGPoint(x: 0, y: 6)
        crystal.addChild(gem)
        // Respiration verticale : la gemme flotte, le socle reste posé.
        JuiceEngine.float(gem, distance: 3)

        // Halo à paliers (gros pixels assumés, jamais de dégradé lisse).
        let halo = PixelIcons.custom(map: [
            "..#..#..",
            "........",
            "#......#",
            "........",
            "........",
            "#......#",
            "........",
            "..#..#.."
        ], palette: [
            "#": SKColor(red: 0.55, green: 0.85, blue: 1.0, alpha: 0.55)
        ], pixel: 3)
        halo.position = CGPoint(x: 0, y: 6)
        halo.zPosition = -0.5
        crystal.addChild(halo)
        halo.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.25, duration: 1.1),
            .fadeAlpha(to: 0.9, duration: 1.1)
        ])))

        let label = SKLabelNode(fontNamed: PixelUI.uiFont)
        label.text = String(localized: "world.saveCrystal.label")
        label.fontSize = 12
        label.fontColor = SKColor(red: 0.65, green: 0.88, blue: 1.0, alpha: 0.80)
        label.position = CGPoint(x: 0, y: -30)
        crystal.addChild(label)

        add(crystal, to: scene)   // espace MONDE : il scrolle avec la zone
        return position
    }
}
