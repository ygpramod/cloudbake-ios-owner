import SwiftUI
import UIKit
import VisionKit

struct DocumentCameraScannerView: UIViewControllerRepresentable {
    let onDocumentSelected: (UIImage) -> Void
    let onFailure: (Error) -> Void

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onDocumentSelected: onDocumentSelected,
            onFailure: onFailure,
            dismiss: dismiss
        )
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let onDocumentSelected: (UIImage) -> Void
        private let onFailure: (Error) -> Void
        private let dismiss: DismissAction

        init(
            onDocumentSelected: @escaping (UIImage) -> Void,
            onFailure: @escaping (Error) -> Void,
            dismiss: DismissAction
        ) {
            self.onDocumentSelected = onDocumentSelected
            self.onFailure = onFailure
            self.dismiss = dismiss
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            guard scan.pageCount > 0 else {
                dismiss()
                return
            }
            onDocumentSelected(scan.imageOfPage(at: 0))
            dismiss()
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            dismiss()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            onFailure(error)
            dismiss()
        }
    }
}
