// CacheManager.swift
// Cloaky
//
// Centralized cache manager with automatic memory warning cleanup.

import Foundation
import UIKit

// MARK: - CacheEntry

private struct CacheEntry<T> {
    let value: T
    let expirationDate: Date
}

// MARK: - CacheManager

actor CacheManager {
    
    static let shared = CacheManager()
    
    // MARK: - Caches
    
    private var objectCache: [String: CacheEntry<AnyObject>] = [:]
    private var imageCache: [String: CacheEntry<UIImage>] = [:]
    
    private let objectCostLimit = 50 * 1024 * 1024 // 50 MB
    private let imageCostLimit = 100 * 1024 * 1024 // 100 MB
    
    private var objectCurrentCost: Int = 0
    private var imageCurrentCost: Int = 0
    
    private let ttlInterval: TimeInterval = 86400 // 24 hours
    
    // MARK: - Init
    
    private init() {}
    
    // MARK: - Object Cache
    
    func setObject(_ object: AnyObject, forKey key: String, cost: Int = 0) {
        let expirationDate = Date().addingTimeInterval(ttlInterval)
        let entry = CacheEntry(value: object, expirationDate: expirationDate)
        
        if let existing = objectCache[key] {
            objectCurrentCost -= cost
        }
        
        objectCache[key] = entry
        objectCurrentCost += cost
        
        enforceObjectLimit()
    }
    
    func object(forKey key: String) -> AnyObject? {
        guard let entry = objectCache[key] else { return nil }
        
        if entry.expirationDate > Date() {
            return entry.value
        } else {
            objectCache.removeValue(forKey: key)
            return nil
        }
    }
    
    func removeObject(forKey key: String) {
        objectCache.removeValue(forKey: key)
    }
    
    // MARK: - Image Cache
    
    func setImage(_ image: UIImage, forKey key: String) {
        let cost = Int(image.size.width * image.size.height * 4)
        let expirationDate = Date().addingTimeInterval(ttlInterval)
        let entry = CacheEntry(value: image, expirationDate: expirationDate)
        
        if let existing = imageCache[key] {
            imageCurrentCost -= cost
        }
        
        imageCache[key] = entry
        imageCurrentCost += cost
        
        enforceImageLimit()
    }
    
    func image(forKey key: String) -> UIImage? {
        guard let entry = imageCache[key] else { return nil }
        
        if entry.expirationDate > Date() {
            return entry.value
        } else {
            imageCache.removeValue(forKey: key)
            return nil
        }
    }
    
    func removeImage(forKey key: String) {
        imageCache.removeValue(forKey: key)
    }
    
    // MARK: - Memory Management
    
    func clearAll() {
        objectCache.removeAll()
        imageCache.removeAll()
        objectCurrentCost = 0
        imageCurrentCost = 0
    }
    
    // MARK: - Private
    
    private func enforceObjectLimit() {
        while objectCurrentCost > objectCostLimit && !objectCache.isEmpty {
            if let firstKey = objectCache.keys.first {
                objectCache.removeValue(forKey: firstKey)
                objectCurrentCost = 0
                for (_, entry) in objectCache {
                    objectCurrentCost += 1
                }
            }
        }
    }
    
    private func enforceImageLimit() {
        while imageCurrentCost > imageCostLimit && !imageCache.isEmpty {
            if let firstKey = imageCache.keys.first {
                imageCache.removeValue(forKey: firstKey)
                imageCurrentCost = 0
                for (_, entry) in imageCache {
                    imageCurrentCost += Int(entry.value.size.width * entry.value.size.height * 4)
                }
            }
        }
    }
}
