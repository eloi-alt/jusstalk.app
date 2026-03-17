// EditorViewModel.swift
// Cloaky
//
// ViewModel for the editor screen with detection overlay, region selection,
// and manual brush tool.

import Foundation
import UIKit
import CoreImage
import Combine

// MARK: - Editor Mode

enum EditorMode: String, CaseIterable {
    case biometrics
    case text
    case manualBrush
    
    var displayName: String {
        switch self {
        case .biometrics:
            return String(localized: "editor.mode.biometrics", defaultValue: "Biometrics")
        case .text:
            return String(localized: "editor.mode.text", defaultValue: "Text")
        case .manualBrush:
            return String(localized: "editor.mode.manual", defaultValue: "Brush")
        }
    }
    
    var iconName: String {
        switch self {
        case .biometrics: return "person.crop.square"
        case .text: return "doc.text.viewfinder"
        case .manualBrush: return "paintbrush.pointed"
        }
    }
}

// MARK: - Detection Step (legacy - kept for EditorView compatibility)

enum DetectionStep: String, CaseIterable {
    case biometrics
    case text
    case brush
    case export
    
    var displayName: String {
        switch self {
        case .biometrics:
            return String(localized: "detection.step.biometrics", defaultValue: "Biometrics")
        case .text:
            return String(localized: "detection.step.text", defaultValue: "Text")
        case .brush:
            return String(localized: "detection.step.brush", defaultValue: "Brush")
        case .export:
            return String(localized: "detection.step.export", defaultValue: "Export")
        }
    }
    
    var stepNumber: Int {
        switch self {
        case .biometrics: return 1
        case .text: return 2
        case .brush: return 3
        case .export: return 4
        }
    }
}

// MARK: - Process Target

/// What the user wants to process (shown in the iOS-style alert popup)
enum ProcessTarget: String, CaseIterable, Identifiable {
    case all
    case onlyBrush
    case onlyAutoDetected
    case onlyFaces
    case onlyHands
    case onlyTexts
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .all:
            return String(localized: "process.target.all", defaultValue: "All")
        case .onlyBrush:
            return String(localized: "process.target.only.brush", defaultValue: "Only Brush")
        case .onlyAutoDetected:
            return String(localized: "process.target.only.detected", defaultValue: "All Detected Biometry")
        case .onlyFaces:
            return String(localized: "process.target.only.faces", defaultValue: "Only Faces")
        case .onlyHands:
            return String(localized: "process.target.only.hands", defaultValue: "Only Hands")
        case .onlyTexts:
            return String(localized: "process.target.only.texts", defaultValue: "Only Texts")
        }
    }
    
    var iconName: String {
        switch self {
        case .all: return "sparkles"
        case .onlyBrush: return "paintbrush.pointed.fill"
        case .onlyAutoDetected: return "person.2.circle"
        case .onlyFaces: return "face.dashed"
        case .onlyHands: return "hand.raised"
        case .onlyTexts: return "doc.text"
        }
    }
}

// MARK: - EditorViewModel

@MainActor
final class EditorViewModel: ObservableObject {
    
    // MARK: - Published State
    
    @Published var originalImage: UIImage?
    @Published var detections: DetectionResults?
    @Published var selectedRegions: Set<UUID> = []
    @Published var isDetecting: Bool = false
    @Published var detectionProgress: Double = 0.0
    @Published var errorMessage: String?
    @Published var selectedMethod: ObfuscationMethod = .intelligentBlur
    @Published var obfuscationSettings: ObfuscationSettings = .default
    @Published var isReadyToProcess: Bool = false
    @Published var nothingDetected: Bool = false
    @Published var detectionComplete: Bool = false
    
    // MARK: - Detection Step (legacy)
    
    @Published var currentDetectionStep: DetectionStep = .biometrics
    
    // MARK: - Editor Mode
    
    @Published var editorMode: EditorMode = .biometrics
    
    // MARK: - Brush State
    
    @Published var brushStrokes: [BrushStroke] = []
    @Published var brushUndoStack: [[BrushStroke]] = []
    @Published var brushSettings = BrushSettings()
    /// Incremented whenever undo/clear happens to tell BrushCanvasView to rebuild.
    @Published var brushRebuildTrigger: Int = 0
    
    // MARK: - Dependencies
    
    let pipeline: ProcessingPipeline
    private var detectionTask: Task<Void, Never>?
    
    // MARK: - Init
    
    init(pipeline: ProcessingPipeline) {
        self.pipeline = pipeline
    }
    
    // MARK: - Image Loading
    
    func loadImage(_ image: UIImage) {
        let normalized = image.normalized()
        originalImage = normalized
        selectedRegions.removeAll()
        detections = nil
        errorMessage = nil
        nothingDetected = false
        detectionComplete = false
        brushStrokes.removeAll()
        brushUndoStack.removeAll()
        brushRebuildTrigger = 0
    }
    
    // MARK: - Detection (legacy combined)
    
    func startDetection() {
        currentDetectionStep = .biometrics
        startBiometricDetection()
    }
    
