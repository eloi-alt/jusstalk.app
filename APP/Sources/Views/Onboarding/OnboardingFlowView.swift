// OnboardingFlowView.swift
// Jusstalk
//
// Premium onboarding flow with 3 cinematic screens before reaching ContentView.

import SwiftUI
import StoreKit

// MARK: - Onboarding Page

enum OnboardingPage: Int, CaseIterable, Hashable {
    case hero = 0
    case demo = 1
    case cta = 2
    
    var title: String {
        switch self {
        case .hero: return "Hero"
        case .demo: return "Demo"
        case .cta: return "CTA"
        }
    }
}

struct OnboardingFlowView: View {
    let onFinish: () -> Void
    let onPurchaseComplete: () -> Void
    
    @EnvironmentObject private var storeManager: StoreManager
    @State private var currentPage: OnboardingPage = .hero
    
    private var totalPages: Int {
        OnboardingPage.allCases.count
    }
    
    var body: some View {
        GeometryReader { geometry in
            let safeTop = geometry.safeAreaInsets.top
            let safeBottom = geometry.safeAreaInsets.bottom
            
            ZStack {
                AnimatedBackground()
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if currentPage != .cta {
                        skipButton
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.top, max(16, safeTop))
                            .padding(.trailing, 24)
                    }
                    
                    TabView(selection: $currentPage) {
                        HeroPageView()
                            .tag(OnboardingPage.hero)
                        
                        DemoPageView()
                            .tag(OnboardingPage.demo)
                        
                        CTAPageJusstalkView(
                            onPurchaseComplete: onPurchaseComplete,
                            onTryFree: onFinish
                        )
                        .tag(OnboardingPage.cta)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    pageIndicator
                    
                    if currentPage != .cta {
                        ctaButton
                            .padding(.horizontal, 24)
                            .padding(.bottom, max(24, safeBottom))
                    } else {
                        Spacer()
                            .frame(height: max(24, safeBottom))
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.clear)
        .task {
            await storeManager.loadProducts()
            await storeManager.checkCurrentEntitlements()
        }
    }
    
    // MARK: - Skip Button
    
    private var skipButton: some View {
        Button {
            withAnimation {
                currentPage = .cta
            }
        } label: {
            Text("Passer")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
    }
    
    // MARK: - Page Indicator
    
    private var pageIndicator: some View {
        VStack(spacing: 8) {
            ProgressView(value: Double(currentPage.rawValue + 1), total: Double(totalPages))
                .progressViewStyle(LinearProgressViewStyle(tint: .white))
                .frame(maxWidth: 200)
            
            Text("Page \(currentPage.rawValue + 1) / \(totalPages)")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - CTA Button
    
    private var ctaButton: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                if let nextPage = OnboardingPage(rawValue: currentPage.rawValue + 1) {
                    currentPage = nextPage
                } else {
                    onFinish()
                }
            }
        } label: {
            HStack {
                Text(currentPage.rawValue < totalPages - 1 ? "Continuer" : "Commencer")
                    .fontWeight(.semibold)
                
                if currentPage.rawValue < totalPages - 1 {
                    Image(systemName: "arrow.right")
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [.blue, .blue.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(14)
            .shadow(color: .blue.opacity(0.4), radius: 8, y: 4)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct OnboardingFlowView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingFlowView(
            onFinish: {},
            onPurchaseComplete: {}
        )
        .environmentObject(StoreManager())
    }
}
#endif
