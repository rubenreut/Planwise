import Foundation

class SmartDateParser {
    static let shared = SmartDateParser()
    
    private let calendar = Calendar.current
    private let locale = Locale.current
    
    // Common time patterns
    private let timePattern = #"(\d{1,2}):?(\d{2})?\s*(am|pm|AM|PM)?"#
    private let relativePattern = #"(in|after)\s+(\d+)\s+(minute|hour|day|week|month)s?"#
    
    // Priority keywords
    private let highPriorityKeywords = ["urgent", "important", "high priority", "asap", "critical", "!!!"]
    private let lowPriorityKeywords = ["low priority", "whenever", "someday", "eventually"]
    
    // Time of day keywords
    private let morningKeywords = ["morning", "am", "breakfast"]
    private let afternoonKeywords = ["afternoon", "lunch", "midday"]
    private let eveningKeywords = ["evening", "dinner", "tonight", "pm"]
    
    private init() {}
    
    // MARK: - Main Parsing Function
    
    func parse(_ input: String) -> ParsedTaskInput {
        var workingInput = input.lowercased()
        var result = ParsedTaskInput()
        
        // Extract priority
        result.priority = extractPriority(from: &workingInput)
        
        // Extract tags (hashtags)
        result.tags = extractTags(from: &workingInput)
        
        // Extract category (if mentioned)
        result.category = extractCategory(from: &workingInput)
        
        // Extract date and time
        let dateTimeResult = extractDateTime(from: &workingInput)
        result.dueDate = dateTimeResult.date
        result.hasTime = dateTimeResult.hasTime
        
        // Clean up the title
        result.title = cleanTitle(workingInput)
        
        return result
    }
    
    // MARK: - Priority Extraction
    
    private func extractPriority(from input: inout String) -> TaskPriority {
        for keyword in highPriorityKeywords {
            if input.contains(keyword) {
                input = input.replacingOccurrences(of: keyword, with: "").trimmingCharacters(in: .whitespaces)
                return .high
            }
        }
        
        for keyword in lowPriorityKeywords {
            if input.contains(keyword) {
                input = input.replacingOccurrences(of: keyword, with: "").trimmingCharacters(in: .whitespaces)
                return .low
            }
        }
        
        return .medium
    }
    
    // MARK: - Tag Extraction
    
    private func extractTags(from input: inout String) -> [String] {
        let tagPattern = #"#(\w+)"#
        var tags: [String] = []
        
        if let regex = try? NSRegularExpression(pattern: tagPattern, options: []) {
            let matches = regex.matches(in: input, options: [], range: NSRange(location: 0, length: input.utf16.count))
            
            for match in matches.reversed() {
                if let range = Range(match.range(at: 1), in: input) {
                    tags.append(String(input[range]))
                }
                
                if let fullRange = Range(match.range, in: input) {
                    input.removeSubrange(fullRange)
                }
            }
        }
        
        return tags.reversed()
    }
    
    // MARK: - Category Extraction
    
    private func extractCategory(from input: inout String) -> String? {
        let categories = ["work", "personal", "health", "learning", "meeting", "other"]
        
        for category in categories {
            if input.contains(category) {
                input = input.replacingOccurrences(of: category, with: "").trimmingCharacters(in: .whitespaces)
                return category
            }
        }
        
        return nil
    }
    
    // MARK: - Date/Time Extraction
    
    private func extractDateTime(from input: inout String) -> (date: Date?, hasTime: Bool) {
        var resultDate: Date?
        var hasTime = false
        
        // Try relative dates first (e.g., "tomorrow", "next week")
        if let date = extractRelativeDate(from: &input) {
            resultDate = date
        }
        
        // Try specific dates (e.g., "July 20", "20/07")
        if resultDate == nil, let date = extractSpecificDate(from: &input) {
            resultDate = date
        }
        
        // Extract time and apply to date
        if let time = extractTime(from: &input) {
            hasTime = true
            if let date = resultDate {
                resultDate = combineDateAndTime(date: date, time: time)
            } else {
                // If no date specified but time is given, assume today
                resultDate = combineDateAndTime(date: Date(), time: time)
            }
        } else if let timeKeyword = extractTimeKeyword(from: &input) {
            // Handle time keywords like "morning", "afternoon"
            let date = resultDate ?? Date()
            resultDate = applyTimeKeyword(to: date, keyword: timeKeyword)
            hasTime = true
        }
        
        return (resultDate, hasTime)
    }
    
