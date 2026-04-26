import Foundation
import UIKit
import CoreBluetooth
import NearbyInteraction

// MARK: - GATT UUIDs (flux Proximity Pairing Service)
// Nuevos UUIDs específicos para flux — no colisionan con Atenea/otras apps

private let kServiceUUID     = CBUUID(string: "F10C8001-2B4E-4F6A-9D3C-7A1E5B8F2D4C")
private let kCharParentToken = CBUUID(string: "F10C8001-0001-4F6A-9D3C-7A1E5B8F2D4C") // padre NI token (read)
private let kCharChildToken  = CBUUID(string: "F10C8001-0002-4F6A-9D3C-7A1E5B8F2D4C") // menor NI token (write)
private let kCharInvitation  = CBUUID(string: "F10C8001-0003-4F6A-9D3C-7A1E5B8F2D4C") // VozInvitation del padre (notify)
private let kCharAck         = CBUUID(string: "F10C8001-0004-4F6A-9D3C-7A1E5B8F2D4C") // VozAcknowledgement (write)

// MARK: - ProximityPairingService
// Adaptación de TapToPayPeerService (Atenea) para sincronizar padre↔menor
// vía UWB + BLE. Al acercar los dos iPhones (<30cm) se transfiere la invitación
// persistente de flux voz, sin pasar por internet.

final class ProximityPairingService: NSObject, ObservableObject {

    // MARK: - Published state

    @Published var phase: PairingPhase = .preparing
    @Published var peerDistance: Float?
    @Published var isConnected = false
    @Published var receivedInvitation: VozInvitation?      // menor recibe
    @Published var receivedAck: VozAcknowledgement?        // padre recibe
    @Published var errorMessage: String?

    // MARK: - Config

    let role: PairingRole
    let invitation: VozInvitation?                         // solo padre lleva la invitación

    private let tapThreshold: Float = 0.30                 // 30 cm — mismo umbral que Atenea Tap to Pay
    private var hasTriggered = false
    private var hasProcessedAck = false
    private var isActive = false

    var onPairingCompleted: ((VozInvitation) -> Void)?     // disparado en el menor al recibir
    var onInvitationSent: ((VozAcknowledgement) -> Void)?  // disparado en el padre al confirmar

    // MARK: - CoreBluetooth — peripheral (parent)

    private var peripheralManager: CBPeripheralManager?
    private var charInvitationMutable: CBMutableCharacteristic?
    private var pendingInvitationData: Data?

    // MARK: - CoreBluetooth — central (child)

    private var centralManager: CBCentralManager?
    private var connectedPeripheral: CBPeripheral?
    private var parentTokenData: Data?

    // MARK: - NearbyInteraction

    private var niSession: NISession?

    // MARK: - Init

    init(role: PairingRole, invitation: VozInvitation? = nil) {
        self.role = role
        self.invitation = invitation
        super.init()
        if role == .parent && invitation == nil {
            print("[flux Pair] ⚠️ padre sin invitación — genera una antes de start()")
        }
    }

    // MARK: - Start / Stop

    func start() {
        guard !isActive else {
            print("[flux Pair] ⚠️ start() ignorado — ya activo")
            return
        }
        isActive = true
        print("[flux Pair] ▶️ start() role=\(role.rawValue)")

        niSession = NISession()
        niSession?.delegate = self
        print("[flux Pair] NISession creado — token: \(niSession?.discoveryToken != nil ? "OK" : "nil (sin UWB)")")

        if role == .parent {
            peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
            print("[flux Pair] Parent: CBPeripheralManager creado, esperando .poweredOn")
        } else {
            centralManager = CBCentralManager(delegate: self, queue: nil)
            print("[flux Pair] Child: CBCentralManager creado, esperando .poweredOn")
        }
    }

    func stop() {
        print("[flux Pair] ⏹ stop() role=\(role.rawValue) isActive=\(isActive)")
        isActive = false
        hasTriggered = false
        hasProcessedAck = false

        niSession?.invalidate()
        niSession = nil

        peripheralManager?.stopAdvertising()
        let retainedPM = peripheralManager
        peripheralManager = nil
        charInvitationMutable = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            retainedPM?.stopAdvertising()
        }

        if let p = connectedPeripheral {
            centralManager?.cancelPeripheralConnection(p)
        }
        centralManager?.stopScan()
        centralManager = nil
        connectedPeripheral = nil
        parentTokenData = nil

