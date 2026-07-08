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
            guard let navigationController = viewController.nearestNavigationController()
                ?? viewController.view.window?.rootViewController?.firstNavigationController()
            else {
                return
            }

            navigationController.interactivePopGestureRecognizer?.isEnabled = true
            navigationController.interactivePopGestureRecognizer?.delegate = nil
        }
    }
}

private extension UIViewController {
    func nearestNavigationController() -> UINavigationController? {
        if let navigationController {
            return navigationController
        }

        return parent?.nearestNavigationController()
    }

    func firstNavigationController() -> UINavigationController? {
        if let navigationController = self as? UINavigationController {
            return navigationController
        }

        for child in children {
            if let navigationController = child.firstNavigationController() {
                return navigationController
            }
        }

        if let presentedViewController,
           let navigationController = presentedViewController.firstNavigationController() {
            return navigationController
        }

        return nil
    }
}
