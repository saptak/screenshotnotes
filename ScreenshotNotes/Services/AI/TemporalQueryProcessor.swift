import Foundation
import SwiftUI
import OSLog

/// Advanced temporal query processing service for natural language date interpretation
/// Handles complex temporal expressions including vacations, events, and contextual periods
@MainActor
public final class TemporalQueryProcessor: ObservableObject {
    public static let shared = TemporalQueryProcessor()
    
    private let logger = Logger(subsystem: "com.screenshotnotes.app", category: "TemporalQueryProcessor")
    
    // MARK: - Published Properties
    
    @Published public private(set) var lastProcessedQuery: String = ""
    @Published public private(set) var detectedPeriods: [TemporalPeriod] = []
    @Published public private(set) var contextualEvents: [ContextualEvent] = []
    
    // MARK: - Configuration
    
    public struct TemporalSettings {
        var enableVacationDetection: Bool = true
        var enableEventContextRecognition: Bool = true
        var enableSeasonalAwareness: Bool = true
        var vacationKeywordThreshold: Int = 2
        var maxEventLookbackDays: Int = 365
        var confidenceThreshold: Double = 0.7
        
        public init() {}
    }
    
    @Published public var settings = TemporalSettings()
    
    // MARK: - Data Models
    
    /// Enhanced temporal period with contextual awareness
    public struct TemporalPeriod: Identifiable {
        public let id = UUID()
        let type: PeriodType
        let startDate: Date?
        let endDate: Date?
        let originalPhrase: String
        let confidence: Double
        let context: PeriodContext?
        let suggestedRefinements: [String]
        
        public enum PeriodType: String, CaseIterable {
            case absolute = "absolute"           // "March 15, 2023"
            case relative = "relative"           // "yesterday", "last week"
            case range = "range"                 // "last month", "past week"
            case namedPeriod = "named_period"    // "vacation", "work trip"
            case event = "event"                 // "meeting", "conference"
            case season = "season"               // "summer 2023"
            case holiday = "holiday"             // "Christmas", "New Year"
            case timeOfDay = "time_of_day"       // "morning", "evening"
            case dayOfWeek = "day_of_week"       // "Monday", "last Friday"
            case fuzzyTime = "fuzzy_time"        // "a while ago", "recently"
        }
        
        public struct PeriodContext {
            let location: String?
            let activity: String?
            let purpose: String?
            let participants: [String]
            let relatedKeywords: [String]
        }
    }
    
    /// Contextual events for enhanced temporal understanding
    public struct ContextualEvent: Identifiable {
        public let id = UUID()
        let name: String
        let type: EventType
        let estimatedDateRange: DateInterval?
        let keywords: [String]
        let confidence: Double
        
        public enum EventType: String, CaseIterable {
            case vacation = "vacation"
            case business = "business"
            case meeting = "meeting"
            case travel = "travel"
            case social = "social"
            case educational = "educational"
            case personal = "personal"
            case seasonal = "seasonal"
        }
    }
    
    // MARK: - Private Properties
    
    private var calendar = Calendar.current
    private var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    
    // Comprehensive temporal patterns
    private let relativePatterns: [String: TimeInterval] = [
        // Basic relative time
        "now": 0,
        "today": 0,
        "yesterday": -86400,
        "tomorrow": 86400,
        "the day before yesterday": -172800,
        "the day after tomorrow": 172800,
        
        // Week-based
        "this week": 0,
        "last week": -604800,
        "next week": 604800,
        "two weeks ago": -1209600,
        "a week ago": -604800,
        
        // Month-based
        "this month": 0,
        "last month": -2592000,
        "next month": 2592000,
        "two months ago": -5184000,
        "a month ago": -2592000,
        
        // Year-based
        "this year": 0,
        "last year": -31536000,
        "next year": 31536000,
        
        // Fuzzy temporal expressions
        "recently": -604800,          // Past week
        "a while ago": -2592000,      // Past month
        "ages ago": -15552000,        // Past 6 months
        "not long ago": -259200,      // Past 3 days
        "just now": -3600,            // Past hour
        "earlier": -21600,            // Past 6 hours
        "later": 21600,               // Next 6 hours
        "soon": 86400,                // Next day
        "sometime": 0                 // Vague reference
    ]
    
