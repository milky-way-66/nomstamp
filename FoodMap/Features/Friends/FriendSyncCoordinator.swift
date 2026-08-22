import Foundation
import FoodMapDomain

/// Reconciles the disposable friend cache with each connected friend's published manifest.
@MainActor
final class FriendSyncCoordinator {
    private let friends: FriendsStore
    private let places: any PlaceRepositoryPort
    private let transport: any StampSyncPort
    private let reconcile = ReconcileManifestUseCase()

    init(friends: FriendsStore, places: any PlaceRepositoryPort, transport: any StampSyncPort) {
        self.friends = friends
        self.places = places
        self.transport = transport
    }

    func sync() async {
        let allPlaces = (try? places.allPlaces()) ?? []
        let outgoing = friends.outgoingShare(for: allPlaces)
        try? await transport.publish(outgoing)

        for friend in friends.circle.friends {
            guard let remote = try? await transport.remoteManifest(for: friend.key) else { continue }
            let diff = reconcile.execute(
                remote: remote,
                local: friends.localManifest(for: friend.key)
            )
            if !diff.needed.isEmpty,
               let incoming = try? await transport.fetchStamps(diff.needed, from: friend.key) {
                friends.receive(incoming, from: friend.key)
            }
            if !diff.retracted.isEmpty {
                friends.drop(diff.retracted, from: friend.key)
            }
        }
    }
}
