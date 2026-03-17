// PaywallContext.swift
// Cloaky
//
// Context enum for customizing paywall messages based on trigger location.

enum PaywallContext {
    case onboarding
    case trialExhausted
    case manualUpgrade
    
    var title: String {
        switch self {
        case .onboarding:
            return "Version payante"
        case .trialExhausted:
            return "Vous avez utilisé vos 3 images gratuites"
        case .manualUpgrade:
            return "Passer à la version payante"
        }
    }
    
    var subtitle: String {
        switch self {
        case .onboarding:
            return "Accès complet à toutes les fonctionnalités"
        case .trialExhausted:
            return "Débloquez la version complète pour continuer à flouter vos photos sans limite"
        case .manualUpgrade:
            return "Débloquez toutes les fonctionnalités premium"
        }
    }
}
