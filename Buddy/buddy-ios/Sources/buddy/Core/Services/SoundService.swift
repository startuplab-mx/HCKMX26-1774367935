import AVFoundation
import AudioToolbox

/// Plays system sounds for pet reactions. Uses AudioToolbox system sounds (no asset files needed).
/// Each PetAction maps to a tonally appropriate system feedback sound.
final class SoundService {
    static let shared = SoundService()
    private init() {}

    var isEnabled = true

    func play(for action: PetAction) {
        guard isEnabled else { return }
        let id: SystemSoundID
        switch action {
        case .idle:  return // silence
        case .eat:   id = 1057 // Tink
        case .sleep: id = 1306 // Begin recording (low murmur)
        case .play:  id = 1322 // Pop
        case .sad:   id = 1304 // Tweet (sad-ish)
        }
        AudioServicesPlaySystemSound(id)
    }

    func playClick() {
        guard isEnabled else { return }
        AudioServicesPlaySystemSound(1104)
    }

    func playReward() {
        guard isEnabled else { return }
        AudioServicesPlaySystemSound(1025)
    }
}
