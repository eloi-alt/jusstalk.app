// FreeTrialManager.swift
// Jusstalk
//
// Manages free trial usage with atomic reservation/commit/rollback flow.
// Ensures trials are only consumed AFTER successful transcription.
// iCloud sync removed to prevent trial bypass across devices.

import Foundation
import OSLog

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
    private let reservationTimeoutSeconds: TimeInterval = 600

    func loadSnapshot() -> FreeTrialSnapshot {
        let local = readLocal()
        var merged = local ?? .initial

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
        var merged = current

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

        AppLogger.debug("Reserved trial. ReservationID: \(reservation.id), remaining: \(updatedSnapshot.remainingTranscriptions)", category: AppLogger.trial)

        return .reserved(reservation, snapshot: updatedSnapshot)
    }

    func commitTrialReservation(_ reservationID: UUID) -> FreeTrialSnapshot {
        guard let reservation = currentReservation, reservation.id == reservationID else {
            AppLogger.debug("Commit failed: reservation not found or ID mismatch", category: AppLogger.trial)
            return cachedSnapshot ?? loadSnapshot()
        }

        var snapshot = cachedSnapshot ?? loadSnapshot()

        guard snapshot.pendingReservationID == reservationID else {
            AppLogger.debug("Commit failed: pending reservation ID mismatch", category: AppLogger.trial)
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

        AppLogger.debug("Committed trial. Total used: \(snapshot.usedTranscriptionCount), remaining: \(snapshot.remainingTranscriptions)", category: AppLogger.trial)

        return snapshot
    }

    func rollbackTrialReservation(_ reservationID: UUID) -> FreeTrialSnapshot {
        guard currentReservation?.id == reservationID else {
            AppLogger.debug("Rollback: no matching reservation found", category: AppLogger.trial)
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

        AppLogger.debug("Rolled back trial. usedTranscriptionCount: \(snapshot.usedTranscriptionCount)", category: AppLogger.trial)

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

            AppLogger.debug("Cleared expired reservation", category: AppLogger.trial)
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

    private func readLocal() -> FreeTrialSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(FreeTrialSnapshot.self, from: data)
    }

    private func persist(_ snapshot: FreeTrialSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
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

        AppLogger.debug("Trial reset to initial state", category: AppLogger.trial)
    }
}

typealias FreeMinutesTrialManager = FreeTrialManager
typealias FreeMinutesTrialSnapshot = FreeTrialSnapshot