    private let namedPeriodPatterns: [String: ContextualEvent.EventType] = [
        // Travel and vacation
        "vacation": .vacation,
        "holiday": .vacation,
        "trip": .travel,
        "getaway": .vacation,
        "travel": .travel,
        "journey": .travel,
        "tour": .travel,
        "cruise": .vacation,
        "safari": .vacation,
        
        // Business and work
        "work": .business,
        "business": .business,
        "meeting": .meeting,
        "conference": .business,
        "workshop": .educational,
        "training": .educational,
        "seminar": .educational,
        "presentation": .business,
        "interview": .business,
        
        // Social events
        "party": .social,
        "wedding": .social,
        "birthday": .social,
        "celebration": .social,
        "dinner": .social,
        "lunch": .social,
        "gathering": .social,
        "reunion": .social,
        
        // Personal activities
        "appointment": .personal,
        "medical": .personal,
        "dental": .personal,
        "checkup": .personal,
        "shopping": .personal,
        "errands": .personal
    ]
    
    private let seasonalPatterns: [String: (month: Int, duration: Int)] = [
        "spring": (month: 3, duration: 3),    // March-May
        "summer": (month: 6, duration: 3),    // June-August
        "fall": (month: 9, duration: 3),      // September-November
        "autumn": (month: 9, duration: 3),    // September-November
        "winter": (month: 12, duration: 3)    // December-February
    ]
    
    private let holidayPatterns: [String: (month: Int, day: Int)] = [
        "new year": (month: 1, day: 1),
        "valentine": (month: 2, day: 14),
        "independence day": (month: 7, day: 4),
        "halloween": (month: 10, day: 31),
        "christmas": (month: 12, day: 25),
        "new year's eve": (month: 12, day: 31)
    ]
    
    private let timeOfDayPatterns: [String: (hour: Int, duration: Int)] = [
        "morning": (hour: 8, duration: 4),    // 8 AM - 12 PM
        "afternoon": (hour: 12, duration: 6), // 12 PM - 6 PM
        "evening": (hour: 18, duration: 4),   // 6 PM - 10 PM
        "night": (hour: 22, duration: 6),     // 10 PM - 4 AM
        "dawn": (hour: 6, duration: 2),       // 6 AM - 8 AM
        "dusk": (hour: 18, duration: 2),      // 6 PM - 8 PM
        "midnight": (hour: 0, duration: 2),   // 12 AM - 2 AM
        "noon": (hour: 12, duration: 2)       // 12 PM - 2 PM
    ]
    
    private let dayOfWeekPatterns: [String: Int] = [
        "monday": 2, "tuesday": 3, "wednesday": 4, "thursday": 5,
        "friday": 6, "saturday": 7, "sunday": 1
    ]
    
    // MARK: - Initialization
    
    private init() {
        logger.info("TemporalQueryProcessor initialized with advanced date recognition")
    }
    
    // MARK: - Public Interface
    
    /// Process temporal expressions in natural language query
    /// - Parameter query: Natural language query containing temporal expressions
    /// - Returns: Array of detected temporal periods with confidence scores
    public func processTemporalQuery(_ query: String) async -> [TemporalPeriod] {
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        lastProcessedQuery = query
        
        logger.debug("Processing temporal query: '\(query)'")
        
        var detectedPeriods: [TemporalPeriod] = []
        
        // Step 1: Extract absolute dates using NSDataDetector
        detectedPeriods.append(contentsOf: await extractAbsoluteDates(normalizedQuery))
        
        // Step 2: Process relative temporal expressions
        detectedPeriods.append(contentsOf: await extractRelativeDates(normalizedQuery))
        
        // Step 3: Detect named periods and events
        detectedPeriods.append(contentsOf: await extractNamedPeriods(normalizedQuery))
        
        // Step 4: Process seasonal references
        detectedPeriods.append(contentsOf: await extractSeasonalReferences(normalizedQuery))
        
        // Step 5: Detect holiday references
        detectedPeriods.append(contentsOf: await extractHolidayReferences(normalizedQuery))
        
        // Step 6: Process time of day references
        detectedPeriods.append(contentsOf: await extractTimeOfDayReferences(normalizedQuery))
        
        // Step 7: Detect day of week references
        detectedPeriods.append(contentsOf: await extractDayOfWeekReferences(normalizedQuery))
        
        // Step 8: Process fuzzy temporal expressions
        detectedPeriods.append(contentsOf: await extractFuzzyTimeReferences(normalizedQuery))
        
        // Step 9: Enhance with contextual information
        let enhancedPeriods = await enhancePeriodsWithContext(detectedPeriods, originalQuery: query)
        
        // Step 10: Filter and rank by confidence
        let filteredPeriods = enhancedPeriods
            .filter { $0.confidence >= settings.confidenceThreshold }
            .sorted { $0.confidence > $1.confidence }
        
        self.detectedPeriods = filteredPeriods
        
        logger.info("Detected \(filteredPeriods.count) temporal periods with avg confidence: \(String(format: "%.2f", filteredPeriods.map { $0.confidence }.reduce(0, +) / Double(max(filteredPeriods.count, 1))))")
        
        return filteredPeriods
    }
    
