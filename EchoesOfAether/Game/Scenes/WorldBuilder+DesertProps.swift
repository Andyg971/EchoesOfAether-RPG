import SpriteKit

// Désert d'Ossara — les PROPS : semis des dunes, du canyon et des flancs,
// emprises au sol, pose d'un décor.
@MainActor
extension WorldBuilder {
    /// Sud : les dunes d'entrée, semées de cactus et d'ossements.
    /// Densité alignée sur la forêt (~11 props par écran) : le sable plat
    /// pardonne moins le vide que l'herbe.
    func addDesertSouthProps(in scene: SKScene, w: CGFloat, h: CGFloat) {
        for (asset, x, y) in [("ds_cactus_tall", 0.14, 0.16),
                              ("ds_cactus_med", 0.86, 0.12),
                              ("ds_bush_dead", 0.30, 0.10),
                              ("ds_cactus_barrel", 0.70, 0.20),
                              ("ds_tumbleweed", 0.585, 0.245),
                              ("ds_skull_cow", 0.135, 0.315),
                              ("ds_bush_dead2", 0.62, 0.28),
                              ("ds_cactus_tall2", 0.90, 0.26),
                              ("ds_cactus_small", 0.52, 0.13),
                              ("ds_rock_pile", 0.08, 0.205),
                              ("ds_bush_dead3", 0.78, 0.155),
                              ("ds_cactus_flower", 0.36, 0.185),
                              ("ds_rock_pile", 0.60, 0.095),
                              ("ds_tumbleweed2", 0.20, 0.33),
                              ("ds_cactus_med2", 0.80, 0.315),
                              ("ds_bones", 0.60, 0.345)] {
            addDesertProp(asset, in: scene, at: CGPoint(x: w * x, y: h * y))
        }
    }

    /// Nord : le canyon, ses éboulis et ses caravanes perdues — puis les
    /// éboulis des flancs : le canyon a des PIEDS de paroi.
    /// Les parois tombaient à pic sur le sable nu. Une frange d'aiguilles
    /// et de blocs les raccorde au sol, des deux côtés, comme le massif de
    /// Cendreval sur la carte du monde. Toujours via `addDesertProp` :
    /// même densité de pixels que le reste de la zone.
    func addDesertNorthProps(in scene: SKScene, w: CGFloat, h: CGFloat) {
        for (asset, x, y) in [("ds_boulder", 0.14, 0.62),
                              ("ds_rock_big", 0.88, 0.66),
                              ("ds_boulder2", 0.34, 0.74),
                              ("ds_rock_spire", 0.70, 0.78),
                              ("ds_bones", 0.24, 0.70),
                              ("ds_skull_cow2", 0.56, 0.72),
                              ("ds_bone", 0.44, 0.80),
                              ("ds_ruin_column", 0.78, 0.86),
                              ("ds_ruin_stone", 0.30, 0.88),
                              ("ds_cactus_tall3", 0.10, 0.78),
                              ("ds_agave", 0.64, 0.64),
                              ("ds_tumbleweed2", 0.50, 0.84),
                              ("ds_skull", 0.16, 0.84),
                              ("ds_rock_pile", 0.60, 0.685),
                              ("ds_bush_dead", 0.40, 0.66),
                              ("ds_cactus_med2", 0.90, 0.80)] {
            addDesertProp(asset, in: scene, at: CGPoint(x: w * x, y: h * y))
        }
        for (asset, x, y) in [("ds_rock_spire", 0.06, 0.58),
                              ("ds_boulder",    0.11, 0.545),
                              ("ds_rock_spire", 0.05, 0.70),
                              ("ds_boulder2",   0.09, 0.755),
                              ("ds_rock_big",   0.07, 0.86),
                              ("ds_rock_pile",  0.13, 0.905),
                              ("ds_rock_spire", 0.95, 0.575),
                              ("ds_boulder2",   0.91, 0.615),
                              ("ds_rock_big",   0.96, 0.71),
                              ("ds_rock_spire", 0.93, 0.815),
                              ("ds_boulder",    0.89, 0.875),
                              ("ds_rock_pile",  0.955, 0.925),
                              // Deux éboulis isolés au milieu du défilé.
                              ("ds_boulder2",   0.36, 0.925),
                              ("ds_rock_pile",  0.68, 0.905)] {
            addDesertProp(asset, in: scene, at: CGPoint(x: w * x, y: h * y))
        }
    }

