// ContentView.swift
// Cloaky
//
// Root content view with NavigationView managing the full app flow.

import SwiftUI
import CloudKit
import StoreKit

// MARK: - ContentView

struct ContentView: View {
    
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var storeManager: StoreManager
    
    var body: some View {
        NavigationView {
            GalleryView()
        }
        .navigationViewStyle(.stack)
        .accentColor(.indigo)
    }
}

// MARK: - Preview

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppState())
    }
}
#endif
