import SwiftUI
import AVFoundation
import UIKit
import PhotosUI
import UniformTypeIdentifiers
import PDFKit

struct ScannerView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var camera = CameraService()
    @State private var selectedType: ScanContext = .chat
    @State private var showResult = false
    @State private var shutterFlash = false

    @State private var pickerItem: PhotosPickerItem?
    @State private var showPhotosPicker = false
    @State private var showFileImporter = false
    @State private var importedRegions: [DetectedTextRegion] = []
    @State private var showImportedResult = false
    @State private var isAnalyzing = false

    static func label(for type: ScanContext) -> String {
        switch type {
        case .chat: "chat"
        case .doc: "doc"
        case .profile: "perfil"
        case .link: "link"
        }
    }

    var body: some View {
        ZStack {
            if camera.isAuthorized {
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()

                // Línea de escaneo a PANTALLA COMPLETA
                FullScreenScanLine()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                // Overlay AR sobre texto detectado (toda la vista)
                GeometryReader { geo in
                    ZStack(alignment: .topLeading) {
                        ForEach(camera.detectedRegions) { region in
                            ARHighlight(region: region, canvas: geo.size)
                        }
                    }
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)

                // Viñeta sutil para dar foco al centro
                RadialGradient(
                    colors: [.clear, .black.opacity(0.35)],
                    center: .center,
                    startRadius: 260,
                    endRadius: 640
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
            } else {
                Color.black.ignoresSafeArea()
                VStack(spacing: 12) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 48, weight: .regular))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("Necesitamos acceso a la cámara")
                        .font(FluxFont.body(15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("flux analiza lo que escaneas on-device. Nada se sube.")
                        .font(FluxFont.body(13))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }

            // Flash de shutter
            if shutterFlash {
                Color.white
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }

            // UI overlay (controls)
            VStack(spacing: 0) {
                topBar
                Spacer()
                HStack(spacing: 6) {
                    ForEach(ScanContext.allCases, id: \.self) { type in
                        typeChip(type)
                    }
                }
                stats
                dock
            }
            .padding(.horizontal, 16)

            if isAnalyzing {
                Color.black.opacity(0.6).ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView().tint(.white)
                    Text("Analizando…")
                        .font(FluxFont.body(13, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await camera.requestAuthorization()
            if camera.isAuthorized { camera.start() }
        }
        .onAppear { camera.scanType = selectedType }
        .onChange(of: selectedType) { _, new in camera.scanType = new }
        .onDisappear { camera.stop() }
        .fullScreenCover(isPresented: $showResult) {
            ScanResultView(
                regions: camera.detectedRegions,
                scanType: selectedType,
                tikTokURL: tikTokURL(in: camera.detectedRegions)
            )
        }
        .fullScreenCover(isPresented: $showImportedResult) {
            ScanResultView(
                regions: importedRegions,
                scanType: selectedType,
                tikTokURL: tikTokURL(in: importedRegions)
            )
        }
        .photosPicker(isPresented: $showPhotosPicker, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task { await handlePickedItem(newItem) }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.image, .pdf, .png, .jpeg, .heic],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                Task { await handlePickedFile(url) }
            }
        }
    }

    // Devuelve el primer URL de TikTok que aparezca en lo que se escaneo.
    // Funciona en cualquier modo (chat, doc, perfil, link). Primero revisa el
    // texto del OCR; si no encuentra nada, mira el portapapeles por si el
    // usuario pego un link manualmente.
    private func tikTokURL(in regions: [DetectedTextRegion]) -> String? {
        // Junta todo el texto detectado en una sola cadena para buscar.
        let combined = regions.map(\.text).joined(separator: " ")
        // Primer intento: lo que la camara/galeria capto via OCR.
        if let fromOCR = TikTokClassifierService.extractTikTokURL(from: combined) {
            return fromOCR
        }
        // Segundo intento: el portapapeles (util cuando el usuario copia un link).
        if let pasted = UIPasteboard.general.string,
           let fromClipboard = TikTokClassifierService.extractTikTokURL(from: pasted) {
            return fromClipboard
        }
        // No hay URL de TikTok que clasificar.
        return nil
    }

    // MARK: - Acciones externas
    private func handlePickedItem(_ item: PhotosPickerItem) async {
        isAnalyzing = true
        defer { Task { @MainActor in isAnalyzing = false; pickerItem = nil } }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        let regions = await camera.analyzeImage(image, type: selectedType)
        await MainActor.run {
            importedRegions = regions
            showImportedResult = true
        }
    }

    // Procesa un archivo elegido desde Files. Acepta imagenes y PDFs.
    private func handlePickedFile(_ url: URL) async {
        // Indicador de carga visible mientras se hace el OCR.
        isAnalyzing = true
        defer { Task { @MainActor in isAnalyzing = false } }
        // Permiso temporal de iOS para leer archivos fuera del sandbox.
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        // Lee los bytes; si no se puede, abortamos en silencio.
        guard let data = try? Data(contentsOf: url) else { return }

        // Caso 1: el archivo es una imagen normal (JPG/PNG/HEIC).
        if let image = UIImage(data: data) {
            let regions = await camera.analyzeImage(image, type: selectedType)
            await MainActor.run {
                importedRegions = regions
                showImportedResult = true
            }
            return
        }

        // Caso 2: el archivo es un PDF. Convertimos las primeras 5 paginas
        // a imagenes y corremos OCR en cada una. El limite es para no
        // bloquear la UI con documentos largos.
        if let pdf = PDFDocument(data: data) {
            var allRegions: [DetectedTextRegion] = []
            let pages = min(pdf.pageCount, 5)
            for i in 0..<pages {
                guard let page = pdf.page(at: i) else { continue }
                // mediaBox = el rectangulo "fisico" de la pagina en puntos.
                let bounds = page.bounds(for: .mediaBox)
                // Escala 2x para que el OCR tenga suficiente resolucion.
                let scale: CGFloat = 2.0
                let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
                let renderer = UIGraphicsImageRenderer(size: size)
                let img = renderer.image { ctx in
                    // Fondo blanco por si el PDF tiene transparencia.
                    UIColor.white.setFill()
                    ctx.fill(CGRect(origin: .zero, size: size))
                    // PDFKit usa coordenadas invertidas en Y, por eso el flip.
                    ctx.cgContext.translateBy(x: 0, y: size.height)
                    ctx.cgContext.scaleBy(x: scale, y: -scale)
                    page.draw(with: .mediaBox, to: ctx.cgContext)
                }
                // OCR sobre la pagina renderizada y acumulamos regiones.
                let regions = await camera.analyzeImage(img, type: selectedType)
                allRegions.append(contentsOf: regions)
            }
            await MainActor.run {
                importedRegions = allRegions
                showImportedResult = true
            }
        }
    }

    private func triggerShutter() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.easeOut(duration: 0.08)) { shutterFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeIn(duration: 0.15)) { shutterFlash = false }
            showResult = true
        }
    }

    // MARK: - Top bar
    private var topBar: some View {
        HStack {
            circleButton(system: "xmark", active: false) { dismiss() }
            Spacer()
            pill
            Spacer()
            circleButton(system: camera.torchOn ? "bolt.fill" : "bolt", active: camera.torchOn) {
                camera.toggleTorch()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
        .padding(.top, 8)
    }

    private func circleButton(system: String, active: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(active ? FluxColor.ink : .white)
                .frame(width: 40, height: 40)
                .background(Circle().fill(active ? Color.white : .white.opacity(0.1)))
                .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 1))
                .background(.ultraThinMaterial, in: Circle())
        }
    }

    private var pill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(hex: 0x4ADE80))
                .frame(width: 6, height: 6)
                .shadow(color: Color(hex: 0x4ADE80), radius: 3)
            Text("WEPROTECT · LIVE")
                .font(FluxFont.mono(10, weight: .bold))
                .tracking(2)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(FluxColor.primary.opacity(0.25))
                .overlay(Capsule().stroke(FluxColor.primary.opacity(0.5), lineWidth: 1))
        )
        .background(.ultraThinMaterial, in: Capsule())
    }

    // MARK: - Type chip
    private func typeChip(_ type: ScanContext) -> some View {
        let isActive = type == selectedType
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.smooth(duration: 0.2)) { selectedType = type }
        } label: {
            Text(Self.label(for: type))
                .font(FluxFont.body(12, weight: isActive ? .semibold : .medium))
                .foregroundStyle(isActive ? FluxColor.ink : .white.opacity(0.6))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(isActive ? Color.white : .white.opacity(0.08))
                        .overlay(Capsule().stroke(.white.opacity(isActive ? 0 : 0.12), lineWidth: 1))
                )
        }
    }

    // MARK: - Stats
    private var stats: some View {
        HStack(spacing: 8) {
            statChip(value: "\(camera.detectedRegions.filter { $0.risk == .high }.count)", label: "patrones")
            statChip(value: "\(camera.detectedRegions.count)", label: "fragmentos")
            statChip(value: "on-device", label: "privado")
        }
        .padding(.bottom, 16)
    }

    private func statChip(value: String, label: String) -> some View {
        HStack(spacing: 6) {
            Text(value)
                .font(FluxFont.display(13, weight: .bold))
                .foregroundStyle(.white)
            Text(label.uppercased())
                .font(FluxFont.mono(9))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.white.opacity(0.1))
                .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 1))
        )
        .background(.ultraThinMaterial, in: Capsule())
    }

    // MARK: - Dock
    private var dock: some View {
        HStack(spacing: 28) {
            dockItem(system: "photo.on.rectangle", label: "galería") {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showPhotosPicker = true
            }

            Button {
                triggerShutter()
            } label: {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 70, height: 70)
                        .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 4))
                    Circle()
                        .strokeBorder(FluxColor.ink, lineWidth: 2)
                        .frame(width: 52, height: 52)
                }
                .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
            }

            dockItem(system: "paperclip", label: "archivo") {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showFileImporter = true
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(.black.opacity(0.5))
                .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.12), lineWidth: 1))
        )
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
        .padding(.bottom, 16)
    }

    private func dockItem(system: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: system)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(.white)
                Text(label)
                    .font(FluxFont.body(10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }
}

