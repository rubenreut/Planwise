//
//  Date+RelativeTime.swift
//  Momentum
//
//  Natural language date parsing
//

import Foundation

extension Date {
    /// Parse relative time expressions into dates
    static func from(relativeExpression: String, baseDate: Date = Date()) -> Date? {
        let expression = relativeExpression.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let calendar = Calendar.current
        
        // Handle "in X hours/minutes"
        if expression.starts(with: "in ") {
            let parts = expression.dropFirst(3).split(separator: " ")
            if parts.count >= 2,
               let value = Int(parts[0]) {
                let unit = String(parts[1])
                
                switch unit {
                case "minute", "minutes", "min", "mins":
                    return calendar.date(byAdding: .minute, value: value, to: baseDate)
                case "hour", "hours", "hr", "hrs":
                    return calendar.date(byAdding: .hour, value: value, to: baseDate)
                case "day", "days":
                    return calendar.date(byAdding: .day, value: value, to: baseDate)
                case "week", "weeks":
                    return calendar.date(byAdding: .weekOfYear, value: value, to: baseDate)
                case "month", "months":
                    return calendar.date(byAdding: .month, value: value, to: baseDate)
                default:
                    break
                }
            }
        }
        
        // Handle "next Monday/Tuesday/etc"
        if expression.starts(with: "next ") {
            let dayName = String(expression.dropFirst(5))
            if let weekday = weekdayNumber(from: dayName) {
                return calendar.nextDate(
                    after: baseDate,
                    matching: DateComponents(weekday: weekday),
                    matchingPolicy: .nextTime
                )
            }
        }
        
        // Handle relative days
        switch expression {
        case "today":
            return calendar.startOfDay(for: baseDate)
        case "tomorrow":
            return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: baseDate))
        case "yesterday":
            return calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: baseDate))
        case "now":
            return baseDate
        case "tonight":
            return calendar.date(bySettingHour: 20, minute: 0, second: 0, of: baseDate)
        case "this morning", "morning":
            return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: baseDate)
        case "this afternoon", "afternoon":
            return calendar.date(bySettingHour: 14, minute: 0, second: 0, of: baseDate)
        case "this evening", "evening":
            return calendar.date(bySettingHour: 18, minute: 0, second: 0, of: baseDate)
        case "noon", "midday":
            return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: baseDate)
        case "midnight":
            return calendar.date(bySettingHour: 0, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: 1, to: baseDate)!)
        case "next week":
            return calendar.date(byAdding: .weekOfYear, value: 1, to: baseDate)
        case "next month":
            return calendar.date(byAdding: .month, value: 1, to: baseDate)
        case "next year":
            return calendar.date(byAdding: .year, value: 1, to: baseDate)
        default:
            break
        }
        
        // Handle "this Monday/Tuesday/etc"
        if expression.starts(with: "this ") {
            let dayName = String(expression.dropFirst(5))
            if let weekday = weekdayNumber(from: dayName) {
                // Find the next occurrence of this weekday
                var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: baseDate)
                components.weekday = weekday
                return calendar.date(from: components)
            }
        }
        
        // Handle day names alone (assumes "this week")
        if let weekday = weekdayNumber(from: expression) {
            var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: baseDate)
            components.weekday = weekday
            if let date = calendar.date(from: components),
               date < baseDate {
                // If the day already passed this week, get next week's
                return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
            }
            return calendar.date(from: components)
        }
        
        // Handle "every day/weekday/weekend"
        if expression.starts(with: "every ") {
            // This would be handled by recurring events
            return nil
        }
        
        return nil
    }
    
    private static func weekdayNumber(from name: String) -> Int? {
        switch name.lowercased() {
        case "sunday", "sun": return 1
        case "monday", "mon": return 2
        case "tuesday", "tue", "tues": return 3
        case "wednesday", "wed": return 4
        case "thursday", "thu", "thurs": return 5
        case "friday", "fri": return 6
        case "saturday", "sat": return 7
        default: return nil
        }
    }
    
    /// Parse time expressions like "at 3pm", "at 15:30"
    static func parseTime(from expression: String, on date: Date = Date()) -> Date? {
        let calendar = Calendar.current
        let timeStr = expression.lowercased()
            .replacingOccurrences(of: "at ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle 12-hour format with am/pm
        let ampmPattern = #"(\d{1,2})(?::(\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)"#
        if let match = timeStr.range(of: ampmPattern, options: .regularExpression) {
            let matched = String(timeStr[match])
            let components = matched.replacingOccurrences(of: #"[^\d:]"#, with: " ", options: .regularExpression)
                .split(separator: " ")
            
            if let hourStr = components.first,
               let hour = Int(hourStr) {
                let isPM = matched.contains("pm") || matched.contains("p.m.")
                var finalHour = hour
                
                if isPM && hour != 12 {
                    finalHour += 12
                } else if !isPM && hour == 12 {
                    finalHour = 0
                }
                
                let minute = components.count > 1 ? Int(components[1]) ?? 0 : 0
                
                return calendar.date(bySettingHour: finalHour, minute: minute, second: 0, of: date)
            }
        }
        
        // Handle 24-hour format
        let twentyFourPattern = #"(\d{1,2}):(\d{2})"#
        if let match = timeStr.range(of: twentyFourPattern, options: .regularExpression) {
            let matched = String(timeStr[match])
            let parts = matched.split(separator: ":")
            
            if parts.count == 2,
               let hour = Int(parts[0]),
               let minute = Int(parts[1]),
               hour >= 0 && hour < 24,
               minute >= 0 && minute < 60 {
                return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date)
            }
        }
        
        return nil
    }
}

// Extend for duration parsing
extension DateComponents {
    static func duration(from expression: String) -> DateComponents? {
        let expr = expression.lowercased()
        
        // Handle "X hours/minutes"
        let pattern = #"(\d+(?:\.\d+)?)\s*(hours?|hrs?|minutes?|mins?|days?)"#
        if let match = expr.range(of: pattern, options: .regularExpression) {
            let matched = String(expr[match])
            let parts = matched.split(whereSeparator: { $0.isLetter || $0.isWhitespace })
            
            if let valueStr = parts.first,
               let value = Double(valueStr) {
                let unit = matched.replacingOccurrences(of: #"[\d\.\s]"#, with: "", options: .regularExpression)
                
                switch unit {
                case "hour", "hours", "hr", "hrs":
                    return DateComponents(hour: Int(value), minute: Int((value.truncatingRemainder(dividingBy: 1)) * 60))
                case "minute", "minutes", "min", "mins":
                    return DateComponents(minute: Int(value))
                case "day", "days":
                    return DateComponents(day: Int(value))
                default:
                    break
                }
            }
        }
        
        // Handle "all day"
        if expr == "all day" {
            return DateComponents(hour: 24)
        }
        
        return nil
    }
}