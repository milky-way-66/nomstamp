import Foundation

/// What one exchange with one friend needs to do.
public struct ManifestDiff: Equatable, Sendable {
    /// Stamps whose version differs, or which are not held at all.
    public let needed: [UUID]
    /// Held here, absent there: the friend retracted them, so they go.
    public let retracted: [UUID]
    /// Thumbnails referenced by the needed stamps and not already on disk. Content addressing
    /// means an image already held is never fetched twice — by anyone, ever.
    public let thumbnailsNeeded: [String]

    public init(needed: [UUID] = [], retracted: [UUID] = [], thumbnailsNeeded: [String] = []) {
        self.needed = needed
        self.retracted = retracted
        self.thumbnailsNeeded = thumbnailsNeeded
    }

    public var isEmpty: Bool {
        needed.isEmpty && retracted.isEmpty && thumbnailsNeeded.isEmpty
    }
}

/// UC-10 — the diff, with no network in sight.
///
/// The hardest part of sync is deciding what to ask for, and this is it: pure, synchronous, and
/// testable without two phones. Everything around it — waking, fetching, retrying — is the
/// transport's problem and has nothing left to decide (ADR-009).
public struct ReconcileManifestUseCase: Sendable {
    public init() {}

    public func execute(
        remote: StampManifest,
        local: StampManifest,
        heldThumbnailHashes: Set<String> = []
    ) -> ManifestDiff {
        var needed: [UUID] = []
        var wantedThumbnails: [String] = []
        var seenThumbnails: Set<String> = []

        for entry in remote.entries {
            let held = local.entry(for: entry.placeID)
            guard held?.version != entry.version else { continue }
            needed.append(entry.placeID)
            if let hash = entry.thumbnailHash,
               !heldThumbnailHashes.contains(hash),
               seenThumbnails.insert(hash).inserted {
                wantedThumbnails.append(hash)
            }
        }

        let remoteIDs = Set(remote.entries.map(\.placeID))
        let retracted = local.entries.map(\.placeID).filter { !remoteIDs.contains($0) }

        return ManifestDiff(needed: needed, retracted: retracted, thumbnailsNeeded: wantedThumbnails)
    }
}