// MARK: - Camera preview
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        v.backgroundColor = .black
        v.videoPreviewLayer.session = session
        v.videoPreviewLayer.videoGravity = .resizeAspectFill
        return v
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

// MARK: - Línea de sensor full-screen (barre toda la vista)
struct FullScreenScanLine: View {
    @State private var progress: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            ZStack(alignment: .top) {
                // Estela luminosa detrás de la línea
                LinearGradient(
                    colors: [
                        Color(hex: 0x4ADE80).opacity(0.0),
                        Color(hex: 0x4ADE80).opacity(0.18),
                        Color(hex: 0x4ADE80).opacity(0.0)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 180)
                .offset(y: progress * h - 90)

                // Línea principal
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                Color(hex: 0x4ADE80).opacity(0.9),
                                Color.white.opacity(0.9),
                                Color(hex: 0x4ADE80).opacity(0.9),
                                .clear
                            ],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(height: 2)
                    .shadow(color: Color(hex: 0x4ADE80).opacity(0.8), radius: 10)
                    .shadow(color: Color(hex: 0x4ADE80).opacity(0.5), radius: 20)
                    .offset(y: progress * h)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                    progress = 1
                }
            }
        }
    }
}

// MARK: - AR highlight overlay
struct ARHighlight: View {
    let region: DetectedTextRegion
    let canvas: CGSize

