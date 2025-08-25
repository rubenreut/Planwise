import Foundation
import SwiftUI
import Speech
import AVFoundation
import Combine

/// Handles all voice recording and speech recognition functionality
@MainActor
class VoiceRecordingViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var isRecording: Bool = false
    @Published var transcribedText: String = ""
    @Published var recordingError: String?
    @Published var isProcessing: Bool = false
    
    // MARK: - Audio Properties
    
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
    
    // MARK: - Initialization
    
    init() {
        setupAudioSession()
    }
    
    // MARK: - Public Methods
    
    func startRecording() async {
        guard !isRecording else { return }
        
        // Reset state
        transcribedText = ""
        recordingError = nil
        isProcessing = true
        
        // Request permissions
        let authorized = await requestSpeechRecognitionPermission()
        guard authorized else {
            recordingError = "Speech recognition permission denied"
            isProcessing = false
            return
        }
        
        // Start recognition
        do {
            try await startVoiceRecognition()
            isRecording = true
            isProcessing = false
        } catch {
            recordingError = "Failed to start recording: \(error.localizedDescription)"
            isProcessing = false
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        // Stop audio engine
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        
        // End recognition
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        // Clean up
        recognitionRequest = nil
        recognitionTask = nil
        audioEngine = nil
        
        isRecording = false
    }
    
    func toggleRecording() async {
        if isRecording {
            stopRecording()
        } else {
            await startRecording()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    private func requestSpeechRecognitionPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { authStatus in
                continuation.resume(returning: authStatus == .authorized)
            }
        }
    }
    
    private func startVoiceRecognition() async throws {
        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // Create and configure request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw VoiceRecordingError.requestCreationFailed
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false
        
        // Setup audio engine
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw VoiceRecordingError.audioEngineCreationFailed
        }
        
        let inputNode = audioEngine.inputNode
        
        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                _Concurrency.Task { @MainActor in
                    self.transcribedText = result.bestTranscription.formattedString
                }
            }
            
            if error != nil || result?.isFinal == true {
                // Clean up but don't call stopRecording (would cause recursion)
                _Concurrency.Task { @MainActor in
                    self.audioEngine?.stop()
                    self.audioEngine?.inputNode.removeTap(onBus: 0)
                    self.recognitionRequest?.endAudio()
                    self.recognitionTask?.cancel()
                    self.recognitionRequest = nil
                    self.recognitionTask = nil
                    self.audioEngine = nil
                    self.isRecording = false
                }
            }
        }
        
        // Configure audio format and tap
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    // MARK: - Cleanup
    
    deinit {
        // Clean up resources
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
    }
}

// MARK: - Error Types

enum VoiceRecordingError: LocalizedError {
    case requestCreationFailed
    case audioEngineCreationFailed
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .requestCreationFailed:
            return "Failed to create speech recognition request"
        case .audioEngineCreationFailed:
            return "Failed to create audio engine"
        case .permissionDenied:
            return "Microphone permission denied"
        }
    }
}