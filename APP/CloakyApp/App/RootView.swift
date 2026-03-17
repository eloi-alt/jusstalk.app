// RootView.swift
// Cloaky
//
// Root view that manages onboarding state and redirects to the appropriate flow.

import SwiftUI

// MARK: - RootView

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var storeManager: StoreManager

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                ContentView()
            } else {
                OnboardingFlowView(
                    onFinish: {
                        hasCompletedOnboarding = true
                    },
                    onPurchaseComplete: {
                        hasCompletedOnboarding = true
                    },
                    appState: appState
                )
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
            .environmentObject(AppState())
    }
}
#endif
