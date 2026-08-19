import UIKit
import FoodMapData

/// Loads stored photos for display, with a small cache so panning the map does not re-read
/// the same thumbnails from disk (NFR-2.2).
final class PhotoImageLoader {
    static let shared = PhotoImageLoader()

    private var storage: FileSystemPhotoStorage?
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 300
    }

    func configure(storage: FileSystemPhotoStorage) {
        self.storage = storage
    }

    func thumbnail(named filename: String) -> UIImage? {
        if let cached = cache.object(forKey: filename as NSString) { return cached }
        guard let url = storage?.url(forFilename: filename),
              let image = UIImage(contentsOfFile: url.path)
        else { return nil }
        cache.setObject(image, forKey: filename as NSString)
        return image
    }

    func fullImage(named filename: String) -> UIImage? {
        guard let url = storage?.url(forFilename: filename) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}
