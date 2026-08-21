import Testing
@testable import FoodMapData

/// UC-1 — the decisions the camera makes (ADR-011, FR-14.1 … FR-14.3, FR-14.8).
///
/// The AVFoundation plumbing cannot run in CI; these are the parts that can.
@Suite("UC-1 Camera policy")
struct CameraPolicyTests {

    /// TC-1-27 — the lens is discovered, not defaulted.
    @Test("The back camera prefers a lens that can focus close")
    func TC_1_27_backPrefersMacroCapableLens() {
        #expect(CameraLensPolicy.lens(for: .back, available: [.wideAngle, .dualWide, .triple]) == .triple)
        #expect(CameraLensPolicy.lens(for: .back, available: [.wideAngle, .dualWide]) == .dualWide)
        #expect(CameraLensPolicy.lens(for: .back, available: [.wideAngle]) == .wideAngle)
        #expect(CameraLensPolicy.lens(for: .back, available: []) == nil)
    }

    /// TC-1-27 — and the front camera exists at all, which was the original complaint.
    @Test("The front camera prefers TrueDepth, then the wide angle")
    func TC_1_27_frontPreference() {
        #expect(CameraLensPolicy.lens(for: .front, available: [.wideAngle, .trueDepth]) == .trueDepth)
        #expect(CameraLensPolicy.lens(for: .front, available: [.wideAngle]) == .wideAngle)
        #expect(CameraLensPolicy.lens(for: .front, available: [.triple]) == nil,
                "A back-only lens is not a front camera")
    }

    @Test("Every preference is ordered, non-empty and free of repeats")
    func preferencesAreWellFormed() {
        for side in CameraSide.allCases {
            let order = CameraLensPolicy.preference(for: side)
            #expect(!order.isEmpty)
            #expect(Set(order).count == order.count, "A preference list may not repeat a lens")
        }
    }

    /// TC-1-28 — a sideways photograph is written sideways.
    @Test("Each orientation maps to its own rotation, and portrait is not assumed")
    func TC_1_28_rotationFollowsTheDevice() {
        #expect(CaptureRotation.degrees(for: .portrait) == 90)
        #expect(CaptureRotation.degrees(for: .portraitUpsideDown) == 270)
        #expect(CaptureRotation.degrees(for: .landscapeLeft) == 180)
        #expect(CaptureRotation.degrees(for: .landscapeRight) == 0)

        // The whole bug in one assertion: the four real orientations must not collapse.
        let real: [CaptureOrientation] = [.portrait, .portraitUpsideDown, .landscapeLeft, .landscapeRight]
        #expect(Set(real.map(CaptureRotation.degrees)).count == 4)
    }

    @Test("A phone held flat over the table falls back to portrait rather than to nothing")
    func indeterminateFallsBackToPortrait() {
        #expect(CaptureRotation.degrees(for: .indeterminate) == CaptureRotation.degrees(for: .portrait))
    }
}