    func startBiometricDetection() {
        detectionTask?.cancel()
        
        detectionTask = Task { [weak self] in
            guard let self = self else { return }
            await self.performBiometricDetection()
        }
    }
    
    func startTextDetection() {
        detectionTask?.cancel()
        
        detectionTask = Task { [weak self] in
            guard let self = self else { return }
            await self.performTextDetection()
        }
    }
    
    // MARK: - Separated Detection Methods (for 5-step flow)
    
    /// Step 1: Detect only faces
    func startFaceOnlyDetection() {
        detectionTask?.cancel()
        
        detectionTask = Task { [weak self] in
            guard let self = self else { return }
            await self.performFaceOnlyDetection()
        }
    }
    
    /// Step 2: Detect only hands
    func startHandOnlyDetection() {
        detectionTask?.cancel()
        
        detectionTask = Task { [weak self] in
            guard let self = self else { return }
            await self.performHandOnlyDetection()
        }
    }
    
    /// Step 3: Detect only text
    func startTextOnlyDetection() {
        detectionTask?.cancel()
        
        detectionTask = Task { [weak self] in
            guard let self = self else { return }
            await self.performTextOnlyDetection()
        }
    }
    
    // MARK: - Legacy step navigation
    
    func proceedToNextDetectionStep() {
        switch currentDetectionStep {
        case .biometrics:
            currentDetectionStep = .text
            startTextDetection()
        case .text:
            currentDetectionStep = .brush
        case .brush:
            currentDetectionStep = .export
        case .export:
            break
        }
    }
    
    // MARK: - Face Only Detection
    