    var body: some View {
        if region.risk != .low {
            let rect = CGRect(
                x: region.boundingBox.minX * canvas.width,
                y: region.boundingBox.minY * canvas.height,
                width: region.boundingBox.width * canvas.width,
                height: region.boundingBox.height * canvas.height
            )
            RoundedRectangle(cornerRadius: 8)
                .stroke(region.risk.color, lineWidth: 2)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(region.risk.color.opacity(0.12))
                )
                .shadow(color: region.risk.color.opacity(0.6), radius: 8)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .overlay(alignment: .topLeading) {
                    Text(region.risk.label)
                        .font(FluxFont.mono(9, weight: .bold))
                        .tracking(1.5)
                        .textCase(.uppercase)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(region.risk.color))
                        .offset(x: rect.minX + 4, y: rect.minY - 10)
                }
        }
    }
}

// MARK: - Scan result — diagnóstico real
// Vista que se muestra despues de un escaneo. Toma las regiones de texto
// detectadas y produce un diagnostico (riesgo, recomendaciones, evidencia).
// Si entre el texto hay un URL de TikTok, tambien lo manda al backend para
// clasificarlo como narcocultura y combina ambos resultados.
struct ScanResultView: View {
    @Environment(\.dismiss) var dismiss
    // Almacen donde se guardan las amenazas que el padre decide archivar.
    @StateObject private var store = ThreatStore.shared
    // Texto detectado por OCR en el escaneo.
    let regions: [DetectedTextRegion]
    // Contexto que el usuario eligio (chat, doc, perfil, link).
    let scanType: ScanContext
    // URL de TikTok detectado, si existe. Detona la llamada al backend.
    var tikTokURL: String? = nil

