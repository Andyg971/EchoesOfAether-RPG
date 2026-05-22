import AVFoundation

/// AudioEngine — STUB temporaire.
///
/// L'ancienne implémentation utilisait AVAudioSourceNode avec closures
/// capturant des var mutables. Sur iOS 26 simulator, le render callback
/// sur AURemoteIO::IOThread crashe avec `_dispatch_assert_queue_fail`
/// (libdispatch precondition échoue).
///
/// Cette version désactive tout audio. Le jeu tourne en silence.
/// TODO V2 : réimplémenter avec AVAudioPlayerNode + AVAudioPCMBuffer
/// pré-rendus (API stable, pas de crash IO thread).
@MainActor
final class AudioEngine {

    static let shared = AudioEngine()

    var isRunning: Bool { false }
    var masterVolume: Float = 1.0

    private init() {}

    // MARK: - Lifecycle (no-op)

    func start() {
        #if DEBUG
        print("[AudioEngine] audio désactivé (stub)")
        #endif
    }

    func stop() {}

    // MARK: - Game Sounds (no-op)

    func playTap() {}
    func playSelect() {}
    func playHit() {}
    func playBlackSlash() {}
    func playDamage() {}
    func playGoldGain() {}
    func playPurchase() {}
    func playQuestComplete() {}
    func playVictory() {}
    func playStep() {}
    func playShopOpen() {}
}
