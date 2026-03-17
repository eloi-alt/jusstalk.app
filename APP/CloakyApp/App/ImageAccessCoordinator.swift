// ImageAccessCoordinator.swift
// Cloaky
//
// Coordinates access decision when user selects a new image.
// Handles trial consumption logic and paywall triggering.

import Foundation

enum ImageAccessDecision: Sendable {
    case allow(snapshot: FreeImageTrialSnapshot, consumedTrial: Bool)
    case requirePaywall(snapshot: FreeImageTrialSnapshot)
}

actor ImageAccessCoordinator {
    static let shared = ImageAccessCoordinator()

    private var lastSelectionConsumedTrial = false

    func beginAccessForNewSelectedImage(isPremium: Bool) async -> ImageAccessDecision {
        let manager = FreeImageTrialManager.shared
        let (canOpen, snapshot) = await manager.checkAndConsumeIfEligible(isPremium: isPremium)
        
        if canOpen {
            if !isPremium {
                lastSelectionConsumedTrial = true
                return .allow(snapshot: snapshot, consumedTrial: true)
            } else {
                lastSelectionConsumedTrial = false
                return .allow(snapshot: snapshot, consumedTrial: false)
            }
        } else {
            lastSelectionConsumedTrial = false
            return .requirePaywall(snapshot: snapshot)
        }
    }

    func rollbackIfImageLoadFailed() async -> FreeImageTrialSnapshot {
        guard lastSelectionConsumedTrial else {
            return await FreeImageTrialManager.shared.loadSnapshot()
        }

        lastSelectionConsumedTrial = false
        return await FreeImageTrialManager.shared.rollbackLastConsumptionForTechnicalFailure()
    }

    func clearReservationFlagAfterSuccessfulEditorEntry() {
        lastSelectionConsumedTrial = false
    }
}
