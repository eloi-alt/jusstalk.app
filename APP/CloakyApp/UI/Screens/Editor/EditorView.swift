// EditorView.swift
// Cloaky
//
// Editor screen with two modes:
// - Auto Detect: automatic biometric detection with region selection
// - Manual Brush: paint-to-blur with adjustable brush size

import SwiftUI
import Photos
import CloudKit

// MARK: - EditorView

struct EditorView: View {
    
    let inputImage: UIImage
    let pipeline: ProcessingPipeline
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var storeManager: StoreManager
    @StateObject private var viewModel: EditorViewModel
    @State private var isNavigatingToProcessing = false
    @State private var canvasDisplaySize: CGSize = .zero
    
    // MARK: - Process Target State
    
    /// Whether the process target popup is visible
    @State private var showProcessPopup = false
    /// The chosen process target (set when user picks from popup)
    @State private var selectedProcessTarget: ProcessTarget = .all
    
    // MARK: - Processing & Result State
    
    @State private var isProcessing = false
    @State private var processedImage: UIImage?
    @State private var showResult = false
    
    // MARK: - Before/After State
    
    @State private var comparisonSplitRatio: Double = 0.5
    @State private var processingError: Error?
    
    // MARK: - Save Confirmation State
    
    @State private var showSaveConfirmation = false
    @State private var saveConfirmationMessage = ""
    
    // MARK: - Zoom / Pan State
    
    /// Whether the zoom/pan inspection mode is active (disables brushes & region taps)
    @State private var isZoomMode: Bool = false
    /// Committed zoom scale (persisted across gestures)
    @State private var zoomScale: CGFloat = 1.0
    /// Committed pan offset (persisted across gestures)
    @State private var panOffset: CGSize = .zero
    /// Transient scale factor while a pinch gesture is in progress
    @State private var livePinchScale: CGFloat = 1.0
    /// Transient drag offset while a drag gesture is in progress
    @State private var liveDragOffset: CGSize = .zero
    
    // MARK: - Paywall State
    
    @State private var showPaywall = false
    
    init(inputImage: UIImage, pipeline: ProcessingPipeline) {
        // Normalize the image (flatten orientation to .up, scale to 1.0)
        // so pixel coordinates are consistent and no rotation ever occurs.
        self.inputImage = inputImage.normalized()
        self.pipeline = pipeline
        self._viewModel = StateObject(wrappedValue: EditorViewModel(pipeline: pipeline))
    }
    
