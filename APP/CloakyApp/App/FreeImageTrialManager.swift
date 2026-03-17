// FreeImageTrialManager.swift
// Cloaky
//
// Manages free trial usage for 3 selected images with iCloud sync.
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
    private let ubiquityStore = NSUbiquitousKeyValueStore.default
    private var cachedSnapshot: FreeImageTrialSnapshot?

    func loadSnapshot() -> FreeImageTrialSnapshot {
        if let cachedSnapshot { return cachedSnapshot }

        let local = readLocal()
        let cloud = readCloud()
        let merged = merge(local: local, cloud: cloud)

        cachedSnapshot = merged
        persist(merged)
        return merged
    }

    func refreshFromCloudIfNeeded() -> FreeImageTrialSnapshot {
        let current = cachedSnapshot ?? loadSnapshot()
        let cloud = readCloud()
        let merged = merge(local: current, cloud: cloud)

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

    private func merge(local: FreeImageTrialSnapshot?, cloud: FreeImageTrialSnapshot?) -> FreeImageTrialSnapshot {
        let localValue = local ?? .initial
        let cloudValue = cloud ?? .initial
        
        if localValue.usedImageCount < 0 || cloudValue.usedImageCount < 0 {
            return FreeImageTrialSnapshot(usedImageCount: 3, maxFreeImages: 3)
        }
        
        return FreeImageTrialSnapshot(
            usedImageCount: min(3, max(localValue.usedImageCount, cloudValue.usedImageCount)),
            maxFreeImages: 3
        )
    }

    private func readLocal() -> FreeImageTrialSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(FreeImageTrialSnapshot.self, from: data)
    }

    private func readCloud() -> FreeImageTrialSnapshot? {
        guard let data = ubiquityStore.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(FreeImageTrialSnapshot.self, from: data)
    }

    private func persist(_ snapshot: FreeImageTrialSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
        
        let iCloudAvailable = FileManager.default.ubiquityIdentityToken != nil
        if iCloudAvailable {
            ubiquityStore.set(data, forKey: storageKey)
            ubiquityStore.synchronize()
        }
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
        
        let iCloudAvailable = FileManager.default.ubiquityIdentityToken != nil
        if iCloudAvailable {
            ubiquityStore.removeObject(forKey: storageKey)
            ubiquityStore.synchronize()
        }
        
        #if DEBUG
        print("[FreeImageTrialManager] Trial reset to initial state")
        #endif
    }
}
