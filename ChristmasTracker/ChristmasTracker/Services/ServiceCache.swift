//
//  ServiceCache.swift
//  ChristmasTracker
//
//  Created by Brian Alberta on 11/14/22.
//

import Foundation


class ServiceCache {
    
    enum CacheError: Error {
        case networkError
        case unknown
        case invalidURL
        case decoder(error: Error)
        case url(error: URLError)
    }
    
    typealias CacheEntry = [Int: CacheValue]
    typealias CacheValue = (data: Data, response: URLResponse)
    
    static let shared = ServiceCache()
    var cache: CacheEntry = [:]
    
    
    private init() {
        NotificationCenter.default.addObserver(self, selector: #selector(clearCache), name: Notification.Name("purchaseStatusChanged"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(clearCache), name: Notification.Name("newItemAdded"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(clearCache), name: Notification.Name("itemDeleted"), object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: Notification.Name("purchaseStatusChanged"), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("newItemAdded"), object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("itemDeleted"), object: nil)
    }
    
    
    func fetchNetworkResponse(request: URLRequest) async throws -> CacheValue {
        
        guard let computedHash = Self.computeHash(data: request),
              let cachedValue = Self.shared.cache[computedHash] else {
            do {
                let data = try await URLSession.shared.data(for: request)
                self.saveResponseToCache(request: request, data: data)
                return data
                
            } catch {
                LogUtility.logServiceError(message: "ListService.getListOverviewByUser",
                                           error: CacheError.unknown)
                throw CacheError.unknown
            }
        }
        return cachedValue
    }
    
    
    func saveResponseToCache(request: URLRequest, data: CacheValue) {
        guard let httpResponse = data.response as? HTTPURLResponse,
                httpResponse.statusCode == 200,
                let computedHash = Self.computeHash(data: request) else {
            return
        }
        
        Self.shared.cache[computedHash] = data
    }
    
    @objc public func clearCache() {
        Self.shared.cache = [:]
    }
    
    static func computeHash(data: URLRequest) -> Int? {
        let urlPath = data.url
        let body = data.hashValue
        var hasher = Hasher()
        hasher.combine(urlPath)
        hasher.combine(body)
        let hash = hasher.finalize()
        return hash
    }
}
