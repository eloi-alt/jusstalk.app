// PerformanceMonitor.swift
// Cloaky
//
// Performance monitoring utilities for profiling and optimization.

import Foundation
import os.log

// MARK: - PerformanceMonitor

/// Lightweight performance monitoring for measuring execution times
final class PerformanceMonitor {
    
    static let shared = PerformanceMonitor()
    
    private let logger = Logger(subsystem: "com.cloak", category: "Performance")
    
    /// Active timers
    private var timers: [String: CFAbsoluteTime] = [:]
    private let lock = NSLock()
    
    private init() {}
    
    // MARK: - Timing
    
    /// Start timing an operation
    func startTimer(_ label: String) {
        lock.lock()
        defer { lock.unlock() }
        timers[label] = CFAbsoluteTimeGetCurrent()
    }
    
    /// Stop timing and return elapsed time in seconds
    @discardableResult
    func stopTimer(_ label: String) -> TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        
        guard let startTime = timers[label] else {
            logger.warning("Timer '\(label)' not found")
            return 0
        }
        
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        timers.removeValue(forKey: label)
        
        #if DEBUG
        logger.info("⏱ \(label): \(String(format: "%.3f", elapsed))s")
        #endif
        
        return elapsed
    }
    
    /// Measure an async operation
    func measure<T>(_ label: String, operation: () async throws -> T) async rethrows -> T {
        startTimer(label)
        let result = try await operation()
        stopTimer(label)
        return result
    }
    
    /// Measure a synchronous operation
    func measure<T>(_ label: String, operation: () throws -> T) rethrows -> T {
        startTimer(label)
        let result = try operation()
        stopTimer(label)
        return result
    }
    
    // MARK: - Memory
    
    /// Current memory usage in MB
    var memoryUsageMB: Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return 0 }
        return Double(info.resident_size) / (1024 * 1024)
    }
    
    /// Log current memory usage
    func logMemory(_ label: String = "") {
        #if DEBUG
        let usage = memoryUsageMB
        logger.info("💾 Memory \(label): \(String(format: "%.1f", usage)) MB")
        #endif
    }
}
