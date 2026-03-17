// FreeImageTrialViewModel.swift
// Cloaky
//
// ViewModel for UI to display trial status and badge.

import Foundation
import Combine

@MainActor
final class FreeImageTrialViewModel: ObservableObject {
    @Published private(set) var snapshot: FreeImageTrialSnapshot = .initial
    @Published private(set) var isLoaded = false

    var usedImageCount: Int { snapshot.usedImageCount }
    var remainingImageCount: Int { snapshot.remainingImageCount }
    var hasRemainingImages: Bool { snapshot.hasRemainingImages }

    func load() async {
        snapshot = await FreeImageTrialManager.shared.loadSnapshot()
        isLoaded = true
    }

    func refresh() async {
        snapshot = await FreeImageTrialManager.shared.refreshFromCloudIfNeeded()
    }

    func update(snapshot: FreeImageTrialSnapshot) {
        self.snapshot = snapshot
    }
}
