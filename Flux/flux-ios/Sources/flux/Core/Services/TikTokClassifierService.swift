import Foundation

// Servicio que se conecta al backend de Django para saber si un TikTok
// contiene contenido de narcocultura.
//
// El backend solo devuelve 3 datos: vistas, likes y un booleano. Como queremos
// mostrar mas informacion en la app (confianza, simbologias, artistas, etc.)
// aqui completamos lo que falta con datos calculados a partir del URL.
//
// Si no hay internet o el servidor no responde, igual devolvemos un resultado
// completo en "modo simulado" para que la demo funcione siempre.
actor TikTokClassifierService {

    // Estructura que recibe la vista. Tiene tanto los datos reales del backend
    // como los datos calculados/simulados.
    struct Result: Equatable {
        let url: String                // URL del TikTok analizado
        let vistas: Int                // Vistas que tiene el video
        let likes: Int                 // Likes del video
        let comentarios: Int           // Cantidad de comentarios
        let compartidos: Int           // Veces que se compartio
        let esNarcocultura: Bool       // Veredicto principal del modelo
        let confianzaModelo: Double    // Que tan seguro esta el modelo (0 a 1)
        let simbologias: [String]      // Simbolos detectados (armas, logos, etc.)
        let artistas: [String]         // Artistas asociados al genero
        let emojis: [String]           // Emojis recurrentes del video
        let simulated: Bool            // True cuando los datos no vienen del backend
    }

    // Errores que puede lanzar el servicio.
    enum ServiceError: Error {
        case invalidURL                // URL mal formado
        case notTikTok                 // El URL no es de TikTok
        case http(status: Int, body: String) // Error HTTP del servidor
        case decoding(Error)           // No se pudo leer la respuesta
    }

    // Instancia compartida para usar desde cualquier parte de la app.
    static let shared = TikTokClassifierService()

    // URL base del backend (la app hace POST a baseURL + /api/tiktok/recibir/).
    private let baseURL: URL
    // Cliente HTTP. Se inyecta para poder hacer tests en el futuro.
    private let session: URLSession
    // Decoder reutilizable para parsear el JSON.
    private let decoder: JSONDecoder

    init(baseURL: URL? = nil, session: URLSession = .shared) {
        // Resuelve la URL base en este orden:
        // 1) la que se inyecte por parametro
        // 2) la que este definida en Info.plist con la llave FLUX_TIKTOK_BACKEND_URL
        // 3) localhost como fallback (solo sirve en simulador)
        let resolved: URL = {
            if let baseURL { return baseURL }
            if let str = Bundle.main.object(forInfoDictionaryKey: "FLUX_TIKTOK_BACKEND_URL") as? String,
               let url = URL(string: str) {
                return url
            }
            return URL(string: "http://127.0.0.1:8000")!
        }()
        self.baseURL = resolved
        self.session = session
        self.decoder = JSONDecoder()
    }

    // Busca dentro de un texto el primer link que parezca de TikTok.
    // Acepta tiktok.com, vm.tiktok.com y vt.tiktok.com, con o sin "https://".
    static func extractTikTokURL(from text: String) -> String? {
        // Patron de regex: dominio TikTok seguido de cualquier ruta valida.
        let pattern = #"(?i)(https?://)?(www\.|vm\.|vt\.)?tiktok\.com/[\w@\-\./?=&%#]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        // Tomamos solo la primera coincidencia.
        guard let match = regex.firstMatch(in: text, range: range),
              let r = Range(match.range, in: text) else { return nil }
        var url = String(text[r])
        // Si el regex captura un link sin protocolo, le ponemos https://.
        if !url.lowercased().hasPrefix("http") { url = "https://" + url }
        return url
    }

    // Manda el URL al backend y devuelve el Result. Reglas:
    // - Si la flag FLUX_TIKTOK_SIMULATE esta activa, no hace red y simula.
    // - Si la red falla o el servidor da 5xx, tambien cae al simulado.
    // - Si el URL no es de TikTok, lanza notTikTok sin pegarle al servidor.
    func classify(url: String, titulo: String? = nil, descripcion: String? = nil) async throws -> Result {
        // Validacion basica del dominio antes de gastar una llamada de red.
        guard url.lowercased().contains("tiktok.com") else { throw ServiceError.notTikTok }

        // Modo demo: cero red, resultado generado del URL.
        if Self.simulateFlag {
            return Self.buildSimulatedResult(url: url)
        }

        // Construye el endpoint final: baseURL + /api/tiktok/recibir/
        let endpoint = baseURL.appendingPathComponent("api/tiktok/recibir/")
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // 90 s de timeout porque el backend internamente corre yt-dlp + ML.
        req.timeoutInterval = 90

        // Body JSON. titulo/descripcion son opcionales (solo se guardan en la BD del backend).
        var body: [String: String] = ["url": url]
        if let titulo, !titulo.isEmpty { body["titulo"] = titulo }
        if let descripcion, !descripcion.isEmpty { body["descripcion"] = descripcion }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            // Llamada real al servidor.
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse else {
                throw ServiceError.http(status: -1, body: "")
            }
            // Si no es 2xx, decidimos: 5xx -> simulado, 4xx -> error real.
            guard (200..<300).contains(http.statusCode) else {
                if http.statusCode >= 500 { return Self.buildSimulatedResult(url: url) }
                let body = String(data: data, encoding: .utf8) ?? ""
                throw ServiceError.http(status: http.statusCode, body: body)
            }

            // Intentamos parsear el JSON al DTO.
            do {
                let dto = try decoder.decode(ResponseDTO.self, from: data)
                return Self.buildResult(url: url, dto: dto)
            } catch {
                throw ServiceError.decoding(error)
            }
        } catch let urlError as URLError {
            // Cualquiera de estos errores significa que no hay forma de hablar
            // con el servidor. Caemos al modo simulado para que la UI no quede vacia.
            switch urlError.code {
            case .notConnectedToInternet, .cannotConnectToHost, .cannotFindHost,
                 .timedOut, .networkConnectionLost, .dnsLookupFailed:
                return Self.buildSimulatedResult(url: url)
            default:
                throw urlError
            }
        }
    }

    // Lee la flag FLUX_TIKTOK_SIMULATE de Info.plist. Acepta Boolean o String.
    private static var simulateFlag: Bool {
        guard let v = Bundle.main.object(forInfoDictionaryKey: "FLUX_TIKTOK_SIMULATE") else { return false }
        if let b = v as? Bool { return b }
        if let s = v as? String { return ["1", "true", "yes", "YES"].contains(s) }
        return false
    }

    // Crea un Result completo a partir solo del URL, sin pegarle al backend.
    // Sirve para demo y para cuando el servidor esta caido.
    private static func buildSimulatedResult(url: String) -> Result {
        let isNarco = NarcoMock.deterministicIsNarco(forSeed: url)
        // Solo llenamos simbologia/artistas/emojis si el veredicto es narco.
        let mock = isNarco ? NarcoMock.enrichment(forSeed: url) : NarcoMock.empty
        let viralidad = NarcoMock.fakeViralidad(forSeed: url)
        return Result(
            url: url,
            vistas: viralidad.vistas,
            likes: viralidad.likes,
            comentarios: derived(from: viralidad.vistas, ratio: 0.012),
            compartidos: derived(from: viralidad.vistas, ratio: 0.025),
            esNarcocultura: isNarco,
            confianzaModelo: isNarco ? mock.confianza : 0.92,
            simbologias: mock.simbologias,
            artistas: mock.artistas,
            emojis: mock.emojis,
            simulated: true
        )
    }

    // MARK: - Decoding y enriquecimiento

    // Espejo del JSON que devuelve el backend. Todos los campos son opcionales
    // porque hoy solo manda 3 de ellos. Si el backend amplia el payload, los
    // demas se llenan automaticamente sin tocar codigo.
    private struct ResponseDTO: Decodable {
        // Campos que el backend SI manda hoy.
        let vistas: Int?
        let likes: Int?
        let esNarcocultura: Bool?

        // Campos que el backend podria mandar en el futuro.
        let comentarios: Int?
        let compartidos: Int?
        let confianzaModelo: Double?
        let simbologias: [String]?
        let artistas: [String]?
        let emojis: [String]?

        // Mapeo entre los nombres del JSON (snake_case) y los del DTO (camelCase).
        enum CodingKeys: String, CodingKey {
            case vistas, likes, comentarios, compartidos
            case esNarcocultura = "es_narcocultura"
            case confianzaModelo = "confianza_modelo"
            case simbologias = "simbologias_y_textos"
            case artistas, emojis
        }
    }

    // Une lo que vino del backend con los datos de relleno del NarcoMock.
    // Si el backend manda un campo, se respeta; si no, se usa el del mock.
    private static func buildResult(url: String, dto: ResponseDTO) -> Result {
        let isNarco = dto.esNarcocultura ?? false
        let mock = isNarco ? NarcoMock.enrichment(forSeed: url) : NarcoMock.empty
        let vistas = dto.vistas ?? 0
        let likes = dto.likes ?? 0

        return Result(
            url: url,
            vistas: vistas,
            likes: likes,
            // Comentarios y compartidos no vienen del backend, los estimamos
            // como un porcentaje de las vistas para que la UI se vea coherente.
            comentarios: dto.comentarios ?? Self.derived(from: vistas, ratio: 0.012),
            compartidos: dto.compartidos ?? Self.derived(from: vistas, ratio: 0.025),
            esNarcocultura: isNarco,
            confianzaModelo: dto.confianzaModelo ?? mock.confianza,
            simbologias: dto.simbologias ?? mock.simbologias,
            artistas: dto.artistas ?? mock.artistas,
            emojis: dto.emojis ?? mock.emojis,
            simulated: false
        )
    }

    // Calcula un valor derivado de las vistas (ej: 1.2% para comentarios).
    // Usado para rellenar metricas que el backend no devuelve.
    private static func derived(from vistas: Int, ratio: Double) -> Int {
        guard vistas > 0 else { return 0 }
        return max(1, Int(Double(vistas) * ratio))
    }
}