    /// Get contextual events that might be referenced in the query
    /// - Parameter query: Natural language query
    /// - Returns: Array of potentially relevant events
    public func getContextualEvents(for query: String) async -> [ContextualEvent] {
        let normalizedQuery = query.lowercased()
        var events: [ContextualEvent] = []
        
        // Detect event types from named period patterns
        for (pattern, eventType) in namedPeriodPatterns {
            if normalizedQuery.contains(pattern) {
                let event = ContextualEvent(
                    name: pattern.capitalized,
                    type: eventType,
                    estimatedDateRange: await estimateDateRangeForEvent(pattern, in: normalizedQuery),
                    keywords: extractRelatedKeywords(for: pattern, in: normalizedQuery),
                    confidence: calculateEventConfidence(pattern, in: normalizedQuery)
                )
                events.append(event)
            }
        }
        
        contextualEvents = events.sorted { $0.confidence > $1.confidence }
        return contextualEvents
    }
    
    /// Suggest temporal refinements for better search results
    /// - Parameter originalPeriods: Initially detected temporal periods
    /// - Returns: Suggested refinements to improve search precision
    public func suggestTemporalRefinements(for originalPeriods: [TemporalPeriod]) -> [String] {
        var suggestions: [String] = []
        
        for period in originalPeriods {
            switch period.type {
            case .namedPeriod:
                suggestions.append("during my \(period.originalPhrase)")
                if let context = period.context {
                    if let location = context.location {
                        suggestions.append("\(period.originalPhrase) in \(location)")
                    }
                    if let activity = context.activity {
                        suggestions.append("\(activity) during \(period.originalPhrase)")
                    }
                }
                
            case .relative:
                if period.originalPhrase.contains("week") {
                    suggestions.append("this week")
                    suggestions.append("past 7 days")
                }
                if period.originalPhrase.contains("month") {
                    suggestions.append("this month")
                    suggestions.append("past 30 days")
                }
                
            case .fuzzyTime:
                suggestions.append("past week")
                suggestions.append("past month")
                suggestions.append("this year")
                
            case .season:
                if let year = calendar.component(.year, from: Date()) as Int? {
                    suggestions.append("\(period.originalPhrase) \(year)")
                    suggestions.append("\(period.originalPhrase) \(year - 1)")
                }
                
            default:
                break
            }
        }
        
        return Array(Set(suggestions)).prefix(5).map { $0 }
    }
    
    // MARK: - Date Extraction Methods
    
