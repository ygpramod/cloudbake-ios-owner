import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum SettingsFileExportResult: Equatable {
    case exported
    case cancelled
}

struct SettingsFileExporter: UIViewControllerRepresentable {
    static let accessibilityIdentifier = "settings.fileExporter"

    let fileURL: URL
    let onCompletion: (SettingsFileExportResult) -> Void

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
        controller.view.accessibilityIdentifier = Self.accessibilityIdentifier
        return controller
    }

    func updateUIViewController(
        _ uiViewController: UIDocumentPickerViewController,
        context: Context
    ) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let onCompletion: (SettingsFileExportResult) -> Void

        init(onCompletion: @escaping (SettingsFileExportResult) -> Void) {
            self.onCompletion = onCompletion
        }

        func documentPicker(
            _ controller: UIDocumentPickerViewController,
            didPickDocumentsAt urls: [URL]
        ) {
            onCompletion(urls.isEmpty ? .cancelled : .exported)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCompletion(.cancelled)
        }
    }
}

struct SettingsFileImporter: UIViewControllerRepresentable {
    static let accessibilityIdentifier = "settings.fileImporter"

    let allowedContentTypes: [UTType]
    let onCompletion: (URL?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCompletion: onCompletion)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(
            forOpeningContentTypes: allowedContentTypes,
            asCopy: true
        )
        controller.delegate = context.coordinator
        controller.allowsMultipleSelection = false
        controller.shouldShowFileExtensions = true
        controller.view.accessibilityIdentifier = Self.accessibilityIdentifier
        return controller
    }

    func updateUIViewController(
        _ uiViewController: UIDocumentPickerViewController,
        context: Context
    ) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let onCompletion: (URL?) -> Void

        init(onCompletion: @escaping (URL?) -> Void) {
            self.onCompletion = onCompletion
        }

        func documentPicker(
            _ controller: UIDocumentPickerViewController,
            didPickDocumentsAt urls: [URL]
        ) {
            onCompletion(urls.first)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCompletion(nil)
        }
    }
}
