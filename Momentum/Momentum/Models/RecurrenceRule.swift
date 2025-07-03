//
//  RecurrenceRule.swift
//  Momentum
//
//  Handles recurring event logic
//

import Foundation

enum RecurrenceFrequency: String, CaseIterable, Codable {
    case daily = "DAILY"
    case weekly = "WEEKLY"
    case monthly = "MONTHLY"
    case yearly = "YEARLY"
    case weekdays = "WEEKDAYS"
    case weekends = "WEEKENDS"
    case custom = "CUSTOM"
}

struct RecurrenceRule: Codable {
    let frequency: RecurrenceFrequency
    let interval: Int // Every N days/weeks/months
    let endDate: Date?
    let occurrenceCount: Int? // Stop after N occurrences
    let daysOfWeek: [Int]? // 1=Sunday, 2=Monday, etc.
    let daysOfMonth: [Int]? // 1-31
    let monthsOfYear: [Int]? // 1-12
    
    // Convenience initializers
    static func daily(interval: Int = 1, endDate: Date? = nil) -> RecurrenceRule {
        RecurrenceRule(
            frequency: .daily,
            interval: interval,
            endDate: endDate,
            occurrenceCount: nil,
            daysOfWeek: nil,
            daysOfMonth: nil,
            monthsOfYear: nil
        )
    }
    
    static func weekly(interval: Int = 1, daysOfWeek: [Int], endDate: Date? = nil) -> RecurrenceRule {
        RecurrenceRule(
            frequency: .weekly,
            interval: interval,
            endDate: endDate,
            occurrenceCount: nil,
            daysOfWeek: daysOfWeek,
            daysOfMonth: nil,
            monthsOfYear: nil
        )
    }
    
    static func weekdays() -> RecurrenceRule {
        RecurrenceRule(
            frequency: .weekdays,
            interval: 1,
            endDate: nil,
            occurrenceCount: nil,
            daysOfWeek: [2, 3, 4, 5, 6], // Monday-Friday
            daysOfMonth: nil,
            monthsOfYear: nil
        )
    }
    
    static func weekends() -> RecurrenceRule {
        RecurrenceRule(
            frequency: .weekends,
            interval: 1,
            endDate: nil,
            occurrenceCount: nil,
            daysOfWeek: [1, 7], // Sunday, Saturday
            daysOfMonth: nil,
            monthsOfYear: nil
        )
    }
    
    static func monthly(interval: Int = 1, dayOfMonth: Int? = nil, endDate: Date? = nil) -> RecurrenceRule {
        RecurrenceRule(
            frequency: .monthly,
            interval: interval,
            endDate: endDate,
            occurrenceCount: nil,
            daysOfWeek: nil,
            daysOfMonth: dayOfMonth != nil ? [dayOfMonth!] : nil,
            monthsOfYear: nil
        )
    }
    
    // Parse from natural language
    static func from(expression: String) -> RecurrenceRule? {
        let expr = expression.lowercased()
        
        // Daily patterns
        if expr.contains("every day") || expr.contains("daily") {
            return .daily()
        }
        
        // Weekday/Weekend patterns
        if expr.contains("every weekday") || expr.contains("weekdays") {
            return .weekdays()
        }
        
        if expr.contains("every weekend") || expr.contains("weekends") {
            return .weekends()
        }
        
        // Weekly patterns
        if expr.contains("every week") || expr.contains("weekly") {
            return .weekly(interval: 1, daysOfWeek: [])
        }
        
        // Specific day patterns
        let weekdays = [
            "sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4,
            "thursday": 5, "friday": 6, "saturday": 7
        ]
        
        for (day, number) in weekdays {
            if expr.contains("every \(day)") {
                return .weekly(interval: 1, daysOfWeek: [number])
            }
        }
        
        // Multiple days pattern
        if expr.contains("every") && (expr.contains("and") || expr.contains(",")) {
            var days: [Int] = []
            for (day, number) in weekdays {
                if expr.contains(day) {
                    days.append(number)
                }
            }
            if !days.isEmpty {
                return .weekly(interval: 1, daysOfWeek: days)
            }
        }
        
        // Monthly patterns
        if expr.contains("every month") || expr.contains("monthly") {
            return .monthly()
        }
        
        // Interval patterns (every 2 days, every 3 weeks, etc.)
        let intervalPattern = #"every (\d+) (day|week|month)"#
        if let match = expr.range(of: intervalPattern, options: .regularExpression) {
            let matched = String(expr[match])
            let parts = matched.split(separator: " ")
            if parts.count >= 3,
               let interval = Int(parts[1]) {
                let unit = String(parts[2])
                switch unit {
                case "day", "days":
                    return .daily(interval: interval)
                case "week", "weeks":
                    return .weekly(interval: interval, daysOfWeek: [])
                case "month", "months":
                    return .monthly(interval: interval)
                default:
                    break
                }
            }
        }
        
        return nil
    }
    
