// DetectionOverlay.swift
// Cloaky
//
// Overlay view rendering detection bounding boxes on images.
// Supports selection toggling with visual feedback.

import SwiftUI

// MARK: - DetectionOverlay

/// Renders bounding boxes over detected biometric regions
struct DetectionOverlay: View {

    let detections: DetectionResults
    let imageSize: CGSize
    let selectedRegions: Set<UUID>
    let deselectedRegions: Set<UUID>
    let onToggleRegion: (UUID) -> Void
    let allowToggle: Bool

    var body: some View {
        GeometryReader { geometry in
            let scale = calculateScale(geometry: geometry)
            let offset = calculateOffset(geometry: geometry, scale: scale)

            ZStack {
                // Render all regions (both selected and deselected)
                ForEach(detections.allRegions.map { RegionWrapper(region: $0) }) { wrapper in
                    let isSelected = selectedRegions.contains(wrapper.id)
                    let isDeselected = deselectedRegions.contains(wrapper.id)
                    let scaledRect = scaleRect(
                        wrapper.boundingBox,
                        scale: scale,
                        offset: offset
                    )

                    DetectionBox(
                        rect: scaledRect,
                        type: wrapper.type,
                        confidence: wrapper.confidence,
                        isSelected: isSelected,
                        isDeselected: isDeselected,
                        onTap: {
                            onToggleRegion(wrapper.id)
                        },
                        allowToggle: allowToggle
                    )
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedRegions)
        }
    }
    
    // MARK: - Coordinate Calculations
    
    private func calculateScale(geometry: GeometryProxy) -> CGFloat {
        let widthScale = geometry.size.width / imageSize.width
        let heightScale = geometry.size.height / imageSize.height
        return min(widthScale, heightScale)
    }
    
    private func calculateOffset(geometry: GeometryProxy, scale: CGFloat) -> CGPoint {
        let scaledWidth = imageSize.width * scale
        let scaledHeight = imageSize.height * scale
        return CGPoint(
            x: (geometry.size.width - scaledWidth) / 2,
            y: (geometry.size.height - scaledHeight) / 2
        )
    }
    
    /// Convert a bounding box from CIImage coordinates (bottom-left origin)
    /// to SwiftUI view coordinates (top-left origin) for display.
    private func scaleRect(_ rect: CGRect, scale: CGFloat, offset: CGPoint) -> CGRect {
        // Flip Y: CIImage origin is bottom-left, SwiftUI origin is top-left.
        let flippedY = imageSize.height - rect.origin.y - rect.height
        return CGRect(
            x: rect.origin.x * scale + offset.x,
            y: flippedY * scale + offset.y,
            width: rect.width * scale,
            height: rect.height * scale
        )
    }
}

// MARK: - Detection Box

/// Individual bounding box for a detected region
struct DetectionBox: View {
    let rect: CGRect
    let type: BiometricType
    let confidence: Float
    let isSelected: Bool
    let isDeselected: Bool
    let onTap: () -> Void
    let allowToggle: Bool

    private var boxColor: Color {
        if isDeselected {
            return Color.gray.opacity(0.5)
        }
        // Couleurs différentes selon le type de détection
        switch type {
        case .text:
            return isSelected ? Color.blue.opacity(0.8) : Color.cyan.opacity(0.7)
        case .face:
            return isSelected ? Color.red.opacity(0.8) : Color.pink.opacity(0.7)
        case .hand:
            return isSelected ? Color.orange.opacity(0.8) : Color.yellow.opacity(0.7)
        case .iris:
            return isSelected ? Color.purple.opacity(0.8) : Color.indigo.opacity(0.7)
        }
    }

    var body: some View {
        ZStack {
            // Bounding box
            RoundedRectangle(cornerRadius: 4)
                .stroke(boxColor, lineWidth: isDeselected ? 1 : (isSelected ? 2 : 1.5))
                .background(boxColor.opacity(isDeselected ? 0.03 : (isSelected ? 0.08 : 0.05)))
                .frame(width: max(rect.width, 1), height: max(rect.height, 1))

            // Label
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Text(type.rawValue)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(isDeselected ? Color.gray : .white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(isDeselected ? Color.gray.opacity(0.3) : boxColor)
                        .cornerRadius(3)
                        .offset(x: 4, y: -14)

                    Spacer()
                }
                Spacer()
            }

            // Bouton pour toggle la sélection (uniquement si allowToggle est true)
            if allowToggle {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Spacer()
                        Button(action: onTap) {
                            ZStack {
                                Circle()
                                    .fill(isDeselected ? Color.green : Color.red)
                                    .frame(width: 24, height: 24)
                                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)

                                Image(systemName: isDeselected ? "arrow.counterclockwise" : "xmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .offset(x: 12, y: -12)
                        .transition(.scale.combined(with: .opacity))
                    }
                    Spacer()
                }
            }
        }
        // Frame principal avec zone de toucher élargie
        .frame(width: max(rect.width + 40, 60), height: max(rect.height + 40, 60))
        .position(x: rect.midX, y: rect.midY)
        .contentShape(Rectangle())
        .onTapGesture {
            if allowToggle {
                onTap()
            }
        }
    }
}

// MARK: - Region Wrapper (for ForEach)

/// Type-erased wrapper for BiometricRegion to use with ForEach
struct RegionWrapper: Identifiable {
    let id: UUID
    let boundingBox: CGRect
    let confidence: Float
    let type: BiometricType
    
    init(region: any BiometricRegion) {
        self.id = region.id
        self.boundingBox = region.boundingBox
        self.confidence = region.confidence
        self.type = region.type
    }
}
