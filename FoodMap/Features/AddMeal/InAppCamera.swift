import SwiftUI
import AVFoundation
import AVKit
import UIKit
import FoodMapData

/// The app's own camera, rather than the system picker.
///
/// Built on AVFoundation so the shutter, framing and chrome belong to the app: photographing
/// food is the core loop (UC-1), and handing it to a stock sheet made it feel like a detour.
/// Capture goes out as JPEG data, which keeps the EXIF the meal's time and place come from.
///
/// What it reaches for, and which way up it writes, are decided by `CameraLensPolicy` and
/// `CaptureRotation` in `FoodMapData` — pure types, because none of this runs on a simulator and
/// the decisions were the part that was wrong (ADR-011).
@MainActor
final class CameraSession: NSObject, ObservableObject {

    enum State: Equatable {
        case idle
        case running
        case denied
        case unavailable
    }

    enum TorchSetting: CaseIterable {
        case off, on, auto
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var side: CameraSide = .back
    @Published private(set) var zoom: Double = 1
    @Published private(set) var availableZooms: [Double] = []
    @Published private(set) var hasTorch = false
    @Published var torch: TorchSetting = .off { didSet { applyTorch() } }
    /// Where the reader last tapped to focus, in preview coordinates — drawn briefly, then cleared.
    @Published var focusPoint: CGPoint?
    /// Set when a capture produced nothing. NFR-4.4: a shutter that does nothing must say so.
    @Published var captureFailed = false

    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private var input: AVCaptureDeviceInput?
    private var device: AVCaptureDevice?
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var onCapture: ((Data) -> Void)?

    /// True where a camera exists at all — false on every simulator.
    static var isSupported: Bool {
        !AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        ).devices.isEmpty
    }

    // MARK: - Lifecycle

    func start() async {
        guard Self.isSupported else {
            state = .unavailable
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else {
                state = .denied
                return
            }
        default:
            state = .denied
            return
        }

        configure(for: side)
        guard state != .unavailable else { return }

        let session = session
        await Task.detached { session.startRunning() }.value
        state = .running
    }

    func stop() {
        setTorch(.off)
        let session = session
        Task.detached { session.stopRunning() }
    }

    // MARK: - Choosing a camera

    /// Flip. The side is not remembered between meals — the next meal opens on the back camera,
    /// because that is what a meal is (FR-14.4).
    func flip() {
        side = (side == .back) ? .front : .back
        torch = .off
        focusPoint = nil
        configure(for: side)
    }

    /// Discovery, not `AVCaptureDevice.default(for:)`. The convenience returns the wide-angle
    /// device, which is the one lens that cannot focus close — and a close-up of a bowl is this
    /// app's most common photograph (ADR-011 §1, FR-14.2).
    private func configure(for side: CameraSide) {
        let types: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera, .builtInDualWideCamera, .builtInWideAngleCamera, .builtInTrueDepthCamera,
        ]
        let discovered = AVCaptureDevice.DiscoverySession(
            deviceTypes: types,
            mediaType: .video,
            position: side == .back ? .back : .front
        ).devices

        let byLens = Dictionary(
            discovered.compactMap { device in Self.lens(of: device).map { ($0, device) } },
            uniquingKeysWith: { first, _ in first }
        )

        guard
            let chosen = CameraLensPolicy.lens(for: side, available: Array(byLens.keys)),
            let device = byLens[chosen],
            let input = try? AVCaptureDeviceInput(device: device)
        else {
            state = .unavailable
            return
        }

        session.beginConfiguration()
        if let existing = self.input { session.removeInput(existing) }
        session.sessionPreset = .photo

        guard session.canAddInput(input) else {
            session.commitConfiguration()
            state = .unavailable
            return
        }
        session.addInput(input)
        self.input = input
        self.device = device

        if session.outputs.isEmpty {
            guard session.canAddOutput(output) else {
                session.commitConfiguration()
                state = .unavailable
                return
            }
            session.addOutput(output)
        }
        output.maxPhotoDimensions = device.activeFormat.supportedMaxPhotoDimensions.last
            ?? output.maxPhotoDimensions
        output.maxPhotoQualityPrioritization = .quality

