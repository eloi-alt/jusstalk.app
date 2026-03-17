// BeforeAfterSlider.swift
// Cloaky
//
// Before/After comparison slider for comparing original and processed images.

import SwiftUI

// MARK: - BeforeAfterSlider

/// Interactive slider comparing original and processed images
struct BeforeAfterSlider: View {
    
    let beforeImage: UIImage
    let afterImage: UIImage
    @Binding var sliderPosition: Double
    
    @State private var isDragging = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // After (processed) image — full background
                Image(uiImage: afterImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                
                // Before (original) image — masked by slider
                Image(uiImage: beforeImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .mask(
                        HStack(spacing: 0) {
                            Rectangle()
                                .frame(width: geometry.size.width * sliderPosition)
                            Spacer(minLength: 0)
                        }
                    )
                
                // Slider line - plus fine
                Rectangle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 2)
                    .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 0)
                    .position(
                        x: geometry.size.width * sliderPosition,
                        y: geometry.size.height / 2
                    )
                
                // Slider handle - plus sobre
                Circle()
                    .fill(Color.white)
                    .frame(width: isDragging ? 36 : 32, height: isDragging ? 36 : 32)
                    .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 1)
                    .overlay(
                        HStack(spacing: 3) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 9, weight: .semibold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundColor(.secondary)
                    )
                    .position(
                        x: geometry.size.width * sliderPosition,
                        y: geometry.size.height / 2
                    )
                    .animation(.spring(response: 0.25), value: isDragging)
                
                // Labels - plus petites et discrètes
                VStack {
                    HStack {
                        // Before label
                        Text(String(localized: "slider.original", defaultValue: "Original"))
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(4)
                            .opacity(sliderPosition > 0.1 ? 1 : 0)
                        
                        Spacer()
                        
                        // After label
                        Text(String(localized: "slider.blurred", defaultValue: "Blurred"))
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(4)
                            .opacity(sliderPosition < 0.9 ? 1 : 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 10)
                    
                    Spacer()
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        let newPosition = value.location.x / geometry.size.width
                        sliderPosition = max(0, min(1, newPosition))
                        
                        // Haptic at center
                        if abs(sliderPosition - 0.5) < 0.02 {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        }
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
        }
        .cornerRadius(8)
        .accessibilityLabel(String(localized: "slider.accessibility.label", defaultValue: "Before/After comparison"))
        .accessibilityHint(String(localized: "slider.accessibility.hint", defaultValue: "Drag to compare the original and blurred image"))
    }
}
