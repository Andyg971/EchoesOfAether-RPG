import SpriteKit

// Désert d'Ossara — ceinture de falaises du canyon et faces de paroi autotilées.
extension WorldBuilder {
    /// Ceinture de falaises : le désert est un canyon, ses bords ont du
    /// volume (mesas ds_cliff_* du pack, plus un simple sable plat qui
    /// s'arrête au bord de l'écran). Chaînées avec chevauchement pour
    /// former une crête continue ; la marche est bloquée par des bandes
    /// d'obstacles, pas par les sprites.
    func addDesertCliffs(in scene: SKScene, w: CGFloat, h: CGFloat) {
        // La crête ne se répète pas : chaque mesa tire son décalage, son
        // échelle et ses accents d'un LCG seedé — même recette que les
        // fleurs du village. Une grande mesa porte la ligne ; devant elle,
        // parfois, une petite en contrebas et un éboulis au pied.
        var seed: UInt64 = 0x055A_44A7
        func next() -> CGFloat {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat(seed >> 40) / CGFloat(1 << 24)
        }
        let rubble = ["ds_boulder", "ds_rock_pile", "ds_boulder2", "ds_rock_big"]

        // Les flancs sont portés par les BANDES de plateau (autotiler, dans
        // buildDesert) : ici on ne pose que des surplombs — quelques mesas
        // ASSISES SUR la bande, jamais sur le sable — et des éboulis à la
        // frontière sable/roche. Empilées sur le sable, elles se lisaient
        // comme des dalles flottantes.
        var y = h * 0.05
        while y < h * 0.92 {
            if next() > 0.35 {
                addDesertProp("ds_cliff_big", in: scene,
                              at: CGPoint(x: w * (0.012 + next() * 0.022), y: y),
                              scale: 0.42 + next() * 0.10)
            }
            if next() > 0.35 {
                addDesertProp("ds_cliff_big", in: scene,
                              at: CGPoint(x: w * (0.966 + next() * 0.022), y: y + next() * 20),
                              scale: 0.42 + next() * 0.10, flipped: true)
            }
            if next() > 0.40 {
                addDesertProp(rubble[Int(next() * 4) % 4], in: scene,
                              at: CGPoint(x: w * (0.076 + next() * 0.014), y: y + next() * 30))
            }
            if next() > 0.40 {
                addDesertProp(rubble[Int(next() * 4) % 4], in: scene,
                              at: CGPoint(x: w * (0.910 + next() * 0.014), y: y + next() * 30))
            }
            y += h * (0.075 + next() * 0.045)
        }

        // Fond nord : la crête ferme le monde derrière l'oasis.
        var x = w * 0.04
        while x < w * 0.98 {
            addDesertProp("ds_cliff_big", in: scene,
                          at: CGPoint(x: x, y: h * (0.962 + next() * 0.016)),
                          scale: 0.46 + next() * 0.12, flipped: next() > 0.5)
            x += w * (0.085 + next() * 0.040)
        }

        // Épaules de l'entrée sud : le canyon s'ouvre sur le centre,
        // épaissi de blocs pour ne pas laisser des tours isolées.
        for (fx, flip) in [(0.09, false), (0.20, true), (0.30, false),
                           (0.70, true), (0.80, false), (0.91, true)] {
            addDesertProp("ds_cliff_left", in: scene,
                          at: CGPoint(x: w * fx, y: h * 0.004), flipped: flip)
            if next() > 0.4 {
                addDesertProp(rubble[Int(next() * 4) % 4], in: scene,
                              at: CGPoint(x: w * fx + (next() - 0.5) * 40, y: h * 0.020))
            }
        }

        // La marche : bandes continues, indépendantes des sprites.
        registerObstacle(CGRect(x: 0, y: 0, width: w * 0.072, height: h))
        registerObstacle(CGRect(x: w * 0.928, y: 0, width: w * 0.072, height: h))
        registerObstacle(CGRect(x: 0, y: h * 0.952, width: w, height: h * 0.048))
        registerObstacle(CGRect(x: 0, y: 0, width: w * 0.34, height: h * 0.018))
        registerObstacle(CGRect(x: w * 0.66, y: 0, width: w * 0.34, height: h * 0.018))
    }

    /// Faces de falaise : sous chaque cellule de paroi dont le sud est
    /// vide, la pierre empilée du pack (48 px → 24 pt, deux par cellule
    /// de 48 pt). C'est l'indice de hauteur qui manquait : sans face, une
    /// paroi vue de dessus n'est qu'une texture posée sur le sable.
    func addCliffFaces(for map: VillageTileMap, cell: CGFloat, in scene: SKScene) {
        let half = cell / 2
        for r in 1..<map.rows {
            for c in 0..<map.cols where map.matter(c, r) && !map.matter(c, r - 1) {
                for i in 0..<2 {
                    let name: String
                    if i == 0, !map.matter(c - 1, r) {
                        name = "ds_cliff_face_l"
                    } else if i == 1, !map.matter(c + 1, r) {
                        name = "ds_cliff_face_r"
                    } else {
                        name = "ds_cliff_face"
                    }
                    guard let t = PixelArtSprites.still(name: name, scale: 0.5,
                                                        anchor: CGPoint(x: 0, y: 1)) else { continue }
                    t.position = CGPoint(x: CGFloat(c) * cell + CGFloat(i) * half,
                                         y: CGFloat(r) * cell)
                    t.zPosition = -9.4
                    add(t, to: scene)
                }
            }
        }
    }
}
