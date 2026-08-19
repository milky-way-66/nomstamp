import SwiftUI
import PhotosUI
import UIKit

/// Camera capture. SwiftUI has no native camera view, so `UIImagePickerController` is wrapped.
/// The simulator has no camera, which is why the library path must always work too.
struct CameraPicker: UIViewControllerRepresentable {
    let onCapture: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, dismiss: { dismiss() })
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onCapture: (Data) -> Void
        private let dismiss: () -> Void

        init(onCapture: @escaping (Data) -> Void, dismiss: @escaping () -> Void) {
            self.onCapture = onCapture
            self.dismiss = dismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage,
               let data = image.jpegData(compressionQuality: 0.9) {
                onCapture(data)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}

/// Loads the raw bytes of chosen library photos.
///
/// The original file data is kept rather than a re-encoded `UIImage`, because re-encoding
/// strips the EXIF that tells us when and where the meal happened (UC-1 / 1a).
enum PhotoLibraryLoader {
    static func load(_ items: [PhotosPickerItem]) async -> [Data] {
        var result: [Data] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                result.append(data)
            }
        }
        return result
    }
}