    var body: some View {
        ZStack {
            if showResult, let result = processedImage {
                // Vue résultat final
                resultView(result)
            } else {
                // Vue éditeur
                VStack(spacing: 0) {
                    // Mode picker (Auto Detect / Manual Brush)
                    modePicker
                    
                    // Image canvas
                    imageCanvas
                    
                    // Context-dependent bottom section
                    bottomSection
                }
                .overlay {
                    if isProcessing {
                        processingOverlay
                    }
                }
            }
            
            // Popup de choix de téléchargement (depuis le bas)
            if showProcessPopup {
                processTargetPopup
                    .transition(.move(edge: .bottom))
                    .zIndex(100)
            }
            
            // Confirmation visuelle de sauvegarde
            if showSaveConfirmation {
                saveConfirmationToast
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(200)
            }
        }
        .navigationTitle(showResult ? String(localized: "editor.result.title", defaultValue: "Result") : String(localized: "editor.title", defaultValue: "Editor"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !showResult {
                    HStack(spacing: 16) {
                        // Existing menu
                        Menu {
                            if viewModel.editorMode == .biometrics || viewModel.editorMode == .text {
                                Button(String(localized: "editor.redetect", defaultValue: "Re-detect")) {
                                    viewModel.startDetection()
                                }
                            } else {
                                Button(role: .destructive) {
                                    viewModel.clearBrushStrokes()
                                } label: {
                                    Label(String(localized: "editor.clear.all", defaultValue: "Effacer tout"), systemImage: "trash")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadImage(inputImage)
            isNavigatingToProcessing = false
        }
        .onDisappear {
            viewModel.cleanup()
        }
        .onChange(of: viewModel.editorMode) { _ in
            viewModel.startDetection()
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(
                storeManager: storeManager,
                appState: appState,
                context: .trialExhausted,
                onPurchaseComplete: {
                    showPaywall = false
                }
            )
        }
        // NavigationLink caché pour le traitement "Strip Metadata"
        .background(
            NavigationLink(
                destination: processingDestination,
                isActive: $isNavigatingToProcessing
            ) {
                EmptyView()
            }
            .hidden()
        )
    }
    
    // MARK: - Processing Overlay
    
    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text(String(localized: "editor.processing", defaultValue: "Traitement en cours..."))
                    .font(.headline)
                    .foregroundColor(.white)
            }
        }
    }
    
    // MARK: - Share Sheet State
    
    @State private var showShareSheet = false
    
    // MARK: - Result View
    
    private func resultView(_ image: UIImage) -> some View {
        VStack(spacing: 0) {
            // Mode Avant/Après avec slider
            BeforeAfterSlider(
                beforeImage: inputImage,
                afterImage: image,
                sliderPosition: $comparisonSplitRatio
            )
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            Spacer()
            
            // Message de succès
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.green)
                
                Text(String(localized: "editor.share.image.saved", defaultValue: "Image téléchargée avec succès"))
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.green.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            
            // Boutons d'action
            VStack(spacing: 12) {
                // Bouton partager
                Button {
                    showShareSheet = true
                } label: {
                    HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text(String(localized: "editor.share", defaultValue: "Partager"))
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.indigo)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .sheet(isPresented: $showShareSheet) {
                    ShareSheet(activityItems: [image])
                }
                
                // Bouton nouvelle image
                Button {
                    resetAndNewImage()
                } label: {
                    HStack(spacing: 8) {
                    Image(systemName: "plus.circle")
                    Text(String(localized: "editor.new.image", defaultValue: "Nouvelle image"))
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(.tertiarySystemBackground))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .background(Color(.systemBackground))
            .shadow(color: .black.opacity(0.05), radius: 5, y: -2)
        }
    }
    
    private func saveImageToPhotos(_ image: UIImage) async {
        // Utiliser le même système que PreviewViewModel
        let viewModel = PreviewViewModel()
        viewModel.processedImage = image
        await viewModel.saveToPhotos()
        
        // Feedback haptique de succès
        await MainActor.run {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            // Afficher la confirmation visuelle
            saveConfirmationMessage = String(localized: "editor.image.saved.photos", defaultValue: "Image sauvegardée dans Photos")
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showSaveConfirmation = true
            }
            
            // Masquer la confirmation après 2 secondes
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(.easeOut(duration: 0.3)) {
                    showSaveConfirmation = false
                }
            }
        }
    }
    
    private func resetAndNewImage() {
        // Retourner à l'écran d'accueil
        dismiss()
    }
    
    // MARK: - Save Confirmation Toast
    
    private var saveConfirmationToast: some View {
        VStack {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.green)
                
                Text(saveConfirmationMessage)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Color(.systemBackground)
                    .opacity(0.95)
            )
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
            )
            
            Spacer()
        }
        .padding(.top, 8)
        .padding(.horizontal, 16)
    }
    
    // MARK: - Mode Picker
    
    private var modePicker: some View {
        HStack(spacing: 4) {
            ForEach(EditorMode.allCases, id: \.rawValue) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        viewModel.editorMode = mode
                        showProcessPopup = false
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: mode.iconName)
                            .font(.caption2)
                        Text(mode.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        viewModel.editorMode == mode
                        ? Color.indigo
                        : Color.clear
                    )
                    .foregroundColor(
                        viewModel.editorMode == mode ? .white : .primary
                    )
                    .cornerRadius(8)
                }
            }
        }
        .padding(4)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    // MARK: - Processing Destination
    
    @ViewBuilder
    private var processingDestination: some View {
        if let image = viewModel.originalImage {
            // Send regions + brush strokes based on the user's chosen ProcessTarget
            ProcessingView(
                image: image,
                regions: viewModel.regionsForTarget(selectedProcessTarget),
                brushStrokes: viewModel.brushStrokesForTarget(selectedProcessTarget),
                brushIntensity: viewModel.brushSettings.blurIntensity,
                canvasDisplaySize: canvasDisplaySize,
                method: viewModel.selectedMethod,
                settings: viewModel.obfuscationSettings,
                pipeline: pipeline
            )
        } else {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                ProgressView()
            }
        }
   }
    
    // MARK: - Computed zoom transform values
    
    private var effectiveScale: CGFloat {
        zoomScale * livePinchScale
    }
    
    private var effectiveOffset: CGSize {
        CGSize(
            width: panOffset.width + liveDragOffset.width,
            height: panOffset.height + liveDragOffset.height
        )
    }
    
    // MARK: - Image Canvas
    
    private var imageCanvas: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                
                // Zoomable / pannable content
                Group {
                    if viewModel.editorMode == .biometrics || viewModel.editorMode == .text {
                        ZStack {
                            Image(uiImage: inputImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .overlay(
                                    GeometryReader { imgGeo in
                                        Color.clear.onAppear {
                                            // Calculate actual display size (aspect-fitted image size)
                                            let imageSize = inputImage.size
                                            let containerSize = imgGeo.size
                                            let imageAspect = imageSize.width / imageSize.height
                                            let containerAspect = containerSize.width / containerSize.height
                                            
                                            let displaySize: CGSize
                                            if imageAspect > containerAspect {
                                                displaySize = CGSize(width: containerSize.width, height: containerSize.width / imageAspect)
                                            } else {
                                                displaySize = CGSize(width: containerSize.height * imageAspect, height: containerSize.height)
                                            }
                                            
                                            // Note: canvasDisplaySize is now managed exclusively by BrushCanvasView
                                            // when in manual brush mode. We don't set it here to avoid conflicts.
                                            // The brush strokes use normalized UV coordinates (0.0-1.0) which are
                                            // independent of display size, ensuring pixel-perfect export.
                                        }
                                        .onChange(of: imgGeo.size) { newSize in
                                            // Calculate actual display size for reference only
                                            // canvasDisplaySize is managed by BrushCanvasView
                                            let imageSize = inputImage.size
                                            let containerSize = newSize
                                            let imageAspect = imageSize.width / imageSize.height
                                            let containerAspect = containerSize.width / containerSize.height
                                            
                                            let _: CGSize
                                            if imageAspect > containerAspect {
                                                _ = CGSize(width: containerSize.width, height: containerSize.width / imageAspect)
                                            } else {
                                                _ = CGSize(width: containerSize.height * imageAspect, height: containerSize.height)
                                            }
                                        }
                                    }
                                )
                            
                            // Detection overlays (only interactive when NOT in zoom mode)
                            autoDetectOverlays
                                .allowsHitTesting(!isZoomMode)
                        }
                    } else {
                        manualBrushOverlay(geometry: geometry)
                            .allowsHitTesting(!isZoomMode)
                    }
                }
                .scaleEffect(effectiveScale)
                .offset(effectiveOffset)
                
                // Zoom / pan gestures (only when zoom mode is active)
                if isZoomMode {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(zoomPanGesture)
                }
                
                // Zoom toggle button (floating, bottom-right of canvas)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        zoomToggleButton
                    }
                }
                .padding(12)
            }
        }
        .frame(maxHeight: .infinity)
        .clipped()
    }
    
    // MARK: - Zoom / Pan Gesture
    
    private var zoomPanGesture: some Gesture {
        // Simultaneous pinch + drag
        SimultaneousGesture(
            MagnificationGesture()
                .onChanged { value in
                    livePinchScale = value
                }
                .onEnded { value in
                    zoomScale = clampedZoom(zoomScale * value)
                    livePinchScale = 1.0
                },
            DragGesture()
                .onChanged { value in
                    liveDragOffset = value.translation
                }
                .onEnded { value in
                    panOffset = CGSize(
                        width: panOffset.width + value.translation.width,
                        height: panOffset.height + value.translation.height
                    )
                    liveDragOffset = .zero
                }
        )
    }
    
    /// Clamp zoom level between 1× and 10×
    private func clampedZoom(_ scale: CGFloat) -> CGFloat {
        min(max(scale, 1.0), 10.0)
    }
    
    // MARK: - Zoom Toggle Button
    
    private var zoomToggleButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isZoomMode.toggle()
                
                // When leaving zoom mode, reset zoom/pan back to default
                if !isZoomMode {
                    zoomScale = 1.0
                    panOffset = .zero
                    livePinchScale = 1.0
                    liveDragOffset = .zero
                }
            }
        } label: {
            Image(systemName: isZoomMode ? "hand.point.up.left.fill" : "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(isZoomMode ? .white : .indigo)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(isZoomMode ? Color.indigo : Color(.systemBackground))
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                )
                .overlay(
                    Circle()
                        .stroke(isZoomMode ? Color.clear : Color(.separator), lineWidth: 0.5)
                )
        }
        .accessibilityLabel(isZoomMode ? String(localized: "editor.zoom.disable", defaultValue: "Disable zoom mode") : String(localized: "editor.zoom.enable", defaultValue: "Enable zoom mode"))
        .accessibilityHint(isZoomMode ? String(localized: "editor.zoom.disable.hint", defaultValue: "Tap to return to editing tools") : String(localized: "editor.zoom.enable.hint", defaultValue: "Tap to zoom and pan the image"))
    }
    
    // MARK: - Detection Overlays
    
    private var autoDetectOverlays: some View {
        ZStack {
            // Loading overlay
            if viewModel.isDetecting {
                detectionLoadingOverlay
            }
            
            // Detection overlay - affiche selon le mode actuel
            if let detections = viewModel.detections {
                detectionOverlayForCurrentMode(detections: detections)
            }
        }
    }
    
    @ViewBuilder
    private func detectionOverlayForCurrentMode(detections: DetectionResults) -> some View {
        switch viewModel.editorMode {
        case .biometrics:
            // Affiche uniquement visages et mains
            let biometricRegions: [any BiometricRegion] = (detections.faces as [any BiometricRegion]) + (detections.hands as [any BiometricRegion])
            if !biometricRegions.isEmpty {
                let biometricDetections = DetectionResults(
                    faces: detections.faces,
                    hands: detections.hands,
                    texts: []
                )
                DetectionOverlay(
                    detections: biometricDetections,
                    imageSize: inputImage.size,
                    selectedRegions: Set(biometricRegions.map(\.id)),
                    deselectedRegions: Set<UUID>(),
                    onToggleRegion: { _ in },
                    allowToggle: false
                )
            }
        case .text:
            // Affiche uniquement les textes
            if !detections.texts.isEmpty {
                let textDetections = DetectionResults(
                    faces: [],
                    hands: [],
                    texts: detections.texts
                )
                DetectionOverlay(
                    detections: textDetections,
                    imageSize: inputImage.size,
                    selectedRegions: Set(detections.texts.map(\.id)),
                    deselectedRegions: Set<UUID>(),
                    onToggleRegion: { _ in },
                    allowToggle: false
                )
            }
        case .manualBrush:
            // Mode pinceau: affiche tout
            let allRegionIDs = Set(detections.allRegions.map(\.id))
            DetectionOverlay(
                detections: detections,
                imageSize: inputImage.size,
                selectedRegions: allRegionIDs,
                deselectedRegions: Set<UUID>(),
                onToggleRegion: { _ in },
                allowToggle: false
            )
        }
    }
    
    // MARK: - Manual Brush Overlay
    
    private func manualBrushOverlay(geometry: GeometryProxy) -> some View {
        BrushCanvasView(
            originalImage: inputImage,
            brushSettings: viewModel.brushSettings,
            strokes: $viewModel.brushStrokes,
            undoStack: $viewModel.brushUndoStack,
            canvasDisplaySize: $canvasDisplaySize,
            rebuildTrigger: $viewModel.brushRebuildTrigger
        )
        .onChange(of: viewModel.brushStrokes.count) { _ in
            viewModel.updateReadyState()
        }
    }
    
    // MARK: - Loading Overlay
    
    private var detectionLoadingOverlay: some View {
        VStack {
            Spacer()
            
            HStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                
                Text(String(localized: "editor.detection.analyzing", defaultValue: "Analyse en cours..."))
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(Int(viewModel.detectionProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .cornerRadius(10)
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Bottom Section
    
    @ViewBuilder
    private var bottomSection: some View {
        if isZoomMode {
            zoomModeBottomBar
        } else if viewModel.editorMode == .biometrics {
            biometricsBottomSection
        } else if viewModel.editorMode == .text {
            textBottomSection
        } else {
            brushBottomSection
        }
    }
    
    // MARK: - Zoom Mode Bottom Bar
    
    private var zoomModeBottomBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.point.up.left.fill")
                .foregroundColor(.indigo)
                .font(.callout)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "editor.zoom.mode", defaultValue: "Zoom & Pan Mode"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(String(localized: "editor.zoom.hint", defaultValue: "Pinch to zoom • Drag to pan • Tap 🔍 to exit"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isZoomMode = false
                    zoomScale = 1.0
                    panOffset = .zero
                    livePinchScale = 1.0
                    liveDragOffset = .zero
                }
            } label: {
                Text(String(localized: "done", defaultValue: "Done"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.indigo)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 5, y: -2)
    }
    
    // MARK: - Biometrics Bottom Section
    
    private var biometricsBottomSection: some View {
        VStack(spacing: 0) {
            // Detection summary or "nothing detected" banner
            if viewModel.nothingDetected {
                nothingDetectedBanner
            } else if let detections = viewModel.detections {
                detectionSummary(detections)
            }
            
            // Method selector (only if there are detections)
            if !viewModel.nothingDetected, viewModel.detections != nil {
                methodSelector
            }
            
            // Bottom toolbar
            biometricsToolbar
        }
    }
    
    // MARK: - Nothing Detected Banner
    
    private var nothingDetectedBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.shield.fill")
                .foregroundColor(.green)
                .font(.callout)
            
            Text(String(localized: "editor.nothing.detected", defaultValue: "Aucune donnée biométrique détectée"))
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.green.opacity(0.08))
    }
    
    // MARK: - Detection Summary
    
    private func detectionSummary(_ detections: DetectionResults) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.callout)
            
            Text(detections.summary)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground))
    }
    
    // MARK: - Method Selector
    
    private var methodSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ObfuscationMethod.allCases.filter(\.isAvailable)) { method in
                    MethodChip(
                        method: method,
                        isSelected: viewModel.selectedMethod == method,
                        onTap: { viewModel.selectedMethod = method }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Biometrics Toolbar
    
    private var biometricsToolbar: some View {
        HStack(spacing: 16) {
            // Bouton Skip optionnel
            Button(action: nextStep) {
                Text(String(localized: "button.skip", defaultValue: "Skip"))
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            
            // Bouton Next
            Button(action: nextStep) {
                HStack {
                    Text(String(localized: "button.next", defaultValue: "Next"))
                    Image(systemName: "arrow.right")
                }
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.indigo)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 5, y: -2)
    }
    
    // MARK: - Text Bottom Section
    
    private var textBottomSection: some View {
        VStack(spacing: 0) {
            // Info banner
            HStack(spacing: 10) {
                Image(systemName: "doc.text.viewfinder")
                    .foregroundColor(.blue)
                    .font(.callout)
                
                Text(String(localized: "editor.text.info", defaultValue: "Text detection results"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                if let detections = viewModel.detections {
                    Text("\(detections.texts.count) regions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.blue.opacity(0.08))
            
            // Navigation buttons
            HStack(spacing: 16) {
                Button(action: previousStep) {
                    HStack {
                        Image(systemName: "arrow.left")
                        Text(String(localized: "button.back", defaultValue: "Back"))
                    }
                    .fontWeight(.medium)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                
                Button(action: nextStep) {
                    HStack {
                        Text(String(localized: "button.continue", defaultValue: "Continue"))
                        Image(systemName: "arrow.right")
                    }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .shadow(color: .black.opacity(0.05), radius: 5, y: -2)
        }
    }
    
    // MARK: - Process Target Popup (depuis le bas)
    
    private var processTargetPopup: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color(.separator))
                        .frame(width: 36, height: 5)
                        .padding(.top, 12)
                    
                    Text(String(localized: "editor.configuration", defaultValue: "Configuration"))
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(String(localized: "editor.what.to.blur", defaultValue: "Que souhaitez-vous flouter ?"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 8)
                }
                
                Divider()
                
                // Options
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.availableProcessTargets.enumerated()), id: \.element.id) { index, target in
                        Button {
                            selectedProcessTarget = target
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showProcessPopup = false
                            }
                            // Lancer le traitement directement
                            Task {
                                await processAndSave(target: target)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: target.iconName)
                                    .font(.body)
                                    .foregroundColor(.indigo)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(target.displayName)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    
                                    Text(processTargetDetail(target))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .contentShape(Rectangle())
                        }
                        
                        if index < viewModel.availableProcessTargets.count - 1 {
                            Divider()
                                .padding(.leading, 56)
                        }
                    }
                }
                
                Divider()
                
                // Cancel button
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showProcessPopup = false
                    }
                } label: {
                    Text(String(localized: "cancel", defaultValue: "Annuler"))
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .contentShape(Rectangle())
                }
            }
            .background(
                Color(.systemBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            )
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: -5)
            .padding(.top, 50)
        }
        .background(
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showProcessPopup = false
                    }
                }
        )
        .ignoresSafeArea(edges: .bottom)
    }
    
    /// Détail pour chaque cible de traitement
    private func processTargetDetail(_ target: ProcessTarget) -> String {
        let detections = viewModel.detections
        let brushCount = viewModel.brushStrokes.count
        
        switch target {
        case .all:
            let regionCount = (detections?.totalCount ?? 0)
            let regionFormat = regionCount == 1 ?
                String(localized: "process.detail.region.single", defaultValue: "%d region") :
                String(localized: "process.detail.region.plural", defaultValue: "%d regions")
            let brushFormat = brushCount == 1 ?
                String(localized: "process.detail.brush.single", defaultValue: "%d stroke") :
                String(localized: "process.detail.brush.plural", defaultValue: "%d strokes")
            return "\(String(format: regionFormat, regionCount)) + \(String(format: brushFormat, brushCount))"
        case .onlyBrush:
            let format = brushCount == 1 ?
                String(localized: "process.detail.brush.single", defaultValue: "%d stroke") :
                String(localized: "process.detail.brush.plural", defaultValue: "%d strokes")
            return String(format: format, brushCount)
        case .onlyAutoDetected:
            let c = detections?.totalCount ?? 0
            let format = c == 1 ?
                String(localized: "process.detail.region.single", defaultValue: "%d region") :
                String(localized: "process.detail.region.plural", defaultValue: "%d regions")
            return String(format: format, c)
        case .onlyFaces:
            let c = detections?.faces.count ?? 0
            let format = c == 1 ?
                String(localized: "process.detail.face.single", defaultValue: "%d face") :
                String(localized: "process.detail.face.plural", defaultValue: "%d faces")
            return String(format: format, c)
        case .onlyHands:
            let c = detections?.hands.count ?? 0
            let format = c == 1 ?
                String(localized: "process.detail.hand.single", defaultValue: "%d hand") :
                String(localized: "process.detail.hand.plural", defaultValue: "%d hands")
            return String(format: format, c)
        case .onlyTexts:
            let c = detections?.texts.count ?? 0
            let format = c == 1 ?
                String(localized: "process.detail.text.single", defaultValue: "%d text") :
                String(localized: "process.detail.text.plural", defaultValue: "%d texts")
            return String(format: format, c)
        }
    }
    
    // MARK: - Brush Bottom Section
    
    private var brushBottomSection: some View {
        VStack(spacing: 0) {
            // Show detected regions badge (remind user detections will be combined)
            if let detections = viewModel.detections, detections.totalCount > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    
                    Text(String(localized: "editor.regions.will.also.be.applied", defaultValue: "%@ will also be applied").replacingOccurrences(of: "%@", with: detections.summary))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.08))
            }
            
            // Brush info bar
            HStack(spacing: 12) {
                // Mode indicator
                Image(systemName: "paintbrush.pointed.fill")
                    .foregroundColor(.indigo)
                    .font(.callout)
                
                Text(String(localized: "editor.brush.title", defaultValue: "Blur brush"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                // Stroke count badge
                if viewModel.brushStrokes.count > 0 {
                    Text("\(viewModel.brushStrokes.count)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 22, height: 22)
                        .background(Color.indigo)
                        .clipShape(Circle())
                }
                
                // Undo button
                Button {
                    viewModel.undoBrushStroke()
                } label: {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .font(.title3)
                        .foregroundColor(viewModel.brushUndoStack.isEmpty ? Color(.tertiaryLabel) : .indigo)
                }
                .disabled(viewModel.brushUndoStack.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemGroupedBackground))
            
            // Brush controls
            VStack(spacing: 14) {
                // Brush size with live preview
                HStack(spacing: 12) {
                    // Live size preview circle
                    ZStack {
                        Circle()
                            .fill(Color.indigo.opacity(0.2))
                            .frame(width: 36, height: 36)
                        
                        Circle()
                            .fill(Color.indigo.opacity(0.6))
                            .frame(
                                width: scaledPreviewSize,
                                height: scaledPreviewSize
                            )
                            .animation(.easeOut(duration: 0.12), value: viewModel.brushSettings.brushSize)
                    }
                    .frame(width: 36, height: 36)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "editor.brush.size", defaultValue: "Size"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Slider(
                            value: $viewModel.brushSettings.brushSize,
                            in: BrushSettings.minBrushSize...BrushSettings.maxBrushSize
                        )
                        .tint(.indigo)
                    }
                    
                    Text("\(Int(viewModel.brushSettings.brushSize))")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.indigo)
                        .frame(width: 32, alignment: .trailing)
                }
                
                // Blur intensity
                HStack(spacing: 12) {
                    // Intensity preview icon
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.15))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "aqi.medium")
                            .font(.system(size: 16))
                            .foregroundColor(.orange)
                            .opacity(0.3 + viewModel.brushSettings.blurIntensity * 0.7)
                    }
                    .frame(width: 36, height: 36)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "editor.brush.intensity", defaultValue: "Blur strength"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Slider(
                            value: $viewModel.brushSettings.blurIntensity,
                            in: 0.1...1.0
                        )
                        .tint(.orange)
                        
                        Text(String(localized: "editor.brush.threshold.warning", defaultValue: "✓ Irreversible - AI cannot reconstruct"))
                            .font(.caption2)
                            .foregroundColor(viewModel.brushSettings.blurIntensity >= 0.7 ? .red : .clear)
                            .animation(.easeInOut(duration: 0.2), value: viewModel.brushSettings.blurIntensity)
                    }
                    
                    Text("\(Int(viewModel.brushSettings.blurIntensity * 100))%")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                        .frame(width: 36, alignment: .trailing)
                }
                
                // Process button
                HStack(spacing: 10) {
                    Spacer()
                    Button {
                        // Always show the popup so user can choose what to process
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showProcessPopup = true
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "wand.and.stars")
                            Text(String(localized: "editor.process", defaultValue: "Process"))
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(viewModel.isReadyToProcess ? Color.indigo : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!viewModel.isReadyToProcess)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .shadow(color: .black.opacity(0.06), radius: 8, y: -3)
        }
    }
    
    /// Maps brush size to a visual preview within the 36pt indicator circle
    private var scaledPreviewSize: CGFloat {
        let minPreview: CGFloat = 6
        let maxPreview: CGFloat = 32
        let ratio = (viewModel.brushSettings.brushSize - BrushSettings.minBrushSize)
            / (BrushSettings.maxBrushSize - BrushSettings.minBrushSize)
        return minPreview + ratio * (maxPreview - minPreview)
    }
    
    // MARK: - Navigation
    
    private func previousStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            switch viewModel.editorMode {
            case .text:
                viewModel.editorMode = .biometrics
            case .manualBrush:
                viewModel.editorMode = .text
            case .biometrics:
                break
            }
        }
    }
    
    private func nextStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            switch viewModel.editorMode {
            case .biometrics:
                viewModel.editorMode = .text
            case .text:
                viewModel.editorMode = .manualBrush
            case .manualBrush:
                break
            }
        }
    }
}

