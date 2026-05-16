import SpriteKit

enum GameState {
    case exploration
    case dialogue
    case combat
    case transition
}

enum GamePhase: Int, CaseIterable {
    case wake
    case village
    case forest
    case shrine
    case complete

    var next: GamePhase? {
        GamePhase(rawValue: rawValue + 1)
    }
}

@MainActor
struct InteractionTarget {
    let node: SKNode
    let radius: CGFloat
    let action: () -> Void

    func contains(_ point: CGPoint) -> Bool {
        point.distance(to: node.position) < radius
    }
}

extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        hypot(x - other.x, y - other.y)
    }
}
