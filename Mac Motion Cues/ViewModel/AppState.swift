import Foundation

@Observable
final class AppState {
    static let shared = AppState()

    var appEnabled: Bool {
        didSet { defaults.set(appEnabled, forKey: Keys.appEnabled) }
    }

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let appEnabled = "appEnabled"
    }

    private init() {
        defaults.register(defaults: [Keys.appEnabled: true])
        appEnabled = defaults.bool(forKey: Keys.appEnabled)
    }
}
