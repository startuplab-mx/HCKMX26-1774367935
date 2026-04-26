import AVFoundation

/// Pet "voice" using AVSpeechSynthesizer with a high-pitched cute voice for each action.
final class PetVoiceService {
    static let shared = PetVoiceService()
    private let synth = AVSpeechSynthesizer()
    private init() {}

    var isEnabled = true

    func say(for action: PetAction, name: String) {
        guard isEnabled else { return }
        let phrase: String
        switch action {
        case .idle:  return
        case .eat:   phrase = ["¡Ñam!", "Mmm rico", "Más por favor"].randomElement()!
        case .sleep: phrase = ["Zzz…", "Buenas noches"].randomElement()!
        case .play:  phrase = ["¡Yupi!", "¡Otra vez!", "¡Wiii!"].randomElement()!
        case .sad:   phrase = ["Buaaa", "No me dejes solo", "Snif"].randomElement()!
        }
        let u = AVSpeechUtterance(string: phrase)
        u.voice = AVSpeechSynthesisVoice(language: "es-ES")
        u.pitchMultiplier = 1.7
        u.rate = 0.55
        u.volume = 0.8
        synth.speak(u)
    }
}
