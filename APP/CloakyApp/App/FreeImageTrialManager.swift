// FreeImageTrialManager.swift
// Cloaky
//
// Manages free trial usage for 3 selected images.
// iCloud sync removed to prevent trial bypass across devices.
// Consumption happens on image selection, BEFORE entering the editor.

import Foundation

struct FreeImageTrialSnapshot: Codable, Sendable {
    var usedImageCount: Int
    let maxFreeImages: Int

    var remainingImageCount: Int {
        max(0, maxFreeImages - usedImageCount)
    }

    var hasRemainingImages: Bool {
        usedImageCount < maxFreeImages
    }

    static let initial = FreeImageTrialSnapshot(
        usedImageCount: 0,
        maxFreeImages: 3
    )
}

actor FreeImageTrialManager {
    static let shared = FreeImageTrialManager()

    private let storageKey = "free_image_trial_snapshot_v1"
    private var cachedSnapshot: FreeImageTrialSnapshot?

    func loadSnapshot() -> FreeImageTrialSnapshot {
        if let cachedSnapshot { return cachedSnapshot }

        let local = readLocal()
        let merged = local ?? .initial

        cachedSnapshot = merged
        persist(merged)
        return merged
    }

    func refreshFromCloudIfNeeded() -> FreeImageTrialSnapshot {
        let current = cachedSnapshot ?? loadSnapshot()
        let merged = current

        cachedSnapshot = merged
        persist(merged)
        return merged
    }

    func canOpenNewImage(isPremium: Bool) -> Bool {
        if isPremium { return true }
        let snapshot = cachedSnapshot ?? loadSnapshot()
        return snapshot.hasRemainingImages
    }

    @discardableResult
    func consumeImageSelectionIfNeeded(isPremium: Bool) -> FreeImageTrialSnapshot {
        let snapshot = cachedSnapshot ?? loadSnapshot()

        guard !isPremium else { return snapshot }
        guard snapshot.usedImageCount < snapshot.maxFreeImages else { return snapshot }

        let updated = FreeImageTrialSnapshot(
            usedImageCount: min(snapshot.maxFreeImages, snapshot.usedImageCount + 1),
            maxFreeImages: snapshot.maxFreeImages
        )

        cachedSnapshot = updated
        persist(updated)
        return updated
    }

    @discardableResult
    func rollbackLastConsumptionForTechnicalFailure() -> FreeImageTrialSnapshot {
        let snapshot = cachedSnapshot ?? loadSnapshot()
        guard snapshot.usedImageCount > 0 else { return snapshot }
        let updated = FreeImageTrialSnapshot(
            usedImageCount: max(0, snapshot.usedImageCount - 1),
            maxFreeImages: snapshot.maxFreeImages
        )
        cachedSnapshot = updated
        persist(updated)
        #if DEBUG
        print("[FreeImageTrialManager] Rollback applied. usedImageCount: \(updated.usedImageCount)")
        #endif
        return updated
    }
    
    func checkAndConsumeIfEligible(isPremium: Bool) -> (canOpen: Bool, snapshot: FreeImageTrialSnapshot) {
        let snapshot = cachedSnapshot ?? loadSnapshot()
        if isPremium { return (true, snapshot) }
        guard snapshot.hasRemainingImages else { return (false, snapshot) }
        let updated = consumeImageSelectionIfNeeded(isPremium: isPremium)
        return (true, updated)
    }

    private func readLocal() -> FreeImageTrialSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(FreeImageTrialSnapshot.self, from: data)
    }

    private func persist(_ snapshot: FreeImageTrialSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    #if DEBUG
    func resetForDebugOnly() {
        cachedSnapshot = .initial
        persist(.initial)
    }
    #endif
    
    func resetTrial() {
        cachedSnapshot = .initial
        UserDefaults.standard.removeObject(forKey: storageKey)
        
        #if DEBUG
        print("[FreeImageTrialManager] Trial reset to initial state")
        #endif
    }
}
