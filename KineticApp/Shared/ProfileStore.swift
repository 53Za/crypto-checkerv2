import Foundation
import KineticCore

/// Persists the user's `UserProfile` in UserDefaults.
@MainActor
final class ProfileStore: ObservableObject {
    private static let key = "kinetic.profile"

    @Published var profile: UserProfile {
        didSet { save() }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode(UserProfile.self, from: data) {
            profile = saved
        } else {
            profile = UserProfile()
        }
    }

    private let defaults: UserDefaults

    private func save() {
        if let data = try? JSONEncoder().encode(profile) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
