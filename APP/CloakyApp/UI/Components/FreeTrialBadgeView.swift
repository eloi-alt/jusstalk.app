// FreeTrialBadgeView.swift
// Cloaky
//
// Badge showing remaining free trial uses.

import SwiftUI

struct FreeTrialBadgeView: View {
    let remaining: Int
    
    var body: some View {
        if remaining > 0 {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                Text("\(remaining) essai\(remaining > 1 ? "s" : "") gratuit\(remaining > 1 ? "s" : "") restant\(remaining > 1 ? "s" : "")")
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .foregroundStyle(.secondary)
        }
    }
}

#if DEBUG
struct FreeTrialBadgeView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            FreeTrialBadgeView(remaining: 3)
            FreeTrialBadgeView(remaining: 2)
            FreeTrialBadgeView(remaining: 1)
            FreeTrialBadgeView(remaining: 0)
        }
        .padding()
    }
}
#endif
