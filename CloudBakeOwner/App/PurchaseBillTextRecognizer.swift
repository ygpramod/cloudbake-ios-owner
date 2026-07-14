import AVFoundation
import Combine
import CoreGraphics
import Foundation
import Speech
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

enum VoiceInventoryRecognitionError: LocalizedError, Equatable {
    case permissionDenied
    case onDeviceRecognitionUnavailable
    case audioUnavailable
    case recognitionFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Microphone and speech recognition access are required to add inventory by voice."
        case .onDeviceRecognitionUnavailable:
            "On-device speech recognition is not available for the current iPhone language."
        case .audioUnavailable:
            "The microphone could not be started."
        case .recognitionFailed:
            "Voice recognition stopped unexpectedly. Try again."
        }
    }
}

@MainActor
protocol VoiceInventorySpeechRecognizing: AnyObject {
    func requestPermission() async -> Bool
    func start(
        onTranscript: @escaping @MainActor (String) -> Void,
        onError: @escaping @MainActor (VoiceInventoryRecognitionError) -> Void
    ) throws
    func stop()
}

@MainActor
final class OnDeviceVoiceInventorySpeechRecognizer: VoiceInventorySpeechRecognizing {
    private let speechRecognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var isInputTapInstalled = false

    init(locale: Locale = .current) {
        speechRecognizer = SFSpeechRecognizer(locale: locale)
    }

    func requestPermission() async -> Bool {
        let speechAllowed: Bool = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard speechAllowed else {
            return false
        }
        return await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { allowed in
                continuation.resume(returning: allowed)
            }
        }
    }

    func start(
        onTranscript: @escaping @MainActor (String) -> Void,
        onError: @escaping @MainActor (VoiceInventoryRecognitionError) -> Void
    ) throws {
        guard let speechRecognizer, speechRecognizer.supportsOnDeviceRecognition else {
            throw VoiceInventoryRecognitionError.onDeviceRecognitionUnavailable
        }

        stop()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        self.request = request

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1_024, format: format) { buffer, _ in
                request.append(buffer)
            }
            isInputTapInstalled = true
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            stop()
            throw VoiceInventoryRecognitionError.audioUnavailable
        }

        task = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            if let result {
                Task { @MainActor in
                    guard self?.request === request else {
                        return
                    }
                    onTranscript(result.bestTranscription.formattedString)
                }
            }
            if error != nil {
                Task { @MainActor in
                    guard self?.request === request else {
                        return
                    }
                    onError(.recognitionFailed)
                }
            }
        }
    }

    func stop() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        if isInputTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            isInputTapInstalled = false
        }
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

@MainActor
final class VoiceInventoryRecognitionSession: ObservableObject {
    @Published private(set) var isListening = false
    @Published private(set) var isRequestingPermission = false
    @Published private(set) var errorMessage: String?

    private let recognizer: any VoiceInventorySpeechRecognizing
    private var startTask: Task<Void, Never>?

    init(recognizer: any VoiceInventorySpeechRecognizing) {
        self.recognizer = recognizer
    }

    func start(onTranscript: @escaping @MainActor (String) -> Void) {
        guard !isListening, !isRequestingPermission else {
            return
        }
        errorMessage = nil
        isRequestingPermission = true
        startTask = Task { [weak self] in
            guard let self else {
                return
            }
            defer {
                isRequestingPermission = false
                startTask = nil
            }
            guard await recognizer.requestPermission() else {
                guard !Task.isCancelled else {
                    return
                }
                errorMessage = VoiceInventoryRecognitionError.permissionDenied.localizedDescription
                return
            }
            guard !Task.isCancelled else {
                return
            }
            do {
                try recognizer.start(
                    onTranscript: onTranscript,
                    onError: { [weak self] error in
                        self?.stop()
                        self?.errorMessage = error.localizedDescription
                    }
                )
                isListening = true
            } catch let error as VoiceInventoryRecognitionError {
                errorMessage = error.localizedDescription
            } catch {
                errorMessage = VoiceInventoryRecognitionError.recognitionFailed.localizedDescription
            }
        }
    }

    func stop() {
        startTask?.cancel()
        startTask = nil
        isRequestingPermission = false
        recognizer.stop()
        isListening = false
    }
}
