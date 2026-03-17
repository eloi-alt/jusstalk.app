// HapticManager.swift
// Cloaky
//
// Centralized haptic feedback manager.

import UIKit

// MARK: - HapticManager

/// Centralized manager for haptic feedback throughout the app
final class HapticManager {
    
    static let shared = HapticManager()
    
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()
    private let selection = UISelectionFeedbackGenerator()
    
    private init() {
        // Prepare generators
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        notification.prepare()
        selection.prepare()
    }
    
    // MARK: - Impact Feedback
    
    /// Light tap — used for selections, toggles
    func lightTap() {
        lightImpact.impactOccurred()
    }
    
    /// Medium tap — used for process start, important actions
    func mediumTap() {
        mediumImpact.impactOccurred()
    }
    
    /// Heavy tap — used for process complete, emphasis
    func heavyTap() {
        heavyImpact.impactOccurred()
    }
    
    // MARK: - Notification Feedback
    
    /// Success — export complete, save success
    func success() {
        notification.notificationOccurred(.success)
    }
    
    /// Warning — approaching limits, caution
    func warning() {
        notification.notificationOccurred(.warning)
    }
    
    /// Error — processing failed, permission denied
    func error() {
        notification.notificationOccurred(.error)
    }
    
    // MARK: - Selection Feedback
    
    /// Selection changed — slider movement, picker changes
    func selectionChanged() {
        selection.selectionChanged()
    }
}
