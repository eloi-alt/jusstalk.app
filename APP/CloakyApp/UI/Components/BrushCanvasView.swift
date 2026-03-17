// BrushCanvasView.swift
// Cloaky
//
// Interactive brush canvas for manual blur painting.
// All images are normalized (orientation flattened, scale=1) before processing
// to guarantee pixel-perfect alignment between original and blurred versions.

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - Brush Stroke

/// A single brush stroke path.
/// Points are in **normalized UV coordinates** (0.0-1.0 relative to original image size).
/// This makes strokes independent of display resolution and ensures pixel-perfect export.
struct BrushStroke: Identifiable {
    let id = UUID()
    /// Points in normalized UV coordinates (0.0-1.0)
    var points: [CGPoint]
    /// Brush size in normalized coordinates (relative to image width)
    let brushSize: CGFloat
    
    /// Convert normalized points to display coordinates for rendering
    func pointsInDisplaySize(_ displaySize: CGSize) -> [CGPoint] {
        points.map { CGPoint(x: $0.x * displaySize.width, y: $0.y * displaySize.height) }
    }
    
    /// Convert normalized brush size to display size
    func brushSizeInDisplaySize(_ displaySize: CGSize) -> CGFloat {
        brushSize * displaySize.width
    }
    
    /// Convert normalized points to pixel coordinates for export
    func pointsInPixelSize(_ pixelSize: CGSize) -> [CGPoint] {
        points.map { CGPoint(x: $0.x * pixelSize.width, y: $0.y * pixelSize.height) }
    }
    
    /// Convert normalized brush size to pixel size
    func brushSizeInPixelSize(_ pixelSize: CGSize) -> CGFloat {
        brushSize * pixelSize.width
    }
}

// MARK: - Brush Settings

class BrushSettings: ObservableObject {
    @Published var brushSize: CGFloat = 50
    @Published var blurIntensity: Double = 0.5
    
    static let minBrushSize: CGFloat = 15
    static let maxBrushSize: CGFloat = 150
}

// MARK: - Image Normalization

/// Flattens orientation and forces scale=1 so pixel coordinates are unambiguous.
private func normalizeImage(_ image: UIImage) -> UIImage {
    let needsOrientationFix = image.imageOrientation != .up
    let needsScaleFix = image.scale != 1.0
    guard needsOrientationFix || needsScaleFix else { return image }
    
    // Render into a fresh bitmap at the visual pixel dimensions
    let pixelWidth = image.size.width * image.scale
    let pixelHeight = image.size.height * image.scale
    let pixelSize = CGSize(width: pixelWidth, height: pixelHeight)
    
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1.0
    let renderer = UIGraphicsImageRenderer(size: pixelSize, format: format)
    return renderer.image { _ in
        image.draw(in: CGRect(origin: .zero, size: pixelSize))
    }
}

// MARK: - ImageLayout

/// Computes the exact rect an aspect-fitted image occupies inside its container.
private struct ImageLayout {
    let imageRect: CGRect
    let containerSize: CGSize
    
    init(imageSize: CGSize, containerSize: CGSize) {
        self.containerSize = containerSize
        
        guard imageSize.width > 0, imageSize.height > 0,
              containerSize.width > 0, containerSize.height > 0 else {
            self.imageRect = .zero
            return
        }
        
        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = containerSize.width / containerSize.height
        
        if imageAspect > containerAspect {
            let displayWidth = containerSize.width
            let displayHeight = containerSize.width / imageAspect
            let offsetY = (containerSize.height - displayHeight) / 2
            imageRect = CGRect(x: 0, y: offsetY, width: displayWidth, height: displayHeight)
        } else {
            let displayHeight = containerSize.height
            let displayWidth = containerSize.height * imageAspect
            let offsetX = (containerSize.width - displayWidth) / 2
            imageRect = CGRect(x: offsetX, y: 0, width: displayWidth, height: displayHeight)
        }
    }
    
