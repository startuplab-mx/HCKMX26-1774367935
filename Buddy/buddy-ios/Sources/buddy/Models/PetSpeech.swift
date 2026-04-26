import Foundation

/// Random short phrases the pet "says" via floating speech bubbles.
/// Curated by personality + context for a kid-friendly tone.
enum PetSpeech {
    static func greeting(name: String) -> String {
        ["¡Hola! 👋", "¡Volviste! 💖", "Te extrañé", "¿Jugamos?", "¡Qué bueno verte!"].randomElement()!
    }

    static func eat() -> String {
        ["¡Ñam! 🍖", "¡Mmm rico!", "¿Más?", "¡Delicioso!", "¡Mi favorito!"].randomElement()!
    }

    static func play() -> String {
        ["¡Yupi! 🎉", "¡Otra vez!", "¡Sí sí sí!", "¡Esto es divertido!", "¡Ja ja!"].randomElement()!
    }

    static func sleep() -> String {
        ["Zzz...", "Buenas noches", "😴", "Sueñitos..."].randomElement()!
    }

    static func bath() -> String {
        ["¡Limpio! 🛁", "Mmm el agua", "¡Brillo!", "Me gustan las burbujas"].randomElement()!
    }

    static func sad() -> String {
        ["😢", "Buaa...", "No me dejes", "Estoy triste", "Necesito mimos"].randomElement()!
    }

    static func bored() -> String {
        ["¿Hago algo? 🤔", "Aburrido...", "¡Hagamos algo!", "Quiero jugar"].randomElement()!
    }

    static func hungry() -> String {
        ["¡Hambre! 🍖", "Mi panza ruge", "¿Comemos?", "Ñom ñom..."].randomElement()!
    }

    static func thirsty() -> String {
        ["¡Sed! 💧", "Quiero agua", "*lengua afuera*", "Glup glup"].randomElement()!
    }

    /// Personality-flavored idle chatter when nothing else is happening.
    static func idle(trait: PersonalityTrait, name: String) -> String {
        switch trait {
        case .glotton:
            return ["¿Hay snacks?", "Pienso en comida", "Mi panza...", "🍔🍖🍪"].randomElement()!
        case .juguetón:
            return ["¡Vamos a correr!", "¿Jugamos?", "🎾 🎾", "¡Tira el juguete!"].randomElement()!
        case .dormilon:
            return ["Tengo sueño", "Otra siesta...", "😴", "Zzz..."].randomElement()!
        case .carinoso:
            return ["Te quiero 💖", "¿Mimos?", "Acércate", "🥰"].randomElement()!
        case .neutral:
            return ["Hmm...", "👀", "*observa*", "¿Qué pasa?"].randomElement()!
        }
    }
}
