import Testing
import Foundation
import FoodMapDomain
#if canImport(CoreBluetooth)
import CoreBluetooth
#endif
@testable import FoodMapData

/// UC-8 — who is in the room, and why the room sometimes looks empty when it isn't.
@Suite("Proximity")
struct ProximityTests {

    private func presence() -> BluetoothPresence {
        BluetoothPresence(assertedName: "Reader", publicKey: FriendKey(bytes: Array(repeating: 7, count: 32))!)
    }

    // MARK: - TC-8-14 — nothing happens until something begins it

    @Test("A presence that was never begun finds nobody")
    func neverBegunFindsNobody() async throws {
        let readers = try await presence().nearbyReaders()
        #expect(readers.isEmpty)
    }

    @Test("A presence that was never begun is not merely searching")
    func neverBegunIsNotSearching() async {
        // The distinction the screen rests on: an empty list from a radio that was never started
        // must never be shown as "nobody is here".
        #expect(await presence().availability() != .searching)
    }

    @Test("Ending a presence that never began is harmless")
    func endingUnbegunIsHarmless() async throws {
        let presence = self.presence()
        presence.end()
        #expect(try await presence.nearbyReaders().isEmpty)
    }

    // MARK: - TC-8-15 — ending forgets

    @Test("Ending forgets everyone who was seen")
    func endingForgets() {
        var registry = PresenceRegistry()
        registry.record(id: UUID(), advertisedName: "Lan", signalStrength: -40)
        registry.record(id: UUID(), advertisedName: "Minh", signalStrength: -50)
        #expect(registry.readers.count == 2)

        registry.forgetAll()
        #expect(registry.readers.isEmpty)
    }

    @Test("An exchange with someone who was never seen is refused as gone")
    func exchangeWithStrangerIsGone() async {
        let stranger = NearbyReader(
            ephemeralID: UUID(),
            assertedName: "Nobody",
            proof: ProximityProof(signalStrength: -40)
        )
        await #expect(throws: HandshakeFailure.self) {
            _ = try await self.presence().exchange(with: stranger)
        }
    }

    // MARK: - TC-8-16 — a radio that is off does not look like an empty room

    #if canImport(CoreBluetooth)
    @Test("Every radio state maps to a reason the screen can say out loud")
    func radioStatesAreLegible() {
        #expect(BluetoothPresence.availability(for: .poweredOn) == .searching)
        #expect(BluetoothPresence.availability(for: .poweredOff) == .poweredOff)
        #expect(BluetoothPresence.availability(for: .unauthorized) == .unauthorized)
        #expect(BluetoothPresence.availability(for: .unsupported) == .unsupported)
        // Not yet known is not yet a failure: the screen keeps waiting rather than accusing the
        // reader of having refused something they were never asked.
        #expect(BluetoothPresence.availability(for: .unknown) == .searching)
        #expect(BluetoothPresence.availability(for: .resetting) == .searching)
    }
    #endif

    // MARK: - TC-8-17 — a name learnt once is kept

    @Test("A sighting without a name keeps the name already learnt")
    func nameSurvivesANamelessPacket() {
        let id = UUID()
        var registry = PresenceRegistry()
        registry.record(id: id, advertisedName: "Lan's iPhone", signalStrength: -60)
        // The scan-response packet: same device, fresh signal, no name in it.
        registry.record(id: id, advertisedName: nil, signalStrength: -42)

        #expect(registry.readers.count == 1)
        #expect(registry.reader(id)?.assertedName == "Lan's iPhone")
        // ...and the fresher reading is the one kept, because the signal is the proximity gate.
        #expect(registry.reader(id)?.proof.signalStrength == -42)
    }

    @Test("A device whose name has never arrived is not shown as a blank row")
    func namelessStrangerIsNotListed() {
        var registry = PresenceRegistry()
        registry.record(id: UUID(), advertisedName: nil, signalStrength: -40)
        #expect(registry.readers.isEmpty)
    }

    @Test("Readers are ordered by how close they are")
    func nearestFirst() {
        var registry = PresenceRegistry()
        registry.record(id: UUID(), advertisedName: "Across the room", signalStrength: -80)
        registry.record(id: UUID(), advertisedName: "Across the table", signalStrength: -45)
        #expect(registry.readers.first?.assertedName == "Across the table")
    }

    // MARK: - The gate itself

    @Test("Two phones on a table pass the gate, and the next table does not")
    func theGateFitsATable() {
        // Guards the floor against being tightened back without the measurement. The -62 here is
        // where published BLE link budgets put two phones a table apart with a hand in the way —
        // it is not a reading anyone took, and OPEN-13 is still owed an afternoon with a meter.
        #expect(ProximityProof(signalStrength: -62).isCloseEnough)
        #expect(!ProximityProof(signalStrength: -85).isCloseEnough)
    }
}