    var displaySize: CGSize { imageRect.size }
    
    /// Gesture point (container coords) → normalized UV coords (0.0-1.0).
    /// Allows points outside image bounds for edge drawing.
    func gestureToNormalizedPoint(_ p: CGPoint, brushRadius: CGFloat = 0) -> CGPoint? {
        let rel = CGPoint(x: p.x - imageRect.origin.x, y: p.y - imageRect.origin.y)
        
        // Allow points outside the image bounds by brush radius for edge drawing
        let margin = brushRadius * 2.0
        guard rel.x >= -margin, rel.y >= -margin,
              rel.x <= imageRect.width + margin,
              rel.y <= imageRect.height + margin else {
            return nil // Too far outside — definitely not trying to draw on the image
        }
        
        // Clamp to image bounds and convert to normalized UV coordinates (0.0-1.0)
        let clampedX = max(0, min(rel.x, imageRect.width))
        let clampedY = max(0, min(rel.y, imageRect.height))
        let normalizedX = clampedX / imageRect.width
        let normalizedY = clampedY / imageRect.height
        return CGPoint(x: normalizedX, y: normalizedY)
    }
    
    /// Normalized UV coords (0.0-1.0) → container coords (for drawing overlays).
    func normalizedPointToContainer(_ p: CGPoint) -> CGPoint {
        let x = p.x * imageRect.width + imageRect.origin.x
        let y = p.y * imageRect.height + imageRect.origin.y
        return CGPoint(x: x, y: y)
    }
    
    /// Normalized brush size → display brush size.
    func normalizedBrushSizeToDisplay(_ normalizedSize: CGFloat) -> CGFloat {
        normalizedSize * imageRect.width
    }
}

// MARK: - Rendering Context

/// Describes what the loading spinner is for.
private enum RenderingReason {
    case applyingBlur
    case undoing
    case updatingIntensity
    
    var message: String {
        switch self {
        case .applyingBlur: return String(localized: "brush.applying.blur", defaultValue: "Applying blur…")
        case .undoing: return String(localized: "brush.undoing", defaultValue: "Reverting…")
        case .updatingIntensity: return String(localized: "brush.updating", defaultValue: "Updating…")
        }
    }
}

// MARK: - BrushCanvasView

struct BrushCanvasView: View {
    
    let originalImage: UIImage
    @ObservedObject var brushSettings: BrushSettings
    @Binding var strokes: [BrushStroke]
    @Binding var undoStack: [[BrushStroke]]
    @Binding var canvasDisplaySize: CGSize
    @Binding var rebuildTrigger: Int
    
    // MARK: - Internal State
    
    @State private var currentStrokePoints: [CGPoint] = []
    @State private var isDrawing: Bool = false
    @State private var isRendering: Bool = false
    @State private var renderingReason: RenderingReason = .applyingBlur
    @State private var compositeImage: UIImage?
    /// Normalized original (orientation=.up, scale=1)
    @State private var normalizedOriginal: UIImage?
    /// Fully blurred version of normalizedOriginal
    @State private var blurredImage: UIImage?
    @State private var containerSize: CGSize = .zero
    @State private var lastTouchContainer: CGPoint = .zero
    @State private var lastRebuildTrigger: Int = -1
    @State private var lastBlurIntensity: Double = -1
    /// Cached normalized image size for consistent UV calculations
    @State private var normalizedImageSize: CGSize = .zero
    
    /// The reference image size for UV calculations (must match toBlurmask)
    /// Uses normalized image size (scale=1.0) to ensure consistency
    private var referenceImageSize: CGSize {
        // Use cached normalized size to match what toBlurmask uses
        if normalizedImageSize == .zero {
            // Calculate what the normalized size will be
            let pixelWidth = originalImage.size.width * originalImage.scale
            let pixelHeight = originalImage.size.height * originalImage.scale
            return CGSize(width: pixelWidth, height: pixelHeight)
        }
        return normalizedImageSize
    }
    
