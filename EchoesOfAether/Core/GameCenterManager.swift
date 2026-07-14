import GameKit
import UIKit

/// GameCenter — authentification + achievements + leaderboards.
/// Appeler `authenticate(from:)` au lancement, `report(_:)` sur les events clés.
@MainActor
final class GameCenterManager {

    static let shared = GameCenterManager()
    private(set) var isAuthenticated = false

    private init() {}

    // MARK: - Auth

    func authenticate(from viewController: UIViewController) {
        let player = GKLocalPlayer.local
        player.authenticateHandler = { [weak self, weak viewController] gcVC, _ in
            if let gcVC, let vc = viewController {
                vc.present(gcVC, animated: true)
            } else {
                self?.isAuthenticated = GKLocalPlayer.local.isAuthenticated
            }
        }
    }

    // MARK: - Achievements

    func report(_ id: Achievement, percent: Double = 100.0) {
        guard isAuthenticated else { return }
        let achievement = GKAchievement(identifier: id.rawValue)
        achievement.percentComplete = min(100, max(0, percent))
        achievement.showsCompletionBanner = true
        GKAchievement.report([achievement])
    }

    // MARK: - IDs

    enum Achievement: String {
        case firstBlood    = "com.appmakerstudio.echoes.firstCombat"
        case bossDefeated  = "com.appmakerstudio.echoes.bossDefeated"
        case lyraQuest     = "com.appmakerstudio.echoes.lyraQuest"
        case deliveryQuest = "com.appmakerstudio.echoes.deliveryQuest"
        case loreCollector = "com.appmakerstudio.echoes.loreCollector"   // 4/4 lore IDs
        case act2Reached   = "com.appmakerstudio.echoes.act2"
        case act3Reached   = "com.appmakerstudio.echoes.act3"
        case act4Reached   = "com.appmakerstudio.echoes.act4"
        case corruptedSoul = "com.appmakerstudio.echoes.corrupted"       // corruption level 3
    }
}
