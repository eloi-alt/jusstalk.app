// GalleryView.swift
// Cloaky
//
// Main entry screen for photo selection with modern, clean UI.

import SwiftUI
import PhotosUI
import CloudKit
import StoreKit

// MARK: - GalleryView

struct GalleryView: View {
    
    @StateObject private var viewModel = GalleryViewModel()
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var storeManager: StoreManager
    @State private var isShowingSettings = false
    @State private var trialViewModel = FreeImageTrialViewModel()
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(.systemBackground), Color.indigo.opacity(0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with settings button
                HStack {
                    Spacer()
                    
                    // Settings button
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                            .foregroundColor(.indigo)
                            .frame(width: 44, height: 44)
                            .background(Color(.systemBackground).opacity(0.8))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(String(localized: "settings", defaultValue: "Settings"))
                }
                .padding(.top, 16)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                
                // Free trial badge
                if !storeManager.isPurchased && trialViewModel.remainingImageCount >= 0 {
                    FreeTrialBadgeView(remaining: trialViewModel.remainingImageCount)
                }
                
                // Main content - centered vertically
                VStack(spacing: 40) {
                    Spacer()
                    
                    // App branding
                    headerSection
                    
                    // Action buttons
                    actionButtons
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                // Info text at the bottom
                footerInfo
                    .padding(.bottom, 8)
            }
        }
        // MARK: - Settings Sheet
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
        // MARK: - Navigation Link (always present)
        .background(
            NavigationLink(
                destination: editorDestination,
                isActive: $viewModel.isNavigatingToEditor
            ) {
                EmptyView()
            }
            .hidden()
        )
        // MARK: - Photo Picker Sheet
        .sheet(isPresented: $viewModel.isShowingPicker) {
            ImagePicker(selectedImage: $viewModel.selectedImage) { image in
                viewModel.appState = appState
                viewModel.storeManager = storeManager
                viewModel.handleSelectedImageWithTrialCheck(image)
            }
        }
        .onAppear {
            // Reset navigation state when returning to gallery
            viewModel.isNavigatingToEditor = false
        }
        .alert(isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Alert(
                title: Text(String(localized: "error", defaultValue: "Error")),
                message: Text(viewModel.errorMessage ?? ""),
                dismissButton: .default(Text(String(localized: "ok", defaultValue: "OK"))) {
                    viewModel.errorMessage = nil
                }
            )
        }
        .onAppear {
            viewModel.appState = appState
            viewModel.storeManager = storeManager
            viewModel.onTrialUpdated = { snapshot in
                trialViewModel.update(snapshot: snapshot)
            }
            Task {
                await trialViewModel.load()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSUbiquitousKeyValueStore.didChangeExternallyNotification)) { _ in
            Task {
                await trialViewModel.refresh()
            }
        }
        .fullScreenCover(isPresented: $viewModel.showPaywall) {
            PaywallView(
                storeManager: storeManager,
                appState: appState,
                context: viewModel.paywallContext,
                onPurchaseComplete: {
                    viewModel.showPaywall = false
                    Task {
                        await trialViewModel.refresh()
                    }
                }
            )
        }
    }
    
    // MARK: - Editor Destination
    
    @ViewBuilder
    private var editorDestination: some View {
        if let image = viewModel.selectedImage {
            ProcessingFlowView(
                inputImage: image,
                pipeline: appState.processingPipeline,
                onComplete: {
                    viewModel.handleNewImage()
                }
            )
        } else {
            // Fallback — should never be shown
            Text(String(localized: "loading", defaultValue: "Loading..."))
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 24) {
            // App Icon
            Image("AppLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: .indigo.opacity(0.25), radius: 20, x: 0, y: 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            
            // Tagline
            Text(String(localized: "gallery.tagline", defaultValue: "Protect Your Privacy"))
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(String(localized: "gallery.subtitle", defaultValue: "Detect and obfuscate biometric data\nin your photos before sharing"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 16) {
            // Primary: Select Photo
            Button {
                viewModel.selectPhotoFromLibrary()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title3)
                    Text(String(localized: "gallery.select.photo", defaultValue: "Select Photo"))
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        colors: [.indigo, .indigo.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(16)
                .shadow(color: .indigo.opacity(0.4), radius: 8, y: 4)
            }
            .accessibilityLabel(String(localized: "gallery.select.photo", defaultValue: "Select Photo"))
            .accessibilityHint(String(localized: "gallery.select.photo.hint", defaultValue: "Opens your photo library to select an image for protection"))
            
            // Secondary: Take Photo
            CameraButton(viewModel: viewModel)
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Footer
    
    private var footerInfo: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "lock.shield")
                    .font(.caption2)
                Text(String(localized: "gallery.footer.ondevice", defaultValue: "All processing happens on-device"))
                    .font(.caption)
            }
            .foregroundColor(.secondary)
            
            HStack(spacing: 4) {
                Image(systemName: "wifi.slash")
                    .font(.caption2)
                Text(String(localized: "gallery.footer.nodata", defaultValue: "No data leaves your phone"))
                    .font(.caption)
            }
            .foregroundColor(.secondary)
        }
    }
}
