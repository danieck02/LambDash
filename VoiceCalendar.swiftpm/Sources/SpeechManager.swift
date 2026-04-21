import Speech
import AVFoundation
import SwiftUI

class SpeechManager: NSObject, ObservableObject, SFSpeechRecognizerDelegate {
    @Published var transcript = ""
    @Published var isRecording = false
    @Published var locale = Locale(identifier: "nl-NL") {
        didSet { recognizer = SFSpeechRecognizer(locale: locale) }
    }

    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let engine = AVAudioEngine()

    override init() {
        super.init()
        recognizer = SFSpeechRecognizer(locale: locale)
    }

    func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { _ in }
        AVAudioApplication.requestRecordPermission { _ in }
    }

    func startRecording() {
        transcript = ""
        task?.cancel()
        task = nil

        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request else { return }
        request.shouldReportPartialResults = true
        request.taskHint = .dictation

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        engine.prepare()
        try? engine.start()
        isRecording = true

        task = recognizer?.recognitionTask(with: request) { [weak self] result, _ in
            if let result {
                DispatchQueue.main.async {
                    self?.transcript = result.bestTranscription.formattedString
                }
            }
        }
    }

    func stopRecording() {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        try? AVAudioSession.sharedInstance().setActive(false)
        isRecording = false
    }
}
