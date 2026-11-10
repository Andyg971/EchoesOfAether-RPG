import SpriteKit
import UIKit

/// Formes rondes et traits obliques rendus en pixel strict.
///
/// `SKShapeNode(circleOfRadius:)`, `ellipseOf:` et les `CGPath` obliques
/// sortent lissés (anticrénelage) : à côté de sprites en `.nearest`, ça se
/// lit tout de suite comme un calque vectoriel posé sur du pixel art. Ici
/// la forme est tramée sur une grille grossière, cellule par cellule, puis
/// agrandie au plus proche voisin — bords en escalier, zéro dégradé.
@MainActor
enum PixelShape {
    private static var cache: [String: SKTexture] = [:]

    /// Disque plein, avec liseré optionnel d'une cellule.
    static func disc(radius: CGFloat, fill: SKColor,
                     stroke: SKColor? = nil, pixel: CGFloat = 3) -> SKSpriteNode {
        ellipse(size: CGSize(width: radius * 2, height: radius * 2),
                fill: fill, stroke: stroke, pixel: pixel)
    }

    /// Ellipse pleine, avec liseré optionnel d'une cellule.
    static func ellipse(size: CGSize, fill: SKColor,
                        stroke: SKColor? = nil, pixel: CGFloat = 3) -> SKSpriteNode {
        let cols = max(3, Int((size.width / pixel).rounded()))
        let rows = max(3, Int((size.height / pixel).rounded()))
        let key = "e|\(cols)|\(rows)|\(fill.pixelKey)|\(stroke?.pixelKey ?? "-")"
        let texture = cache[key] ?? {
            let made = ellipseTexture(cols: cols, rows: rows, fill: fill, stroke: stroke)
            cache[key] = made
            return made
        }()
        let sprite = SKSpriteNode(texture: texture)
        sprite.size = CGSize(width: CGFloat(cols) * pixel, height: CGFloat(rows) * pixel)
        return sprite
    }

    /// Ligne brisée tracée en carrés (pas d'un `pixel`), sans rotation :
    /// chaque carré reste aligné sur la grille, donc net.
    static func polyline(_ points: [CGPoint], color: SKColor,
                         pixel: CGFloat = 3) -> SKNode {
        let node = SKNode()
        guard points.count > 1 else { return node }
        var seen = Set<String>()
        for (start, end) in zip(points, points.dropFirst()) {
            let dx = end.x - start.x, dy = end.y - start.y
            let steps = max(1, Int((max(abs(dx), abs(dy)) / pixel).rounded()))
            for i in 0...steps {
                let t = CGFloat(i) / CGFloat(steps)
                let gx = ((start.x + dx * t) / pixel).rounded()
                let gy = ((start.y + dy * t) / pixel).rounded()
                guard seen.insert("\(gx)|\(gy)").inserted else { continue }
                let cell = SKSpriteNode(color: color,
                                        size: CGSize(width: pixel, height: pixel))
                cell.position = CGPoint(x: gx * pixel, y: gy * pixel)
                node.addChild(cell)
            }
        }
        return node
    }

    // MARK: - Tramage

    private static func ellipseTexture(cols: Int, rows: Int, fill: SKColor,
                                       stroke: SKColor?) -> SKTexture {
        func inside(_ c: Int, _ r: Int) -> Bool {
            guard c >= 0, c < cols, r >= 0, r < rows else { return false }
            let nx = (CGFloat(c) + 0.5) / CGFloat(cols) * 2 - 1
            let ny = (CGFloat(r) + 0.5) / CGFloat(rows) * 2 - 1
            return nx * nx + ny * ny <= 1
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let image = UIGraphicsImageRenderer(
            size: CGSize(width: cols, height: rows), format: format
        ).image { ctx in
            ctx.cgContext.setShouldAntialias(false)
            for r in 0..<rows {
                for c in 0..<cols where inside(c, r) {
                    let onEdge = !(inside(c - 1, r) && inside(c + 1, r)
                                   && inside(c, r - 1) && inside(c, r + 1))
                    let color = (onEdge ? stroke : nil) ?? fill
                    guard color.cgColor.alpha > 0 else { continue }
                    ctx.cgContext.setFillColor(color.cgColor)
                    ctx.cgContext.fill(CGRect(x: c, y: r, width: 1, height: 1))
                }
            }
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        return texture
    }
}

private extension SKColor {
    /// Clé de cache stable (composantes arrondies au millième).
    var pixelKey: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return [r, g, b, a].map { String(Int(($0 * 1000).rounded())) }
            .joined(separator: ",")
    }
}

extension SKColor {
    /// Couleur opaque équivalente à `self` posée à `alpha` sur `base`.
    /// Une cellule tramée n'a pas de transparence partielle par-dessus son
    /// fond : on précalcule le mélange.
    func blendedOver(_ base: SKColor, _ alpha: CGFloat) -> SKColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        base.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return SKColor(red: r2 + (r1 - r2) * alpha, green: g2 + (g1 - g2) * alpha,
                       blue: b2 + (b1 - b2) * alpha, alpha: 1)
    }
}