    private func extractRelativeDate(from input: inout String) -> Date? {
        let today = Date()
        let calendar = self.calendar
        
        // Tomorrow
        if input.contains("tomorrow") || input.contains("tmrw") {
            input = input.replacingOccurrences(of: "tomorrow", with: "")
                        .replacingOccurrences(of: "tmrw", with: "")
            return calendar.date(byAdding: .day, value: 1, to: today)
        }
        
        // Today
        if input.contains("today") {
            input = input.replacingOccurrences(of: "today", with: "")
            return today
        }
        
        // Day names
        let dayNames = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
        let shortDayNames = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
        
        for (index, dayName) in dayNames.enumerated() {
            if input.contains(dayName) || input.contains(shortDayNames[index]) {
                input = input.replacingOccurrences(of: dayName, with: "")
                             .replacingOccurrences(of: shortDayNames[index], with: "")
                
                // Find next occurrence of this day
                let todayWeekday = calendar.component(.weekday, from: today)
                let targetWeekday = index + 2 // Calendar weekdays start at 1 (Sunday)
                
                var daysToAdd = targetWeekday - todayWeekday
                if daysToAdd <= 0 {
                    daysToAdd += 7
                }
                
                return calendar.date(byAdding: .day, value: daysToAdd, to: today)
            }
        }
        
        // Next week/month
        if input.contains("next week") {
            input = input.replacingOccurrences(of: "next week", with: "")
            return calendar.date(byAdding: .weekOfYear, value: 1, to: today)
        }
        
        if input.contains("next month") {
            input = input.replacingOccurrences(of: "next month", with: "")
            return calendar.date(byAdding: .month, value: 1, to: today)
        }
        
        // In X days/hours
        if let regex = try? NSRegularExpression(pattern: relativePattern, options: []) {
            let matches = regex.matches(in: input, options: [], range: NSRange(location: 0, length: input.utf16.count))
            
            if let match = matches.first {
                if let numberRange = Range(match.range(at: 2), in: input),
                   let unitRange = Range(match.range(at: 3), in: input),
                   let number = Int(input[numberRange]) {
                    
                    let unit = String(input[unitRange])
                    var date: Date?
                    
                    switch unit {
                    case "minute", "minutes":
                        date = calendar.date(byAdding: .minute, value: number, to: today)
                    case "hour", "hours":
                        date = calendar.date(byAdding: .hour, value: number, to: today)
                    case "day", "days":
                        date = calendar.date(byAdding: .day, value: number, to: today)
                    case "week", "weeks":
                        date = calendar.date(byAdding: .weekOfYear, value: number, to: today)
                    case "month", "months":
                        date = calendar.date(byAdding: .month, value: number, to: today)
                    default:
                        break
                    }
                    
                    if let fullRange = Range(match.range, in: input) {
                        input.removeSubrange(fullRange)
                    }
                    
                    return date
                }
            }
        }
        
        return nil
    }
    
    private func extractSpecificDate(from input: inout String) -> Date? {
        // This is simplified - in production, you'd want more robust date parsing
        // For now, we'll skip specific date parsing
        return nil
    }
    
    private func extractTime(from input: inout String) -> Date? {
        if let regex = try? NSRegularExpression(pattern: timePattern, options: .caseInsensitive) {
            let matches = regex.matches(in: input, options: [], range: NSRange(location: 0, length: input.utf16.count))
            
            if let match = matches.first {
                if let hourRange = Range(match.range(at: 1), in: input),
                   let hour = Int(input[hourRange]) {
                    
                    var finalHour = hour
                    var minute = 0
                    
                    // Extract minutes if present
                    if let minuteRange = Range(match.range(at: 2), in: input),
                       let min = Int(input[minuteRange]) {
                        minute = min
                    }
                    
                    // Handle AM/PM
                    if let ampmRange = Range(match.range(at: 3), in: input) {
                        let ampm = input[ampmRange].lowercased()
                        if ampm == "pm" && finalHour < 12 {
                            finalHour += 12
                        } else if ampm == "am" && finalHour == 12 {
                            finalHour = 0
                        }
                    } else if hour <= 7 {
                        // Assume PM for hours 1-7 without AM/PM
                        finalHour += 12
                    }
                    
                    // Remove the time from input
                    if let fullRange = Range(match.range, in: input) {
                        input.removeSubrange(fullRange)
                    }
                    
                    // Create date with time components
                    var components = DateComponents()
                    components.hour = finalHour
                    components.minute = minute
                    
                    return calendar.date(from: components)
                }
            }
        }
        
        return nil
    }
    
    private func extractTimeKeyword(from input: inout String) -> String? {
        for keyword in morningKeywords {
            if input.contains(keyword) {
                input = input.replacingOccurrences(of: keyword, with: "")
                return "morning"
            }
        }
        
        for keyword in afternoonKeywords {
            if input.contains(keyword) {
                input = input.replacingOccurrences(of: keyword, with: "")
                return "afternoon"
            }
        }
        
        for keyword in eveningKeywords {
            if input.contains(keyword) {
                input = input.replacingOccurrences(of: keyword, with: "")
                return "evening"
            }
        }
        
        return nil
    }
    
    private func applyTimeKeyword(to date: Date, keyword: String) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        
        switch keyword {
        case "morning":
            components.hour = 9
            components.minute = 0
        case "afternoon":
            components.hour = 14
            components.minute = 0
        case "evening":
            components.hour = 18
            components.minute = 0
        default:
            break
        }
        
        return calendar.date(from: components) ?? date
    }
    
    private func combineDateAndTime(date: Date, time: Date) -> Date {
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        
        var combined = dateComponents
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute
        
        return calendar.date(from: combined) ?? date
    }
    
    private func cleanTitle(_ input: String) -> String {
        // Remove extra spaces and trim
        let cleaned = input
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Capitalize first letter
        return cleaned.prefix(1).uppercased() + cleaned.dropFirst()
    }
}

// MARK: - Parsed Result

struct ParsedTaskInput {
    var title: String = ""
    var dueDate: Date?
    var hasTime: Bool = false
    var priority: TaskPriority = .medium
    var category: String?
    var tags: [String] = []
    var estimatedDuration: Int?
    
    var hasDueDate: Bool {
        dueDate != nil
    }
}