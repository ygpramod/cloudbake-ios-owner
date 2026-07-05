import CoreGraphics
import Foundation
import Vision

protocol PurchaseBillTextRecognizing {
    func recognizedText(from image: CGImage) async throws -> String
}

final class VisionPurchaseBillTextRecognizer: PurchaseBillTextRecognizing {
    func recognizedText(from image: CGImage) async throws -> String {
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
