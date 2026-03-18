// ContentView.swift
// Jusstalk
//
// Main content view with recording functionality and paywall integration.

import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var storeManager: StoreManager
    @StateObject private var recordingVM = RecordingViewModel()
    @State private var showSettings = false
    @State private var selectedTranscription: Transcription?
    
    @StateObject private var historyManager = TranscriptionHistoryManager.shared

    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground).ignoresSafeArea()

                VStack {
                    headerBar
                    
                    offlineQueueIndicator
                    
                    if !historyManager.transcriptions.isEmpty {
                        recentTranscriptionsSection
                    }

                    Spacer()
                    
                    offlineSavedToast

                    recordingButton

                    statusSection
                    
                    trialIndicator
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(item: $recordingVM.currentTranscription, onDismiss: {
                recordingVM.resetAfterPresentation()
            }) { transcription in
                TranscriptionView(transcription: transcription) { 
                    recordingVM.resetAfterPresentation()
                }
            }
            .sheet(isPresented: $recordingVM.shouldShowPaywall) {
                PaywallView(
                    onPurchaseComplete: {
                        recordingVM.shouldShowPaywall = false
                    },
                    paywallReason: recordingVM.paywallReason
                )
                .environmentObject(storeManager)
            }
            .onAppear {
                recordingVM.configure(storeManager: storeManager)
            }
            .sheet(item: $selectedTranscription) { transcription in
                TranscriptionView(transcription: transcription) {
                    selectedTranscription = nil
                }
            }
            .alert("Mode hors-ligne", isPresented: $recordingVM.showOfflineRecordingPrompt) {
                Button("Enregistrer pour plus tard") {
                    recordingVM.confirmOfflineRecording()
                }
                Button("Annuler", role: .cancel) {
                    recordingVM.cancelOfflineRecording()
                }
            } message: {
                Text("Pas de connexion détectée. Voulez-vous enregistrer votre vocal pour qu'il soit transcrit automatiquement lors de votre prochaine connexion ?\n\nVous pouvez sauvegarder jusqu'à 10 vocaux hors-ligne.")
            }
            .alert("Mode hors-ligne (Essai)", isPresented: $recordingVM.showOfflineRecordingPromptTrial) {
                Button("Enregistrer pour plus tard") {
                    recordingVM.confirmOfflineRecording()
                }
                Button("Annuler", role: .cancel) {
                    recordingVM.cancelOfflineRecording()
                }
            } message: {
                Text("Pas de connexion détectée. Votre enregistrement sera sauvegardé et transcrit automatiquement lors de votre prochaine connexion.\n\nCela consommera 1 de vos \(recordingVM.remainingTrialTranscriptions) essai(s) gratuit(s).")
            }
        }
    }
    
    private var headerBar: some View {
        HStack {
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }

    private var recordingButton: some View {
        Button { Task { await recordingVM.toggleRecording() } } label: {
            ZStack {
                Circle()
                    .fill(recordingVM.isRecording ? Color.red.opacity(0.2) : Color.blue.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: recordingVM.isRecording ? "stop.circle.fill" : "mic.fill")
                    .font(.system(size: 44))
                    .foregroundColor(recordingVM.isRecording ? .red : .blue)
            }
            .scaleEffect(recordingVM.isRecording ? 1.05 : 1.0)
            .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        }
        .disabled(recordingVM.isProcessing)
    }

    private var statusSection: some View {
        VStack(spacing: 8) {
            Text(recordingVM.statusText)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
            if recordingVM.isProcessing { ProgressView() }
            if let error = recordingVM.errorMessage {
                Text(error).font(.system(size: 14)).foregroundColor(.red)
            }
        }
        .padding(.bottom, 16)
    }
    
    private var trialIndicator: some View {
        Group {
            if !storeManager.isPremium {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                    Text("\(recordingVM.remainingTrialTranscriptions) transcription\(recordingVM.remainingTrialTranscriptions == 1 ? "" : "s") gratuite\(recordingVM.remainingTrialTranscriptions == 1 ? "" : "s") restante\(recordingVM.remainingTrialTranscriptions == 1 ? "" : "s")")
                        .font(.system(size: 13))
                }
                .foregroundColor(.secondary)
                .padding(.bottom, 24)
            }
        }
    }
    
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var queueManager = OfflineQueueManager.shared
    
    private var offlineQueueIndicator: some View {
        Group {
            if recordingVM.pendingRecordingsCount > 0 && !networkMonitor.isConnected {
                HStack(spacing: 6) {
                    Image(systemName: "wifi.slash")
                        .font(.caption2)
                    Text("\(recordingVM.pendingRecordingsCount) vocal(aux) en attente de connexion")
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                .foregroundColor(.orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(20)
                .padding(.bottom, 8)
            } else if queueManager.isProcessingQueue {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.7)
                    Text("Traitement des vocaux hors-ligne...")
                        .font(.caption2)
                }
                .foregroundColor(.blue)
                .padding(.bottom, 8)
            }
        }
    }
    
    private var offlineSavedToast: some View {
        Group {
            if recordingVM.showOfflineSavedToast {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.caption)
                    Text("Vocal sauvegardé — sera transcrit à la reconnexion (\(recordingVM.pendingRecordingsCount)/10)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.green)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.12))
                .cornerRadius(20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    private var recentTranscriptionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transcriptions récentes")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 24)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(historyManager.transcriptions.prefix(5)) { transcription in
                        TranscriptionCard(transcription: transcription)
                            .onTapGesture {
                                selectedTranscription = transcription
                            }
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 16)
        }
    }
}

struct TranscriptionCard: View {
    let transcription: Transcription
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(cardPreviewText(transcription.text))
                .font(.system(size: 12))
                .foregroundColor(.primary)
                .lineLimit(3)
            
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 9))
                Text(cardFormattedDate(transcription.dateCreated))
                    .font(.system(size: 10))
            }
            .foregroundColor(.secondary)
        }
        .padding(12)
        .frame(width: 160, height: 100, alignment: .topLeading)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func cardPreviewText(_ text: String) -> String {
        let maxLength = 80
        if text.count <= maxLength {
            return text
        }
        return String(text.prefix(maxLength)) + "..."
    }
    
    private func cardFormattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
