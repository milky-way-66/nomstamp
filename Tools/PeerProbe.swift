import Foundation
import CoreBluetooth

// A second Nomstamp reader, for a Mac.
//
// The connect ceremony needs two phones, and TC-8-12 stays a manual case because of it. This
// closes most of the gap with hardware you already have: a Mac has a real Bluetooth radio, so it
// can stand in for the phone across the table and say out loud what it sees.
//
// It is deliberately **not** built on `BluetoothPresence`. A harness that shares the app's code
// shares the app's mistakes, and would have happily reported success against the very bug this
// exists to catch. Everything here is written against CoreBluetooth directly.
//
//   swift Tools/PeerProbe.swift listen      — watch for the phone's advertisement (default)
//   swift Tools/PeerProbe.swift advertise   — pretend to be a reader the phone can find
//   swift Tools/PeerProbe.swift both        — both at once, which is what a phone does
//
// The first run makes macOS ask Terminal for Bluetooth. Say yes, or nothing will be seen.
//
// These two must match `BluetoothPresence.serviceUUID` and `.keyCharacteristicUUID`. They are
// repeated rather than imported for the reason above; the probe prints them at startup so a
// mismatch is visible in the first two lines rather than as a silent empty room.
let serviceUUID = CBUUID(string: "F00D5A1D-0000-4E0F-B7A1-0F00DDA7A509")
let keyCharacteristicUUID = CBUUID(string: "F00D5A1D-0001-4E0F-B7A1-0F00DDA7A509")

// Line-buffered, so the log appears as it happens rather than in a lump when the pipe closes.
// This tool exists to be watched while someone walks across a restaurant; a buffered one is
// useless for that, and silent if it is ever killed before it flushes.
setvbuf(stdout, nil, _IOLBF, 0)

enum Mode: String { case listen, advertise, both }
let mode = Mode(rawValue: CommandLine.arguments.dropFirst().first ?? "listen") ?? .listen

func stamp() -> String {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss"
    return f.string(from: Date())
}

/// Watches for phones advertising the Nomstamp service.
///
/// Prints every packet rather than every device. That is the point: the advert and the scan
/// response arrive separately, and seeing a nameless packet followed by a named one is what
/// confirms the split `PresenceRegistry` exists to survive (TC-8-17). The rolling signal column
/// is also the instrument OPEN-13 is waiting for — put the phone on the table, walk to the next
/// one, and read where the numbers land.
final class Listener: NSObject, CBCentralManagerDelegate {
    private var central: CBCentralManager?
    private var namesByDevice: [UUID: String] = [:]
    private var packetsByDevice: [UUID: Int] = [:]

    func start() {
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func centralManagerDidUpdateState(_ manager: CBCentralManager) {
        switch manager.state {
        case .poweredOn:
            print("[\(stamp())] listening for Nomstamp on \(serviceUUID.uuidString)")
            print("           (nothing below this line means no phone is advertising)")
            manager.scanForPeripherals(
                withServices: [serviceUUID],
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
            )
        case .poweredOff:
            print("Bluetooth is switched off on this Mac.")
        case .unauthorized:
            print("This terminal has not been allowed Bluetooth — System Settings › Privacy & Security › Bluetooth.")
        case .unsupported:
            print("No Bluetooth radio here at all. (A simulator reports exactly this.)")
        default:
            break
        }
    }

    func centralManager(
        _ manager: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let id = peripheral.identifier
        let advertised = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        if let advertised { namesByDevice[id] = advertised }
        packetsByDevice[id, default: 0] += 1

        let known = namesByDevice[id]
        let name = known ?? "(no name yet)"
        // -70 is `ProximityProof.signalFloor`. Shown as a verdict so the reading can be judged
        // where it is taken rather than worked out afterwards.
        let verdict = RSSI.intValue >= -70 ? "PASSES the gate" : "refused by the gate"
        let source = advertised != nil ? "name in this packet" : "name from an earlier packet"
        print("[\(stamp())] \(name.padding(toLength: max(24, name.count), withPad: " ", startingAt: 0)) "
              + "\(RSSI.intValue) dBm  \(verdict)  — \(source), packet #\(packetsByDevice[id]!)")
    }
}

/// Pretends to be a reader with their Add-friend screen open, so a phone can find *something*.
///
/// The key it offers is 32 bytes of a recognisable pattern rather than a real one: enough for
/// `FriendKey(bytes:)` to accept it and for the phone to reach the matching word, and obviously
/// fake in a log if it ever turns up somewhere it should not.
final class Advertiser: NSObject, CBPeripheralManagerDelegate {
    private var peripheral: CBPeripheralManager?
    private let fakeKey = Data((0..<32).map { UInt8(($0 &* 7) &+ 11) })

    func start() {
        peripheral = CBPeripheralManager(delegate: self, queue: .main)
    }

    func peripheralManagerDidUpdateState(_ manager: CBPeripheralManager) {
        guard manager.state == .poweredOn else {
            print("Cannot advertise: radio state \(manager.state.rawValue)")
            return
        }
        let service = CBMutableService(type: serviceUUID, primary: true)
        service.characteristics = [
            CBMutableCharacteristic(
                type: keyCharacteristicUUID,
                properties: [.read],
                value: fakeKey,
                permissions: [.readable]
            )
        ]
        manager.removeAllServices()
        manager.add(service)
    }

    func peripheralManager(_ manager: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error {
            print("Could not publish the service: \(error.localizedDescription)")
            return
        }
        // Advertising only after the service is published — the phone had this the wrong way
        // round, and a device that connected discovered nothing.
        manager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
            CBAdvertisementDataLocalNameKey: "Probe Mac"
        ])
        print("[\(stamp())] advertising as \"Probe Mac\" — this should appear on the phone's Add friend screen")
    }

    func peripheralManager(_ manager: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        print("[\(stamp())] a phone connected and read the key — the exchange works")
        request.value = fakeKey
        manager.respond(to: request, withResult: .success)
    }
}

print("Nomstamp peer probe — mode: \(mode.rawValue)")
print("service \(serviceUUID.uuidString)  characteristic \(keyCharacteristicUUID.uuidString)")
print("These must match BluetoothPresence.swift. Ctrl-C to stop.\n")

let listener = Listener()
let advertiser = Advertiser()
if mode == .listen || mode == .both { listener.start() }
if mode == .advertise || mode == .both { advertiser.start() }
RunLoop.main.run()
