import SwiftUI
import Observation
import FoodMapDomain
import FoodMapDesign

/// Which printing the app is in, and when it changes (ADR-006).
///
/// The decision itself is `ChooseAppearanceUseCase`, and is unit-tested. This only gathers what
/// that rule needs — where the reader is, what the sky is doing there — and hands the answer to
/// the interface. Weather is decoration: nothing here reports a failure, because a missed forecast
/// simply means the reader's own clock decides the lights instead (ADR-006, revised 20 August).
@MainActor
@Observable
final class AppearanceStore {
    private(set) var appearance: Appearance

    private let weather: WeatherPort
    private let location: any LocationPort
    private let clock: ClockPort
    private let choose = ChooseAppearanceUseCase()
    /// Set by `-ForceSkin <name>`, which the design sweep uses to photograph every printing.
    private let forcedSkin: FoodMapDomain.Skin?
    /// Set by `-ForceNight`. Since the appearance follows the sun rather than the system setting,
    /// flipping the simulator to dark no longer reaches the app, and the night market would only
    /// be photographable after sunset.
    private let forcedNight: Bool
    /// The ticker that catches six o'clock while the app is open (ADR-006, revised 20 August).
    private var ticker: Task<Void, Never>?

    /// How often the lights are re-checked while the app is in front of the reader.
    ///
    /// A minute rather than something cleverer: the check is a pure function over a clock reading
    /// and costs nothing, and scheduling for the next boundary exactly would mean recomputing that
    /// schedule every time the sky, the time zone or the reader's latitude moved it.
    static let tick: Duration = .seconds(60)

    init(weather: WeatherPort, location: any LocationPort, clock: ClockPort) {
        self.weather = weather
        self.location = location
        self.clock = clock
        self.forcedSkin = Self.forcedSkin()
        self.forcedNight = ProcessInfo.processInfo.arguments.contains("-ForceNight")
        // Start on the clock so the first frame is already printed correctly — someone opening the
        // app at nine at night should never see a flash of daylight; the sky, which needs a fix and
        // a network round trip, refines it a moment later.
        let opening = ChooseAppearanceUseCase().execute(weather: nil, on: clock.now)
        self.appearance = Self.forcing(skin: self.forcedSkin, night: self.forcedNight, on: opening)
        apply()
        startTicking()
    }

    /// Re-run the rule on a timer, so an app left open through six o'clock changes with the hour
    /// rather than waiting to be backgrounded and brought to the front again.
    private func startTicking() {
        guard forcedSkin == nil, !forcedNight else { return }
        ticker?.cancel()
        // Weak, and it stops when the store goes: a `deinit` cannot touch a main-actor property,
        // and a ticker outliving the thing it ticks for is the only leak available here.
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.tick)
                guard let self, !Task.isCancelled else { return }
                self.reconsider(sky: nil)
            }
        }
    }

    /// Ask the sky again. Called when the app comes to the front: between two sessions it can have
    /// started raining, or got dark, and the app should have noticed.
    func refresh() async {
        guard forcedSkin == nil, !forcedNight else { return }
        reconsider(sky: await currentSky())
    }

    /// Put a reading — or the absence of one, which is the ticker's case — through the rule, and
    /// re-ink only if the answer moved. The root rebuilds on a change of appearance, so a store
    /// that assigned unconditionally would rebuild the interface once a minute.
    private func reconsider(sky: WeatherSnapshot?) {
        let next = choose.execute(weather: sky, on: clock.now)
        guard next != appearance else { return }
        appearance = next
        apply()
    }

    private func currentSky() async -> WeatherSnapshot? {
        guard let coordinate = await location.currentCoordinate() else { return nil }
        return await weather.snapshot(at: coordinate)
    }

    /// Point the design tokens at the current skin.
    ///
    /// `Theme` is read by every view that draws chrome, so the skin lives there as a stored value
    /// rather than in the environment; the root view rebuilds on change (see `FoodMapApp`).
    private func apply() {
        Theme.skin = appearance.skin.rendered
    }

    private static func forcing(skin: FoodMapDomain.Skin?, night: Bool, on appearance: Appearance) -> Appearance {
        Appearance(skin: skin ?? appearance.skin, isNight: night || appearance.isNight)
    }

    private static func forcedSkin() -> FoodMapDomain.Skin? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-ForceSkin"), index + 1 < arguments.count else { return nil }
        return FoodMapDomain.Skin(rawValue: arguments[index + 1])
    }
}

extension FoodMapDomain.Skin {
    /// The same skin, as the design package draws it.
    ///
    /// Two enumerations rather than one because the packages are deliberately leaves: the domain
    /// decides *which* printing the day calls for, the design package owns what a printing looks
    /// like, and neither depends on the other. The name is what crosses, and this is the only
    /// place it does — a case added on one side and not the other trips the switch below.
    var rendered: FoodMapDesign.Skin {
        switch self {
        case .pandan: .pandan
        case .bay: .bay
        case .tamarind: .tamarind
        case .sim: .sim
        case .lotus: .lotus
        }
    }
}

extension Appearance {
    /// Light or dark, decided by the sun where the reader is standing rather than by the system
    /// setting (ADR-006). Someone eating at a night market at nine has the lights down whatever
    /// their phone thinks.
    var colorScheme: ColorScheme { isNight ? .dark : .light }
}
