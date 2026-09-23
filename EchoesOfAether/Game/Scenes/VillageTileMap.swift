import SpriteKit

// MARK: - VillageTileMap (autotiler)

/// Grille binaire pour l'autotiling du village : on marque les cellules
/// "matière" (terre battue, eau), puis `pieces()` renvoie les tuiles
/// pleines + les transitions à poser sur les cellules d'herbe voisines,
/// nommées par la position de la matière (n, ne, e, se, s, sw, w, nw,
/// et cnw/cne/cse/csw pour les coins diagonaux isolés).
struct VillageTileMap {
    let tile: CGFloat
    let cols: Int
    let rows: Int
    private var cells: [Bool]

    init(width: CGFloat, height: CGFloat, tile: CGFloat) {
        self.tile = tile
        self.cols = Int(ceil(width / tile)) + 1
        self.rows = Int(ceil(height / tile)) + 1
        self.cells = Array(repeating: false, count: cols * rows)
    }

    private func isSet(_ c: Int, _ r: Int) -> Bool {
        guard c >= 0, c < cols, r >= 0, r < rows else { return false }
        return cells[r * cols + c]
    }

    /// Lecture publique : la passe des falaises (faces sud) a besoin de
    /// connaître la matière cellule par cellule, pas seulement les pièces.
    func matter(_ c: Int, _ r: Int) -> Bool { isSet(c, r) }

    /// La cellule sous ce point (coordonnées monde) est-elle marquée ?
    func contains(_ p: CGPoint) -> Bool {
        guard p.x >= 0, p.y >= 0 else { return false }
        return isSet(Int(p.x / tile), Int(p.y / tile))
    }

    /// Marque toutes les cellules intersectant le rectangle (points).
    mutating func stamp(rect: CGRect) {
        let c0 = max(0, Int(rect.minX / tile))
        let c1 = min(cols - 1, Int((rect.maxX - 0.5) / tile))
        let r0 = max(0, Int(rect.minY / tile))
        let r1 = min(rows - 1, Int((rect.maxY - 0.5) / tile))
        guard c0 <= c1, r0 <= r1 else { return }
        for r in r0...r1 {
            for c in c0...c1 { cells[r * cols + c] = true }
        }
    }

    /// Ne garde que les cellules qui sont AUSSI matière dans `other`.
    /// Sert à découper une piste selon la zone qu'elle traverse : une route
    /// de terre battue porte des bords `me_edge_*` qui contiennent de
    /// l'herbe — traversant le désert, elle y semait un liseré vert.
    mutating func intersect(_ other: VillageTileMap) {
        for i in cells.indices where cells[i] {
            cells[i] = other.cells.indices.contains(i) && other.cells[i]
        }
    }

    /// Ajoute les cellules matière de `other`.
    mutating func formUnion(_ other: VillageTileMap) {
        for i in cells.indices where !cells[i] {
            if other.cells.indices.contains(i), other.cells[i] { cells[i] = true }
        }
    }

    /// Efface les cellules intersectant le rectangle (l'inverse de `stamp`).
    mutating func clear(rect: CGRect) {
        let c0 = max(0, Int(rect.minX / tile))
        let c1 = min(cols - 1, Int((rect.maxX - 0.5) / tile))
        let r0 = max(0, Int(rect.minY / tile))
        let r1 = min(rows - 1, Int((rect.maxY - 0.5) / tile))
        guard c0 <= c1, r0 <= r1 else { return }
        for r in r0...r1 {
            for c in c0...c1 { cells[r * cols + c] = false }
        }
    }

    /// Marque les cellules dont le centre est dans l'ellipse.
    mutating func stampEllipse(center: CGPoint, radiusX: CGFloat, radiusY: CGFloat) {
        guard radiusX > 0, radiusY > 0 else { return }
        for r in 0..<rows {
            for c in 0..<cols {
                let x = (CGFloat(c) + 0.5) * tile
                let y = (CGFloat(r) + 0.5) * tile
                let dx = (x - center.x) / radiusX
                let dy = (y - center.y) / radiusY
                if dx * dx + dy * dy <= 1 { cells[r * cols + c] = true }
            }
        }
    }