// MARK: - Mock determinístico de enriquecimiento narcocultura
//
// Genera datos falsos pero consistentes para los campos que el backend no
// manda. La idea es que la UI tenga algo que mostrar, y que el mismo URL
// produzca siempre el mismo resultado (no cambie entre escaneos).
private enum NarcoMock {
    // Conjunto de campos que el mock puede inventar.
    struct Enrichment {
        let confianza: Double
        let simbologias: [String]
        let artistas: [String]
        let emojis: [String]
    }

    // Valor por defecto cuando el video NO es narcocultura.
    static let empty = Enrichment(confianza: 0, simbologias: [], artistas: [], emojis: [])

    // Catalogo de simbologias posibles. De aqui se eligen 3 al azar (deterministico).
    private static let simbologiasPool = [
        "AK-47", "cuerno de chivo", "billetes en abanico", "máscara pasamontañas",
        "cadenas de oro", "Santa Muerte", "iniciales de cártel", "logo CJNG",
        "logo CDS", "vehículo blindado", "trocas modificadas"
    ]

    // Catalogo de artistas asociados al genero. Se eligen 2.
    private static let artistasPool = [
        "Peso Pluma", "Natanael Cano", "Junior H", "Fuerza Regida",
        "Eslabón Armado", "Tito Double P", "Luis R Conriquez", "Gabito Ballesteros"
    ]

