import SwiftUI
import AVFoundation
import UIKit

/// The app's own camera, rather than the system picker.
///
/// Built on AVFoundation so the shutter, framing and chrome belong to the app: photographing
/// food is the core loop (UC-1), and handing it to a stock sheet made it feel like a detour.
/// Capture goes out as JPEG data, which keeps the EXIF the meal's time and place come from.
@MainActor
final class CameraSession: NSObject, ObservableObject {

    enum State: Equatable {
        case idle
        case running
        case denied
        case unavailable
    }

    @Published private(set) var state: State = .idle

    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private var onCapture: ((Data) -> Void)?

    /// True where a camera exists at all — false on every simulator.
    static var isSupported: Bool {
        AVCaptureDevice.default(for: .video) != nil
    }

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

        configureIfNeeded()
        guard state != .unavailable else { return }

        let session = session
        await Task.detached { session.startRunning() }.value
        state = .running
    }

    func stop() {
        let session = session
        Task.detached { session.stopRunning() }
    }

    func capture(_ onCapture: @escaping (Data) -> Void) {
        guard state == .running else { return }
        self.onCapture = onCapture
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        output.capturePhoto(with: settings, delegate: self)
    }

    private func configureIfNeeded() {
        guard session.inputs.isEmpty else { return }

        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input),
              session.canAddOutput(output)
        else {
            session.commitConfiguration()
            state = .unavailable
            return
        }

        session.addInput(input)
        session.addOutput(output)
        session.commitConfiguration()
    }
}

extension CameraSession: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        // fileDataRepresentation keeps the EXIF; re-encoding a UIImage would lose it.
        guard let data = photo.fileDataRepresentation() else { return }
        Task { @MainActor in
            onCapture?(data)
            onCapture = nil
        }
    }
}

/// The live preview layer. UIKit, because SwiftUI has no equivalent.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

/// Full-screen capture: preview, one shutter, one way out.
///
/// This is step one of logging a meal, not a detour from a form, so it owns the whole screen
/// and the caller decides what capture and close mean (UC-1).
struct InAppCameraView<Auxiliary: View>: View {
    let onCapture: (Data) -> Void
    let onClose: () -> Void
    @ViewBuilder var auxiliary: () -> Auxiliary

    @StateObject private var camera = CameraSession()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch camera.state {
            case .running:
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()
            case .denied:
                message(
                    "Camera access is off",
                    detail: "Turn it on in Settings, or choose a photo from your library instead.",
                    systemImage: "camera.metering.unknown"
                )
            case .unavailable:
                message(
                    "No camera here",
                    detail: "Choose a photo from your library instead.",
                    systemImage: "camera.on.rectangle"
                )
            case .idle:
                ProgressView()
                    .tint(.white)
            }

            controls
        }
        .task { await camera.start() }
        .onDisappear { camera.stop() }
    }

    private var controls: some View {
        VStack {
            HStack {
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
            }
            .padding(.horizontal, Theme.screenMargin)

            Spacer()

            // The shutter is centred; anything else the caller needs sits beside it, so the
            // photo remains the one obvious action.
            ZStack {
                if camera.state == .running {
                    Button {
                        camera.capture { data in onCapture(data) }
                    } label: {
                        Circle()
                            .fill(.white)
                            .frame(width: 64, height: 64)
                            .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 3).padding(-5))
                    }
                    .accessibilityLabel("Take the photo")
                    .accessibilityIdentifier("shutterButton")
                }

                HStack {
                    Spacer()
                    auxiliary()
                }
            }
            .frame(height: 64)
            .padding(.horizontal, Theme.screenMargin)
            .padding(.bottom, Theme.Space.loose)
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
