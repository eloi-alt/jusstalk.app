// RecordingViewModel.swift
// Jusstalk
//
// ViewModel that handles audio recording and transcription with atomic trial consumption.

import Foundation
import SwiftUI

@MainActor
class RecordingViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var statusText = "Tap to record"
    @Published var errorMessage: String?
    @Published var currentTranscription: Transcription?
    
    // MARK: - Paywall Properties
    
    @Published var shouldShowPaywall: Bool = false
    @Published var paywallReason: String?
    @Published var remainingTrialTranscriptions: Int = 3
    
    // MARK: - Dependencies
    
    private var storeManager: StoreManager?
    private let trialManager = FreeTrialManager.shared
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
        guard !isProcessing else { return }
        
        if isRecording {
            await stopRecording()
        } else {
            await startRecording()
        }
    }
    
    func resetAfterPresentation() {
        currentTranscription = nil
        errorMessage = nil
        statusText = "Tap to record"
    }
    
    // MARK: - Private Methods
    
    private func startRecording() async {
        currentTranscription = nil
        errorMessage = nil
        
        let isPremium = storeManager?.isPremium ?? false
        let isEligible = await checkEligibility(isPremium: isPremium)
        
        if !isEligible {
            shouldShowPaywall = true
            paywallReason = "trial_exhausted"
            return
        }
        
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
        guard !isProcessing else { return }
        
        isRecording = false
        isProcessing = true
        statusText = "Transcribing..."
        errorMessage = nil

        guard let audioURL = audioService.stopRecording() else {
            currentTranscription = nil
            errorMessage = "Failed to save recording"
            isProcessing = false
            statusText = "Tap to record"
            return
        }

        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            currentTranscription = nil
            errorMessage = "Recording file not found"
            isProcessing = false
            statusText = "Tap to record"
            return
        }

        let duration = audioService.getAudioDuration(url: audioURL)
        
        guard duration > 0 else {
            currentTranscription = nil
            errorMessage = "Recording is empty"
            audioService.cleanupAudioFile(url: audioURL)
            isProcessing = false
            statusText = "Tap to record"
            return
        }
        
        let isPremium = storeManager?.isPremium ?? false

        await performTranscriptionWithTrialManagement(
            audioURL: audioURL,
            duration: duration,
            isPremium: isPremium
        )

        audioService.cleanupAudioFile(url: audioURL)
    }
    
    private func performTranscriptionWithTrialManagement(
        audioURL: URL,
        duration: TimeInterval,
        isPremium: Bool
    ) async {
        if isPremium {
            await transcribeAndSave(audioURL: audioURL, duration: duration, isPremium: true, reservation: nil as TrialReservation?)
            return
        }

        let reservationResult = await trialManager.reserveTrialIfEligible(isPremium: isPremium)

        switch reservationResult {
        case .premium:
            await transcribeAndSave(audioURL: audioURL, duration: duration, isPremium: true, reservation: nil as TrialReservation?)

        case .denied:
            await transcribeAndSave(audioURL: audioURL, duration: duration, isPremium: false, reservation: nil as TrialReservation?)
            shouldShowPaywall = true
            paywallReason = "trial_exhausted"

        case .reserved(let reservation, _):
            do {
                let transcribedText = try await transcriptionService.transcribe(audioURL: audioURL)
                let trimmedText = transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)

                if trimmedText.isEmpty {
                    _ = await trialManager.rollbackTrialReservation(reservation.id)
                    currentTranscription = nil
                    errorMessage = "Transcription vide, aucun essai consommé"
                    statusText = "Tap to record"
                    isProcessing = false
                    return
                }

                _ = await trialManager.commitTrialReservation(reservation.id)

                currentTranscription = Transcription(text: trimmedText, audioURL: audioURL, duration: duration)
                statusText = "Tap to record"

                await updateRemainingTrialCount()

            } catch {
                _ = await trialManager.rollbackTrialReservation(reservation.id)
                currentTranscription = nil
                errorMessage = "Transcription failed: \(error.localizedDescription)"
                statusText = "Tap to record"
            }

            isProcessing = false
        }
    }
    
    private func transcribeAndSave(
        audioURL: URL,
        duration: TimeInterval,
        isPremium: Bool,
        reservation: TrialReservation?
    ) async {
        do {
            let transcribedText = try await transcriptionService.transcribe(audioURL: audioURL)
            let trimmedText = transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmedText.isEmpty {
                if let reservation = reservation {
                    _ = await trialManager.rollbackTrialReservation(reservation.id)
                }
                currentTranscription = nil
                errorMessage = "Transcription vide"
                statusText = "Tap to record"
                isProcessing = false
                return
            }

            currentTranscription = Transcription(text: trimmedText, audioURL: audioURL, duration: duration)
            statusText = "Tap to record"

            if !isPremium {
                await updateRemainingTrialCount()
            }

        } catch {
            if let reservation = reservation {
                _ = await trialManager.rollbackTrialReservation(reservation.id)
            }
            currentTranscription = nil
            errorMessage = "Transcription failed: \(error.localizedDescription)"
            statusText = "Tap to record"
        }

        isProcessing = false
    }
    
    private func checkEligibility(isPremium: Bool) async -> Bool {
        if isPremium {
            return true
        }
        
        let snapshot = await trialManager.loadSnapshot()
        return snapshot.hasRemainingTranscriptions
    }
    
    private func updateRemainingTrialCount() async {
        let snapshot = await trialManager.loadSnapshot()
        remainingTrialTranscriptions = snapshot.remainingTranscriptions
    }
}
