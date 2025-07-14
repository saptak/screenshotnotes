import Foundation
import SwiftUI
import OSLog

/// Safe JSON encoding/decoding utilities with comprehensive error handling
/// Implements Iteration 8.5.2.2: JSON Encoding/Decoding Safety
@MainActor
struct SafeCoding {
    private static let logger = Logger(subsystem: "com.screenshotnotes.app", category: "SafeCoding")
    
    // MARK: - Safe Encoding
    
    /// Safely encodes any Codable type with error handling and recovery
    static func encode<T: Codable>(
        _ value: T,
        context: ErrorContext = .general,
        source: String = #function
    ) async -> Result<Data, AppError> {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            
            let data = try encoder.encode(value)
            logger.info("Successfully encoded \(String(describing: T.self)) - Size: \(data.count) bytes")
            return .success(data)
            
        } catch let encodingError as EncodingError {
            let appError = AppError.from(encodingError, context: context, source: source)
            logger.error("Encoding failed: \(appError.logDescription)")
            
            // Attempt recovery with alternative encoding
            return await attemptAlternativeEncoding(value, context: context, source: source)
            
        } catch {
            let appError = AppError.from(error, context: context, source: source)
            logger.error("Unexpected encoding error: \(appError.logDescription)")
            return .failure(appError)
        }
    }
    
    /// Safe encoding with automatic backup creation
    static func encodeWithBackup<T: Codable>(
        _ value: T,
        to url: URL,
        context: ErrorContext = .general,
        source: String = #function
    ) async -> Result<Void, AppError> {
        let result = await encode(value, context: context, source: source)
        
        switch result {
        case .success(let data):
            // Create backup of existing file if it exists
            let backupURL = url.appendingPathExtension("backup")
            if Foundation.FileManager.default.fileExists(atPath: url.path) {
                try? Foundation.FileManager.default.copyItem(at: url, to: backupURL)
            }
            
            do {
                try data.write(to: url)
                logger.info("Successfully wrote encoded data to \(url.lastPathComponent)")
                return .success(())
            } catch {
                let appError = AppError.from(error, context: context, source: source)
                logger.error("Failed to write encoded data: \(appError.logDescription)")
                return .failure(appError)
            }
            
        case .failure(let error):
            return .failure(error)
        }
    }
    
    // MARK: - Safe Decoding
    
    /// Safely decodes JSON data with error handling and recovery
    static func decode<T: Codable>(
        _ type: T.Type,
        from data: Data,
        context: ErrorContext = .general,
        source: String = #function
    ) async -> Result<T, AppError> {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let value = try decoder.decode(type, from: data)
            logger.info("Successfully decoded \(String(describing: type)) - Size: \(data.count) bytes")
            return .success(value)
            
        } catch let decodingError as DecodingError {
            let appError = AppError.from(decodingError, context: context, source: source)
            logger.error("Decoding failed: \(appError.logDescription)")
            
            // Attempt recovery with alternative decoding strategies
            return await attemptAlternativeDecoding(type, from: data, context: context, source: source)
            
        } catch {
            let appError = AppError.from(error, context: context, source: source)
            logger.error("Unexpected decoding error: \(appError.logDescription)")
            return .failure(appError)
        }
    }
    
    /// Safe decoding from file with backup restoration
    static func decodeFromFile<T: Codable>(
        _ type: T.Type,
        from url: URL,
        context: ErrorContext = .general,
        source: String = #function
    ) async -> Result<T, AppError> {
        do {
            let data = try Data(contentsOf: url)
            return await decode(type, from: data, context: context, source: source)
            
        } catch {
            logger.warning("Failed to read from primary file, attempting backup restoration")
            
            // Try backup file
            let backupURL = url.appendingPathExtension("backup")
            if Foundation.FileManager.default.fileExists(atPath: backupURL.path) {
                do {
                    let backupData = try Data(contentsOf: backupURL)
                    let result = await decode(type, from: backupData, context: context, source: source)
                    
                    if case .success = result {
                        // Restore from backup
                        try? Foundation.FileManager.default.removeItem(at: url)
                        try? Foundation.FileManager.default.copyItem(at: backupURL, to: url)
                        logger.info("Successfully restored from backup: \(url.lastPathComponent)")
                    }
                    
                    return result
                } catch {
                    let appError = AppError.from(error, context: context, source: source)
                    logger.error("Backup restoration failed: \(appError.logDescription)")
                    return .failure(appError)
                }
            }
            
            let appError = AppError.from(error, context: context, source: source)
            logger.error("File reading failed: \(appError.logDescription)")
            return .failure(appError)
        }
    }
    
    // MARK: - Recovery Strategies
    
    private static func attemptAlternativeEncoding<T: Codable>(
        _ value: T,
        context: ErrorContext,
        source: String
    ) async -> Result<Data, AppError> {
        logger.info("Attempting alternative encoding strategies")
        
        // Strategy 1: Use different output formatting
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .secondsSince1970
            encoder.outputFormatting = [.sortedKeys]
            
            let data = try encoder.encode(value)
            logger.info("Alternative encoding (secondsSince1970) succeeded")
            return .success(data)
        } catch {
            logger.warning("Alternative encoding strategy 1 failed")
        }
        
        // Strategy 2: Use property list encoding for compatible types
        if let plistValue = value as? NSCoding {
            do {
                let data = try NSKeyedArchiver.archivedData(withRootObject: plistValue, requiringSecureCoding: false)
                logger.info("Property list encoding succeeded")
                return .success(data)
            } catch {
                logger.warning("Property list encoding failed")
            }
        }
        
        // All strategies failed
        let error = AppError(
            type: .data(.encodingFailed),
            context: context,
            severity: .error,
            source: source,
            originalError: nil,
            retryAttempt: 0,
            timestamp: Date(),
            recoveryStrategy: nil,
            retryStrategy: nil,
            requiresUserFeedback: true
        )
        return .failure(error)
    }
    
    private static func attemptAlternativeDecoding<T: Codable>(
        _ type: T.Type,
        from data: Data,
        context: ErrorContext,
        source: String
    ) async -> Result<T, AppError> {
        logger.info("Attempting alternative decoding strategies")
        
        // Strategy 1: Use different date decoding strategy
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            
            let value = try decoder.decode(type, from: data)
            logger.info("Alternative decoding (secondsSince1970) succeeded")
            return .success(value)
        } catch {
            logger.warning("Alternative decoding strategy 1 failed")
        }
        
        // Strategy 2: Use millisecondsSince1970 for timestamps
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .millisecondsSince1970
            
            let value = try decoder.decode(type, from: data)
            logger.info("Alternative decoding (millisecondsSince1970) succeeded")
            return .success(value)
        } catch {
            logger.warning("Alternative decoding strategy 2 failed")
        }
        
        // Strategy 3: Try property list decoding for compatible types
        if type is NSCoding.Type {
            do {
                if let plistValue = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? T {
                    logger.info("Property list decoding succeeded")
                    return .success(plistValue)
                }
            } catch {
                logger.warning("Property list decoding failed")
            }
        }
        
        // All strategies failed
        let error = AppError(
            type: .data(.decodingFailed),
            context: context,
            severity: .error,
            source: source,
            originalError: nil,
            retryAttempt: 0,
            timestamp: Date(),
            recoveryStrategy: nil,
            retryStrategy: nil,
            requiresUserFeedback: true
        )
        return .failure(error)
    }
}

