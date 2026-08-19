import UIKit
import FoodMapData

/// Loads stored photos for display, with a small cache so panning the map does not re-read
/// the same thumbnails from disk (NFR-2.2).
final class PhotoImageLoader {
    static let shared = PhotoImageLoader()

    private var storage: FileSystemPhotoStorage?
    private let cache = NSCache<NSString, UIImage>()
    private let fullImageCache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 300
        fullImageCache.countLimit = 8
        // ~24 M pixels, about six 2048 px photos — enough for one place's meals, not enough to
        // matter against the app's footprint.
        fullImageCache.totalCostLimit = 24_000_000
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

    /// A full-size photo, cached far more sparingly than thumbnails: these are up to 2048 px on
    /// the long edge, so a handful of them is already tens of megabytes decoded (NFR-2.2).
    func fullImage(named filename: String) -> UIImage? {
        if let cached = fullImageCache.object(forKey: filename as NSString) { return cached }
        guard let url = storage?.url(forFilename: filename),
              let image = UIImage(contentsOfFile: url.path)
        else { return nil }
        // Cost in pixels, which is what actually occupies memory once decoded.
        fullImageCache.setObject(
            image,
            forKey: filename as NSString,
            cost: Int(image.size.width * image.size.height)
        )
        return image
    }
}
