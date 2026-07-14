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
    func rebaseTranscript(to transcript: String)
    func stop()
}

struct VoiceInventoryTranscriptionSegment: Equatable {
    let text: String
    let startTime: TimeInterval
    let duration: TimeInterval

    var endTime: TimeInterval {
        startTime + duration
    }
}

struct VoiceInventoryTranscriptAccumulator {
    private static let newUtterancePause: TimeInterval = 0.75

    private var baselineTranscript = ""
    private var ignoredRecognitionWords: [String] = []
    private var completedUtterances: [[VoiceInventoryTranscriptionSegment]] = []
    private var activeSegments: [VoiceInventoryTranscriptionSegment] = []

    mutating func merge(
        _ rawIncomingSegments: [VoiceInventoryTranscriptionSegment],
        isFinal: Bool = false
    ) -> String {
        let incomingSegments = segmentsAfterRebase(from: rawIncomingSegments)
        guard !incomingSegments.isEmpty else {
            return transcript
        }
        guard let updateStartTime = incomingSegments.first?.startTime else {
            return transcript
        }

        if activeSegments.isEmpty {
            activeSegments = incomingSegments
        } else if words(in: incomingSegments) == words(in: activeSegments) {
            let activeStartTime = activeSegments.first?.startTime ?? updateStartTime
            let repeatedOnResetTimeline = abs(updateStartTime - activeStartTime) >= 0.5
            if isFinal || repeatedOnResetTimeline {
                let updatedTranscript = transcript
                rebase(to: updatedTranscript)
                return updatedTranscript
            }
            return transcript
        } else if isFinal {
            activeSegments = incomingSegments
        } else if isCumulativeRevision(incomingSegments) {
            activeSegments = incomingSegments
        } else if let activeStartTime = activeSegments.first?.startTime,
                  abs(updateStartTime - activeStartTime) < 0.01 {
            activeSegments = incomingSegments
        } else if let activeStartTime = activeSegments.first?.startTime,
                  updateStartTime > activeStartTime {
            activeSegments.removeAll { segment in
                segment.endTime > updateStartTime || abs(segment.startTime - updateStartTime) < 0.01
            }
            activeSegments.append(contentsOf: incomingSegments)
        } else {
            completeActiveUtterance()
            activeSegments = incomingSegments
        }

        let updatedTranscript = transcript
        if isFinal {
            rebase(to: updatedTranscript)
        }
        return updatedTranscript
    }

    mutating func reset() {
        baselineTranscript = ""
        ignoredRecognitionWords = []
        completedUtterances = []
        activeSegments = []
    }

    mutating func rebase(to transcript: String) {
        let recognizedWords = words(in: completedUtterances.flatMap { $0 } + activeSegments)
        if !recognizedWords.isEmpty {
            ignoredRecognitionWords.append(contentsOf: recognizedWords)
        }
        baselineTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        completedUtterances = []
        activeSegments = []
    }

    private mutating func segmentsAfterRebase(
        from incomingSegments: [VoiceInventoryTranscriptionSegment]
    ) -> [VoiceInventoryTranscriptionSegment] {
        guard !ignoredRecognitionWords.isEmpty else {
            return incomingSegments
        }
        let incomingWords = words(in: incomingSegments)
        guard incomingWords.starts(with: ignoredRecognitionWords) else {
            ignoredRecognitionWords = []
            return incomingSegments
        }
        return Array(incomingSegments.dropFirst(ignoredRecognitionWords.count))
    }

    private mutating func completeActiveUtterance() {
        guard !activeSegments.isEmpty else {
            return
        }
        completedUtterances.append(activeSegments)
        activeSegments = []
    }

    private func isCumulativeRevision(
        _ incomingSegments: [VoiceInventoryTranscriptionSegment]
    ) -> Bool {
        let incomingWords = words(in: incomingSegments)
        let activeWords = words(in: activeSegments)
        return incomingWords.starts(with: activeWords) || activeWords.starts(with: incomingWords)
    }

    private func words(in segments: [VoiceInventoryTranscriptionSegment]) -> [String] {
        segments.map {
            $0.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
    }

    private var transcript: String {
        let recognizedTranscript = (completedUtterances + [activeSegments])
            .filter { !$0.isEmpty }
            .map(formattedTranscript(from:))
            .joined(separator: "\n")
        return [baselineTranscript, recognizedTranscript]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    private func formattedTranscript(
        from segments: [VoiceInventoryTranscriptionSegment]
    ) -> String {
        var result = ""
        var priorEndTime: TimeInterval?
        var priorTextWasNumeric = false
        for segment in segments {
            let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                continue
            }
            let pauseDuration = priorEndTime.map { segment.startTime - $0 }
            let textIsNumeric = text.allSatisfy(\.isNumber)
            if priorTextWasNumeric,
               textIsNumeric,
               let pauseDuration,
               pauseDuration < 0.35 {
                result += text
            } else if let pauseDuration,
                      pauseDuration >= Self.newUtterancePause {
                result += "\n\(text)"
            } else if result.isEmpty || text.first?.isPunctuation == true {
                result += text
            } else {
                result += " \(text)"
            }
            priorEndTime = segment.endTime
            priorTextWasNumeric = textIsNumeric
        }
        return result
    }
}

@MainActor
final class OnDeviceVoiceInventorySpeechRecognizer: VoiceInventorySpeechRecognizing {
    private let speechRecognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var isInputTapInstalled = false
    private var transcriptAccumulator = VoiceInventoryTranscriptAccumulator()

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
        transcriptAccumulator.reset()
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
                    let segments = result.bestTranscription.segments.map {
                        VoiceInventoryTranscriptionSegment(
                            text: $0.substring,
                            startTime: $0.timestamp,
                            duration: $0.duration
                        )
                    }
                    guard let transcript = self?.transcriptAccumulator.merge(
                        segments,
                        isFinal: result.isFinal
                    ),
                          !transcript.isEmpty else {
                        return
                    }
                    onTranscript(transcript)
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

    func rebaseTranscript(to transcript: String) {
        transcriptAccumulator.rebase(to: transcript)
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

    func start(
        baselineTranscript: String = "",
        onTranscript: @escaping @MainActor (String) -> Void
    ) {
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
                recognizer.rebaseTranscript(to: baselineTranscript)
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

    func rebaseTranscript(to transcript: String) {
        recognizer.rebaseTranscript(to: transcript)
    }
}
