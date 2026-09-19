import UIKit

/// Point d'entrée. Cycle de vie **par scènes** (`UIWindowSceneDelegate`) :
/// depuis Xcode 27, le SDK refuse de lancer une app qui crée sa fenêtre à la
/// main dans l'`AppDelegate` — « UIScene life cycle is required for apps
/// built with this SDK ». Le projet déclarait déjà un manifeste de scène
/// (`UIApplicationSceneManifest_Generation`), il ne restait qu'à l'honorer.
@main
final class EchoesOfAetherApp: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Avant toute scène : la police pixel doit être enregistrée quand le
        // premier écran se construit.
        PixelUI.registerPixelFont()
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default",
                                          sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

/// Une seule scène : la fenêtre du jeu. C'est ici — et plus dans
/// l'`AppDelegate` — que la fenêtre naît et reçoit son contrôleur.
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = GameViewController()
        window.makeKeyAndVisible()
        self.window = window
    }
}