    private func performFaceOnlyDetection() async {
        guard let image = originalImage,
              let ciImage = CIImage(image: image) else { return }
        
        await MainActor.run {
            self.isDetecting = true
            self.errorMessage = nil
            self.detections = nil
            self.detectionProgress = 0.0
        }
        
        let settings = DetectionSettings(
            detectFaces: true,
            detectHands: false,
            detectText: false,
            detectIris: false,
            sensitivity: 0.5,
            textMode: .sensitiveOnly
        )
        
        do {
            let results = try await pipeline.detectionEngine.detect(
                in: ciImage,
                settings: settings
            ) { progress in
                Task { @MainActor in
                    self.detectionProgress = progress
                }
            }
            
            try Task.checkCancellation()
            
            await MainActor.run {
                self.detections = results
                self.isDetecting = false
                self.detectionProgress = 1.0
                self.nothingDetected = results.faces.isEmpty
                self.updateReadyState()
            }
            
        } catch {
            if !Task.isCancelled {
                await MainActor.run {
                    self.isDetecting = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - Hand Only Detection
    
    private func performHandOnlyDetection() async {
        guard let image = originalImage,
              let ciImage = CIImage(image: image) else { return }
        
        await MainActor.run {
            self.isDetecting = true
            self.errorMessage = nil
            self.detections = nil
            self.detectionProgress = 0.0
        }
        
        let settings = DetectionSettings(
            detectFaces: false,
            detectHands: true,
            detectText: false,
            detectIris: false,
            sensitivity: 0.5,
            textMode: .sensitiveOnly
        )
        
        do {
            let results = try await pipeline.detectionEngine.detect(
                in: ciImage,
                settings: settings
            ) { progress in
                Task { @MainActor in
                    self.detectionProgress = progress
                }
            }
            
            try Task.checkCancellation()
            
            await MainActor.run {
                self.detections = results
                self.isDetecting = false
                self.detectionProgress = 1.0
                self.nothingDetected = results.hands.isEmpty
                self.updateReadyState()
            }
            
        } catch {
            if !Task.isCancelled {
                await MainActor.run {
                    self.isDetecting = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - Text Only Detection
    
    private func performTextOnlyDetection() async {
        guard let image = originalImage,
              let ciImage = CIImage(image: image) else { return }
        
        await MainActor.run {
            self.isDetecting = true
            self.errorMessage = nil
            self.detections = nil
            self.detectionProgress = 0.0
        }
        
        let settings = DetectionSettings.maskAllText
        
        do {
            let results = try await pipeline.detectionEngine.detect(
                in: ciImage,
                settings: settings
            ) { progress in
                Task { @MainActor in
                    self.detectionProgress = progress
                }
            }
            
            try Task.checkCancellation()
            
            await MainActor.run {
                self.detections = results
                self.isDetecting = false
                self.detectionProgress = 1.0
                self.nothingDetected = results.texts.isEmpty
                self.updateReadyState()
            }
            
        } catch {
            if !Task.isCancelled {
                await MainActor.run {
                    self.isDetecting = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - Legacy Biometric Detection (faces + hands)
    
    private func performBiometricDetection() async {
        guard let image = originalImage,
              let ciImage = CIImage(image: image) else { return }
        
        await MainActor.run {
            self.isDetecting = true
            self.errorMessage = nil
            self.detections = nil
            self.detectionProgress = 0.0
        }
        
        let settings = DetectionSettings.default
        
        do {
            let results = try await pipeline.detectionEngine.detect(
                in: ciImage,
                settings: settings
            ) { progress in
                Task { @MainActor in
                    self.detectionProgress = progress
                }
            }
            
            try Task.checkCancellation()
            
            await MainActor.run {
                self.detections = results
                self.isDetecting = false
                self.detectionProgress = 1.0
                self.nothingDetected = results.totalCount == 0
                self.updateReadyState()
            }
            
        } catch {
            if !Task.isCancelled {
                await MainActor.run {
                    self.isDetecting = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - Legacy Text Detection
    
    private func performTextDetection() async {
        guard let image = originalImage,
              let ciImage = CIImage(image: image) else { return }
        
        await MainActor.run {
            self.isDetecting = true
            self.errorMessage = nil
            self.detectionProgress = 0.0
        }
        
        let settings = DetectionSettings.maskAllText
        
        do {
            let textResults = try await pipeline.detectionEngine.detect(
                in: ciImage,
                settings: settings
            ) { progress in
                Task { @MainActor in
                    self.detectionProgress = progress
                }
            }
            
            try Task.checkCancellation()
            
            // Merge with existing biometric results
            await MainActor.run {
                if let existingDetections = self.detections {
                    self.detections = existingDetections.mergingWith(textResults)
                } else {
                    self.detections = textResults
                }
                
                self.isDetecting = false
                self.detectionProgress = 1.0
                self.detectionComplete = true
                self.selectAll()
                self.nothingDetected = self.detections?.totalCount == 0
                self.updateReadyState()
            }
            
        } catch {
            if !Task.isCancelled {
                await MainActor.run {
                    self.isDetecting = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - Region Selection
    
    func toggleRegion(_ id: UUID) {
        if selectedRegions.contains(id) {
            selectedRegions.remove(id)
        } else {
            selectedRegions.insert(id)
        }
        updateReadyState()
    }
    
    func selectAll() {
        guard let detections = detections else { return }
        selectedRegions = Set(detections.allRegions.map(\.id))
        updateReadyState()
    }
    
    func deselectAll() {
        selectedRegions.removeAll()
        updateReadyState()
    }
    
    func isRegionSelected(_ id: UUID) -> Bool {
        selectedRegions.contains(id)
    }
    
    var selectedBiometricRegions: [any BiometricRegion] {
        guard let detections = detections else { return [] }
        return detections.allRegions.filter { selectedRegions.contains($0.id) }
    }
    
    // MARK: - Brush
    
    var hasBrushStrokes: Bool {
        !brushStrokes.isEmpty
    }
    
    /// Undo last brush stroke -- triggers a full composite rebuild.
    func undoBrushStroke() {
        guard let previous = brushUndoStack.popLast() else { return }
        brushStrokes = previous
        brushRebuildTrigger += 1
        updateReadyState()
    }
    
    /// Clear all brush strokes -- triggers a full composite rebuild.
    func clearBrushStrokes() {
        brushUndoStack.append(brushStrokes)
        brushStrokes.removeAll()
        brushRebuildTrigger += 1
        updateReadyState()
    }
    
    // MARK: - Process Target Filtering
    
    /// Returns which process targets are available based on detections + brush strokes
    var availableProcessTargets: [ProcessTarget] {
        let hasDetections = (detections?.totalCount ?? 0) > 0
        let hasFaces = !(detections?.faces.isEmpty ?? true)
        let hasHands = !(detections?.hands.isEmpty ?? true)
        let hasTexts = !(detections?.texts.isEmpty ?? true)
        let hasBrush = !brushStrokes.isEmpty
        
        var targets: [ProcessTarget] = []
        
        // "All" only when BOTH brush strokes AND detections exist
        if hasBrush && hasDetections {
            targets.append(.all)
        }
        if hasBrush {
            targets.append(.onlyBrush)
        }
        if hasDetections {
            targets.append(.onlyAutoDetected)
        }
        if hasFaces {
            targets.append(.onlyFaces)
        }
        if hasHands {
            targets.append(.onlyHands)
        }
        if hasTexts {
            targets.append(.onlyTexts)
        }
        return targets
    }
    
    /// Returns the biometric regions matching the given process target
    func regionsForTarget(_ target: ProcessTarget) -> [any BiometricRegion] {
        guard let detections = detections else { return [] }
        switch target {
        case .all, .onlyAutoDetected:
            return Array(detections.faces) + Array(detections.hands) + Array(detections.texts)
        case .onlyFaces:
            return Array(detections.faces)
        case .onlyHands:
            return Array(detections.hands)
        case .onlyTexts:
            return Array(detections.texts)
        case .onlyBrush:
            return []
        }
    }
    
    /// Returns the brush strokes matching the given process target
    func brushStrokesForTarget(_ target: ProcessTarget) -> [BrushStroke] {
        switch target {
        case .all, .onlyBrush:
            return brushStrokes
        case .onlyAutoDetected, .onlyFaces, .onlyHands, .onlyTexts:
            return []
        }
    }
    
    // MARK: - Processing Readiness
    
    func updateReadyState() {
        let hasDetections = detections?.totalCount ?? 0 > 0
        isReadyToProcess = hasDetections || !brushStrokes.isEmpty || nothingDetected
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        detectionTask?.cancel()
    }
}