    // Estado del boton "guardar amenaza".
    @State private var isSaved = false
    // Visibilidad del toast de confirmacion.
    @State private var showSavedToast = false

    // Estado de la llamada al backend de TikTok. Empieza en idle, pasa por
    // loading mientras esperamos al servidor y termina en success o failure.
    @State private var tikTokState: TikTokState = .idle
    enum TikTokState: Equatable {
        case idle                                                  // sin URL detectada
        case loading(url: String)                                  // request en vuelo
        case success(TikTokClassifierService.Result)               // respuesta lista
        case failure(message: String, url: String)                 // error de red
    }

    // Diagnostico mostrado al usuario. Combina el analisis on-device
    // (patrones locales en el texto) con el veredicto del backend de TikTok.
    // Si el backend confirma narcocultura, el veredicto pasa a "danger" y
    // se agregan recomendaciones especificas.
    private var diagnosis: WeProtectOnDevice.Diagnosis {
        // Analisis local sin red.
        let base = WeProtectOnDevice.diagnose(regions: regions, context: scanType)
        // Si no hubo respuesta de narco del backend, usamos el local tal cual.
        guard case .success(let r) = tikTokState, r.esNarcocultura else { return base }

        // Hallazgo sintetico que se agrega arriba de los locales.
        let injected = WeProtectOnDevice.Diagnosis.Finding(
            tag: "narcocultura",
            quote: "Modelo ML detectó narcocultura (\(Int(r.confianzaModelo * 100))% confianza)",
            risk: .high
        )
        // Score: nunca menor a 78 cuando el backend confirma narco.
        let fused = min(100, max(base.score, 78))
        // Recomendaciones especificas para el caso de narcocultura.
        let extraRecs = [
            "Habla con tu hij@ sobre por qué este contenido aparece en su feed.",
            "Revisa cuentas que sigue en TikTok y bloquea las que promueven cárteles.",
            "Activa restricciones de contenido en TikTok → Configuración → Bienestar digital."
        ]
        // Construimos el diagnostico fusionado.
        return WeProtectOnDevice.Diagnosis(
            verdict: .danger,
            score: fused,
            summary: "El backend identificó narcocultura en este TikTok. " + base.summary,
            findings: [injected] + base.findings,
            recommendations: extraRecs + base.recommendations
        )
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        verdictHero
                        if tikTokState != .idle { tikTokSection }
                        scoreBar
                        summarySection
                        if !diagnosis.findings.isEmpty { findingsSection }
                        recommendationsSection
                        evidenceSection
                        actions
                        Text(privacyFooter)
                            .font(FluxFont.mono(10))
                            .tracking(1)
                            .foregroundStyle(FluxColor.inkFaint)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .multilineTextAlignment(.center)
                            .padding(.top, 8)
                    }
                    .padding(20)
                }
                .background(FluxColor.base.ignoresSafeArea())

                // Toast de confirmación
                if showSavedToast {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(FluxColor.safe)
                        Text("Amenaza guardada")
                            .font(FluxFont.body(13, weight: .semibold))
                            .foregroundStyle(FluxColor.ink)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(FluxColor.surface)
                            .shadow(color: .black.opacity(0.1), radius: 12, y: 4)
                    )
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
                }
            }
            .navigationTitle("Análisis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("cerrar") { dismiss() }
                }
            }
            .task(id: tikTokURL) {
                await classifyTikTokIfNeeded()
            }
        }
    }

    // Texto del pie de pantalla. Cambia segun si hubo o no llamada al servidor,
    // para ser honestos con el usuario sobre que datos salieron del telefono.
    private var privacyFooter: String {
        switch tikTokState {
        case .success, .loading:
            return "Texto: análisis on-device · URL TikTok: enviada al servidor de clasificación"
        default:
            return "Análisis on-device · nada se subió a un servidor"
        }
    }

    // MARK: - TikTok backend

    // Si hay un URL de TikTok detectado, lo manda al backend y actualiza el
    // estado segun la respuesta. Se llama desde .task(id: tikTokURL),
    // asi que se reejecuta automaticamente si el URL cambia.
    private func classifyTikTokIfNeeded() async {
        // Sin URL no hay nada que clasificar.
        guard let url = tikTokURL, !url.isEmpty else { return }
        // Mostramos el spinner mientras esperamos al servidor.
        await MainActor.run { tikTokState = .loading(url: url) }
        do {
            // Llamada al servicio (puede caer en simulado si no hay red).
            let result = try await TikTokClassifierService.shared.classify(url: url)
            await MainActor.run { tikTokState = .success(result) }
        } catch {
            // Convertimos el error tecnico en un mensaje amigable para la UI.
            let msg: String
            switch error {
            case TikTokClassifierService.ServiceError.http(let status, _):
                msg = "El servidor respondió \(status)."
            case TikTokClassifierService.ServiceError.notTikTok:
                msg = "El link no es de TikTok."
            case TikTokClassifierService.ServiceError.decoding:
                msg = "Respuesta inesperada del servidor."
            default:
                msg = "No se pudo conectar con el servicio."
            }
            await MainActor.run { tikTokState = .failure(message: msg, url: url) }
        }
    }

    // Tarjeta de la clasificacion TikTok. Cambia su contenido segun el estado:
    // loading -> spinner, success -> datos, failure -> mensaje + reintentar.
    private var tikTokSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Encabezado fijo de la tarjeta.
            HStack(spacing: 8) {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text("CLASIFICACIÓN TIKTOK")
                    .font(FluxFont.mono(10, weight: .bold))
                    .tracking(2)
            }
            .foregroundStyle(FluxColor.inkMuted)

            // Cuerpo de la tarjeta segun el estado actual.
            switch tikTokState {
            case .idle:
                // Sin URL detectado: la tarjeta no aparece (filtrado en el padre).
                EmptyView()
            case .loading(let url):
                // Mientras esperamos al servidor: spinner + URL truncado.
                HStack(spacing: 10) {
                    ProgressView().scaleEffect(0.8)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Analizando en servidor…")
                            .font(FluxFont.body(13, weight: .semibold))
                            .foregroundStyle(FluxColor.ink)
                        Text(url)
                            .font(FluxFont.mono(10))
                            .foregroundStyle(FluxColor.inkFaint)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            case .success(let result):
                // Hay respuesta: mostramos veredicto + metricas + recursos.
                tikTokSuccess(result)
            case .failure(let message, let url):
                // Hubo error: mensaje y boton de reintento.
                tikTokFailure(message: message, url: url)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            // Color del borde varia segun el estado (rojo, verde, amarillo).
            RoundedRectangle(cornerRadius: 16)
                .fill(tikTokBackgroundColor.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(tikTokBackgroundColor.opacity(0.3), lineWidth: 1))
        )
    }

    // Color base de la tarjeta TikTok segun el estado:
    // narco -> rojo, seguro -> verde, error -> amarillo, otros -> gris.
    private var tikTokBackgroundColor: Color {
        switch tikTokState {
        case .success(let r): return r.esNarcocultura ? FluxColor.danger : FluxColor.safe
        case .failure: return FluxColor.warn
        default: return FluxColor.inkMuted
        }
    }

    // Estado exitoso de la tarjeta TikTok. Renderiza, en este orden:
    // 1) Encabezado con icono + titulo del veredicto + URL truncado.
    // 2) Barra de confianza del modelo.
    // 3) Cuatro metricas de viralidad.
    // 4) (Solo si es narco) simbologias, artistas y emojis.
    private func tikTokSuccess(_ r: TikTokClassifierService.Result) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Encabezado: icono grande + textos.
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: r.esNarcocultura ? "exclamationmark.octagon.fill" : "checkmark.seal.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(r.esNarcocultura ? FluxColor.danger : FluxColor.safe)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        // Frase principal segun el veredicto.
                        Text(r.esNarcocultura ? "Contenido de narcocultura" : "Sin señales de narcocultura")
                            .font(FluxFont.body(15, weight: .semibold))
                            .foregroundStyle(FluxColor.ink)
                        // Badge SIMULADO cuando el dato no vino del backend.
                        // Se muestra para no engañar al usuario.
                        if r.simulated {
                            Text("SIMULADO")
                                .font(FluxFont.mono(8, weight: .bold))
                                .tracking(1.5)
                                .foregroundStyle(FluxColor.warn)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .stroke(FluxColor.warn.opacity(0.5), lineWidth: 1)
                                )
                        }
                    }
                    // URL del video, en mono y con truncamiento al medio.
                    Text(r.url)
                        .font(FluxFont.mono(10))
                        .foregroundStyle(FluxColor.inkFaint)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 0)
            }

            // Bloque de confianza: barra horizontal con el porcentaje del modelo.
            // Solo se muestra si tenemos un valor mayor a 0.
            if r.confianzaModelo > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("CONFIANZA DEL MODELO")
                            .font(FluxFont.mono(9, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(FluxColor.inkMuted)
                        Spacer()
                        Text("\(Int(r.confianzaModelo * 100))%")
                            .font(FluxFont.display(13, weight: .bold))
                            .foregroundStyle(r.esNarcocultura ? FluxColor.danger : FluxColor.safe)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(FluxColor.line)
                            Capsule()
                                .fill(r.esNarcocultura ? FluxColor.danger : FluxColor.safe)
                                .frame(width: geo.size.width * CGFloat(r.confianzaModelo))
                        }
                    }
                    .frame(height: 6)
                }
            }

            // Cuatro chips de viralidad: vistas, likes, comentarios y compartidos.
            // Los numeros se formatean con K/M/B para que no se desborden.
            HStack(spacing: 8) {
                tikTokMetric(value: formatCount(r.vistas), label: "vistas")
                tikTokMetric(value: formatCount(r.likes), label: "likes")
                tikTokMetric(value: formatCount(r.comentarios), label: "coment.")
                tikTokMetric(value: formatCount(r.compartidos), label: "compart.")
            }

            // Listas de recursos detectados. Solo aparecen si el video es
            // narcocultura, porque para videos seguros no aplican.
            if r.esNarcocultura {
                if !r.simbologias.isEmpty {
                    // Tags rojos con los simbolos detectados (armas, logos, etc.).
                    tikTokTagGroup(title: "simbologías detectadas", items: r.simbologias, color: FluxColor.danger)
                }
                if !r.artistas.isEmpty {
                    // Tags amarillos con los artistas asociados al genero.
                    tikTokTagGroup(title: "artistas asociados", items: r.artistas, color: FluxColor.warn)
                }
                if !r.emojis.isEmpty {
                    // Linea horizontal con los emojis recurrentes del video.
                    HStack(spacing: 6) {
                        Text("EMOJIS")
                            .font(FluxFont.mono(9, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(FluxColor.inkMuted)
                        Text(r.emojis.joined(separator: " "))
                            .font(.system(size: 18))
                    }
                }
            }
        }
    }

    // Grupo de tags scrollable horizontal (titulo + lista de capsulas).
    // Lo usamos para simbologias y artistas; cada uno con su color.
    private func tikTokTagGroup(title: String, items: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(FluxFont.mono(9, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(FluxColor.inkMuted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(items, id: \.self) { item in
                        Text(item)
                            .font(FluxFont.body(11, weight: .semibold))
                            .foregroundStyle(color)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(color.opacity(0.12))
                                    .overlay(Capsule().stroke(color.opacity(0.4), lineWidth: 1))
                            )
                    }
                }
            }
        }
    }

    // Estado de error: icono + mensaje + boton "reintentar".
    // El boton vuelve a llamar a classifyTikTokIfNeeded() con el mismo URL.
    private func tikTokFailure(message: String, url: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "wifi.exclamationmark")
                    .foregroundStyle(FluxColor.warn)
                Text("No se pudo clasificar")
                    .font(FluxFont.body(14, weight: .semibold))
                    .foregroundStyle(FluxColor.ink)
            }
            Text(message)
                .font(FluxFont.body(12))
                .foregroundStyle(FluxColor.inkMuted)
            Button {
                Task { await classifyTikTokIfNeeded() }
            } label: {
                Text("reintentar")
                    .font(FluxFont.body(12, weight: .semibold))
                    .foregroundStyle(FluxColor.primary)
            }
        }
    }

    // Capsula con un valor numerico y su etiqueta debajo.
    // Se usa para mostrar las 4 metricas de viralidad.
    private func tikTokMetric(value: String, label: String) -> some View {
        HStack(spacing: 6) {
            Text(value)
                .font(FluxFont.display(13, weight: .bold))
                .foregroundStyle(FluxColor.ink)
            Text(label.uppercased())
                .font(FluxFont.mono(9))
                .tracking(1.5)
                .foregroundStyle(FluxColor.inkMuted)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(FluxColor.surface)
                .overlay(Capsule().stroke(FluxColor.line))
        )
    }

    // Formatea un numero grande a un texto corto: 1500 -> "1.5K".
    // Usa K para miles, M para millones, B para miles de millones.
    private func formatCount(_ n: Int) -> String {
        switch n {
        case ..<1_000: return "\(n)"
        case ..<1_000_000: return String(format: "%.1fK", Double(n) / 1_000)
        case ..<1_000_000_000: return String(format: "%.1fM", Double(n) / 1_000_000)
        default: return String(format: "%.1fB", Double(n) / 1_000_000_000)
        }
    }

    // Hero
    private var verdictHero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Circle()
                    .fill(diagnosis.verdict.color)
                    .frame(width: 10, height: 10)
                    .shadow(color: diagnosis.verdict.color.opacity(0.7), radius: 6)
                Text(contextHeader.uppercased())
                    .font(FluxFont.mono(10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(FluxColor.inkMuted)
                Spacer()
                Image(systemName: verdictIcon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(diagnosis.verdict.color)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(diagnosis.verdict.label)
                    .font(FluxFont.title1)
                    .foregroundStyle(FluxColor.ink)
                Text(verdictSubtitle)
                    .font(FluxFont.body(13))
                    .foregroundStyle(FluxColor.inkMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(diagnosis.verdict.color.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(diagnosis.verdict.color.opacity(0.3), lineWidth: 1))
        )
    }

    private var verdictIcon: String {
        switch diagnosis.verdict {
        case .safe: return "checkmark.seal.fill"
        case .caution: return "exclamationmark.triangle.fill"
        case .danger: return "exclamationmark.octagon.fill"
        }
    }

    private var verdictSubtitle: String {
        let high = diagnosis.findings.filter { $0.risk == .high }.count
        let med = diagnosis.findings.filter { $0.risk == .medium }.count
        switch diagnosis.verdict {
        case .safe: return "\(regions.count) fragmentos analizados · 0 señales"
        case .caution: return "\(med) señal\(med == 1 ? "" : "es") que merece\(med == 1 ? "" : "n") atención"
        case .danger: return "\(high) señal\(high == 1 ? "" : "es") de riesgo alto · \(med) media\(med == 1 ? "" : "s")"
        }
    }

    // Acciones (guardar, compartir, descartar)
    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                saveThreat()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isSaved ? "checkmark.circle.fill" : "bookmark.fill")
                    Text(isSaved ? "amenaza guardada" : "guardar amenaza")
                        .font(FluxFont.body(15, weight: .semibold))
                }
                .foregroundStyle(isSaved ? FluxColor.safe : FluxColor.base)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isSaved ? FluxColor.safe.opacity(0.12) : FluxColor.ink)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isSaved ? FluxColor.safe.opacity(0.4) : .clear, lineWidth: 1)
                )
            }
            .disabled(isSaved)

            Button {
                dismiss()
            } label: {
                Text("descartar")
                    .font(FluxFont.body(14, weight: .medium))
                    .foregroundStyle(FluxColor.inkMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
    }

    private func saveThreat() {
        let threat = SavedThreat.from(diagnosis: diagnosis, regions: regions, context: scanType)
        store.save(threat)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isSaved = true
            showSavedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeOut(duration: 0.3)) {
                showSavedToast = false
            }
        }
    }

    private var contextHeader: String {
        switch scanType {
        case .chat: return "análisis de chat"
        case .doc: return "análisis de documento"
        case .profile: return "análisis de perfil"
        case .link: return "análisis de enlace"
        }
    }

    // Score
    private var scoreBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("NIVEL DE RIESGO")
                    .font(FluxFont.mono(10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(FluxColor.inkMuted)
                Spacer()
                Text("\(diagnosis.score)/100")
                    .font(FluxFont.display(14, weight: .bold))
                    .foregroundStyle(diagnosis.verdict.color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(FluxColor.line)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [FluxColor.safe, FluxColor.warn, FluxColor.danger],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(diagnosis.score) / 100)
                }
            }
            .frame(height: 8)
        }
    }

    // Summary
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("resumen")
            Text(diagnosis.summary)
                .font(FluxFont.body(14))
                .foregroundStyle(FluxColor.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // Findings
    private var findingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("señales detectadas")
            ForEach(diagnosis.findings) { f in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(f.risk.label.uppercased())
                            .font(FluxFont.mono(9, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(f.risk.color))
                        Text(f.tag)
                            .font(FluxFont.body(13, weight: .semibold))
                            .foregroundStyle(FluxColor.ink)
                    }
                    Text("\"\(f.quote)\"")
                        .font(FluxFont.body(12))
                        .foregroundStyle(FluxColor.inkMuted)
                        .lineLimit(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(FluxColor.surface)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(f.risk.color.opacity(0.3), lineWidth: 1))
                )
            }
        }
    }

    // Recomendaciones
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("qué hacer ahora")
            ForEach(Array(diagnosis.recommendations.enumerated()), id: \.offset) { i, rec in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(i + 1)")
                        .font(FluxFont.mono(11, weight: .bold))
                        .foregroundStyle(FluxColor.primary)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(FluxColor.primary.opacity(0.12)))
                    Text(rec)
                        .font(FluxFont.body(13))
                        .foregroundStyle(FluxColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(FluxColor.surfaceAlt)
        )
    }

    // Evidencia
    private var evidenceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("evidencia (\(regions.count) fragmentos)")
            ForEach(regions.prefix(12)) { r in
                HStack(alignment: .top, spacing: 10) {
                    Circle().fill(r.risk.color).frame(width: 8, height: 8).padding(.top, 5)
                    Text(r.text)
                        .font(FluxFont.body(12))
                        .foregroundStyle(FluxColor.inkMuted)
                        .lineLimit(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(FluxColor.surface)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(FluxColor.line))
                )
            }
            if regions.count > 12 {
                Text("+\(regions.count - 12) fragmentos más")
                    .font(FluxFont.body(11))
                    .foregroundStyle(FluxColor.inkFaint)
            }
        }
    }

    private func sectionTitle(_ t: String) -> some View {
        Text(t.uppercased())
            .font(FluxFont.mono(10, weight: .bold))
            .tracking(1.5)
            .foregroundStyle(FluxColor.inkMuted)
    }
}
