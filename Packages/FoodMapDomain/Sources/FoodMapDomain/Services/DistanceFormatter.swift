import Foundation

public enum DistanceFormatter {
    /// Metres below a kilometre, kilometres to one decimal above it. Metric only (NFR-5.4).
    public static func string(fromMeters meters: Double) -> String {
        meters < 1000
            ? "\(Int(meters.rounded())) m"
            : String(format: "%.1f km", meters / 1000)
    }
}
