import SwiftUI

private struct AppNavigateKey: EnvironmentKey {
    static let defaultValue: (AppDestination) -> Void = { _ in }
}

extension EnvironmentValues {
    var navigateToAppDestination: (AppDestination) -> Void {
        get { self[AppNavigateKey.self] }
        set { self[AppNavigateKey.self] = newValue }
    }
}