    private func extractAbsoluteDates(_ query: String) async -> [TemporalPeriod] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return []
        }
        
        let matches = detector.matches(in: query, options: [], range: NSRange(location: 0, length: query.utf16.count))
        
        return matches.compactMap { match in
            guard let date = match.date,
                  let range = Range(match.range, in: query) else { return nil }
            
            let originalPhrase = String(query[range])
            let endDate = calendar.date(byAdding: .day, value: 1, to: date) ?? date
            
            return TemporalPeriod(
                type: .absolute,
                startDate: date,
                endDate: endDate,
                originalPhrase: originalPhrase,
                confidence: 0.95,
                context: nil,
                suggestedRefinements: [
                    "on \(dateFormatter.string(from: date))",
                    "around \(dateFormatter.string(from: date))"
                ]
            )
        }
    }
    
    private func extractRelativeDates(_ query: String) async -> [TemporalPeriod] {
        var periods: [TemporalPeriod] = []
        
        for (pattern, offset) in relativePatterns {
            if query.contains(pattern) {
                let (startDate, endDate) = calculateDateRange(from: offset, pattern: pattern)
                
                periods.append(TemporalPeriod(
                    type: .relative,
                    startDate: startDate,
                    endDate: endDate,
                    originalPhrase: pattern,
                    confidence: 0.9,
                    context: nil,
                    suggestedRefinements: generateRelativeRefinements(pattern)
                ))
            }
        }
        
        return periods
    }
    
    private func extractNamedPeriods(_ query: String) async -> [TemporalPeriod] {
        var periods: [TemporalPeriod] = []
        
        for (pattern, eventType) in namedPeriodPatterns {
            if query.contains(pattern) {
                let context = extractContextForNamedPeriod(pattern, in: query)
                let confidence = calculateNamedPeriodConfidence(pattern, context: context, in: query)
                
                periods.append(TemporalPeriod(
                    type: .namedPeriod,
                    startDate: nil, // Will be determined by actual screenshot analysis
                    endDate: nil,
                    originalPhrase: pattern,
                    confidence: confidence,
                    context: context,
                    suggestedRefinements: generateNamedPeriodRefinements(pattern, context: context)
                ))
            }
        }
        
        return periods
    }
    
    private func extractSeasonalReferences(_ query: String) async -> [TemporalPeriod] {
        var periods: [TemporalPeriod] = []
        
        for (season, info) in seasonalPatterns {
            if query.contains(season) {
                let year = extractYearFromQuery(query) ?? calendar.component(.year, from: Date())
                let startDate = calendar.date(from: DateComponents(year: year, month: info.month, day: 1))
                let endDate = calendar.date(byAdding: .month, value: info.duration, to: startDate!)
                
                periods.append(TemporalPeriod(
                    type: .season,
                    startDate: startDate,
                    endDate: endDate,
                    originalPhrase: season,
                    confidence: 0.8,
                    context: nil,
                    suggestedRefinements: [
                        "\(season) \(year)",
                        "\(season) \(year - 1)",
                        "during \(season)"
                    ]
                ))
            }
        }
        
        return periods
    }
    
    private func extractHolidayReferences(_ query: String) async -> [TemporalPeriod] {
        var periods: [TemporalPeriod] = []
        
        for (holiday, info) in holidayPatterns {
            if query.contains(holiday) {
                let year = extractYearFromQuery(query) ?? calendar.component(.year, from: Date())
                let holidayDate = calendar.date(from: DateComponents(year: year, month: info.month, day: info.day))
                let endDate = calendar.date(byAdding: .day, value: 1, to: holidayDate!)
                
                periods.append(TemporalPeriod(
                    type: .holiday,
                    startDate: holidayDate,
                    endDate: endDate,
                    originalPhrase: holiday,
                    confidence: 0.9,
                    context: nil,
                    suggestedRefinements: [
                        "\(holiday) \(year)",
                        "around \(holiday)",
                        "\(holiday) celebration"
                    ]
                ))
            }
        }
        
        return periods
    }
    
    private func extractTimeOfDayReferences(_ query: String) async -> [TemporalPeriod] {
        var periods: [TemporalPeriod] = []
        
        for (timePhrase, info) in timeOfDayPatterns {
            if query.contains(timePhrase) {
                // For time of day, we'll provide a template that can be applied to any date
                periods.append(TemporalPeriod(
                    type: .timeOfDay,
                    startDate: nil, // Will be combined with other temporal info
                    endDate: nil,
                    originalPhrase: timePhrase,
                    confidence: 0.7,
                    context: TemporalPeriod.PeriodContext(
                        location: nil,
                        activity: nil,
                        purpose: nil,
                        participants: [],
                        relatedKeywords: [timePhrase]
                    ),
                    suggestedRefinements: [
                        "this \(timePhrase)",
                        "yesterday \(timePhrase)",
                        "in the \(timePhrase)"
                    ]
                ))
            }
        }
        
        return periods
    }
    
    private func extractDayOfWeekReferences(_ query: String) async -> [TemporalPeriod] {
        var periods: [TemporalPeriod] = []
        
        for (dayName, weekday) in dayOfWeekPatterns {
            if query.contains(dayName) {
                let isLastWeek = query.contains("last \(dayName)")
                let isNextWeek = query.contains("next \(dayName)")
                
                let targetDate = findDateForWeekday(weekday, isLast: isLastWeek, isNext: isNextWeek)
                let endDate = calendar.date(byAdding: .day, value: 1, to: targetDate)
                
                periods.append(TemporalPeriod(
                    type: .dayOfWeek,
                    startDate: targetDate,
                    endDate: endDate,
                    originalPhrase: isLastWeek ? "last \(dayName)" : isNextWeek ? "next \(dayName)" : dayName,
                    confidence: 0.85,
                    context: nil,
                    suggestedRefinements: [
                        "this \(dayName)",
                        "last \(dayName)",
                        "\(dayName) morning",
                        "\(dayName) evening"
                    ]
                ))
            }
        }
        
        return periods
    }
    
    private func extractFuzzyTimeReferences(_ query: String) async -> [TemporalPeriod] {
        let fuzzyPatterns = [
            "a while ago": (days: -30, confidence: 0.6),
            "ages ago": (days: -180, confidence: 0.5),
            "recently": (days: -7, confidence: 0.7),
            "not long ago": (days: -3, confidence: 0.8),
            "sometime": (days: -30, confidence: 0.4)
        ]
        
        var periods: [TemporalPeriod] = []
        
        for (pattern, info) in fuzzyPatterns {
            if query.contains(pattern) {
                let startDate = calendar.date(byAdding: .day, value: info.days, to: Date())
                let endDate = Date()
                
                periods.append(TemporalPeriod(
                    type: .fuzzyTime,
                    startDate: startDate,
                    endDate: endDate,
                    originalPhrase: pattern,
                    confidence: info.confidence,
                    context: nil,
                    suggestedRefinements: [
                        "past week",
                        "past month",
                        "this year"
                    ]
                ))
            }
        }
        
        return periods
    }
    
    // MARK: - Helper Methods
    
    private func calculateDateRange(from offset: TimeInterval, pattern: String) -> (Date?, Date?) {
        let baseDate = Date()
        
        if pattern.contains("week") || pattern.contains("month") || pattern.contains("year") {
            // For range periods, calculate start and end
            let startDate = baseDate.addingTimeInterval(offset)
            let endDate = offset < 0 ? baseDate : baseDate.addingTimeInterval(offset * 2)
            return (startDate, endDate)
        } else {
            // For point-in-time periods
            let targetDate = baseDate.addingTimeInterval(offset)
            let endDate = calendar.date(byAdding: .day, value: 1, to: targetDate)
            return (targetDate, endDate)
        }
    }
    
    private func extractContextForNamedPeriod(_ period: String, in query: String) -> TemporalPeriod.PeriodContext? {
        // Extract location, activity, and purpose from context
        var location: String?
        var activity: String?
        var purpose: String?
        var participants: [String] = []
        var relatedKeywords: [String] = []
        
        // Simple location extraction (in real app, would use more sophisticated NLP)
        let locationPatterns = ["in ", "at ", "to ", "from "]
        for pattern in locationPatterns {
            if let range = query.range(of: pattern) {
                let afterPattern = String(query[range.upperBound...])
                let words = afterPattern.components(separatedBy: .whitespacesAndNewlines)
                if let firstWord = words.first, firstWord.count > 2 {
                    location = firstWord
                    break
                }
            }
        }
        
        // Activity extraction
        let activityPatterns = ["for ", "during ", "while "]
        for pattern in activityPatterns {
            if let range = query.range(of: pattern) {
                let afterPattern = String(query[range.upperBound...])
                let words = afterPattern.components(separatedBy: .whitespacesAndNewlines)
                if let firstWord = words.first, firstWord.count > 3 {
                    activity = firstWord
                    break
                }
            }
        }
        
        // Extract related keywords
        relatedKeywords = query.components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 3 && $0 != period }
            .prefix(5)
            .map { $0 }
        
        if location != nil || activity != nil || !relatedKeywords.isEmpty {
            return TemporalPeriod.PeriodContext(
                location: location,
                activity: activity,
                purpose: purpose,
                participants: participants,
                relatedKeywords: relatedKeywords
            )
        }
        
        return nil
    }
    
    private func calculateNamedPeriodConfidence(_ period: String, context: TemporalPeriod.PeriodContext?, in query: String) -> Double {
        var confidence = 0.7 // Base confidence for named periods
        
        // Boost confidence for context clues
        if let context = context {
            if context.location != nil { confidence += 0.1 }
            if context.activity != nil { confidence += 0.1 }
            if !context.relatedKeywords.isEmpty { confidence += 0.05 }
        }
        
        // Boost confidence for vacation-specific keywords
        if period == "vacation" || period == "holiday" {
            let vacationKeywords = ["flight", "hotel", "resort", "beach", "travel", "trip"]
            let keywordCount = vacationKeywords.filter { query.contains($0) }.count
            confidence += Double(keywordCount) * 0.05
        }
        
        return min(1.0, confidence)
    }
    
    private func extractYearFromQuery(_ query: String) -> Int? {
        // Simple year extraction using regex
        let yearPattern = "\\b(20\\d{2})\\b"
        let regex = try? NSRegularExpression(pattern: yearPattern)
        let matches = regex?.matches(in: query, range: NSRange(location: 0, length: query.utf16.count))
        
        if let match = matches?.first {
            let yearString = String(query[Range(match.range, in: query)!])
            return Int(yearString)
        }
        
        return nil
    }
    
    private func findDateForWeekday(_ weekday: Int, isLast: Bool, isNext: Bool) -> Date {
        let today = Date()
        let currentWeekday = calendar.component(.weekday, from: today)
        
        if isLast {
            let daysBack = (currentWeekday - weekday + 7) % 7
            return calendar.date(byAdding: .day, value: -(daysBack + 7), to: today) ?? today
        } else if isNext {
            let daysForward = (weekday - currentWeekday + 7) % 7
            return calendar.date(byAdding: .day, value: daysForward + 7, to: today) ?? today
        } else {
            // This week or most recent occurrence
            let daysForward = (weekday - currentWeekday + 7) % 7
            if daysForward == 0 {
                return today
            } else {
                return calendar.date(byAdding: .day, value: daysForward > 3 ? daysForward - 7 : daysForward, to: today) ?? today
            }
        }
    }
    
    private func enhancePeriodsWithContext(_ periods: [TemporalPeriod], originalQuery: String) async -> [TemporalPeriod] {
        return periods.map { period in
            var enhancedPeriod = period
            
            // Add contextual refinements based on query content
            var additionalRefinements: [String] = []
            
            if originalQuery.lowercased().contains("work") {
                additionalRefinements.append("work-related \(period.originalPhrase)")
            }
            
            if originalQuery.lowercased().contains("personal") {
                additionalRefinements.append("personal \(period.originalPhrase)")
            }
            
            if originalQuery.lowercased().contains("travel") {
                additionalRefinements.append("travel during \(period.originalPhrase)")
            }
            
            enhancedPeriod = TemporalPeriod(
                type: period.type,
                startDate: period.startDate,
                endDate: period.endDate,
                originalPhrase: period.originalPhrase,
                confidence: period.confidence,
                context: period.context,
                suggestedRefinements: period.suggestedRefinements + additionalRefinements
            )
            
            return enhancedPeriod
        }
    }
    
    private func estimateDateRangeForEvent(_ eventName: String, in query: String) async -> DateInterval? {
        // Placeholder for estimating date ranges based on event context
        // In production, would analyze user's screenshot patterns to identify when events occurred
        return nil
    }
    
    private func extractRelatedKeywords(for pattern: String, in query: String) -> [String] {
        return query.components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 3 && $0 != pattern }
            .prefix(3)
            .map { $0 }
    }
    
    private func calculateEventConfidence(_ pattern: String, in query: String) -> Double {
        var confidence = 0.6 // Base confidence
        
        // Boost for multiple related keywords
        let relatedKeywords = extractRelatedKeywords(for: pattern, in: query)
        confidence += Double(relatedKeywords.count) * 0.1
        
        // Boost for specific event types
        if ["vacation", "holiday", "trip"].contains(pattern) {
            let travelKeywords = ["flight", "hotel", "travel", "airport"]
            let matches = travelKeywords.filter { query.contains($0) }.count
            confidence += Double(matches) * 0.1
        }
        
        return min(1.0, confidence)
    }
    
    private func generateRelativeRefinements(_ pattern: String) -> [String] {
        switch pattern {
        case "yesterday":
            return ["yesterday morning", "yesterday evening", "24 hours ago"]
        case "last week":
            return ["past 7 days", "previous week", "1 week ago"]
        case "last month":
            return ["past 30 days", "previous month", "1 month ago"]
        default:
            return [pattern]
        }
    }
    
    private func generateNamedPeriodRefinements(_ pattern: String, context: TemporalPeriod.PeriodContext?) -> [String] {
        var refinements = ["during my \(pattern)", "from my \(pattern)"]
        
        if let context = context {
            if let location = context.location {
                refinements.append("\(pattern) in \(location)")
            }
            if let activity = context.activity {
                refinements.append("\(activity) during \(pattern)")
            }
        }
        
        return refinements
    }
}