        DispatchQueue.main.async {
            self.phase = .preparing
            self.isConnected = false
            self.peerDistance = nil
        }
    }

    // MARK: - Parent: enviar invitación vía notify

    private func sendInvitationNotify() {
        guard let inv = invitation else {
            print("[flux Pair] ⚠️ sendInvitation: no hay invitación que enviar")
            return
        }
        guard let char = charInvitationMutable,
              let manager = peripheralManager else {
            print("[flux Pair] ⚠️ sendInvitation: peripheralManager o char nil")
            return
        }
        do {
            let data = try JSONEncoder().encode(inv)
            pendingInvitationData = data
            let sent = manager.updateValue(data, for: char, onSubscribedCentrals: nil)
            print("[flux Pair] Parent: notify invitación enviado=\(sent) · \(data.count) bytes")
            if sent { pendingInvitationData = nil }
        } catch {
            print("[flux Pair] ❌ error encoding invitación: \(error)")
        }
    }

    // Retry automático cuando la cola BLE se libera
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        guard let data = pendingInvitationData,
              let char = charInvitationMutable else { return }
        print("[flux Pair] Parent: reintentando notify")
        let sent = peripheral.updateValue(data, for: char, onSubscribedCentrals: nil)
        if sent { pendingInvitationData = nil }
    }

    // MARK: - Parent: build GATT service

    private func buildGATTService() {
        guard let niToken = niSession?.discoveryToken else {
            print("[flux Pair] ⚠️ buildGATT: discoveryToken nil — UWB no disponible")
            errorMessage = "Este dispositivo no soporta UWB. Se requiere iPhone 11 o superior."
            return
        }
        guard let tokenData = try? NSKeyedArchiver.archivedData(withRootObject: niToken, requiringSecureCoding: true) else {
            print("[flux Pair] ⚠️ no se pudo archivar NI token")
            return
        }
        print("[flux Pair] Parent: NI token archivado (\(tokenData.count) bytes)")

        // Parent NI token — static read
        let charParentToken = CBMutableCharacteristic(
            type: kCharParentToken,
            properties: [.read],
            value: tokenData,
            permissions: [.readable]
        )

        // Child NI token — write
        let charChildToken = CBMutableCharacteristic(
            type: kCharChildToken,
            properties: [.write],
            value: nil,
            permissions: [.writeable]
        )

        // Invitation — notify (parent push)
        charInvitationMutable = CBMutableCharacteristic(
            type: kCharInvitation,
            properties: [.notify],
            value: nil,
            permissions: [.readable]
        )

        // Acknowledgement — write (child confirms receipt)
        let charAck = CBMutableCharacteristic(
            type: kCharAck,
            properties: [.write],
            value: nil,
            permissions: [.writeable]
        )

        let service = CBMutableService(type: kServiceUUID, primary: true)
        service.characteristics = [charParentToken, charChildToken, charInvitationMutable!, charAck]
        peripheralManager?.add(service)
        print("[flux Pair] Parent: servicio GATT agregado")
    }

    // MARK: - Child: escribir token propio al parent

    private func writeChildToken(to peripheral: CBPeripheral) {
        guard let niToken = niSession?.discoveryToken,
              let tokenData = try? NSKeyedArchiver.archivedData(withRootObject: niToken, requiringSecureCoding: true),
              let service = peripheral.services?.first(where: { $0.uuid == kServiceUUID }),
              let char = service.characteristics?.first(where: { $0.uuid == kCharChildToken })
        else {
            print("[flux Pair] ⚠️ Child: writeChildToken — prerequisitos no listos")
            return
        }
        print("[flux Pair] Child: escribiendo token NI propio (\(tokenData.count) bytes)")
        peripheral.writeValue(tokenData, for: char, type: .withResponse)
    }

    // MARK: - Child: iniciar NI con token del parent

    private func startNIWithParentToken(_ data: Data) {
        guard let token = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data) else {
            print("[flux Pair] ⚠️ Child: no se pudo deserializar NI token del parent")
            return
        }
        let config = NINearbyPeerConfiguration(peerToken: token)
        niSession?.run(config)
        print("[flux Pair] Child: NISession.run() — UWB midiendo distancia")
    }

    // MARK: - Child: enviar acknowledgement al parent

    func sendAcknowledgement(for invitationID: UUID, success: Bool) {
        guard role == .child else { return }
        guard let peripheral = connectedPeripheral,
              let service = peripheral.services?.first(where: { $0.uuid == kServiceUUID }),
              let char = service.characteristics?.first(where: { $0.uuid == kCharAck }) else {
            print("[flux Pair] ⚠️ Child: peripheral/characteristic no disponible para ack")
            return
        }
        let (childName, childAge): (String, Int) = MainActor.assumeIsolated {
            let p = ProfileStore.shared.activeProfile
            let name = p?.displayName ?? UIDevice.current.name
            let age = p?.childAge ?? 13
            print("[flux Pair] Child: enviando ack · nombre='\(name)' edad=\(age)")
            return (name, age)
        }
        let ack = VozAcknowledgement(
            invitationID: invitationID,
            childDeviceName: UIDevice.current.name,
            childName: childName,
            childAge: childAge,
            success: success
        )
        do {
            let data = try JSONEncoder().encode(ack)
            peripheral.writeValue(data, for: char, type: .withResponse)
            print("[flux Pair] Child: ACK enviado (\(data.count) bytes) success=\(success)")
        } catch {
            print("[flux Pair] ❌ error encoding ack: \(error)")
        }
    }
}