    /// Oasis : la halte sur la route, palmeraie et campement autour du
    /// bassin. Palmiers et fleurs sont posés PAR `addOasis` — ils étaient
    /// semés ici à la main, trois de-ci de-là, et l'oasis se lisait comme
    /// une flaque avec des plantes autour au lieu d'une halte.
    func addDesertOasisAndPalms(in scene: SKScene, w: CGFloat, h: CGFloat) {
        addOasis(in: scene, at: DesertPOI.oasis.scaled(w: w, h: h), w: w, h: h)
        // Le nord garde une trace de vert : un palmier esseulé au canyon.
        addDesertProp("ds_palm_tall2", in: scene, at: CGPoint(x: w * 0.905, y: h * 0.900))
        addDesertProp("ds_flowers_red", in: scene, at: CGPoint(x: w * 0.885, y: h * 0.885))
        // Et un petit près de la cité, côté est.
        addDesertProp("ds_palm_small", in: scene, at: CGPoint(x: w * 0.68, y: h * 0.330))
    }

    /// Emprise au sol d'un décor : sur quelle surface il arrête Kael.
    struct Footprint {
        let widthRatio: CGFloat
        let depthRatio: CGFloat
        let maxDepth: CGFloat
    }

    /// Ce qui arrête Kael à Ossara, décidé d'après l'ASSET.
    ///
    /// La solidité se décidait au point d'appel : chaque pose passait un
    /// `solid:` calculé sur un préfixe de nom. Trois s'étaient trompées — la
    /// porte des remparts se traversait de part en part, les palissades aussi,
    /// et un cactus du nord passait au travers parce que son groupe testait
    /// « ds_boulder ». Une table : un seul endroit à tenir quand un pack
    /// arrive, et l'oubli devient visible au lieu d'être silencieux.
    ///
    /// Absent de la table = on marche dessus (ossements, empreintes, fleurs,
    /// tapis, échelle couchée, broussailles sèches). Tout ce qui a un volume
    /// y figure.
    static let desertFootprints: [String: Footprint] = [
        // Bâti : l'empreinte couvre la façade, pas le toit — on passe derrière.
        "ds_house_red":     Footprint(widthRatio: 0.92, depthRatio: 0.34, maxDepth: 48),
        "ds_house_sand":    Footprint(widthRatio: 0.92, depthRatio: 0.34, maxDepth: 48),
        "ds_house_large":   Footprint(widthRatio: 0.92, depthRatio: 0.34, maxDepth: 48),
        // Toile tendue : on la contourne.
        "ds_tent_big":      Footprint(widthRatio: 0.62, depthRatio: 0.45, maxDepth: 30),
        "ds_tent_canvas":   Footprint(widthRatio: 0.62, depthRatio: 0.45, maxDepth: 30),
        "ds_tent_round":    Footprint(widthRatio: 0.62, depthRatio: 0.45, maxDepth: 30),
        "ds_tent_small":    Footprint(widthRatio: 0.62, depthRatio: 0.45, maxDepth: 30),
        // Épines.
        "ds_cactus_tall":   Footprint(widthRatio: 0.42, depthRatio: 0.35, maxDepth: 20),
        "ds_cactus_tall2":  Footprint(widthRatio: 0.42, depthRatio: 0.35, maxDepth: 20),
        "ds_cactus_tall3":  Footprint(widthRatio: 0.42, depthRatio: 0.35, maxDepth: 20),
        "ds_cactus_med":    Footprint(widthRatio: 0.42, depthRatio: 0.35, maxDepth: 20),
        "ds_cactus_med2":   Footprint(widthRatio: 0.42, depthRatio: 0.35, maxDepth: 20),
        "ds_cactus_small":  Footprint(widthRatio: 0.40, depthRatio: 0.35, maxDepth: 16),
        "ds_cactus_barrel": Footprint(widthRatio: 0.55, depthRatio: 0.45, maxDepth: 16),
        "ds_cactus_barrel2": Footprint(widthRatio: 0.55, depthRatio: 0.45, maxDepth: 16),
        "ds_cactus_flower": Footprint(widthRatio: 0.55, depthRatio: 0.45, maxDepth: 16),
        "ds_agave":         Footprint(widthRatio: 0.50, depthRatio: 0.40, maxDepth: 16),
        // Pierre.
        "ds_boulder":       Footprint(widthRatio: 0.72, depthRatio: 0.45, maxDepth: 26),
        "ds_boulder2":      Footprint(widthRatio: 0.72, depthRatio: 0.45, maxDepth: 26),
        "ds_rock_big":      Footprint(widthRatio: 0.72, depthRatio: 0.45, maxDepth: 30),
        "ds_rock_pile":     Footprint(widthRatio: 0.72, depthRatio: 0.45, maxDepth: 22),
        "ds_rock_spire":    Footprint(widthRatio: 0.60, depthRatio: 0.45, maxDepth: 26),
        "ds_ruin_column":   Footprint(widthRatio: 0.60, depthRatio: 0.45, maxDepth: 22),
        "ds_ruin_stone":    Footprint(widthRatio: 0.70, depthRatio: 0.45, maxDepth: 22),
        // Mobilier de la place.
        "ds_well":          Footprint(widthRatio: 0.70, depthRatio: 0.50, maxDepth: 22),
        "ds_market":        Footprint(widthRatio: 0.85, depthRatio: 0.40, maxDepth: 24),
        "ds_campfire":      Footprint(widthRatio: 0.50, depthRatio: 0.50, maxDepth: 16),
        "ds_fence":         Footprint(widthRatio: 0.95, depthRatio: 0.28, maxDepth: 14),
        "ds_pot":           Footprint(widthRatio: 0.55, depthRatio: 0.50, maxDepth: 12),
        "ds_pot2":          Footprint(widthRatio: 0.55, depthRatio: 0.50, maxDepth: 12),
        // Palmeraie : seul le tronc arrête Kael, on passe sous les palmes.
        "ds_palm_tall1":    Footprint(widthRatio: 0.30, depthRatio: 0.30, maxDepth: 12),
        "ds_palm_tall2":    Footprint(widthRatio: 0.30, depthRatio: 0.30, maxDepth: 12),
        "ds_palm_small":    Footprint(widthRatio: 0.35, depthRatio: 0.35, maxDepth: 12),
        // Bêtes du camp : on les contourne.
        "ds_camel_1":       Footprint(widthRatio: 0.70, depthRatio: 0.45, maxDepth: 14),
        "ds_camel_2":       Footprint(widthRatio: 0.70, depthRatio: 0.45, maxDepth: 14),
        // Les falaises et l'enceinte ont des obstacles explicites
        // (bandes continues) — pas d'entrée ici.
    ]

