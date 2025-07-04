import Foundation

final class SearchCache {
    private var cache: [String: [Screenshot]] = [:]
    private var accessTimes: [String: Date] = [:]
    private let maxCacheSize = 50
    private let cacheExpirationTime: TimeInterval = 300 // 5 minutes
    
    func getCachedResults(for query: String) -> [Screenshot]? {
        let cacheKey = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let cachedResults = cache[cacheKey],
              let accessTime = accessTimes[cacheKey],
              Date().timeIntervalSince(accessTime) < cacheExpirationTime else {
            // Remove expired entry
            cache.removeValue(forKey: cacheKey)
            accessTimes.removeValue(forKey: cacheKey)
            return nil
        }
        
        // Update access time
        accessTimes[cacheKey] = Date()
        return cachedResults
    }
    
    func setCachedResults(_ results: [Screenshot], for query: String) {
        let cacheKey = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Don't cache empty queries or very short queries
        guard cacheKey.count >= 2 else { return }
        
        // Ensure cache doesn't exceed max size
        if cache.count >= maxCacheSize {
            cleanupOldestEntries()
        }
        
        cache[cacheKey] = results
        accessTimes[cacheKey] = Date()
    }
    
    func clearCache() {
        cache.removeAll()
        accessTimes.removeAll()
    }
    
    private func cleanupOldestEntries() {
        let sortedByAccessTime = accessTimes.sorted { $0.value < $1.value }
        let entriesToRemove = sortedByAccessTime.prefix(maxCacheSize / 4) // Remove 25% of entries
        
        for (key, _) in entriesToRemove {
            cache.removeValue(forKey: key)
            accessTimes.removeValue(forKey: key)
        }
    }
}