// RecordingViewModel.swift
// Jusstalk
//
// ViewModel that handles audio recording and transcription with premium trial support.

import Foundation

@MainActor
class RecordingViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var statusText = "Tap to record"
    @Published var errorMessage: String?
    @Published var currentTranscription: Transcription?
    @Published var transcriptionComplete = false
    
    // MARK: - Paywall Properties
    
    @Published var shouldShowPaywall: Bool = false
    @Published var paywallReason: String?
    @Published var remainingTrialTranscriptions: Int = 3
    
    // MARK: - Dependencies
    
    private var storeManager: StoreManager?
    private let trialManager = FreeMinutesTrialManager.shared
    private let audioService = AudioService()
    private let transcriptionService = TranscriptionService()
    
    // MARK: - Configuration
    
    func configure(storeManager: StoreManager) {
        self.storeManager = storeManager
        Task {
            await updateRemainingTrialCount()
        }
    }
    
    // MARK: - Public Methods
    
    func toggleRecording() async {
        if isRecording {
            await stopRecording()
        } else {
            await startRecording()
        }
    }
    
    // MARK: - Private Methods
    
    private func startRecording() async {
        // Check premium + trial status BEFORE starting recording
        let isPremium = storeManager?.isPremium ?? false
        let isEligible = await checkEligibility(isPremium: isPremium)
        
        if !isEligible {
            // Trial exhausted - show paywall before recording
            shouldShowPaywall = true
            paywallReason = "trial_exhausted"
            return
        }
        
        errorMessage = nil
        let hasPermission = await audioService.requestMicrophonePermission()
        guard hasPermission else {
            errorMessage = "Microphone access required"
            return
        }

        do {
            _ = try audioService.startRecording()
            isRecording = true
            statusText = "Recording... Tap to stop"
        } catch {
            errorMessage = "Failed to start recording"
        }
    }

    private func stopRecording() async {
        isRecording = false
        statusText = "Transcribing..."
        isProcessing = true

        guard let audioURL = audioService.stopRecording() else {
            errorMessage = "Failed to save recording"
            isProcessing = false
            statusText = "Tap to record"
            return
        }

        let duration = audioService.getAudioDuration(url: audioURL)
        let isPremium = storeManager?.isPremium ?? false

        // Proceed with transcription (eligibility already checked in startRecording)
        do {
            let transcribedText = try await transcriptionService.transcribe(audioURL: audioURL)
            currentTranscription = Transcription(text: transcribedText, audioURL: audioURL, duration: duration)
            transcriptionComplete = true
            statusText = "Tap to record"
            
            // Consume trial transcription if not premium
            if !isPremium {
                _ = await trialManager.consumeTranscription(duration: duration, isPremium: isPremium)
            }
            
            // Update remaining trial count
            await updateRemainingTrialCount()
        } catch {
            errorMessage = "Transcription failed"
            statusText = "Tap to record"
        }

        isProcessing = false
        audioService.cleanupAudioFile(url: audioURL)
    }
    
    private func checkEligibility(isPremium: Bool) async -> Bool {
        if isPremium {
            return true
        }
        
        let snapshot = await trialManager.loadSnapshot()
        return snapshot.hasRemainingTranscriptions
    }
    
    private func checkTranscriptionEligibility(duration: TimeInterval, isPremium: Bool) async -> Bool {
        if isPremium {
            return true
        }
        
        let (canTranscribe, _) = await trialManager.checkAndConsumeIfEligible(
            duration: duration,
            isPremium: isPremium
        )
        
        return canTranscribe
    }
    
    private func updateRemainingTrialCount() async {
        let snapshot = await trialManager.loadSnapshot()
        remainingTrialTranscriptions = snapshot.remainingTranscriptions
    }

    func reset() {
        currentTranscription = nil
        transcriptionComplete = false
        errorMessage = nil
        statusText = "Tap to record"
    }
}
