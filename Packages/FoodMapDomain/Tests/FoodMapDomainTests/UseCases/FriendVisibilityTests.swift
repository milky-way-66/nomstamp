import Testing
import Foundation
@testable import FoodMapDomain

/// FR-12.11 — hiding a friend, and showing only one.
@Suite("Friend visibility")
struct FriendVisibilityTests {

    private func key(_ byte: UInt8) -> FriendKey {
        FriendKey(bytes: [byte] + Array(repeating: 0, count: 31))!
    }

    private func circle(_ count: Int) -> FriendCircle {
        FriendCircle((0..<count).map { index in
            Friend(
                key: key(UInt8(index + 1)),
                assignedName: "Friend \(index + 1)",
                inkSlot: index,
                connectedAt: Date(timeIntervalSince1970: 0),
                lastReachedAt: Date(timeIntervalSince1970: 0)
            )
        })
    }

    @Test("Nobody is hidden to begin with")
    func nobodyHiddenInitially() {
        let visibility = FriendVisibility()
        #expect(!visibility.isHidden(key(1)))
        #expect(visibility.hidden.isEmpty)
    }

    @Test("Toggling hides, and toggling again shows")
    func togglingRoundTrips() {
        var visibility = FriendVisibility()
        visibility.toggle(key(1))
        #expect(visibility.isHidden(key(1)))
        visibility.toggle(key(1))
        #expect(!visibility.isHidden(key(1)))
    }

    // MARK: - TC-10-20

    @Test("Isolating one friend hides every other")
    func isolatingHidesTheRest() {
        let circle = self.circle(4)
        var visibility = FriendVisibility()
        visibility.isolate(key(2), within: circle)

        #expect(!visibility.isHidden(key(2)))
        #expect(visibility.isHidden(key(1)))
        #expect(visibility.isHidden(key(3)))
        #expect(visibility.isHidden(key(4)))
        #expect(visibility.isIsolated(key(2), within: circle))
    }

    @Test("Restoring brings back everyone, including those hidden before the isolation")
    func restoringShowsEveryone() {
        let circle = self.circle(4)
        var visibility = FriendVisibility()
        // Someone was already switched off by hand, before any isolating happened.
        visibility.toggle(key(4))
        visibility.isolate(key(2), within: circle)
        visibility.showEveryone()

        #expect(visibility.hidden.isEmpty, "Restoring left someone dark that the reader never chose")
        #expect(!visibility.isIsolated(key(2), within: circle))
    }

    @Test("Isolating twice in a row is still just that one friend")
    func isolatingIsIdempotent() {
        let circle = self.circle(4)
        var visibility = FriendVisibility()
        visibility.isolate(key(2), within: circle)
        visibility.isolate(key(2), within: circle)
        #expect(visibility.isIsolated(key(2), within: circle))
    }

    @Test("Isolating someone else moves the isolation rather than stacking it")
    func isolatingSomeoneElseMoves() {
        let circle = self.circle(4)
        var visibility = FriendVisibility()
        visibility.isolate(key(2), within: circle)
        visibility.isolate(key(3), within: circle)

        #expect(visibility.isIsolated(key(3), within: circle))
        #expect(!visibility.isIsolated(key(2), within: circle))
        #expect(visibility.isHidden(key(2)))
    }

    @Test("A friend alone in the circle is not 'isolated' — there is nothing to isolate them from")
    func aCircleOfOneIsNotIsolation() {
        // Otherwise the only friend a reader has would offer to *show only* themselves, which is
        // the state they are already in.
        #expect(FriendVisibility().isIsolated(key(1), within: circle(1)))
    }

    @Test("A hidden friend is never reported as isolated")
    func hiddenIsNotIsolated() {
        let circle = self.circle(3)
        var visibility = FriendVisibility()
        visibility.isolate(key(1), within: circle)
        visibility.toggle(key(1))
        #expect(!visibility.isIsolated(key(1), within: circle))
    }

    @Test("A stranger is never isolated, whatever is hidden")
    func strangersAreNotIsolated() {
        #expect(!FriendVisibility().isIsolated(key(99), within: circle(3)))
    }

    @Test("Forgetting a removed friend clears the key they left behind")
    func forgettingClearsTheKey() {
        var visibility = FriendVisibility()
        visibility.toggle(key(1))
        visibility.forget(key(1))
        #expect(!visibility.isHidden(key(1)))
    }
}