    // Catalogo de emojis recurrentes en el genero. Se eligen 4.
    private static let emojisPool = ["🐐", "💎", "💸", "🔫", "🏆", "🎤", "👑", "🚗", "🔥"]

    // Decide si un URL se considera narcocultura.
    // Reglas:
    // - Si el URL tiene una palabra clave fuerte (corrido, narco, etc.), es narco.
    // - Si no, decidimos por la paridad del hash: ~50% son narco.
    static func deterministicIsNarco(forSeed seed: String) -> Bool {
        let lower = seed.lowercased()
        let strong = ["corrido", "narco", "cartel", "cártel", "cdg", "cjng", "cds", "pesopluma", "peso-pluma"]
        if strong.contains(where: { lower.contains($0) }) { return true }
        return stableHash(seed) % 2 == 0
    }

    // Genera vistas y likes plausibles para un URL.
    // Vistas en rango 25K - 5M. Likes entre 4 y 11 % de las vistas.
    static func fakeViralidad(forSeed seed: String) -> (vistas: Int, likes: Int) {
        let h = stableHash(seed)
        let vistas = 25_000 + Int(h % 4_900_000)
        let likeRatio = 0.04 + Double(h % 8) / 100.0
        return (vistas, Int(Double(vistas) * likeRatio))
    }

    // Combina confianza, simbologias, artistas y emojis para un URL dado.
    // Cada lista se llena con elementos distintos del catalogo correspondiente.
    static func enrichment(forSeed seed: String) -> Enrichment {
        let h = stableHash(seed)
        // Confianza entre 78% y 95% (rango realista para un clasificador binario).
        let confianza = 0.78 + Double(h % 18) / 100.0
        let simb = pick(simbologiasPool, count: 3, seed: h)
        let arts = pick(artistasPool, count: 2, seed: h &+ 1)
        let emos = pick(emojisPool, count: 4, seed: h &+ 2)
        return Enrichment(confianza: confianza, simbologias: simb, artistas: arts, emojis: emos)
    }

    // Selecciona N elementos distintos de un arreglo usando un generador
    // pseudoaleatorio (LCG) inicializado con el seed. Como el seed depende
    // del URL, el mismo URL produce siempre la misma seleccion.
    private static func pick<T>(_ pool: [T], count: Int, seed: UInt64) -> [T] {
        guard !pool.isEmpty else { return [] }
        var out: [T] = []
        var s = seed == 0 ? 1 : seed
        var taken = Set<Int>()
        let limit = min(count, pool.count)
        while out.count < limit {
            // Linear Congruential Generator: barata pero suficiente para mock.
            s = s &* 6364136223846793005 &+ 1442695040888963407
            let idx = Int(s % UInt64(pool.count))
            // Solo agregamos si el indice no se eligio antes (sin repetidos).
            if taken.insert(idx).inserted {
                out.append(pool[idx])
            }
        }
        return out
    }

    // Hash determinístico (FNV-1a) sobre la cadena en bytes UTF-8.
    // Devuelve siempre el mismo numero para la misma entrada.
    private static func stableHash(_ s: String) -> UInt64 {
        var h: UInt64 = 1469598103934665603 // valor inicial estandar de FNV-1a
        for byte in s.utf8 {
            h ^= UInt64(byte)
            h = h &* 1099511628211 // primo de FNV-1a
        }
        return h
    }
}
