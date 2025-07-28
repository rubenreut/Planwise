import Foundation
import EventKit
import UniformTypeIdentifiers

class DataExportService {
    static let shared = DataExportService()
    
    private init() {}
    
    // MARK: - Export to iCalendar (.ics) format
    
    func exportToICS(events: [Event]) -> String {
        var icsContent = """
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:-//Planwise//Calendar Export//EN
        CALSCALE:GREGORIAN
        METHOD:PUBLISH
        X-WR-CALNAME:Planwise Calendar
        X-WR-TIMEZONE:\(TimeZone.current.identifier)
        
        """
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd'T'HHmmss"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        
        for event in events {
            guard let startTime = event.startTime,
                  let endTime = event.endTime,
                  let uid = event.id?.uuidString else { continue }
            
            let title = event.title ?? "Untitled Event"
            let description = event.notes ?? ""
            let location = event.location ?? ""
            let category = event.category?.name ?? ""
            
            icsContent += """
            BEGIN:VEVENT
            UID:\(uid)@planwise.app
            DTSTAMP:\(dateFormatter.string(from: Date()))Z
            DTSTART:\(dateFormatter.string(from: startTime))Z
            DTEND:\(dateFormatter.string(from: endTime))Z
            SUMMARY:\(escapeICSText(title))
            """
            
            if !description.isEmpty {
                icsContent += "\nDESCRIPTION:\(escapeICSText(description))"
            }
            
            if !location.isEmpty {
                icsContent += "\nLOCATION:\(escapeICSText(location))"
            }
            
            if !category.isEmpty {
                icsContent += "\nCATEGORIES:\(escapeICSText(category))"
            }
            
            if event.isCompleted {
                icsContent += "\nSTATUS:COMPLETED"
            }
            
            icsContent += "\nEND:VEVENT\n"
        }
        
        icsContent += "END:VCALENDAR"
        
        return icsContent
    }
    
    // MARK: - Export to CSV format
    
    func exportToCSV(events: [Event]) -> String {
        var csvContent = "Title,Start Date,Start Time,End Date,End Time,Category,Location,Notes,Completed\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        
        for event in events {
            guard let startTime = event.startTime,
                  let endTime = event.endTime else { continue }
            
            let title = escapeCSVField(event.title ?? "Untitled")
            let startDate = dateFormatter.string(from: startTime)
            let startTimeStr = timeFormatter.string(from: startTime)
            let endDate = dateFormatter.string(from: endTime)
            let endTimeStr = timeFormatter.string(from: endTime)
            let category = escapeCSVField(event.category?.name ?? "")
            let location = escapeCSVField(event.location ?? "")
            let notes = escapeCSVField(event.notes ?? "")
            let completed = event.isCompleted ? "Yes" : "No"
            
            csvContent += "\(title),\(startDate),\(startTimeStr),\(endDate),\(endTimeStr),\(category),\(location),\(notes),\(completed)\n"
        }
        
        return csvContent
    }
    
    // MARK: - Export to JSON format
    
    func exportToJSON(events: [Event]) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let exportData = events.compactMap { event -> ExportableEvent? in
            guard let id = event.id?.uuidString,
                  let startTime = event.startTime,
                  let endTime = event.endTime else { return nil }
            
            return ExportableEvent(
                id: id,
                title: event.title ?? "Untitled",
                startTime: startTime,
                endTime: endTime,
                category: event.category?.name,
                categoryColor: event.category?.colorHex,
                location: event.location,
                notes: event.notes,
                isAllDay: false, // TODO: Add isAllDay to Event model
                isCompleted: event.isCompleted,
                completedAt: event.completedAt,
                recurrenceRule: event.recurrenceRule
            )
        }
        
        let exportContainer = ExportContainer(
            exportDate: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            eventCount: exportData.count,
            events: exportData
        )
        
        return try? encoder.encode(exportContainer)
    }
    
    // MARK: - Create temporary file for sharing
    
    func createTemporaryFile(content: String, filename: String) -> URL? {
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(filename)
        
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            return nil
        }
    }
    
    func createTemporaryFile(data: Data, filename: String) -> URL? {
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(filename)
        
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            return nil
        }
    }
    
    // MARK: - Helper functions
    
    private func escapeICSText(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: ";", with: "\\;")
    }
    
    private func escapeCSVField(_ text: String) -> String {
        if text.contains("\"") || text.contains(",") || text.contains("\n") {
            let escaped = text.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return text
    }
}

// MARK: - Export Models

struct ExportableEvent: Codable {
    let id: String
    let title: String
    let startTime: Date
    let endTime: Date
    let category: String?
    let categoryColor: String?
    let location: String?
    let notes: String?
    let isAllDay: Bool
    let isCompleted: Bool
    let completedAt: Date?
    let recurrenceRule: String?
}

struct ExportContainer: Codable {
    let exportDate: Date
    let appVersion: String
    let eventCount: Int
    let events: [ExportableEvent]
}