// MARK: - CBPeripheralManagerDelegate (parent)

extension ProximityPairingService: CBPeripheralManagerDelegate {

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        let stateStr: String
        switch peripheral.state {
        case .poweredOn:    stateStr = "poweredOn"
        case .poweredOff:   stateStr = "poweredOff"
        case .unauthorized: stateStr = "unauthorized"
        case .unsupported:  stateStr = "unsupported"
        case .resetting:    stateStr = "resetting"
        case .unknown:      stateStr = "unknown"
        @unknown default:   stateStr = "unknown"
        }
        print("[flux Pair] Parent: CBPeripheralManager state=\(stateStr)")

        switch peripheral.state {
        case .poweredOn:
            buildGATTService()
        case .poweredOff:
            errorMessage = "Bluetooth apagado — actívalo en Ajustes."
        case .unauthorized:
            errorMessage = "Bluetooth no autorizado — revisa permisos en Ajustes > Privacidad > Bluetooth."
        default: break
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error {
            print("[flux Pair] ⚠️ error agregando servicio — \(error.localizedDescription)")
            return
        }
        print("[flux Pair] Parent: servicio agregado — iniciando advertising")
        peripheral.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [kServiceUUID],
            CBAdvertisementDataLocalNameKey: "fluxPair"
        ])
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error {
            print("[flux Pair] ⚠️ error advertising — \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        } else {
            print("[flux Pair] Parent: advertising activo — esperando menor")
            DispatchQueue.main.async { self.phase = .waitingForPeer }
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            let charUUID = request.characteristic.uuid
            guard let data = request.value else {
                peripheral.respond(to: request, withResult: .attributeNotFound)
                continue
            }
            print("[flux Pair] Parent: write en \(charUUID) — \(data.count) bytes")
            peripheral.respond(to: request, withResult: .success)

            if charUUID == kCharChildToken {
                guard let token = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data) else {
                    print("[flux Pair] ⚠️ Parent: no se pudo deserializar token del menor")
                    continue
                }
                let config = NINearbyPeerConfiguration(peerToken: token)
                niSession?.run(config)
                print("[flux Pair] Parent: NISession.run() — UWB midiendo distancia")
                DispatchQueue.main.async { self.isConnected = true }

            } else if charUUID == kCharAck {
                guard !hasProcessedAck else { continue }
                do {
                    let ack = try JSONDecoder().decode(VozAcknowledgement.self, from: data)
                    print("[flux Pair] Parent: ✅ ACK recibido de '\(ack.childDeviceName)' success=\(ack.success)")
                    hasProcessedAck = true
                    DispatchQueue.main.async {
                        self.receivedAck = ack
                        self.phase = ack.success ? .approved : .declined("Menor rechazó la invitación")
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.onInvitationSent?(ack)
                    }
                } catch {
                    print("[flux Pair] ❌ error decoding ack: \(error)")
                }
            }
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        print("[flux Pair] Parent: central subscrito a \(characteristic.uuid)")
        DispatchQueue.main.async { self.isConnected = true }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        print("[flux Pair] Parent: central desuscrito de \(characteristic.uuid)")
    }
}

// MARK: - CBCentralManagerDelegate (child)

