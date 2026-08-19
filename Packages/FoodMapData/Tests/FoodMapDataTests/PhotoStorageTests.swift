import Testing
import Foundation
import ImageIO
import FoodMapDomain
@testable import FoodMapData

@Suite("Photo storage and EXIF")
struct PhotoStorageTests {

    private func makeSUT() throws -> (FileSystemPhotoStorage, TemporaryDirectory) {
        let temp = TemporaryDirectory()
        return (try FileSystemPhotoStorage(directory: temp.url), temp)
    }

    @Test("TC-1-11 a stored photo produces a full image and a thumbnail, both decodable")
    func TC_1_11_storesFullImageAndThumbnail() throws {
        let (sut, temp) = try makeSUT()
        let data = JPEGFactory.make(width: 3000, height: 2000)

        let photo = try sut.store(imageData: data)

        let fullURL = sut.url(forFilename: photo.filename)
        let thumbURL = sut.url(forFilename: photo.thumbnailFilename)
        #expect(FileManager.default.fileExists(atPath: fullURL.path))
        #expect(FileManager.default.fileExists(atPath: thumbURL.path))

        // Both must be real, decodable images — not zero-byte files.
        let fullSize = try imageSize(at: fullURL)
        let thumbSize = try imageSize(at: thumbURL)

        #expect(max(fullSize.width, fullSize.height) <= 2048, "NFR-8.1 caps the long edge at 2048")
        #expect(thumbSize.width == thumbSize.height, "thumbnails are square so pins line up")
        #expect(thumbSize.width <= 240, "NFR-8.2 caps thumbnails at 240 px")
        #expect(photo.width > 0 && photo.height > 0)
        _ = temp
    }

    @Test("TC-1-12 southern and western hemisphere coordinates are negated correctly")
    func TC_1_12_handlesHemisphereSigns() throws {
        let (sut, temp) = try makeSUT()
        // Sydney: southern latitude, eastern longitude.
        let sydney = JPEGFactory.make(latitude: -33.8688, longitude: 151.2093)
        // Lima: southern latitude, western longitude.
        let lima = JPEGFactory.make(latitude: -12.0464, longitude: -77.0428)

        let sydneyMeta = sut.readMetadata(from: sydney)
        let limaMeta = sut.readMetadata(from: lima)

        #expect(abs((sydneyMeta.coordinate?.latitude ?? 0) - (-33.8688)) < 0.001)
        #expect(abs((sydneyMeta.coordinate?.longitude ?? 0) - 151.2093) < 0.001)
        #expect(abs((limaMeta.coordinate?.latitude ?? 0) - (-12.0464)) < 0.001)
        #expect(abs((limaMeta.coordinate?.longitude ?? 0) - (-77.0428)) < 0.001)
        _ = temp
    }

    @Test("a Hanoi photo keeps its positive coordinates")
    func handlesNorthernEastern() throws {
        let (sut, temp) = try makeSUT()
        let data = JPEGFactory.make(latitude: 21.0285, longitude: 105.8542)

        let meta = sut.readMetadata(from: data)

        #expect(abs((meta.coordinate?.latitude ?? 0) - 21.0285) < 0.001)
        #expect(abs((meta.coordinate?.longitude ?? 0) - 105.8542) < 0.001)
        _ = temp
    }

    @Test("TC-1-13 a photo with no GPS yields no coordinate and no error")
    func TC_1_13_missingGPSIsNotAnError() throws {
        let (sut, temp) = try makeSUT()
        let data = JPEGFactory.make()

        let meta = sut.readMetadata(from: data)

        #expect(meta.coordinate == nil)
        #expect(meta.takenAt == nil)
        _ = temp
    }

    @Test("capture time is read from EXIF")
    func readsCaptureTime() throws {
        let (sut, temp) = try makeSUT()
        let when = Date(timeIntervalSince1970: 1_767_225_600)
        let data = JPEGFactory.make(takenAt: when)

        let meta = sut.readMetadata(from: data)

        let read = try #require(meta.takenAt)
        #expect(abs(read.timeIntervalSince(when)) < 1)
        _ = temp
    }

    @Test("stored photos carry the metadata their file contained")
    func storedPhotoKeepsMetadata() throws {
        let (sut, temp) = try makeSUT()
        let when = Date(timeIntervalSince1970: 1_767_225_600)
        let data = JPEGFactory.make(takenAt: when, latitude: 21.0285, longitude: 105.8542)

        let photo = try sut.store(imageData: data)

        #expect(photo.takenAt != nil)
        #expect(photo.coordinate != nil)
        _ = temp
    }

    @Test("TC-3-04 deleting a photo removes both files from disk")
    func TC_3_04_deleteRemovesFiles() throws {
        let (sut, temp) = try makeSUT()
        let photo = try sut.store(imageData: JPEGFactory.make())
        let fullURL = sut.url(forFilename: photo.filename)
        let thumbURL = sut.url(forFilename: photo.thumbnailFilename)
        #expect(FileManager.default.fileExists(atPath: fullURL.path))

        sut.delete(photo)

        #expect(!FileManager.default.fileExists(atPath: fullURL.path))
        #expect(!FileManager.default.fileExists(atPath: thumbURL.path))
        _ = temp
    }

    @Test("deleting an already-missing photo is safe")
    func deleteIsIdempotent() throws {
        let (sut, temp) = try makeSUT()
        let photo = try sut.store(imageData: JPEGFactory.make())

        sut.delete(photo)
        sut.delete(photo) // must not crash — cleanup after a failure calls this blindly

        #expect(!FileManager.default.fileExists(atPath: sut.url(forFilename: photo.filename).path))
        _ = temp
    }

    @Test("unreadable data is rejected rather than written")
    func rejectsGarbage() throws {
        let (sut, temp) = try makeSUT()

        #expect(throws: PhotoStorageError.unreadableImage) {
            try sut.store(imageData: Data([0x00, 0x01, 0x02]))
        }
        _ = temp
    }

    private func imageSize(at url: URL) throws -> (width: Double, height: Double) {
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let props = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        let width = try #require(props[kCGImagePropertyPixelWidth] as? Double)
        let height = try #require(props[kCGImagePropertyPixelHeight] as? Double)
        return (width, height)
    }
}
