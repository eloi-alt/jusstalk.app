// GalleryViewModel.swift
// Cloaky
//
// ViewModel for the gallery/photo selection screen.

import Foundation
import UIKit
import Photos
import Combine
import AVFoundation

// MARK: - GalleryViewModel

@MainActor
final class GalleryViewModel: ObservableObject {
    
    // MARK: - Published State
    
    @Published var selectedImage: UIImage?
    @Published var isShowingPicker: Bool = false
    @Published var isShowingCamera: Bool = false
    @Published var hasPhotoPermission: Bool = false
    @Published var errorMessage: String?
    @Published var isNavigatingToEditor: Bool = false
    
    // Trial-related state
    @Published var showPaywall: Bool = false
    @Published var paywallContext: PaywallContext = .manualUpgrade
    
    // Prevent double-tap issues
    private var isHandlingImageSelection: Bool = false
    
    // Reference to AppState for premium check (injected from view)
    weak var appState: AppState?
    
    // Reference to StoreManager for premium check (injected from view)
    weak var storeManager: StoreManager?
    
    // Computed premium status from StoreManager (or appState fallback)
    var isPremium: Bool {
        storeManager?.isPurchased ?? appState?.isPremium ?? false
    }
    
    // Callback for when editing is complete
    var onEditingComplete: (() -> Void)?
    
    // Callback to update trial view model
    var onTrialUpdated: ((FreeImageTrialSnapshot) -> Void)?
    
    // MARK: - Init
    
    init() {}
    
    // MARK: - Photo Library Access
    
    /// Request photo library access permission
    func requestPhotoPermission() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        switch status {
        case .authorized, .limited:
            hasPhotoPermission = true
        case .notDetermined:
            Task {
                let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
                hasPhotoPermission = (newStatus == .authorized || newStatus == .limited)
            }
        case .denied, .restricted:
            hasPhotoPermission = false
            errorMessage = String(localized: "error.photo.access.denied.settings", defaultValue: "Photo access denied. Please enable in Settings.")
        @unknown default:
            break
        }
    }
    
    // MARK: - Image Selection
    
    /// Open the photo picker
    func selectPhotoFromLibrary() {
        requestPhotoPermission()
        isShowingPicker = true
    }
    
    /// UNIQUE ENTRY POINT: Handle image selected from picker or camera
    /// This is the ONLY place where trial logic should be triggered
    func handleSelectedImageWithTrialCheck(_ image: UIImage?) {
        guard !isHandlingImageSelection else { return }
        guard let image = image else { return }
        
        isHandlingImageSelection = true
        
        Task {
            await processImageSelectionWithTrial(image: image)
        }
    }
    
    /// Process image selection with trial check
    private func processImageSelectionWithTrial(image: UIImage) async {
        let decision = await ImageAccessCoordinator.shared.beginAccessForNewSelectedImage(isPremium: isPremium)
        
        switch decision {
        case .requirePaywall(let snapshot):
            onTrialUpdated?(snapshot)
            paywallContext = .trialExhausted
            showPaywall = true
            isHandlingImageSelection = false
            
        case .allow(let snapshot, _):
            onTrialUpdated?(snapshot)
            selectedImage = image
            
            do {
                try await Task.sleep(nanoseconds: 100_000_000)
            } catch {}
            
            isNavigatingToEditor = true
            await ImageAccessCoordinator.shared.clearReservationFlagAfterSuccessfulEditorEntry()
            isHandlingImageSelection = false
        }
    }
    
    /// Handle image load failure - rollback if needed
    func handleImageLoadFailure() {
        Task {
            let rolledBack = await ImageAccessCoordinator.shared.rollbackIfImageLoadFailed()
            onTrialUpdated?(rolledBack)
        }
    }
    
    /// Open camera
    func takePhoto() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            errorMessage = String(localized: "error.camera.unavailable", defaultValue: "Camera is not available on this device.")
            return
        }
        
        // Check and request camera permission explicitly to prevent black screen issue
        let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
        switch authStatus {
        case .authorized:
            isShowingCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.isShowingCamera = true
                    } else {
                        self.errorMessage = String(localized: "error.camera.denied", defaultValue: "Camera access is required to take photos.")
                    }
                }
            }
        case .denied, .restricted:
            errorMessage = String(localized: "error.camera.denied", defaultValue: "Camera access is denied. Please enable it in Settings.")
        @unknown default:
            break
        }
    }
    
    /// Reset state for new selection
    func reset() {
        selectedImage = nil
        isNavigatingToEditor = false
        errorMessage = nil
    }
    
    /// Called when user finishes editing and wants to select a new image
    func handleNewImage() {
        reset()
        onEditingComplete?()
    }
}