    private var layout: ImageLayout {
        // Use normalized size for UV calculations to match toBlurmask
        ImageLayout(imageSize: referenceImageSize, containerSize: containerSize)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Layer 1 — Composite image (or original)
                displayedImage
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                
                // Layer 2 — Live stroke overlay (lightweight, no image processing)
                if !currentStrokePoints.isEmpty && isDrawing {
                    liveStrokeOverlay(containerSize: geometry.size)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .allowsHitTesting(false)
                }
                
                // Layer 3 — Brush cursor: only while actively dragging, not after lift
                EmptyView()
                
                // Layer 4 — Loading spinner
                if isRendering {
                    renderingOverlay
                }
                
                // Gesture catcher
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(drawingGesture)
            }
            .onAppear {
                containerSize = geometry.size
                let lyt = ImageLayout(imageSize: originalImage.size, containerSize: geometry.size)
                canvasDisplaySize = lyt.displaySize
                lastBlurIntensity = brushSettings.blurIntensity
                prepareImages()
            }
            .onChange(of: geometry.size) { newSize in
                containerSize = newSize
                let lyt = ImageLayout(imageSize: originalImage.size, containerSize: newSize)
                canvasDisplaySize = lyt.displaySize
            }
            .onChange(of: rebuildTrigger) { newValue in
                guard newValue != lastRebuildTrigger else { return }
                lastRebuildTrigger = newValue
                rebuildCompositeFromScratch(reason: .undoing)
            }
            .onChange(of: brushSettings.blurIntensity) { newValue in
                // Always regenerate blur when intensity changes - no threshold needed
                lastBlurIntensity = newValue
                
                // Regenerate immediately for responsive feel
                // If strokes exist, rebuild composite with new blur
                if !strokes.isEmpty {
                    regenerateBlurAndRebuild()
                } else {
                    // No strokes yet, just regenerate cached blur for when user draws
                    regenerateBlurOnly()
                }
            }
        }
    }
    
    // MARK: - Displayed Image
    
    private var displayedImage: Image {
        if let composite = compositeImage {
            return Image(uiImage: composite)
        }
        return Image(uiImage: originalImage)
    }
    
    // MARK: - Live Stroke Overlay
    
    private func liveStrokeOverlay(containerSize: CGSize) -> some View {
        Canvas { context, size in
            guard !currentStrokePoints.isEmpty else { return }

            let lyt = ImageLayout(imageSize: originalImage.size, containerSize: size)
            // Convert normalized points to container coordinates for display
            let containerPoints = currentStrokePoints.map { lyt.normalizedPointToContainer($0) }
            // Convert normalized brush size to display size
            let normalizedBrushSize = brushSettings.brushSize / lyt.displaySize.width
            let displayBrushSize = lyt.normalizedBrushSizeToDisplay(normalizedBrushSize)

            if containerPoints.count == 1 {
                let p = containerPoints[0]
                var path = Path()
                path.addEllipse(in: CGRect(
                    x: p.x - displayBrushSize / 2,
                    y: p.y - displayBrushSize / 2,
                    width: displayBrushSize,
                    height: displayBrushSize
                ))
                context.fill(path, with: .color(.white.opacity(0.45)))
            } else {
                var path = Path()
                path.move(to: containerPoints[0])
                for i in 1..<containerPoints.count {
                    path.addLine(to: containerPoints[i])
                }
                let strokedPath = path.strokedPath(
                    StrokeStyle(
                        lineWidth: displayBrushSize,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                context.fill(strokedPath, with: .color(.white.opacity(0.45)))
            }
        }
    }
    
    // MARK: - Rendering Overlay
    
    private var renderingOverlay: some View {
        ZStack {
            Color.black.opacity(0.15)
                .allowsHitTesting(true) // Block interactions during render
            
            VStack(spacing: 8) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
                Text(renderingReason.message)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(18)
            .background(.ultraThinMaterial)
            .cornerRadius(14)
        }
    }
    
    // MARK: - Drawing Gesture
    
    private var drawingGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !isRendering else { return }

                let containerPoint = value.location
                lastTouchContainer = containerPoint

                // Convert brush size to normalized coordinates (relative to image width)
                let normalizedBrushSize = brushSettings.brushSize / layout.displaySize.width
                let brushRadius = layout.normalizedBrushSizeToDisplay(normalizedBrushSize) / 2
                guard let normalizedPoint = layout.gestureToNormalizedPoint(containerPoint, brushRadius: brushRadius) else { return }

                if !isDrawing {
                    isDrawing = true
                    currentStrokePoints = [normalizedPoint]

                    undoStack.append(strokes)
                    if undoStack.count > 30 { undoStack.removeFirst() }
                } else {
                    if let last = currentStrokePoints.last {
                        // Distance in normalized space (approximate)
                        let dx = normalizedPoint.x - last.x
                        let dy = normalizedPoint.y - last.y
                        if sqrt(dx * dx + dy * dy) > 0.005 { // ~0.5% of image size
                            currentStrokePoints.append(normalizedPoint)
                        }
                    }
                }
            }
            .onEnded { _ in
                guard isDrawing else { return }
                isDrawing = false

                guard !currentStrokePoints.isEmpty else { return }

                // Convert brush size to normalized coordinates
                let normalizedBrushSize = brushSettings.brushSize / layout.displaySize.width

                let finishedStroke = BrushStroke(
                    points: currentStrokePoints,
                    brushSize: normalizedBrushSize
                )

                currentStrokePoints = []
                isRendering = true
                renderingReason = .applyingBlur

                strokes.append(finishedStroke)
                renderSingleStroke(finishedStroke)
            }
    }
    
    // MARK: - Prepare Images (on appear)
    
    private func prepareImages() {
        let original = originalImage
        lastBlurIntensity = brushSettings.blurIntensity
        
        // Calculate normalized size immediately for UV consistency
        let calculatedNormalizedSize = CGSize(
            width: original.size.width * original.scale,
            height: original.size.height * original.scale
        )
        normalizedImageSize = calculatedNormalizedSize
        
        DispatchQueue.global(qos: .userInitiated).async {
            let normalized = normalizeImage(original)
            let blurred = Self.generateBlurred(from: normalized, intensity: brushSettings.blurIntensity)
            
            DispatchQueue.main.async {
                normalizedOriginal = normalized
                blurredImage = blurred
                // Update with actual normalized size (should match calculated)
                normalizedImageSize = normalized.size
            }
        }
    }
    
    // MARK: - Regenerate Blur Only (no strokes, no spinner needed)
    
    private func regenerateBlurOnly() {
        guard let normalized = normalizedOriginal else { return }
        let intensity = brushSettings.blurIntensity
        
        Task {
            let blurred = await Task.detached(priority: .userInitiated) {
                Self.generateBlurred(from: normalized, intensity: intensity)
            }.value
            
            await MainActor.run {
                self.blurredImage = blurred
            }
        }
    }
    
    // MARK: - Regenerate Blur + Rebuild Composite
    
    private func regenerateBlurAndRebuild() {
        guard let normalized = normalizedOriginal else { return }
        
        isRendering = true
        renderingReason = .updatingIntensity
        
        let intensity = brushSettings.blurIntensity
        let allStrokes = strokes
        let dispSize = layout.displaySize
        
        Task.detached(priority: .userInitiated) {
            guard let newBlurred = Self.generateBlurred(from: normalized, intensity: intensity) else {
                await MainActor.run { self.isRendering = false }
                return
            }
            
            let composite: UIImage?
            if allStrokes.isEmpty {
                composite = nil
            } else {
                composite = Self.buildFullComposite(
                    original: normalized,
                    blurred: newBlurred,
                    strokes: allStrokes,
                    displaySize: dispSize
                )
            }
            
            await MainActor.run {
                self.blurredImage = newBlurred
                self.compositeImage = composite
                self.isRendering = false
            }
        }
    }
    
    // MARK: - Render Single Stroke (incremental — fast)
    
    private func renderSingleStroke(_ stroke: BrushStroke) {
        guard let normalized = normalizedOriginal,
              let blurred = blurredImage else {
            isRendering = false
            return
        }
        
        let baseImage = compositeImage ?? normalized
        let imgSize = normalized.size // Pixel dimensions (scale=1)
        let dispSize = layout.displaySize
        
        DispatchQueue.global(qos: .userInteractive).async {
            let result = Self.compositeOneStroke(
                base: baseImage,
                blurred: blurred,
                stroke: stroke,
                pixelSize: imgSize,
                displaySize: dispSize
            )
            
            DispatchQueue.main.async {
                if let result = result {
                    compositeImage = result
                }
                isRendering = false
            }
        }
    }
    
    // MARK: - Rebuild Composite From Scratch
    
    private func rebuildCompositeFromScratch(reason: RenderingReason) {
        guard let normalized = normalizedOriginal,
              let blurred = blurredImage else {
            compositeImage = nil
            isRendering = false
            return
        }
        
        let allStrokes = strokes
        
        if allStrokes.isEmpty {
            compositeImage = nil
            isRendering = false
            return
        }
        
        isRendering = true
        renderingReason = reason
        
        let dispSize = layout.displaySize
        
        DispatchQueue.global(qos: .userInteractive).async {
            let result = Self.buildFullComposite(
                original: normalized,
                blurred: blurred,
                strokes: allStrokes,
                displaySize: dispSize
            )
            
            DispatchQueue.main.async {
                compositeImage = result
                isRendering = false
            }
        }
    }
    
    // MARK: - Static: Generate Blurred Image
    
    private static func generateBlurred(from normalized: UIImage, intensity: Double) -> UIImage? {
        guard let ciImage = CIImage(image: normalized) else { return nil }
        
        // Blur radius: intensity 0.1-1.0 maps to 6-60 pixels
        // Threshold at 0.7 (70%) - beyond this, even AI models cannot reconstruct
        let blurRadius = intensity * 60.0
        
        // Extend the image to avoid edge artifacts in Gaussian blur
        let extendedImage = ciImage.clampedToExtent()
        
        let blurFilter = CIFilter.gaussianBlur()
        blurFilter.inputImage = extendedImage
        blurFilter.radius = Float(blurRadius)
        
        guard let output = blurFilter.outputImage else { return nil }
        
        // Crop back to original extent
        let croppedOutput = output.cropped(to: ciImage.extent)
        
        let ctx = CIContext(options: [.useSoftwareRenderer: false])
        guard let cgImage = ctx.createCGImage(croppedOutput, from: ciImage.extent) else { return nil }
        
        // Same pixel dimensions, scale=1, orientation=.up — identical to normalized original
        return UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
    }
    
    // MARK: - Static: Build Full Composite
    
    private static func buildFullComposite(
        original: UIImage,
        blurred: UIImage,
        strokes: [BrushStroke],
        displaySize: CGSize
    ) -> UIImage? {
        guard !strokes.isEmpty else { return nil }
        
        let pixelSize = original.size // scale=1 so size = pixels
        var current = original
        
        for stroke in strokes {
            if let next = compositeOneStroke(
                base: current,
                blurred: blurred,
                stroke: stroke,
                pixelSize: pixelSize,
                displaySize: displaySize
            ) {
                current = next
            }
        }
        return current
    }
    
    // MARK: - Static: Composite One Stroke
    
    /// Composites a single blur stroke onto a base image.
    /// Both `base` and `blurred` MUST be normalized (scale=1, orientation=.up)
    /// with identical pixel dimensions.
    /// Points in stroke are normalized UV coordinates (0.0-1.0).
    private static func compositeOneStroke(
        base: UIImage,
        blurred: UIImage,
        stroke: BrushStroke,
        pixelSize: CGSize,
        displaySize: CGSize
    ) -> UIImage? {
        guard displaySize.width > 0, displaySize.height > 0 else { return nil }
        guard !stroke.points.isEmpty else { return nil }

        // Convert normalized points to pixel coordinates
        let pixelPoints = stroke.pointsInPixelSize(pixelSize)
        let pixelBrushSize = stroke.brushSizeInPixelSize(pixelSize)
        
        // Render in pixel space (scale=1)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: pixelSize, format: format)
        
        return renderer.image { context in
            let fullRect = CGRect(origin: .zero, size: pixelSize)
            
            // Draw base — draw(in:) forces exact pixel alignment
            base.draw(in: fullRect)
            
            // Create clipping path
            context.cgContext.saveGState()

            if pixelPoints.count == 1 {
                let p = pixelPoints[0]
                UIBezierPath(ovalIn: CGRect(
                    x: p.x - pixelBrushSize / 2,
                    y: p.y - pixelBrushSize / 2,
                    width: pixelBrushSize,
                    height: pixelBrushSize
                )).addClip()
            } else {
                let strokePath = UIBezierPath()
                strokePath.move(to: pixelPoints[0])
                for i in 1..<pixelPoints.count {
                    strokePath.addLine(to: pixelPoints[i])
                }
                let cgStrokePath = strokePath.cgPath.copy(
                    strokingWithWidth: pixelBrushSize,
                    lineCap: .round,
                    lineJoin: .round,
                    miterLimit: 10
                )
                UIBezierPath(cgPath: cgStrokePath).addClip()
            }
            
            // Draw blurred image in SAME rect — pixel-perfect alignment guaranteed
            blurred.draw(in: fullRect)
            
            context.cgContext.restoreGState()
        }
    }
}