    // Generate next occurrence dates
    func nextOccurrences(after startDate: Date, limit: Int = 10) -> [Date] {
        var occurrences: [Date] = []
        let calendar = Calendar.current
        var currentDate = startDate
        var count = 0
        
        while occurrences.count < limit {
            // Check end conditions
            if let endDate = endDate, currentDate > endDate {
                break
            }
            if let maxCount = occurrenceCount, count >= maxCount {
                break
            }
            
            // Generate based on frequency
            switch frequency {
            case .daily:
                currentDate = calendar.date(byAdding: .day, value: interval, to: currentDate)!
                occurrences.append(currentDate)
                
            case .weekly:
                if let daysOfWeek = daysOfWeek, !daysOfWeek.isEmpty {
                    // Find next occurrence on specified days
                    for _ in 1...7 {
                        currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
                        let weekday = calendar.component(.weekday, from: currentDate)
                        if daysOfWeek.contains(weekday) {
                            occurrences.append(currentDate)
                            break
                        }
                    }
                } else {
                    // Same day next week
                    currentDate = calendar.date(byAdding: .weekOfYear, value: interval, to: currentDate)!
                    occurrences.append(currentDate)
                }
                
            case .weekdays:
                repeat {
                    currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
                    let weekday = calendar.component(.weekday, from: currentDate)
                    if weekday >= 2 && weekday <= 6 { // Monday-Friday
                        occurrences.append(currentDate)
                        break
                    }
                } while true
                
            case .weekends:
                repeat {
                    currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
                    let weekday = calendar.component(.weekday, from: currentDate)
                    if weekday == 1 || weekday == 7 { // Sunday or Saturday
                        occurrences.append(currentDate)
                        break
                    }
                } while true
                
            case .monthly:
                if let daysOfMonth = daysOfMonth, !daysOfMonth.isEmpty {
                    // Specific day of month
                    var components = calendar.dateComponents([.year, .month, .day], from: currentDate)
                    components.month! += interval
                    components.day = daysOfMonth[0]
                    if let nextDate = calendar.date(from: components) {
                        currentDate = nextDate
                        occurrences.append(currentDate)
                    }
                } else {
                    // Same date next month
                    currentDate = calendar.date(byAdding: .month, value: interval, to: currentDate)!
                    occurrences.append(currentDate)
                }
                
            case .yearly:
                currentDate = calendar.date(byAdding: .year, value: interval, to: currentDate)!
                occurrences.append(currentDate)
                
            case .custom:
                // Handle custom rules
                break
            }
            
            count += 1
        }
        
        return occurrences
    }
    
    // Convert to/from string for storage
    var ruleString: String {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(self) {
            return data.base64EncodedString()
        }
        return ""
    }
    
    static func from(ruleString: String) -> RecurrenceRule? {
        if let data = Data(base64Encoded: ruleString) {
            let decoder = JSONDecoder()
            return try? decoder.decode(RecurrenceRule.self, from: data)
        }
        return nil
    }
}

// MARK: - Natural Language Generation
extension RecurrenceRule {
    var naturalDescription: String {
        switch frequency {
        case .daily:
            if interval == 1 {
                return "Every day"
            } else {
                return "Every \(interval) days"
            }
            
        case .weekly:
            if let days = daysOfWeek, !days.isEmpty {
                let dayNames = days.compactMap { dayNumber in
                    switch dayNumber {
                    case 1: return "Sunday"
                    case 2: return "Monday"
                    case 3: return "Tuesday"
                    case 4: return "Wednesday"
                    case 5: return "Thursday"
                    case 6: return "Friday"
                    case 7: return "Saturday"
                    default: return nil
                    }
                }
                
                if interval == 1 {
                    return "Every \(dayNames.joined(separator: ", "))"
                } else {
                    return "Every \(interval) weeks on \(dayNames.joined(separator: ", "))"
                }
            } else {
                return interval == 1 ? "Every week" : "Every \(interval) weeks"
            }
            
        case .weekdays:
            return "Every weekday"
            
        case .weekends:
            return "Every weekend"
            
        case .monthly:
            if let days = daysOfMonth, !days.isEmpty {
                return "Every month on the \(days[0])th"
            } else {
                return interval == 1 ? "Every month" : "Every \(interval) months"
            }
            
        case .yearly:
            return interval == 1 ? "Every year" : "Every \(interval) years"
            
        case .custom:
            return "Custom recurrence"
        }
    }
}