    /// Retire les cellules qu'aucune berge ne sait border : le pack d'eau ne
    /// dessine que des bords à UN côté (n/s/e/o) ou à un COIN (deux côtés
    /// adjacents). Une pointe d'une cellule — trois côtés ouverts, ou deux
    /// côtés opposés — n'a pas de tuile, et c'est pour l'éviter que le bassin
    /// de l'oasis était tracé au rectangle. Éroder jusqu'à stabilité rend
    /// n'importe quelle forme organique bordable.
    mutating func erodeUnborderable() {
        var changed = true
        while changed {
            changed = false
            var next = cells
            for r in 0..<rows {
                for c in 0..<cols where isSet(c, r) {
                    let n = isSet(c, r + 1), s = isSet(c, r - 1)
                    let e = isSet(c + 1, r), w = isSet(c - 1, r)
                    let open = [n, s, e, w].filter { !$0 }.count
                    if open >= 3 || (!n && !s) || (!e && !w) {
                        next[r * cols + c] = false
                        changed = true
                    }
                }
            }
            cells = next
        }
    }

    /// Ellipse à bord DIFFUS. `feather` (fraction du rayon) délimite la frange
    /// où les cellules sont prises de plus en plus rarement vers l'extérieur.
    ///
    /// Deux teintes de sous-bois séparées par un bord net dessinent des
    /// TERRASSES en escalier — le massif ressemblait à une rizière. Diluée,
    /// l'ombre se lit comme la lumière qui perce un couvert. Le tirage est
    /// haché sur la cellule, donc stable d'une visite à l'autre.
    mutating func stampEllipse(center: CGPoint, radiusX: CGFloat, radiusY: CGFloat,
                               feather: CGFloat) {
        guard radiusX > 0, radiusY > 0, feather > 0 else {
            stampEllipse(center: center, radiusX: radiusX, radiusY: radiusY)
            return
        }
        for r in 0..<rows {
            for c in 0..<cols {
                let x = (CGFloat(c) + 0.5) * tile
                let y = (CGFloat(r) + 0.5) * tile
                let dx = (x - center.x) / radiusX
                let dy = (y - center.y) / radiusY
                let d = (dx * dx + dy * dy).squareRoot()
                guard d <= 1 else { continue }
                if d <= 1 - feather {
                    cells[r * cols + c] = true
                } else {
                    let odds = (1 - d) / feather          // 1 au cœur, 0 au bord
                    let draw = CGFloat(Self.noise(c, r) % 1000) / 1000
                    if draw < odds { cells[r * cols + c] = true }
                }
            }
        }
    }

    /// Bruit déterministe par cellule (frange des ellipses diffuses).
    private static func noise(_ c: Int, _ r: Int) -> Int {
        var h = c &* 374_761_393 &+ r &* 668_265_263
        h = (h ^ (h >> 13)) &* 1_274_126_177
        return abs(h ^ (h >> 16))
    }

    /// Tuiles à poser : `suffix == nil` → tuile pleine, sinon suffixe de
    /// transition pour la cellule d'herbe (rangée = y vers le haut).
    func pieces() -> [(suffix: String?, col: Int, row: Int)] {
        var out: [(String?, Int, Int)] = []
        for r in 0..<rows {
            for c in 0..<cols {
                if isSet(c, r) {
                    out.append((nil, c, r))
                    continue
                }
                let n = isSet(c, r + 1), s = isSet(c, r - 1)
                let e = isSet(c + 1, r), w = isSet(c - 1, r)
                let suffix: String?
                switch (n, s, e, w) {
                case (true, _, true, _):  suffix = "ne"
                case (true, _, _, true):  suffix = "nw"
                case (_, true, true, _):  suffix = "se"
                case (_, true, _, true):  suffix = "sw"
                case (true, _, _, _):     suffix = "n"
                case (_, true, _, _):     suffix = "s"
                case (_, _, true, _):     suffix = "e"
                case (_, _, _, true):     suffix = "w"
                default:
                    if isSet(c + 1, r + 1)      { suffix = "cne" }
                    else if isSet(c - 1, r + 1) { suffix = "cnw" }
                    else if isSet(c + 1, r - 1) { suffix = "cse" }
                    else if isSet(c - 1, r - 1) { suffix = "csw" }
                    else { suffix = nil }
                }
                if let suffix { out.append((suffix, c, r)) }
            }
        }
        return out
    }
}
