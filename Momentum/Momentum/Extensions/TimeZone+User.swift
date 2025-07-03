//
//  TimeZone+User.swift
//  Momentum
//
//  User timezone handling
//

import Foundation

extension TimeZone {
    /// Get the user's current timezone
    static var userTimeZone: TimeZone {
        return TimeZone.current
    }
    
    /// Get timezone offset in hours from UTC
    static var currentOffsetHours: Int {
        return TimeZone.current.secondsFromGMT() / 3600
    }
    
    /// Get timezone identifier (e.g., "America/New_York")
    static var currentIdentifier: String {
        return TimeZone.current.identifier
    }
    
    /// Format for display (e.g., "EST", "PDT")
    static var currentAbbreviation: String {
        return TimeZone.current.abbreviation() ?? "UTC"
    }
    
    /// Get a formatted offset string (e.g., "+03:00", "-05:00")
    static var offsetString: String {
        let offset = TimeZone.current.secondsFromGMT()
        let hours = abs(offset) / 3600
        let minutes = (abs(offset) % 3600) / 60
        let sign = offset >= 0 ? "+" : "-"
        return String(format: "%@%02d:%02d", sign, hours, minutes)
    }
}

extension Date {
    /// Convert UTC date to user's local time
    func toUserTimeZone() -> Date {
        // Dates are already in user's timezone when displayed
        // This is more for clarity in the code
        return self
    }
    
    /// Get the date in user's timezone with time components
    func inUserTimeZone() -> (date: Date, hour: Int, minute: Int) {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: self)
        return (self, components.hour ?? 0, components.minute ?? 0)
    }
    
    /// Format for display in user's timezone
    func formattedInUserTimeZone(dateStyle: DateFormatter.Style = .medium, timeStyle: DateFormatter.Style = .short) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        formatter.timeZone = TimeZone.current
        return formatter.string(from: self)
    }
}