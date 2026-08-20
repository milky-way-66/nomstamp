import Foundation

/// One line of a manifest: enough to decide whether anything needs fetching, and nothing more.
///
/// A whole 500-place manifest is roughly 25 KB, which is two round trips. That is deliberate:
/// **a sync that transfers only the manifest is a complete sync**, and the thumbnails follow
/// lazily as pins come into view (ADR-009).
public struct ManifestEntry: Equatable, Sendable {
    public let placeID: UUID
    public let version: String
    public let thumbnailHash: String?

    public init(placeID: UUID, version: String, thumbnailHash: String? = nil) {
        self.placeID = placeID
        self.version = version
        self.thumbnailHash = thumbnailHash
    }
}

public struct StampManifest: Equatable, Sendable {
    public let entries: [ManifestEntry]

    public init(_ entries: [ManifestEntry] = []) {
        self.entries = entries
    }

    public var isEmpty: Bool { entries.isEmpty }

    public func entry(for placeID: UUID) -> ManifestEntry? {
        entries.first { $0.placeID == placeID }
    }
}

/// What this device offers a friend: the stamps it shares, and the tombstones for what it used
/// to share.
///
/// Retraction is a record rather than an omission. Silence is indistinguishable from a stamp that
/// simply has not arrived yet, so unsharing has to say so out loud — and it is still best-effort,
/// which the interface must admit rather than promise deletion (NFR-1.7, TC-9-14).
public struct OutgoingShare: Equatable, Sendable {
    public let stamps: [SharedStamp]
    public let retractions: [UUID]

    public init(stamps: [SharedStamp] = [], retractions: [UUID] = []) {
        self.stamps = stamps
        self.retractions = retractions
    }

    public var manifest: StampManifest {
        StampManifest(stamps.map {
            ManifestEntry(placeID: $0.placeID, version: $0.version, thumbnailHash: $0.thumbnailHash)
        })
    }
}