// MARK: - Safe UserDefaults Extension

extension UserDefaults {
    /// Safely store Codable objects with error handling
    func setCodable<T: Codable>(_ value: T, forKey key: String) async -> Bool {
        let result = await SafeCoding.encode(value, context: .general, source: "UserDefaults.setCodable")
        
        switch result {
        case .success(let data):
            set(data, forKey: key)
            return true
        case .failure(let error):
            await AppErrorHandler.shared.handle(error, context: .general, source: "UserDefaults.setCodable")
            return false
        }
    }
    
    /// Safely retrieve Codable objects with error handling
    func getCodable<T: Codable>(_ type: T.Type, forKey key: String) async -> T? {
        guard let data = data(forKey: key) else { return nil }
        
        let result = await SafeCoding.decode(type, from: data, context: .general, source: "UserDefaults.getCodable")
        
        switch result {
        case .success(let value):
            return value
        case .failure(let error):
            await AppErrorHandler.shared.handle(error, context: .general, source: "UserDefaults.getCodable")
            return nil
        }
    }
}

// MARK: - Safe File Operations

@MainActor
struct SafeFileOperations {
    private static let logger = Logger(subsystem: "com.screenshotnotes.app", category: "SafeFileOperations")
    
    /// Safely read file with error handling and recovery
    static func readFile(at url: URL, context: ErrorContext = .general) async -> Result<Data, AppError> {
        do {
            let data = try Data(contentsOf: url)
            logger.info("Successfully read file: \(url.lastPathComponent) (\(data.count) bytes)")
            return .success(data)
        } catch {
            let appError = AppError.from(error, context: context, source: "SafeFileOperations.readFile")
            logger.error("File read failed: \(appError.logDescription)")
            return .failure(appError)
        }
    }
    
    /// Safely write file with atomic operations and backup
    static func writeFile(data: Data, to url: URL, context: ErrorContext = .general) async -> Result<Void, AppError> {
        let tempURL = url.appendingPathExtension("tmp")
        
        do {
            // Write to temporary file first
            try data.write(to: tempURL)
            
            // Create backup if original exists
            if Foundation.FileManager.default.fileExists(atPath: url.path) {
                let backupURL = url.appendingPathExtension("backup")
                try? Foundation.FileManager.default.removeItem(at: backupURL)
                try Foundation.FileManager.default.copyItem(at: url, to: backupURL)
            }
            
            // Atomic move
            try Foundation.FileManager.default.moveItem(at: tempURL, to: url)
            
            logger.info("Successfully wrote file: \(url.lastPathComponent) (\(data.count) bytes)")
            return .success(())
            
        } catch {
            // Clean up temp file
            try? Foundation.FileManager.default.removeItem(at: tempURL)
            
            let appError = AppError.from(error, context: context, source: "SafeFileOperations.writeFile")
            logger.error("File write failed: \(appError.logDescription)")
            return .failure(appError)
        }
    }
    
    /// Safely delete file with backup preservation
    static func deleteFile(at url: URL, preserveBackup: Bool = true, context: ErrorContext = .general) async -> Result<Void, AppError> {
        do {
            if preserveBackup && Foundation.FileManager.default.fileExists(atPath: url.path) {
                let backupURL = url.appendingPathExtension("deleted")
                try? Foundation.FileManager.default.removeItem(at: backupURL)
                try Foundation.FileManager.default.copyItem(at: url, to: backupURL)
            }
            
            try Foundation.FileManager.default.removeItem(at: url)
            logger.info("Successfully deleted file: \(url.lastPathComponent)")
            return .success(())
            
        } catch {
            let appError = AppError.from(error, context: context, source: "SafeFileOperations.deleteFile")
            logger.error("File deletion failed: \(appError.logDescription)")
            return .failure(appError)
        }
    }
}