// MARK: - Method Chip

struct MethodChip: View {
    let method: ObfuscationMethod
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 5) {
                Image(systemName: method.iconName)
                    .font(.caption2)
                Text(method.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.indigo : Color.clear)
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.indigo : Color(.separator), lineWidth: 1)
            )
        }
        .accessibilityLabel(method.displayName)
        .accessibilityHint(method.description)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Processing & Save Extension

extension EditorView {
    
    /// Traite l'image avec la cible sélectionnée et sauvegarde directement
    func processAndSave(target: ProcessTarget) async {
        guard let image = viewModel.originalImage else { return }
        
        await MainActor.run {
            isProcessing = true
        }
        
        do {
            let normalizedImage = image.normalized()
            guard let ciImage = CIImage(image: normalizedImage) else {
                throw ProcessingError.imageConversionFailed
            }
            
            let regions = viewModel.regionsForTarget(target)
            let brushStrokes = viewModel.brushStrokesForTarget(target)
            
            // Détection du nombre de visages pour ajuster le temps de traitement
            let faceCount = viewModel.detections?.faces.count ?? 0
            if faceCount > 1 {
                // Délai supplémentaire de 500ms par visage supplémentaire pour assurer une meilleure détection
                let additionalDelay = UInt64(faceCount - 1) * 500_000_000 // nanoseconds
                try? await Task.sleep(nanoseconds: additionalDelay)
            }
            
            var result: CIImage = ciImage
            
            // Appliquer le flou des régions détectées
            if !regions.isEmpty {
                result = await pipeline.obfuscationEngine.obfuscate(
                    result,
                    regions: regions,
                    method: viewModel.selectedMethod,
                    settings: viewModel.obfuscationSettings
                ) { _ in }
            }
            
            // Appliquer le flou du pinceau
            if !brushStrokes.isEmpty {
                result = pipeline.applyBrushBlur(
                    to: result,
                    strokes: brushStrokes,
                    intensity: viewModel.brushSettings.blurIntensity,
                    imageSize: normalizedImage.size, // Use normalized image size (pixels)
                    displaySize: canvasDisplaySize
                )
            }
            
            // Si aucun traitement, appliquer au moins le stripping de métadonnées
            if regions.isEmpty && brushStrokes.isEmpty {
                // Juste strip metadata
            }
            
            // Rendre en UIImage
            guard let cgImage = pipeline.ciContext.createCGImage(result, from: result.extent) else {
                throw ProcessingError.imageConversionFailed
            }
            let processedUIImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
            
            // Strip metadata
            guard let cleanImage = pipeline.metadataHandler.stripMetadata(from: processedUIImage) else {
                throw ProcessingError.metadataStrippingFailed
            }
            
            // Sauvegarder dans Photos
            try await PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCreationRequest.forAsset()
                if let data = cleanImage.jpegData(compressionQuality: 1.0) {
                    request.addResource(with: .photo, data: data, options: nil)
                }
            })
            
            await MainActor.run {
                processedImage = cleanImage
                isProcessing = false
                showResult = true
            }
            
        } catch {
            await MainActor.run {
                processingError = error
                isProcessing = false
            }
        }
    }
}

// MARK: - Share Sheet (iOS 15 Compatible)

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
