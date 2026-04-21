import Speech
import AVFoundation
import SwiftUI

class SpeechManager: NSObject, ObservableObject, SFSpeechRecognizerDelegate {
    @Published var transcript = ""
    @Published var isRecording = false
    @Published var errorMessage = ""
    @Published var locale = Locale(identifier: "nl-NL") {
        didSet { recognizer = SFSpeechRecognizer(locale: locale) }
    }

    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let engine = AVAudioEngine()
    private var tapInstalled = false

    override init() {
        super.init()
        recognizer = SFSpeechRecognizer(locale: locale)
    }

    func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { _ in }
        AVAudioSession.sharedInstance().requestRecordPermission { _ in }
    }

    func startRecording() {
        guard !isRecording else { return }
        transcript = ""
        errorMessage = ""
        task?.cancel()
        task = nil

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            DispatchQueue.main.async { self.errorMessage = "Audio sessie mislukt: \(error.localizedDescription)" }
            return
        }

        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request else { return }
        request.shouldReportPartialResults = true
        request.taskHint = .dictation

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }
        tapInstalled = true

        engine.prepare()
        do {
            try engine.start()
        } catch {
            removeTapIfNeeded()
            DispatchQueue.main.async { self.errorMessage = "Microfoon kon niet starten: \(error.localizedDescription)" }
            return
        }

        isRecording = true

        task = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            if let result {
                DispatchQueue.main.async {
                    self?.transcript = result.bestTranscription.formattedString
                }
            }
            if let error {
                DispatchQueue.main.async {
                    self?.errorMessage = error.localizedDescription
                    self?.isRecording = false
                }
            }
        }
    }

    func stopRecording() {
        engine.stop()
        removeTapIfNeeded()
        request?.endAudio()
        task?.cancel()
        try? AVAudioSession.sharedInstance().setActive(false)
        isRecording = false
    }

    private func removeTapIfNeeded() {
        guard tapInstalled else { return }
        engine.inputNode.removeTap(onBus: 0)
        tapInstalled = false
    }
}