    /// Prop du désert : posé aux pieds, ombre au sol, profondeur selon y.
    /// Son emprise vient de `desertFootprints`, pas de l'appelant.
    @discardableResult
    func addDesertProp(_ name: String, in scene: SKScene, at pos: CGPoint,
                               scale: CGFloat? = nil, flipped: Bool = false) -> SKNode? {
        let scale = scale ?? Self.desertDisplayScale(for: name)
        guard let node = PixelArtSprites.still(name: name, scale: scale,
                                               anchor: CGPoint(x: 0.5, y: 0.0)) else { return nil }
        if flipped { node.xScale = -abs(node.xScale == 0 ? 1 : node.xScale) }
        node.position = pos
        node.zPosition = depthLayer(for: pos.y, sceneHeight: scene.size.height)
        addGroundShadow(under: node, width: 26 * scale, height: 8 * scale)
        add(node, to: scene)
        if let f = Self.desertFootprints[name] {
            registerFootprint(of: node, widthRatio: f.widthRatio,
                              depthRatio: f.depthRatio, maxDepth: f.maxDepth)
        }
        return node
    }

    /// La cité des caravanes : maisons d'adobe, tentes, souk et puits.
    ///
    /// C'est le contenu qui manquait à Ossara. La zone n'avait qu'un coffre,
    /// une oasis et trois rôdeurs — le scénario parle pourtant d'une route de
    /// caravanes, et le joueur ne croisait jamais personne qui l'ait empruntée.
}
