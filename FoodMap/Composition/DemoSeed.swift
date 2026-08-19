import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import FoodMapDomain

/// Seeds a small, believable map when launched with `-SeedDemoData`.
///
/// Used by UI journeys and for looking at the design without hand-entering data. Never runs
/// in a normal launch.
enum DemoSeed {

    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains("-SeedDemoData")
    }

    static func apply(to dependencies: AppDependencies) {
        guard (try? dependencies.places.allPlaces())?.isEmpty ?? false else { return }

        // Visited: two meals at one restaurant, so the "one pin, many visits" rule is visible.
        _ = try? dependencies.logMeal.execute(
            LogMealRequest(
                target: .newPlace(PlaceDraft(
                    name: "Phở Thìn",
                    address: "13 Lò Đúc, Hai Bà Trưng",
                    coordinate: Coordinate(latitude: 21.0181, longitude: 105.8554)
                )),
                photoData: [jpeg(hue: 0.07)],
                dishName: "Phở bò tái lăn",
                rating: 5,
                note: "Smoky, the beef is seared first."
            )
        )

        if let phoThin = (try? dependencies.places.allPlaces())?.first(where: { $0.name == "Phở Thìn" }) {
            _ = try? dependencies.logMeal.execute(
                LogMealRequest(
                    target: .existingPlace(phoThin.id),
                    photoData: [jpeg(hue: 0.1)],
                    dishName: "Quẩy",
                    rating: 4
                )
            )
        }

        _ = try? dependencies.logMeal.execute(
            LogMealRequest(
                target: .newPlace(PlaceDraft(
                    name: "Bánh mì Bà Dần",
                    address: "Ngõ Huyện, Hoàn Kiếm",
                    coordinate: Coordinate(latitude: 21.0305, longitude: 105.8489)
                )),
                photoData: [jpeg(hue: 0.12)],
                dishName: "Bánh mì pate trứng",
                rating: 4
            )
        )

        // Wishlist: saved on someone's recommendation, never visited.
        _ = try? dependencies.savePlace.execute(
            PlaceDraft(
                name: "Bún chả Hương Liên",
                address: "24 Lê Văn Hưu",
                coordinate: Coordinate(latitude: 21.0180, longitude: 105.8541),
                note: "Lan said the bún chả here is the best in Hanoi",
                tags: ["bún chả", "Hà Nội"]
            )
        )

        _ = try? dependencies.savePlace.execute(
            PlaceDraft(
                name: "Cà phê Giảng",
                address: "39 Nguyễn Hữu Huân",
                coordinate: Coordinate(latitude: 21.0338, longitude: 105.8535),
                note: "Egg coffee — go upstairs, Hùng says",
                tags: ["cà phê"]
            )
        )
    }

    /// A plausible food-coloured placeholder, generated rather than bundled so no binary
    /// assets are committed for demo purposes.
    static func placeholderJPEG(hue: Double) -> Data { jpeg(hue: hue) }

    private static func jpeg(hue: Double) -> Data {
        let size = 900
        let context = CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )!

        let colors = [
            CGColor(red: 0.86, green: 0.52 + hue, blue: 0.24, alpha: 1),
            CGColor(red: 0.62, green: 0.24 + hue, blue: 0.15, alpha: 1)
        ] as CFArray
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
        context.drawLinearGradient(
            gradient,
            start: .zero,
            end: CGPoint(x: size, y: size),
            options: []
        )
        // A few darker blobs so the thumbnail does not read as a flat swatch.
        context.setFillColor(CGColor(red: 0.35, green: 0.16, blue: 0.1, alpha: 0.55))
        for index in 0..<6 {
            let x = Double((index * 137) % size)
            let y = Double((index * 241) % size)
            context.fillEllipse(in: CGRect(x: x, y: y, width: 180, height: 140))
        }

        let image = context.makeImage()!
        let output = NSMutableData()
        let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
        return output as Data
    }
}
