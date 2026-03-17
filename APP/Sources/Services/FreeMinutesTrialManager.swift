// FreeTrialManager.swift
// Jusstalk
//
// Manages free trial usage with atomic reservation/commit/rollback flow.
// Ensures trials are only consumed AFTER successful transcription.

import Foundation

struct FreeTrialSnapshot: Codable, Sendable {
    var usedTranscriptionCount: Int
    var pendingReservationID: UUID?
    let maxFreeTranscriptions: Int
    let maxSecondsPerTranscription: Int

    var remainingTranscriptions: Int {
        max(0, maxFreeTranscriptions - usedTranscriptionCount)
    }

    var hasRemainingTranscriptions: Bool {
        usedTranscriptionCount < maxFreeTranscriptions
    }

    static let initial = FreeTrialSnapshot(
        usedTranscriptionCount: 0,
        pendingReservationID: nil,
        maxFreeTranscriptions: 3,
        maxSecondsPerTranscription: 60
    )
}

struct TrialReservation: Codable, Sendable, Identifiable {
    let id: UUID
    let createdAt: Date

    var isExpired: Bool {
        Date().timeIntervalSince(createdAt) > 600
    }
}

enum TrialReservationResult: Sendable {
    case premium
    case reserved(TrialReservation, snapshot: FreeTrialSnapshot)
    case denied(snapshot: FreeTrialSnapshot)
}

enum TrialConsumptionError: Error, LocalizedError {
    case noTranscriptionText
    case reservationExpired
    case reservationNotFound
    case transcriptionFailed(Error)

    var errorDescription: String? {
        switch self {
        case .noTranscriptionText:
            return "Transcription vide"
        case .reservationExpired:
            return "Réservation expirée"
        case .reservationNotFound:
            return "Réservation non trouvée"
        case .transcriptionFailed(let error):
            return "Transcription échouée: \(error.localizedDescription)"
        }
    }
}

