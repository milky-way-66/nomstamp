import Foundation
import FoodMapDomain
#if canImport(CoreBluetooth)
import CoreBluetooth
#endif

/// Who is in the room, over Bluetooth.
///
/// Bluetooth and **not** the local network, which is the rule the whole in-person guarantee rests
/// on. `MultipeerConnectivity` and a plain `NWBrowser` both discover peers over the LAN as well as
/// over radio, so two people on one office Wi-Fi would find each other from different buildings.
/// Radio range cannot be faked; the same subnet is not the same room (FR-10.10).
///
/// Discovery runs **only while the *Add friend* screen is open**, and advertises an ephemeral
/// identifier rather than the public key: a stable identifier broadcast in the clear would let
/// anyone track a phone (FR-10.11).
public final class BluetoothPresence: NSObject, ProximityPort, PeerHandshakePort, @unchecked Sendable {

    /// The service every Nomstamp advertises while its Add-friend screen is open. A fixed UUID so
    /// a scan can filter on it, which is also what lets iOS wake a suspended app for an encounter
    /// if routine proximity sync is built later.
    public static let serviceUUID = "F00D5A1D-0000-4E0F-B7A1-0F00DDA7A509"

    /// Where this device's public key is offered to whoever connects.
    ///
    /// The exchange rides the **same** link the proximity reading came from, rather than opening a
    /// second connection over Wi-Fi. That is not an optimisation: it is the guarantee. A separate
    /// AWDL or Bonjour link would have to be matched back to the Bluetooth advertisement by some
    /// identifier, and the moment two transports are correlated by an identifier, the identifier —
    /// not the radio — is what proves co-presence, and identifiers travel (ADR-009, FR-10.10).
    ///
    /// The key is *read*, never advertised: a public key in an advertisement packet is a stable
    /// identifier broadcast in the clear to everyone in range, which is exactly what FR-10.11
    /// forbids. It is offered only to a device that has already connected, at the reader's tap.
    public static let keyCharacteristicUUID = "F00D5A1D-0001-4E0F-B7A1-0F00DDA7A509"

    /// What the advertisement carries: a name to show, and nothing that outlives the screen.
    private let assertedName: String
    private var ephemeralID = UUID()
    /// This device's own key, handed over once the other reader has tapped.
    private let publicKey: FriendKey

    #if canImport(CoreBluetooth)
    private var central: CBCentralManager?
    private var peripheral: CBPeripheralManager?
    private let lock = NSLock()
    private var registry = PresenceRegistry()
    private var knownPeripherals: [UUID: CBPeripheral] = [:]
    private var pending: [UUID: Pending] = [:]
    /// Set the moment `begin()` runs, cleared by `end()`. Without it there is no way to tell a
    /// radio that found nobody from a radio nobody started (TC-8-14).
    private var running = false

    private struct Pending {
        let reader: NearbyReader
        let continuation: CheckedContinuation<HandshakeResult, Error>
    }
    #endif

    public init(assertedName: String, publicKey: FriendKey) {
        self.assertedName = assertedName
        self.publicKey = publicKey
        super.init()
    }

    /// Starts advertising and scanning. Called when the screen appears, and only then.
    ///
    /// Both managers are built here rather than in `init` because building a `CBCentralManager` is
    /// what makes iOS ask the reader for Bluetooth. Asking at launch, for a screen most readers
    /// never open, would be a permission prompt with no explanation attached to it.
    public func begin() {
        #if canImport(CoreBluetooth)
        guard !lock.withLock({ running }) else { return }
        ephemeralID = UUID()
        lock.withLock {
            running = true
            registry.forgetAll()
            knownPeripherals.removeAll()
        }
        central = CBCentralManager(delegate: self, queue: .main)
        peripheral = CBPeripheralManager(delegate: self, queue: .main)
        #endif
    }

    /// Stops both, and forgets what was seen. Called when the screen disappears — the window in
    /// which a reader is discoverable is the window in which they asked to be.
    public func end() {
        #if canImport(CoreBluetooth)
        central?.stopScan()
        peripheral?.stopAdvertising()
        peripheral?.removeAllServices()
        central = nil
        peripheral = nil
        let orphans = lock.withLock { () -> [Pending] in
            running = false
            registry.forgetAll()
            knownPeripherals.removeAll()
            let waiting = Array(pending.values)
            pending.removeAll()
            return waiting
        }
        // Anyone still waiting is waiting on a screen that has closed. Resumed outside the lock:
        // a continuation can run arbitrary code, and running it under our own lock invites a
        // deadlock the first time that code asks us anything.
        for entry in orphans { entry.continuation.resume(throwing: HandshakeFailure.gone) }
        #endif
    }

    // MARK: - The exchange

    /// Connects to the chosen reader, reads their key, and returns it with a **freshly measured**
    /// proof.
    ///
    /// Re-reading the signal matters: a row can sit on screen for a minute while its owner walks
    /// out of the restaurant, and connecting to a stale row would let the domain refuse a
    /// connection on evidence that was true two rooms ago.
    public func exchange(with reader: NearbyReader) async throws -> HandshakeResult {
        #if canImport(CoreBluetooth)
        let target = lock.withLock { knownPeripherals[reader.ephemeralID] }
        guard let central, let target else { throw HandshakeFailure.gone }
        return try await withCheckedThrowingContinuation { continuation in
            lock.withLock { pending[reader.ephemeralID] = Pending(reader: reader, continuation: continuation) }
            target.delegate = self
            central.connect(target)
        }
        #else
        throw HandshakeFailure.unsupported
        #endif
    }

    public func nearbyReaders() async throws -> [NearbyReader] {
        #if canImport(CoreBluetooth)
        lock.withLock { registry.readers }
        #else
        []
        #endif
    }

