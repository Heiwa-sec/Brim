import Foundation

/// Disables the lock-screen card when it may have crashed the app while showing. The flag is set while the card is
/// on screen; a launch that finds it still set means the last run died there. Two such launches in a row trip the switch.
struct KillSwitch {
    static let maxCrashes = 2
    private static let openKey = "lockscreen.sessionOpen"
    private static let crashKey = "lockscreen.crashes"

    let defaults: UserDefaults
    let arguments: [String]

    init(defaults: UserDefaults = .standard, arguments: [String] = CommandLine.arguments) {
        self.defaults = defaults
        self.arguments = arguments
    }

    var tripped: Bool { arguments.contains("--disable-lockscreen") || defaults.integer(forKey: Self.crashKey) >= Self.maxCrashes }

    /// Call once per launch, before anything can show the card.
    func recordLaunch() {
        defaults.set(defaults.bool(forKey: Self.openKey) ? defaults.integer(forKey: Self.crashKey) + 1 : 0, forKey: Self.crashKey)
        defaults.set(false, forKey: Self.openKey)
    }

    func cardShown() { defaults.set(true, forKey: Self.openKey) }
    func cardHidden() { defaults.set(false, forKey: Self.openKey) }

    /// Called when the user switches the feature back on.
    func reset() { defaults.set(0, forKey: Self.crashKey) }
}
