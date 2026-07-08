import SwiftUI
import UIKit

private struct AppNavigateKey: EnvironmentKey {
    static let defaultValue: (AppDestination) -> Void = { _ in }
}

extension EnvironmentValues {
    var navigateToAppDestination: (AppDestination) -> Void {
        get { self[AppNavigateKey.self] }
        set { self[AppNavigateKey.self] = newValue }
    }
}

struct NativeBackSwipeEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ viewController: UIViewController, context: Context) {
        DispatchQueue.main.async {
            guard let navigationController = viewController.nearestNavigationController else {
                return
            }

            navigationController.interactivePopGestureRecognizer?.isEnabled = true
            navigationController.interactivePopGestureRecognizer?.delegate = nil
        }
    }
}

private extension UIViewController {
    var nearestNavigationController: UINavigationController? {
        if let navigationController {
            return navigationController
        }

        return parent?.nearestNavigationController
    }
}
