import SpriteKit

// Désert d'Ossara — l'enceinte de la cité : courtines, colonnes, portes.
extension WorldBuilder {
    /// L'enceinte de la cité : courtines d'adobe (kit ds_wall_*) fermées
    /// sur les quatre côtés, percées de deux portes (sud et nord).
    ///
    /// Andy voulait la cité « bien fermée avec les remparts tout autour »
    /// (référence : TDRPG Desert de Raou, dont ces murs sont extraits).
    func addDesertRamparts(in scene: SKScene, w: CGFloat, h: CGFloat) {
        let southY = h * 0.375
        let northY = h * 0.635
        let leftX  = w * 0.10
        let rightX = w * 0.90
        // ds_gate2 : 197 px × 0,65 = 128 pt de façade.
        let gateHalf: CGFloat = 64

        for y in [southY, northY] {
            addWallGate(in: scene, at: CGPoint(x: w * 0.50, y: y))
            addWallRun(in: scene, fromX: leftX, toX: w * 0.50 - gateHalf, y: y)
            addWallRun(in: scene, fromX: w * 0.50 + gateHalf, toX: rightX, y: y)
        }
        addWallColumn(in: scene, x: leftX, fromY: southY, toY: northY)
        addWallColumn(in: scene, x: rightX, fromY: southY, toY: northY)

        // Tours d'angle : un embout de mur coiffe chaque coin — sans elles,
        // les jointures des courtines se lisaient comme un bug de tuiles.
        for (cx, cy) in [(leftX, southY), (rightX, southY),
                         (leftX, northY), (rightX, northY)] {
            addDesertProp("ds_wall_end", in: scene, at: CGPoint(x: cx, y: cy - 4))
        }
        // Porte de service à l'est : une palissade fermée dans la courtine
        // (purement visuelle — l'obstacle du flanc reste continu).
        addDesertProp("ds_palisade_gate", in: scene,
                      at: CGPoint(x: rightX, y: h * 0.520))
    }

    /// Courtine horizontale : tuiles ds_wall_h enchaînées + obstacle continu.
    func addWallRun(in scene: SKScene, fromX x0: CGFloat, toX x1: CGFloat, y: CGFloat) {
        guard x1 > x0 else { return }
        let scale = WorldBuilder.desertDisplayScale(for: "ds_wall_h")
        let tileW = 48 * scale
        var x = x0 + tileW / 2
        while x < x1 + 1 {
            guard let t = PixelArtSprites.still(name: "ds_wall_h", scale: scale,
                                                anchor: CGPoint(x: 0.5, y: 0.0)) else { break }
            t.position = CGPoint(x: min(x, x1 - tileW / 2), y: y)
            t.zPosition = depthLayer(for: y, sceneHeight: scene.size.height)
            add(t, to: scene)
            x += tileW
        }
        registerObstacle(CGRect(x: x0, y: y - 2, width: x1 - x0, height: 16))
    }

    /// Flanc vertical : tuiles ds_wall_v empilées + obstacle continu.
    func addWallColumn(in scene: SKScene, x: CGFloat, fromY y0: CGFloat, toY y1: CGFloat) {
        guard y1 > y0 else { return }
        let scale = WorldBuilder.desertDisplayScale(for: "ds_wall_v")
        let tileH = 48 * scale
        var y = y0
        while y < y1 {
            guard let t = PixelArtSprites.still(name: "ds_wall_v", scale: scale,
                                                anchor: CGPoint(x: 0.5, y: 0.0)) else { break }
            t.position = CGPoint(x: x, y: min(y, y1 - tileH))
            t.zPosition = depthLayer(for: t.position.y, sceneHeight: scene.size.height)
            add(t, to: scene)
            y += tileH
        }
        registerObstacle(CGRect(x: x - 10, y: y0, width: 20, height: y1 - y0))
    }

    /// Porte de l'enceinte : arche beige, deux emprises (une par pilier),
    /// le passage central reste ouvert. Mesuré sur l'asset (197 px) : l'arche
    /// occupe ~36 % à 64 % de la largeur.
    func addWallGate(in scene: SKScene, at pos: CGPoint) {
        guard let gate = PixelArtSprites.still(name: "ds_gate2",
                                               scale: WorldBuilder.desertDisplayScale(for: "ds_gate2"),
                                               anchor: CGPoint(x: 0.5, y: 0.0)) else { return }
        gate.position = pos
        gate.zPosition = depthLayer(for: pos.y, sceneHeight: scene.size.height)
        add(gate, to: scene)

        let f = gate.calculateAccumulatedFrame()
        let depth: CGFloat = 16
        registerObstacle(CGRect(x: f.minX, y: pos.y - 2,
                                width: f.width * 0.36, height: depth))
        registerObstacle(CGRect(x: f.minX + f.width * 0.64, y: pos.y - 2,
                                width: f.width * 0.36, height: depth))
    }
}
