import Foundation

/// Which lens the camera reaches for, and which way up the photograph is written (ADR-011).
///
/// Pure Swift with no AVFoundation, for one reason: `CameraSession.isSupported` is false on every
/// simulator, so nothing about the camera runs in CI. The *decisions* it makes can still be
/// tested — they are the part that was wrong — while the AVFoundation plumbing around them stays
/// a manual check on a device (TC-1-31).

/// The capture devices this app knows how to ask for.
public enum CameraLens: String, Sendable, CaseIterable {
    case triple
    case dualWide
    case wideAngle
    case trueDepth
}

public enum CameraSide: String, Sendable, CaseIterable {
    case back
    case front
}

public enum CameraLensPolicy {

    /// Triple and dual-wide first because both include the **ultra-wide**, which is the lens the
    /// system switches to for automatic macro. A bowl photographed at arm's length is this app's
    /// most common shot and the one a bare wide-angle focuses worst (ADR-011 §1).
    ///
    /// This is why `AVCaptureDevice.default(for: .video)` is not used: it returns the wide-angle
    /// device, which is precisely the one that cannot focus close.
    public static let backPreference: [CameraLens] = [.triple, .dualWide, .wideAngle]

    public static let frontPreference: [CameraLens] = [.trueDepth, .wideAngle]

    public static func preference(for side: CameraSide) -> [CameraLens] {
        side == .back ? backPreference : frontPreference
    }

    /// The first preferred lens the device actually has, or nil where it has none.
    public static func lens(for side: CameraSide, available: [CameraLens]) -> CameraLens? {
        preference(for: side).first { available.contains($0) }
    }
}

/// How the phone is being held, independent of UIKit so the mapping can be tested on macOS.
public enum CaptureOrientation: String, Sendable, CaseIterable {
    case portrait
    case portraitUpsideDown
    case landscapeLeft
    case landscapeRight
    /// Flat on the table, or unknown — very common when photographing food from directly above.
    case indeterminate
}

public enum CaptureRotation {

    /// The angle written onto the capture connection, in degrees, matching
    /// `AVCaptureConnection.videoRotationAngle`.
    ///
    /// Nothing set this before, so it defaulted to portrait and every sideways photograph was
    /// stored claiming to be upright (ADR-011 §4). `indeterminate` keeps that old default
    /// deliberately: a phone held flat over a table has no meaningful rotation, and portrait is
    /// the right guess for a reader standing over their lunch.
    public static func degrees(for orientation: CaptureOrientation) -> Double {
        switch orientation {
        case .portrait, .indeterminate: return 90
        case .portraitUpsideDown: return 270
        case .landscapeLeft: return 180
        case .landscapeRight: return 0
        }
    }
}
