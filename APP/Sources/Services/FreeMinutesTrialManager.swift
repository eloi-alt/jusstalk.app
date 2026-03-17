// FreeMinutesTrialManager.swift
// Jusstalk
//
// Manages free trial usage for 3 transcriptions with iCloud sync.
// Each transcription is limited to 60 seconds max.

import Foundation

struct FreeMinutesTrialSnapshot: Codable, Sendable {
    var usedTranscriptionCount: Int
    let maxFreeTranscriptions: Int
    let maxSecondsPerTranscription: Int

    var remainingTranscriptions: Int {
        max(0, maxFreeTranscriptions - usedTranscriptionCount)
    }

    var hasRemainingTranscriptions: Bool {
        usedTranscriptionCount < maxFreeTranscriptions
    }

    static let initial = FreeMinutesTrialSnapshot(
        usedTranscriptionCount: 0,
        maxFreeTranscriptions: 3,
        maxSecondsPerTranscription: 60
    )
}

actor FreeMinutesTrialManager {
    static let shared = FreeMinutesTrialManager()

    private let storageKey = "free_trial_snapshot_v1"
    private var cachedSnapshot: FreeMinutesTrialSnapshot?
    private var iCloudAvailable: Bool = false

    init() {
        checkiCloudAvailability()
    }

    private func checkiCloudAvailability() {
        if FileManager.default.ubiquityIdentityToken != nil {
            do {
                _ = NSUbiquitousKeyValueStore.default
                iCloudAvailable = true
            } catch {
                iCloudAvailable = false
            }
        } else {
            iCloudAvailable = false
        }
    }

    func loadSnapshot() -> FreeMinutesTrialSnapshot {
        if let cachedSnapshot { return cachedSnapshot }

        let local = readLocal()
        let cloud = readCloud()
        let merged = merge(local: local, cloud: cloud)

        cachedSnapshot = merged
        persist(merged)
        return merged
    }

    func refreshFromCloudIfNeeded() -> FreeMinutesTrialSnapshot {
        let current = cachedSnapshot ?? loadSnapshot()
        let cloud = readCloud()
        let merged = merge(local: current, cloud: cloud)

        cachedSnapshot = merged
        persist(merged)
        return merged
    }

    func canConsumeTranscription(duration: TimeInterval, isPremium: Bool) -> Bool {
        if isPremium { return true }
        let snapshot = cachedSnapshot ?? loadSnapshot()
        let requested = Int(duration.rounded())
        return snapshot.hasRemainingTranscriptions && requested <= snapshot.maxSecondsPerTranscription
    }

    @discardableResult
    func consumeTranscription(duration: TimeInterval, isPremium: Bool) -> FreeMinutesTrialSnapshot {
        let snapshot = cachedSnapshot ?? loadSnapshot()

        guard !isPremium else { return snapshot }
        guard snapshot.hasRemainingTranscriptions else { return snapshot }
        
        let updated = FreeMinutesTrialSnapshot(
            usedTranscriptionCount: min(snapshot.maxFreeTranscriptions, snapshot.usedTranscriptionCount + 1),
            maxFreeTranscriptions: snapshot.maxFreeTranscriptions,
            maxSecondsPerTranscription: snapshot.maxSecondsPerTranscription
        )

        cachedSnapshot = updated
        persist(updated)
        
        #if DEBUG
        print("[FreeMinutesTrialManager] Consumed 1 transcription. Total used: \(updated.usedTranscriptionCount), remaining: \(updated.remainingTranscriptions)")
        #endif
        
        return updated
    }

    @discardableResult
    func rollbackLastConsumption() -> FreeMinutesTrialSnapshot {
        let snapshot = cachedSnapshot ?? loadSnapshot()
        guard snapshot.usedTranscriptionCount > 0 else { return snapshot }
        
        let updated = FreeMinutesTrialSnapshot(
            usedTranscriptionCount: max(0, snapshot.usedTranscriptionCount - 1),
            maxFreeTranscriptions: snapshot.maxFreeTranscriptions,
            maxSecondsPerTranscription: snapshot.maxSecondsPerTranscription
        )
        cachedSnapshot = updated
        persist(updated)
        
        #if DEBUG
        print("[FreeMinutesTrialManager] Rollback applied. usedTranscriptionCount: \(updated.usedTranscriptionCount)")
        #endif
        
        return updated
    }
    
    func checkAndConsumeIfEligible(duration: TimeInterval, isPremium: Bool) -> (canTranscribe: Bool, snapshot: FreeMinutesTrialSnapshot) {
        let snapshot = cachedSnapshot ?? loadSnapshot()
        
        if isPremium { 
            return (true, snapshot) 
        }
        
        let requested = Int(duration.rounded())
        
        guard snapshot.hasRemainingTranscriptions else {
            return (false, snapshot)
        }
        
        guard requested <= snapshot.maxSecondsPerTranscription else {
            return (false, snapshot)
        }
        
        let updated = consumeTranscription(duration: duration, isPremium: isPremium)
        return (true, updated)
    }
    
    func getMaxSecondsPerTranscription() -> Int {
        let snapshot = cachedSnapshot ?? loadSnapshot()
        return snapshot.maxSecondsPerTranscription
    }

    private func merge(local: FreeMinutesTrialSnapshot?, cloud: FreeMinutesTrialSnapshot?) -> FreeMinutesTrialSnapshot {
        let localValue = local ?? .initial
        let cloudValue = cloud ?? .initial
        
        if localValue.usedTranscriptionCount < 0 || cloudValue.usedTranscriptionCount < 0 {
            return FreeMinutesTrialSnapshot(usedTranscriptionCount: 3, maxFreeTranscriptions: 3, maxSecondsPerTranscription: 60)
        }
        
        return FreeMinutesTrialSnapshot(
            usedTranscriptionCount: min(3, max(localValue.usedTranscriptionCount, cloudValue.usedTranscriptionCount)),
            maxFreeTranscriptions: 3,
            maxSecondsPerTranscription: 60
        )
    }

    private func readLocal() -> FreeMinutesTrialSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(FreeMinutesTrialSnapshot.self, from: data)
    }

    private func readCloud() -> FreeMinutesTrialSnapshot? {
        guard iCloudAvailable else { return nil }
        guard let data = try? NSUbiquitousKeyValueStore.default.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(FreeMinutesTrialSnapshot.self, from: data)
    }

    private func persist(_ snapshot: FreeMinutesTrialSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
        
        if iCloudAvailable {
            do {
                try NSUbiquitousKeyValueStore.default.set(data, forKey: storageKey)
                NSUbiquitousKeyValueStore.default.synchronize()
            } catch {
                #if DEBUG
                print("[FreeMinutesTrialManager] iCloud sync failed: \(error)")
                #endif
            }
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
        
        if iCloudAvailable {
            do {
                try NSUbiquitousKeyValueStore.default.removeObject(forKey: storageKey)
                NSUbiquitousKeyValueStore.default.synchronize()
            } catch {
                #if DEBUG
                print("[FreeMinutesTrialManager] iCloud reset failed: \(error)")
                #endif
            }
        }
        
        #if DEBUG
        print("[FreeMinutesTrialManager] Trial reset to initial state")
        #endif
    }
}