    /// Why the room looks empty, so the screen can say it (FR-10.13).
    public func availability() async -> ProximityAvailability {
        #if canImport(CoreBluetooth)
        guard lock.withLock({ running }), let central else { return .unsupported }
        return Self.availability(for: central.state)
        #else
        return .unsupported
        #endif
    }

    #if canImport(CoreBluetooth)
    /// Kept static and pure so the mapping is testable without a radio (TC-8-16).
    static func availability(for state: CBManagerState) -> ProximityAvailability {
        switch state {
        case .poweredOff: return .poweredOff
        case .unauthorized: return .unauthorized
        case .unsupported: return .unsupported
        // `.unknown` and `.resetting` are both "ask again in a moment". Reporting them as a
        // failure would accuse the reader of refusing something they have not been asked yet.
        default: return .searching
        }
    }
    #endif
}

#if canImport(CoreBluetooth)
extension BluetoothPresence: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ manager: CBCentralManager) {
        guard manager.state == .poweredOn else { return }
        manager.scanForPeripherals(
            withServices: [CBUUID(string: Self.serviceUUID)],
            // Repeated reports are wanted: the signal strength is the proximity gate, and one
            // reading taken as someone walks past would be the wrong one.
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
    }

    public func centralManager(
        _ manager: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        // 127 is CoreBluetooth's "no reading available", not a very strong signal.
        guard RSSI.intValue != 127 else { return }
        let advertised = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        lock.withLock {
            // The name may be absent from this particular packet — see `PresenceRegistry.record`.
            registry.record(
                id: peripheral.identifier,
                advertisedName: advertised ?? peripheral.name,
                signalStrength: RSSI.intValue
            )
            // Held so the exchange can connect to it later. CoreBluetooth discards a peripheral
            // it holds no strong reference to, and a discarded one cannot be connected.
            knownPeripherals[peripheral.identifier] = peripheral
        }
    }
}

extension BluetoothPresence: CBPeripheralManagerDelegate {
    public func peripheralManagerDidUpdateState(_ manager: CBPeripheralManager) {
        guard manager.state == .poweredOn else { return }

        let service = CBMutableService(type: CBUUID(string: Self.serviceUUID), primary: true)
        service.characteristics = [
            CBMutableCharacteristic(
                type: CBUUID(string: Self.keyCharacteristicUUID),
                properties: [.read],
                value: Data(publicKey.bytes),
                permissions: [.readable]
            )
        ]
        // Advertising waits for `didAdd` below. Adding a service is asynchronous, and a device
        // that connects to an advertisement for a service the stack has not published yet
        // discovers nothing and is told the reader refused.
        manager.removeAllServices()
        manager.add(service)
    }

    public func peripheralManager(
        _ manager: CBPeripheralManager,
        didAdd service: CBService,
        error: Error?
    ) {
        guard error == nil else { return }
        manager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [CBUUID(string: Self.serviceUUID)],
            // The name the other reader will see, and a suggestion they may overwrite — the name
            // that ends up stored is the one they type, never this one (FR-10.6).
            CBAdvertisementDataLocalNameKey: assertedName
        ])
    }
}
#endif

/// Why an exchange did not happen. Never surfaced as a technical failure: the screen says they
/// moved out of range, because from the reader's side that is what happened.
public enum HandshakeFailure: Error, Equatable {
    case gone
    case refused
    case unsupported
}

#if canImport(CoreBluetooth)
extension BluetoothPresence: CBPeripheralDelegate {
    public func centralManager(_ manager: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([CBUUID(string: Self.serviceUUID)])
    }

    public func centralManager(
        _ manager: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        finish(peripheral.identifier, with: .failure(HandshakeFailure.gone))
    }

    public func centralManager(
        _ manager: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        // Harmless once the key has been read — `finish` only resumes someone still waiting.
        finish(peripheral.identifier, with: .failure(HandshakeFailure.gone))
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first else {
            return finish(peripheral.identifier, with: .failure(HandshakeFailure.refused))
        }
        peripheral.discoverCharacteristics([CBUUID(string: Self.keyCharacteristicUUID)], for: service)
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard let characteristic = service.characteristics?.first else {
            return finish(peripheral.identifier, with: .failure(HandshakeFailure.refused))
        }
        // The proof is taken here, on the open link, rather than reused from the scan.
        peripheral.readRSSI()
        peripheral.readValue(for: characteristic)
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didReadRSSI RSSI: NSNumber,
        error: Error?
    ) {
        guard RSSI.intValue != 127 else { return }
        lock.withLock {
            guard let entry = pending[peripheral.identifier] else { return }
            pending[peripheral.identifier] = Pending(
                reader: NearbyReader(
                    ephemeralID: entry.reader.ephemeralID,
                    assertedName: entry.reader.assertedName,
                    proof: ProximityProof(signalStrength: RSSI.intValue)
                ),
                continuation: entry.continuation
            )
        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard let data = characteristic.value, let key = FriendKey(bytes: Array(data)) else {
            return finish(peripheral.identifier, with: .failure(HandshakeFailure.refused))
        }
        let reader = lock.withLock { pending[peripheral.identifier]?.reader }
        guard let reader else { return }
        central?.cancelPeripheralConnection(peripheral)
        finish(peripheral.identifier, with: .success(HandshakeResult(
            key: key,
            assertedName: reader.assertedName,
            proof: reader.proof
        )))
    }

    private func finish(_ id: UUID, with result: Result<HandshakeResult, Error>) {
        let entry = lock.withLock { pending.removeValue(forKey: id) }
        entry?.continuation.resume(with: result)
    }
}
#endif
