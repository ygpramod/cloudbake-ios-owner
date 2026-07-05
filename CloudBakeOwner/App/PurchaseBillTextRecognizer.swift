import CoreGraphics
import Foundation
import Vision

protocol DocumentTextRecognizing {
    func recognizedText(from image: CGImage) async throws -> String
}

final class VisionDocumentTextRecognizer: DocumentTextRecognizing {
    func recognizedText(from image: CGImage) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            try await Self.recognizedTextOffMainThread(from: image)
        }.value
    }

    private static func recognizedTextOffMainThread(from image: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: PurchaseBillTextRecognitionError.unreadableResult)
                    return
                }

                let recognizedLines = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }

                continuation.resume(returning: recognizedLines.joined(separator: "\n"))
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            do {
                try VNImageRequestHandler(cgImage: image).perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

enum PurchaseBillTextRecognitionError: Error, Equatable {
    case unreadableResult
}

typealias PurchaseBillTextRecognizing = DocumentTextRecognizing
typealias RecipeTextRecognizing = DocumentTextRecognizing
typealias VisionPurchaseBillTextRecognizer = VisionDocumentTextRecognizer
typealias VisionRecipeTextRecognizer = VisionDocumentTextRecognizer
