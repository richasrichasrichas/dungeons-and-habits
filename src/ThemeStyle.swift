// SPDX-License-Identifier: MPL-2.0
import SwiftUI

enum AppConfiguration {
    static let apiURLDefaultsKey = "dah.apiBaseURL"
    static let userIDDefaultsKey = "dah.userID"
    static let defaultAPIURLString = "http://localhost:8080"

    static var currentAPIURL: URL? {
        let configured = UserDefaults.standard.string(forKey: apiURLDefaultsKey)
            ?? (Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String)
            ?? defaultAPIURLString
        return URL(string: configured.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    static var currentUserID: UUID? {
        let configured = UserDefaults.standard.string(forKey: userIDDefaultsKey)
            ?? (Bundle.main.object(forInfoDictionaryKey: "DUNGEONS_USER_ID") as? String)
        guard let configured else { return nil }
        return UUID(uuidString: configured)
    }
}

enum AppTheme {
    static let background = Color(red: 0.055, green: 0.063, blue: 0.090)
    static let surface = Color(red: 0.105, green: 0.118, blue: 0.157)
    static let accent = Color(red: 0.45, green: 0.82, blue: 0.71)
    static let secondaryText = Color.white.opacity(0.68)
}