        // The preview is mirrored for the front camera because a reader expects to move left and
        // see the image move left. The **file** is not, so text behind them stays readable
        // (ADR-011 §13, FR-14.19).
        if let connection = output.connection(with: .video), connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = false
        }
        session.commitConfiguration()

        rotationCoordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)
        hasTorch = device.hasTorch
        zoom = device.videoZoomFactor
        availableZooms = Self.zoomMarks(for: device)
    }

    private static func lens(of device: AVCaptureDevice) -> CameraLens? {
        switch device.deviceType {
        case .builtInTripleCamera: return .triple
        case .builtInDualWideCamera: return .dualWide
        case .builtInWideAngleCamera: return .wideAngle
        case .builtInTrueDepthCamera: return .trueDepth
        default: return nil
        }
    }

    /// The marks the viewfinder offers. Pinch is a fine gesture and a poor control — it cannot be
    /// aimed at a number (ADR-011 §7, FR-14.12).
    private static func zoomMarks(for device: AVCaptureDevice) -> [Double] {
        let factors = device.virtualDeviceSwitchOverVideoZoomFactors.map(\.doubleValue)
        guard !factors.isEmpty else { return [] }
        // An ultra-wide is present when the device switches over above 1: the wide sits at that
        // factor, so 1 in the device's terms is the 0.5x the reader knows.
        let marks = [1.0] + factors
        return marks.filter { $0 <= device.maxAvailableVideoZoomFactor }
    }

    // MARK: - Focus, exposure, zoom, light

    /// One tap sets focus **and** exposure. Separating them is a photographer's distinction, not
    /// a diner's: a reader who taps the food means *that is the subject* (FR-14.6).
    func focus(at point: CGPoint, in size: CGSize) {
        guard let device, size.width > 0, size.height > 0 else { return }
        let normalised = CGPoint(x: point.y / size.height, y: 1 - point.x / size.width)

        configureDevice { device in
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = normalised
                if device.isFocusModeSupported(.autoFocus) { device.focusMode = .autoFocus }
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = normalised
                if device.isExposureModeSupported(.autoExpose) { device.exposureMode = .autoExpose }
            }
        }
        focusPoint = point
    }

    /// Back to continuous auto — what a second tap, or a flip, means.
    func resetFocus() {
        configureDevice { device in
            if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
            if device.isExposureModeSupported(.continuousAutoExposure) { device.exposureMode = .continuousAutoExposure }
        }
        focusPoint = nil
    }

    func setZoom(_ factor: Double) {
        guard let device else { return }
        let clamped = min(max(factor, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
        configureDevice { $0.videoZoomFactor = clamped }
        zoom = clamped
    }

    func cycleTorch() {
        guard hasTorch else { return }
        switch torch {
        case .off: torch = .on
        case .on: torch = .auto
        case .auto: torch = .off
        }
    }

    private func setTorch(_ setting: TorchSetting) {
        guard device?.hasTorch == true else { return }
        configureDevice { device in
            switch setting {
            case .off: device.torchMode = .off
            case .on: device.torchMode = .on
            case .auto: device.torchMode = .auto
            }
        }
    }

    private func applyTorch() { setTorch(torch) }

    private func configureDevice(_ body: (AVCaptureDevice) -> Void) {
        guard let device, (try? device.lockForConfiguration()) != nil else { return }
        body(device)
        device.unlockForConfiguration()
    }

    // MARK: - Capture

    func capture(_ onCapture: @escaping (Data) -> Void) {
        guard state == .running else { return }
        self.onCapture = onCapture
        captureFailed = false

        // The rotation the photograph is written with. Nothing set this before, so it defaulted
        // to portrait and a sideways shot was stored claiming to be upright (FR-14.8).
        if let connection = output.connection(with: .video) {
            let angle = rotationCoordinator.map { Double($0.videoRotationAngleForHorizonLevelCapture) }
                ?? CaptureRotation.degrees(for: .portrait)
            if connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
        }

        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        settings.photoQualityPrioritization = .quality
        settings.maxPhotoDimensions = output.maxPhotoDimensions
        if device?.hasTorch == true {
            settings.flashMode = (torch == .on) ? .on : (torch == .auto ? .auto : .off)
        }
        output.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraSession: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        // fileDataRepresentation keeps the EXIF; re-encoding a UIImage would lose it.
        let data = (error == nil) ? photo.fileDataRepresentation() : nil
        Task { @MainActor in
            if let data {
                onCapture?(data)
            } else {
                // Previously this returned and the reader saw a shutter that did nothing
                // (NFR-4.4, FR-14.10).
                captureFailed = true
            }
            onCapture = nil
        }
    }
}

/// The live preview layer. UIKit, because SwiftUI has no equivalent.
///
/// It also carries the volume-button shutter: `AVCaptureEventInteraction` needs a view to attach
/// to, and the physical button is the only control on this screen a reader can find without
/// looking — which is what they are doing, holding the phone over a bowl one-handed (FR-14.11).
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let isMirrored: Bool
    let onVolumeShutter: () -> Void

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        let interaction = AVCaptureEventInteraction { event in
            guard event.phase == .ended else { return }
            Task { @MainActor in onVolumeShutter() }
        }
        view.addInteraction(interaction)
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        guard let connection = view.previewLayer.connection,
              connection.isVideoMirroringSupported else { return }
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = isMirrored
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

/// Full-screen capture: preview, one shutter, and the controls a camera has.
///
/// This is step one of logging a meal, not a detour from a form, so it owns the whole screen
/// and the caller decides what capture and close mean (UC-1).
struct InAppCameraView<Auxiliary: View>: View {
    let onCapture: (Data) -> Void
    let onClose: () -> Void
    /// How many photographs this visit has already taken — shown so the reader knows the shutter
    /// worked, and so several dishes can be photographed without leaving (FR-14.14, FR-14.15).
    var shotCount: Int = 0
    var latestShot: Data?
    var onReviewShots: (() -> Void)?
    @ViewBuilder var auxiliary: () -> Auxiliary

    @StateObject private var camera = CameraSession()
    @State private var dimmed = false
    @State private var pinchStart: Double?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch camera.state {
            case .running:
                preview
            case .denied:
                message(
                    "Nomstamp hasn't been allowed the camera",
                    detail: "You can allow it in Settings — or pick a photo you already took.",
                    systemImage: "camera.metering.unknown"
                )
            case .unavailable:
                message(
                    "This phone has no camera",
                    detail: "Choose a photo from your library instead.",
                    systemImage: "camera.on.rectangle"
                )
            case .idle:
                ProgressView().tint(.white)
            }

            controls

            // The shutter answers: a brief dim, alongside the haptic (FR-14.9).
            if dimmed {
                Color.black.ignoresSafeArea().transition(.opacity)
            }
        }
        .task { await camera.start() }
        .onDisappear { camera.stop() }
        .alert("That shot didn't come through", isPresented: $camera.captureFailed) {
            Button("Try again", role: .cancel) {}
        } message: {
            Text("Nothing was saved. Press the shutter again.")
        }
    }

    private var preview: some View {
        GeometryReader { geometry in
            CameraPreview(
                session: camera.session,
                isMirrored: camera.side == .front,
                onVolumeShutter: { take() }
            )
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture { location in
                camera.focus(at: location, in: geometry.size)
            }
            .gesture(
                MagnifyGesture()
                    .onChanged { value in
                        let start = pinchStart ?? camera.zoom
                        pinchStart = start
                        camera.setZoom(start * value.magnification)
                    }
                    .onEnded { _ in pinchStart = nil }
            )
            .overlay(alignment: .topLeading) {
                if let point = camera.focusPoint {
                    // Where the reader told the camera to look.
                    Rectangle()
                        .stroke(.white.opacity(0.9), lineWidth: 1)
                        .frame(width: 64, height: 64)
                        .position(point)
                        .allowsHitTesting(false)
                        .task {
                            try? await Task.sleep(for: .seconds(2))
                            camera.resetFocus()
                        }
                }
            }
        }
        .ignoresSafeArea()
    }

    private var controls: some View {
        VStack {
            HStack(alignment: .top) {
                Button { onClose() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: Theme.minimumTouchTarget, height: Theme.minimumTouchTarget)
                        .background(.black.opacity(0.4), in: Circle())
                }
                .accessibilityLabel("Close the camera")
                .accessibilityIdentifier("closeCameraButton")

                Spacer()

                if camera.state == .running && camera.hasTorch {
                    Button { camera.cycleTorch() } label: {
                        Image(systemName: torchGlyph)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(camera.torch == .off ? .white : .yellow)
                            .frame(width: Theme.minimumTouchTarget, height: Theme.minimumTouchTarget)
                            .background(.black.opacity(0.4), in: Circle())
                    }
                    .accessibilityLabel("Light")
                    .accessibilityIdentifier("torchButton")
                }
            }
            .padding(.horizontal, Theme.screenMargin)

            Spacer()

            if camera.state == .running && camera.availableZooms.count > 1 {
                zoomMarks
            }

            // The shutter is centred; anything else the caller needs sits beside it, so the
            // photo remains the one obvious action.
            ZStack {
                if camera.state == .running {
                    Button { take() } label: {
                        Circle()
                            .fill(.white)
                            .frame(width: 64, height: 64)
                            .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 3).padding(-5))
                    }
                    .accessibilityLabel("Take the photo")
                    .accessibilityIdentifier("shutterButton")
                }

                HStack {
                    shotThumbnail
                    Spacer()
                    if camera.state == .running {
                        Button { camera.flip() } label: {
                            Image(systemName: "arrow.triangle.2.circlepath.camera")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(width: 46, height: 46)
                                .background(.white.opacity(0.18), in: Circle())
                        }
                        .accessibilityLabel("Switch camera")
                        .accessibilityIdentifier("flipCameraButton")
                    }
                    auxiliary()
                }
            }
            .frame(height: 64)
            .padding(.horizontal, Theme.screenMargin)
            .padding(.bottom, Theme.Space.loose)
        }
    }

    /// 0.5x / 1x / 2x. Pinch still works and moves with them (FR-14.12).
    private var zoomMarks: some View {
        HStack(spacing: Theme.Space.tight) {
            ForEach(camera.availableZooms, id: \.self) { factor in
                let isLive = abs(camera.zoom - factor) < 0.05
                Button { camera.setZoom(factor) } label: {
                    Text(Self.zoomLabel(factor, marks: camera.availableZooms))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isLive ? .black : .white)
                        .frame(width: 36, height: 28)
                        .background(isLive ? .white : .black.opacity(0.35), in: Capsule())
                }
                .accessibilityIdentifier("zoom-\(Int(factor * 10))")
            }
        }
        .padding(.bottom, Theme.Space.snug)
    }

    /// Proof the shutter worked, and the way back to what was taken (FR-14.14).
    @ViewBuilder private var shotThumbnail: some View {
        if shotCount > 0 {
            Button { onReviewShots?() } label: {
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let latestShot, let image = UIImage(data: latestShot) {
                            Image(uiImage: image).resizable().scaledToFill()
                        } else {
                            Color.white.opacity(0.2)
                        }
                    }
                    .frame(width: 46, height: 46)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.white.opacity(0.7), lineWidth: 1))

                    Text("\(shotCount)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(3)
                        .background(.white, in: Circle())
                        .offset(x: 4, y: 4)
                }
            }
            .accessibilityLabel("Photos taken")
            .accessibilityValue("\(shotCount)")
            .accessibilityIdentifier("shotCountButton")
        } else {
            Color.clear.frame(width: 46, height: 46)
        }
    }

    private var torchGlyph: String {
        switch camera.torch {
        case .off: return "bolt.slash"
        case .on: return "bolt.fill"
        case .auto: return "bolt.badge.a"
        }
    }

    private static func zoomLabel(_ factor: Double, marks: [Double]) -> String {
        // The device counts from its wide lens; the reader counts from theirs. Where an
        // ultra-wide is present the smallest mark is the 0.5x they know.
        guard let smallest = marks.min(), let base = marks.dropFirst().first, smallest < base else {
            return String(format: "%.0f×", factor)
        }
        let relative = factor / base
        return relative < 1
            ? String(format: "%.1f×", relative)
            : String(format: "%.0f×", relative)
    }

    private func take() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.easeOut(duration: 0.08)) { dimmed = true }
        camera.capture { data in
            withAnimation(.easeIn(duration: 0.12)) { dimmed = false }
            onCapture(data)
        }
        Task {
            try? await Task.sleep(for: .milliseconds(180))
            withAnimation(.easeIn(duration: 0.12)) { dimmed = false }
        }
    }

    private func message(
        _ title: LocalizedStringKey,
        detail: LocalizedStringKey,
        systemImage: String
    ) -> some View {
        VStack(spacing: Theme.Space.snug) {
            Image(systemName: systemImage)
                .font(.system(size: 32))
            Text(title)
                .font(Theme.display(.headline))
            Text(detail)
                .font(Theme.label(.footnote))
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Space.generous)
        }
        .foregroundStyle(.white)
    }
}
