import SwiftUI
import Observation
import FoodMapDomain
import FoodMapDesign

/// Which printing the app is in, and when it changes (ADR-006).
///
/// The decision itself is `ChooseAppearanceUseCase`, and is unit-tested. This only gathers what
/// that rule needs — where the reader is, what the sky is doing there — and hands the answer to
/// the interface. Weather is decoration: nothing here reports a failure, because a missed forecast
/// simply means the day's rotation decides instead.
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
    /// Set by `-ForceEffect <name>`. The sky the reader is standing under is not something a test
    /// can arrange, and the window is now the only place the weather appears at all — so it needs
    /// the same door the skins have, or three of the four skies could never be reviewed.
    private let forcedEffect: SkyEffect?
    /// Set by `-ForceNight`. Since the appearance follows the sun rather than the system setting,
    /// flipping the simulator to dark no longer reaches the app, and the night market would only
    /// be photographable after sunset.
    private let forcedNight: Bool

    init(weather: WeatherPort, location: any LocationPort, clock: ClockPort) {
        self.weather = weather
        self.location = location
        self.clock = clock
        self.forcedSkin = Self.forcedSkin()
        self.forcedEffect = Self.forcedEffect()
        self.forcedNight = ProcessInfo.processInfo.arguments.contains("-ForceNight")
        // Start on the day's rotation so the first frame is already printed correctly; the sky,
        // which needs a fix and a network round trip, refines it a moment later.
        let opening = ChooseAppearanceUseCase().execute(weather: nil, on: clock.now)
        self.appearance = Self.forcing(
            skin: self.forcedSkin,
            effect: self.forcedEffect,
            night: self.forcedNight,
            on: opening
        )
        apply()
    }

    /// Ask the sky again. Called when the app comes to the front: between two sessions it can have
    /// started raining, or got dark, and the app should have noticed.
    func refresh() async {
        guard forcedSkin == nil, forcedEffect == nil, !forcedNight else { return }
        let snapshot = await currentSky()
        let next = choose.execute(weather: snapshot, on: clock.now)
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

    private static func forcing(
        skin: FoodMapDomain.Skin?,
        effect: SkyEffect?,
        night: Bool,
        on appearance: Appearance
    ) -> Appearance {
        Appearance(
            skin: skin ?? appearance.skin,
            // A forced night gets the night's effect too, or the sweep would photograph a dark
            // market under a midday sun — unless the sky was named outright, which wins.
            effect: effect ?? (night ? .lanterns : appearance.effect),
            isNight: night || appearance.isNight
        )
    }

    private static func forcedEffect() -> SkyEffect? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-ForceEffect"), index + 1 < arguments.count else { return nil }
        return SkyEffect(rawValue: arguments[index + 1])
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
