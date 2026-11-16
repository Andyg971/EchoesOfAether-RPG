import GameController
import SpriteKit

/// Manettes physiques (PS4/PS5, Xbox, Switch Pro, 8BitDo, MFi…).
///
/// Tout passe par le profil `extendedGamepad` du framework GameController :
/// iOS normalise lui-même les manettes de marques différentes vers la même
/// disposition, donc une seule implémentation couvre toutes les références.
///
/// Le service ne connaît pas le jeu : il expose un vecteur de direction
/// (stick gauche ou croix directionnelle) et des boutons logiques. Chaque
/// scène branche son propre `onPress` à son arrivée.
@MainActor
final class GameControllerInput {
    static let shared = GameControllerInput()

    /// Boutons logiques, indépendants de la marque de la manette.
    enum Button {
        /// Bas (A Xbox, ✕ PlayStation) : valider / interagir.
        case confirm
        /// Droite (B Xbox, ○ PlayStation) : annuler / fermer.
        case back
        /// Gauche (X Xbox, □ PlayStation) : action secondaire.
        case west
        /// Haut (Y Xbox, △ PlayStation) : inventaire.
        case north
        /// Menu / Start : pause.
        case start
        /// Options / Select : carte du monde.
        case select
        case shoulderLeft
        case shoulderRight
    }

    /// Consommateur courant des pressions (la scène affichée).
    var onPress: ((Button) -> Void)?

    /// Vrai tant qu'au moins une manette est connectée.
    private(set) var isConnected = false

    private var didStart = false
    private let deadZone: Float = 0.22

    private init() {}

    /// Démarre l'écoute des connexions. Idempotent.
    func start() {
        guard !didStart else { return }
        didStart = true
        let center = NotificationCenter.default
        center.addObserver(forName: .GCControllerDidConnect, object: nil,
                           queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                GCController.controllers().forEach { self?.attach($0) }
                self?.refreshConnection()
            }
        }
        center.addObserver(forName: .GCControllerDidDisconnect, object: nil,
                           queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshConnection() }
        }
        GCController.controllers().forEach(attach)
        refreshConnection()
    }

    /// Direction courante : croix directionnelle si pressée, sinon stick
    /// gauche. Norme bornée à 1 (pas de diagonale plus rapide).
    var stick: CGVector {
        var x: Float = 0
        var y: Float = 0
        for controller in GCController.controllers() {
            guard let pad = controller.extendedGamepad else { continue }
            let dpadX = pad.dpad.xAxis.value
            let dpadY = pad.dpad.yAxis.value
            if dpadX != 0 || dpadY != 0 {
                x = dpadX
                y = dpadY
            } else {
                x = pad.leftThumbstick.xAxis.value
                y = pad.leftThumbstick.yAxis.value
            }
            if x != 0 || y != 0 { break }
        }
        let length = (x * x + y * y).squareRoot()
        guard length > deadZone else { return .zero }
        let scale = length > 1 ? 1 / length : 1
        return CGVector(dx: CGFloat(x * scale), dy: CGFloat(y * scale))
    }

    // MARK: - Câblage

    private func refreshConnection() {
        isConnected = !GCController.controllers().isEmpty
    }

    private func attach(_ controller: GCController) {
        guard let pad = controller.extendedGamepad else { return }
        bind(pad.buttonA, to: .confirm)
        bind(pad.buttonB, to: .back)
        bind(pad.buttonX, to: .west)
        bind(pad.buttonY, to: .north)
        bind(pad.buttonMenu, to: .start)
        if let options = pad.buttonOptions { bind(options, to: .select) }
        bind(pad.leftShoulder, to: .shoulderLeft)
        bind(pad.rightShoulder, to: .shoulderRight)
    }

    private func bind(_ input: GCControllerButtonInput, to button: Button) {
        input.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            MainActor.assumeIsolated { self?.onPress?(button) }
        }
    }
}