actor FreeTrialManager {
    static let shared = FreeTrialManager()

    private let storageKey = "free_trial_snapshot_v2"
    private var cachedSnapshot: FreeTrialSnapshot?
    private var currentReservation: TrialReservation?
    private var iCloudAvailable: Bool = false
    private let reservationTimeoutSeconds: TimeInterval = 600

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

    func loadSnapshot() -> FreeTrialSnapshot {
        let local = readLocal()
        let cloud = readCloud()
        var merged = merge(local: local, cloud: cloud)

        merged = cleanupExpiredReservations(snapshot: merged)

        cachedSnapshot = merged
        
        if currentReservation == nil && merged.pendingReservationID != nil {
            merged = FreeTrialSnapshot(
                usedTranscriptionCount: merged.usedTranscriptionCount,
                pendingReservationID: nil,
                maxFreeTranscriptions: merged.maxFreeTranscriptions,
                maxSecondsPerTranscription: merged.maxSecondsPerTranscription
            )
            cachedSnapshot = merged
        }
        
        persist(merged)
        return merged
    }

    func refreshFromCloudIfNeeded() -> FreeTrialSnapshot {
        let current = cachedSnapshot ?? loadSnapshot()
        let cloud = readCloud()
        var merged = merge(local: current, cloud: cloud)

        merged = cleanupExpiredReservations(snapshot: merged)

        cachedSnapshot = merged
        persist(merged)
        return merged
    }

    func canStartTrial(isPremium: Bool) -> Bool {
        if isPremium { return true }
        let snapshot = loadSnapshot()
        return snapshot.hasRemainingTranscriptions
    }

    func reserveTrialIfEligible(isPremium: Bool) -> TrialReservationResult {
        if isPremium {
            return .premium
        }

        let snapshot = loadSnapshot()

        guard snapshot.hasRemainingTranscriptions else {
            return .denied(snapshot: snapshot)
        }

        let reservation = TrialReservation(
            id: UUID(),
            createdAt: Date()
        )

        currentReservation = reservation

        var updatedSnapshot = snapshot
        updatedSnapshot.pendingReservationID = reservation.id
        cachedSnapshot = updatedSnapshot

        #if DEBUG
        print("[FreeTrialManager] Reserved trial. ReservationID: \(reservation.id), remaining: \(updatedSnapshot.remainingTranscriptions)")
        #endif

        return .reserved(reservation, snapshot: updatedSnapshot)
    }

    func commitTrialReservation(_ reservationID: UUID) -> FreeTrialSnapshot {
        guard let reservation = currentReservation, reservation.id == reservationID else {
            #if DEBUG
            print("[FreeTrialManager] Commit failed: reservation not found or ID mismatch")
            #endif
            return cachedSnapshot ?? loadSnapshot()
        }

        var snapshot = cachedSnapshot ?? loadSnapshot()

        guard snapshot.pendingReservationID == reservationID else {
            #if DEBUG
            print("[FreeTrialManager] Commit failed: pending reservation ID mismatch")
            #endif
            return snapshot
        }

        snapshot = FreeTrialSnapshot(
            usedTranscriptionCount: snapshot.usedTranscriptionCount + 1,
            pendingReservationID: nil,
            maxFreeTranscriptions: snapshot.maxFreeTranscriptions,
            maxSecondsPerTranscription: snapshot.maxSecondsPerTranscription
        )

        currentReservation = nil
        cachedSnapshot = snapshot
        persist(snapshot)

        #if DEBUG
        print("[FreeTrialManager] Committed trial. Total used: \(snapshot.usedTranscriptionCount), remaining: \(snapshot.remainingTranscriptions)")
        #endif

        return snapshot
    }

    func rollbackTrialReservation(_ reservationID: UUID) -> FreeTrialSnapshot {
        guard currentReservation?.id == reservationID else {
            #if DEBUG
            print("[FreeTrialManager] Rollback: no matching reservation found")
            #endif
            return cachedSnapshot ?? loadSnapshot()
        }

        var snapshot = cachedSnapshot ?? loadSnapshot()

        snapshot = FreeTrialSnapshot(
            usedTranscriptionCount: snapshot.usedTranscriptionCount,
            pendingReservationID: nil,
            maxFreeTranscriptions: snapshot.maxFreeTranscriptions,
            maxSecondsPerTranscription: snapshot.maxSecondsPerTranscription
        )

        currentReservation = nil
        cachedSnapshot = snapshot
        persist(snapshot)

        #if DEBUG
        print("[FreeTrialManager] Rolled back trial. usedTranscriptionCount: \(snapshot.usedTranscriptionCount)")
        #endif

        return snapshot
    }

    func getCurrentReservation() -> TrialReservation? {
        return currentReservation
    }

    func clearReservationIfExpired() {
        guard let reservation = currentReservation else { return }

        if reservation.isExpired {
            var snapshot = cachedSnapshot ?? loadSnapshot()
            snapshot = FreeTrialSnapshot(
                usedTranscriptionCount: snapshot.usedTranscriptionCount,
                pendingReservationID: nil,
                maxFreeTranscriptions: snapshot.maxFreeTranscriptions,
                maxSecondsPerTranscription: snapshot.maxSecondsPerTranscription
            )
            currentReservation = nil
            cachedSnapshot = snapshot
            persist(snapshot)

            #if DEBUG
            print("[FreeTrialManager] Cleared expired reservation")
            #endif
        }
    }

    private func cleanupExpiredReservations(snapshot: FreeTrialSnapshot) -> FreeTrialSnapshot {
        guard let pendingID = snapshot.pendingReservationID else {
            return snapshot
        }

        if currentReservation?.id == pendingID && currentReservation?.isExpired == true {
            return FreeTrialSnapshot(
                usedTranscriptionCount: snapshot.usedTranscriptionCount,
                pendingReservationID: nil,
                maxFreeTranscriptions: snapshot.maxFreeTranscriptions,
                maxSecondsPerTranscription: snapshot.maxSecondsPerTranscription
            )
        }

        return snapshot
    }

    func checkDurationEligibility(duration: TimeInterval) -> (eligible: Bool, snapshot: FreeTrialSnapshot) {
        let snapshot = loadSnapshot()
        let requested = Int(duration.rounded())

        guard snapshot.hasRemainingTranscriptions else {
            return (false, snapshot)
        }

        guard requested <= snapshot.maxSecondsPerTranscription else {
            return (false, snapshot)
        }

        return (true, snapshot)
    }

    func getRemainingTranscriptions() -> Int {
        let snapshot = loadSnapshot()
        return snapshot.remainingTranscriptions
    }

    private func merge(local: FreeTrialSnapshot?, cloud: FreeTrialSnapshot?) -> FreeTrialSnapshot {
        let localValue = local ?? .initial
        let cloudValue = cloud ?? .initial

        if localValue.usedTranscriptionCount < 0 || cloudValue.usedTranscriptionCount < 0 {
            return FreeTrialSnapshot(
                usedTranscriptionCount: 3,
                pendingReservationID: nil,
                maxFreeTranscriptions: 3,
                maxSecondsPerTranscription: 60
            )
        }

        return FreeTrialSnapshot(
            usedTranscriptionCount: min(3, max(localValue.usedTranscriptionCount, cloudValue.usedTranscriptionCount)),
            pendingReservationID: localValue.pendingReservationID ?? cloudValue.pendingReservationID,
            maxFreeTranscriptions: 3,
            maxSecondsPerTranscription: 60
        )
    }

    private func readLocal() -> FreeTrialSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(FreeTrialSnapshot.self, from: data)
    }

    private func readCloud() -> FreeTrialSnapshot? {
        guard iCloudAvailable else { return nil }
        guard let data = try? NSUbiquitousKeyValueStore.default.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(FreeTrialSnapshot.self, from: data)
    }

    private func persist(_ snapshot: FreeTrialSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)

        if iCloudAvailable {
            do {
                try NSUbiquitousKeyValueStore.default.set(data, forKey: storageKey)
                NSUbiquitousKeyValueStore.default.synchronize()
            } catch {
                #if DEBUG
                print("[FreeTrialManager] iCloud sync failed: \(error)")
                #endif
            }
        }
    }

    #if DEBUG
    func resetForDebugOnly() {
        cachedSnapshot = .initial
        currentReservation = nil
        persist(.initial)
    }
    #endif

    func resetTrial() {
        cachedSnapshot = .initial
        currentReservation = nil
        UserDefaults.standard.removeObject(forKey: storageKey)

        if iCloudAvailable {
            do {
                try NSUbiquitousKeyValueStore.default.removeObject(forKey: storageKey)
                NSUbiquitousKeyValueStore.default.synchronize()
            } catch {
                #if DEBUG
                print("[FreeTrialManager] iCloud reset failed: \(error)")
                #endif
            }
        }

        #if DEBUG
        print("[FreeTrialManager] Trial reset to initial state")
        #endif
    }
}

typealias FreeMinutesTrialManager = FreeTrialManager
typealias FreeMinutesTrialSnapshot = FreeTrialSnapshot
