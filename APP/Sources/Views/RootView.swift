// RootView.swift
// Jusstalk
//
// Root view that manages onboarding state and redirects to the appropriate flow.

import SwiftUI
import AVFoundation

// MARK: - RootView

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @EnvironmentObject var appState: JusstalkAppState
    @EnvironmentObject var storeManager: StoreManager

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                ContentView()
            } else {
                OnboardingFlowView(
                    onFinish: {
                        hasCompletedOnboarding = true
                        requestMicrophonePermission()
                    },
                    onPurchaseComplete: {
                        hasCompletedOnboarding = true
                        requestMicrophonePermission()
                    }
                )
            }
        }
        .onAppear {
            appState.storeManager = storeManager
        }
    }
    
    private func requestMicrophonePermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            #if DEBUG
            print("[RootView] Microphone permission requested: \(granted)")
            #endif
        }
    }
}

// MARK: - Preview

#if DEBUG
struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
            .environmentObject(JusstalkAppState())
            .environmentObject(StoreManager())
    }
}
#endif
