import Foundation
import FoodMapDomain

/// What the scan has seen, kept apart from the radio that saw it.
///
/// Separate because the interesting rules here are not radio rules. Whether a phone that stops
/// announcing its name for one packet disappears from the list is a decision about what the
/// reader sees, and it deserves a test that does not need two devices in a room (TC-8-17).
struct PresenceRegistry {
    private var seen: [UUID: NearbyReader] = [:]

    /// Records one sighting.
    ///
    /// `advertisedName` is optional because it genuinely is. A BLE advertisement is 31 bytes, and
    /// a 128-bit service UUID takes most of them; any device name longer than about eight
    /// characters — which is nearly all of them — travels in the scan response instead, arriving
    /// in a *separate* callback. Dropping the sightings that carry no name would make most phones
    /// flicker in and out of the list, or never appear at all. So a name, once learnt, is kept.
    mutating func record(id: UUID, advertisedName: String?, signalStrength: Int) {
        guard let name = advertisedName ?? seen[id]?.assertedName else { return }
        seen[id] = NearbyReader(
            ephemeralID: id,
            assertedName: name,
            proof: ProximityProof(signalStrength: signalStrength)
        )
    }

    /// Ordered by how close they are, because in a room with four candidates the one being held
    /// up at arm's length is almost always the one meant.
    var readers: [NearbyReader] {
        seen.values.sorted { $0.proof.signalStrength > $1.proof.signalStrength }
    }

    func reader(_ id: UUID) -> NearbyReader? { seen[id] }

    mutating func forgetAll() { seen.removeAll() }
}
