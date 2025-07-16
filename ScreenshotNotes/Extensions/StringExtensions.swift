import Foundation

// MARK: - String Extensions for Natural Language Search

extension String {
    /// Finds all matches of a regex pattern in the string
    func matches(of pattern: String) -> [Substring] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return []
        }
        
        let matches = regex.matches(in: self, options: [], range: NSRange(location: 0, length: self.utf16.count))
        return matches.compactMap { match in
            guard let range = Range(match.range, in: self) else { return nil }
            return self[range]
        }
    }
    
    /// Checks if the string contains a regex pattern
    func contains(regex pattern: String) -> Bool {
        return range(of: pattern, options: .regularExpression) != nil
    }
    
    /// Case-insensitive contains check
    func localizedCaseInsensitiveContains(_ substring: String) -> Bool {
        return range(of: substring, options: .caseInsensitive) != nil
    }
    
    /// Case-insensitive hasPrefix check
    func localizedCaseInsensitiveHasPrefix(_ prefix: String) -> Bool {
        return lowercased().hasPrefix(prefix.lowercased())
    }
}