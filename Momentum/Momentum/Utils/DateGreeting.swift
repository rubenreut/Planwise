//
//  DateGreeting.swift
//  Momentum
//
//  Utility for displaying time-based greetings across the app
//

import Foundation

extension Date {
    static func getTimeBasedGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 0..<12:
            return "Good morning"
        case 12..<17:
            return "Good afternoon"
        default:
            return "Good evening"
        }
    }
    
    static func formatDateWithGreeting(_ date: Date) -> String {
        // Add personalized greeting for today
        if Calendar.current.isDateInToday(date) {
            let userName = UserDefaults.standard.string(forKey: "userDisplayName") ?? ""
            let greeting = getTimeBasedGreeting()
            if !userName.isEmpty {
                return "\(greeting), \(userName)"
            } else {
                return greeting
            }
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: date)
        }
    }
}