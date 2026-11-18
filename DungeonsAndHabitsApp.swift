// SPDX-License-Identifier: MPL-2.0
import SwiftUI

@main
@MainActor
struct DungeonsAndHabitsApp: App {
    @State private var gameManager: GameManager

    init() {
        let api = APIService(
            baseURLProvider: { AppConfiguration.currentAPIURL },
            tokenProvider: {
                // Troque por um leitor do Keychain quando login/JWT for adicionado.
                nil
            }
        )
        _gameManager = State(
            initialValue: GameManager(repository: RemoteGameRepository(api: api))
        )
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(gameManager)
                .preferredColorScheme(.dark)
        }
    }
}
