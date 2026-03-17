// ProgressBar.swift
// Cloaky
//
// Custom styled progress bar with gradient fill.

import SwiftUI

// MARK: - CloakyProgressBar

/// Custom progress bar with indigo-to-teal gradient fill
struct CloakyProgressBar: View {
    
    let progress: Double
    let height: CGFloat
    let showPercentage: Bool
    
    init(progress: Double, height: CGFloat = 20, showPercentage: Bool = true) {
        self.progress = progress
        self.height = height
        self.showPercentage = showPercentage
    }
    
    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color(.systemGray5))
                        .frame(height: height)
                    
                    // Gradient fill
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.indigo, .teal],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: max(0, geometry.size.width * CGFloat(min(progress, 1.0))),
                            height: height
                        )
                        .animation(.linear(duration: 0.3), value: progress)
                }
            }
            .frame(height: height)
            
            if showPercentage {
                Text("\(Int(min(progress, 1.0) * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct CloakyProgressBar_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            CloakyProgressBar(progress: 0.0)
            CloakyProgressBar(progress: 0.33)
            CloakyProgressBar(progress: 0.66)
            CloakyProgressBar(progress: 1.0)
        }
        .padding()
    }
}
#endif