// MARK: - Blur Mask for Final Pipeline Export

extension Array where Element == BrushStroke {

    /// Convert brush strokes to a CIImage mask for the processing pipeline.
    /// Points are normalized UV coordinates (0.0-1.0), so displaySize is no longer needed.
    func toBlurmask(imageSize: CGSize, displaySize: CGSize) -> CIImage? {
        guard !isEmpty else { return nil }

        // Create a slightly larger canvas to handle strokes at edges
        let edgeMargin: CGFloat = 60.0
        let canvasSize = CGSize(
            width: imageSize.width + edgeMargin * 2,
            height: imageSize.height + edgeMargin * 2
        )
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        let maskImage = renderer.image { context in
            // Fill with black (no blur)
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: canvasSize))

            UIColor.white.setFill()
            UIColor.white.setStroke()

            for stroke in self {
                // Convert normalized points to pixel coordinates, offset by margin
                let pixelPoints = stroke.pointsInPixelSize(imageSize).map { 
                    CGPoint(x: $0.x + edgeMargin, y: $0.y + edgeMargin)
                }
                let pixelBrushSize = stroke.brushSizeInPixelSize(imageSize)
                guard !pixelPoints.isEmpty else { continue }

                if pixelPoints.count == 1 {
                    let p = pixelPoints[0]
                    UIBezierPath(ovalIn: CGRect(
                        x: p.x - pixelBrushSize / 2,
                        y: p.y - pixelBrushSize / 2,
                        width: pixelBrushSize,
                        height: pixelBrushSize
                    )).fill()
                } else {
                    let path = UIBezierPath()
                    path.lineWidth = pixelBrushSize
                    path.lineCapStyle = .round
                    path.lineJoinStyle = .round
                    path.move(to: pixelPoints[0])
                    for i in 1..<pixelPoints.count {
                        path.addLine(to: pixelPoints[i])
                    }
                    path.stroke()
                }
            }
        }
        
        // Create CIImage from the mask and crop to original image extent
        let ciMask = CIImage(image: maskImage)
        let cropRect = CGRect(x: edgeMargin, y: edgeMargin, width: imageSize.width, height: imageSize.height)
        return ciMask?.cropped(to: cropRect)
    }
}