extension ProximityPairingService: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let stateStr: String
        switch central.state {
        case .poweredOn:    stateStr = "poweredOn"
        case .poweredOff:   stateStr = "poweredOff"
        case .unauthorized: stateStr = "unauthorized"
        case .unsupported:  stateStr = "unsupported"
        case .resetting:    stateStr = "resetting"
        case .unknown:      stateStr = "unknown"
        @unknown default:   stateStr = "unknown"
        }
        print("[flux Pair] Child: CBCentralManager state=\(stateStr)")

        switch central.state {
        case .poweredOn:
            central.scanForPeripherals(withServices: [kServiceUUID], options: [
                CBCentralManagerScanOptionAllowDuplicatesKey: false
            ])
            print("[flux Pair] Child: scan iniciado")
            DispatchQueue.main.async { self.phase = .preparing }
        case .poweredOff:
            errorMessage = "Bluetooth apagado."
        case .unauthorized:
            errorMessage = "Bluetooth no autorizado."
        default: break
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "?"
        print("[flux Pair] Child: peripheral descubierto '\(name)' RSSI=\(RSSI)")
        central.stopScan()
        connectedPeripheral = peripheral
        peripheral.delegate = self
        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("[flux Pair] Child: ✅ conectado a '\(peripheral.name ?? peripheral.identifier.uuidString)'")
        peripheral.discoverServices([kServiceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("[flux Pair] ⚠️ Child: falló conexión — \(error?.localizedDescription ?? "unknown")")
        if isActive && !hasTriggered {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                guard self.isActive && !self.hasTriggered else { return }
                central.scanForPeripherals(withServices: [kServiceUUID], options: nil)
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("[flux Pair] Child: desconectado — \(error?.localizedDescription ?? "ok")")
        DispatchQueue.main.async { self.isConnected = false }
    }
}

// MARK: - CBPeripheralDelegate (child)

extension ProximityPairingService: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            print("[flux Pair] ⚠️ Child: error servicios — \(error.localizedDescription)")
            return
        }
        guard let service = peripheral.services?.first(where: { $0.uuid == kServiceUUID }) else { return }
        peripheral.discoverCharacteristics([kCharParentToken, kCharChildToken, kCharInvitation, kCharAck], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error {
            print("[flux Pair] ⚠️ Child: error characteristics — \(error.localizedDescription)")
            return
        }
        for char in service.characteristics ?? [] {
            switch char.uuid {
            case kCharInvitation:
                peripheral.setNotifyValue(true, for: char)
                print("[flux Pair] Child: subscrito a INVITATION (notify)")
            case kCharParentToken:
                peripheral.readValue(for: char)
            default: break
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            print("[flux Pair] ⚠️ Child: didUpdateValue error \(characteristic.uuid) — \(error.localizedDescription)")
            return
        }
        guard let data = characteristic.value else { return }

        switch characteristic.uuid {

        case kCharParentToken:
            print("[flux Pair] Child: parent NI token recibido (\(data.count) bytes)")
            parentTokenData = data
            writeChildToken(to: peripheral)

        case kCharInvitation:
            do {
                let inv = try JSONDecoder().decode(VozInvitation.self, from: data)
                if inv.isExpired {
                    print("[flux Pair] ⚠️ Child: invitación expirada")
                    DispatchQueue.main.async { self.phase = .declined("Invitación expirada") }
                    sendAcknowledgement(for: inv.id, success: false)
                    return
                }
                print("[flux Pair] 🎉 Child: INVITACIÓN recibida para \(inv.childName)")
                DispatchQueue.main.async {
                    self.receivedInvitation = inv
                    self.phase = .approved
                }
                sendAcknowledgement(for: inv.id, success: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.onPairingCompleted?(inv)
                }
            } catch {
                print("[flux Pair] ❌ error decoding invitation: \(error)")
            }

        default: break
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            print("[flux Pair] ⚠️ Child: write error \(characteristic.uuid) — \(error.localizedDescription)")
            return
        }
        if characteristic.uuid == kCharChildToken {
            print("[flux Pair] Child: ✅ token escrito — iniciando UWB")
            if let data = parentTokenData {
                startNIWithParentToken(data)
            }
            DispatchQueue.main.async { self.phase = .waitingForPeer }
        }
    }
}

// MARK: - NISessionDelegate

extension ProximityPairingService: NISessionDelegate {

    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard let peer = nearbyObjects.first, let distance = peer.distance else { return }

        DispatchQueue.main.async {
            self.peerDistance = distance
            guard distance < self.tapThreshold, !self.hasTriggered else { return }

            print("[flux Pair] 🎯 TAP detectado (\(String(format: "%.1f", distance * 100))cm)")
            let impact = UIImpactFeedbackGenerator(style: .heavy)
            impact.impactOccurred()

            self.hasTriggered = true
            self.phase = .reading

            // Parent: una vez cerca, enviar la invitación vía notify
            if self.role == .parent {
                print("[flux Pair] 💌 Parent: enviando invitación tras tap")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    self.sendInvitationNotify()
                }
            }
            // Child: espera el notify con la invitación (llega por didUpdateValueFor)
        }
    }

    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        print("[flux Pair] NI: peer removido — \(reason.rawValue)")
        DispatchQueue.main.async { self.peerDistance = nil }
    }

    func session(_ session: NISession, didInvalidateWith error: Error) {
        print("[flux Pair] ⚠️ NISession invalidada: \(error.localizedDescription)")
        DispatchQueue.main.async { self.errorMessage = error.localizedDescription }
    }

    func sessionWasSuspended(_ session: NISession) {
        print("[flux Pair] NI: sesión suspendida")
    }

    func sessionSuspensionEnded(_ session: NISession) {
        print("[flux Pair] NI: suspensión terminada")
    }
}
