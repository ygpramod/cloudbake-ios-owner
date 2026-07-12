import SwiftUI
import UIKit

struct ManualBackupFileExporter: UIViewControllerRepresentable {
    let fileURL: URL
    let onCompletion: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCompletion: onCompletion)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(
            forExporting: [fileURL],
            asCopy: true
        )
        controller.delegate = context.coordinator
        controller.shouldShowFileExtensions = true
        return controller
    }

    func updateUIViewController(
        _ uiViewController: UIDocumentPickerViewController,
        context: Context
    ) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let onCompletion: (Bool) -> Void

        init(onCompletion: @escaping (Bool) -> Void) {
            self.onCompletion = onCompletion
        }

        func documentPicker(
            _ controller: UIDocumentPickerViewController,
            didPickDocumentsAt urls: [URL]
        ) {
            onCompletion(!urls.isEmpty)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCompletion(false)
        }
    }
}

