import SwiftUI
import CoreData

/// Manages data export, import, backup, and deletion operations
@MainActor
class DataManagementViewModel: ObservableObject {
    // MARK: - Backup Settings
    @AppStorage("autoBackupEnabled") var autoBackupEnabled = false
    @AppStorage("lastBackupDate") var lastBackupTimestamp: Double = 0
    
    // MARK: - Published Properties
    @Published var showingExportOptions = false
    @Published var exportFileURL: URL?
    @Published var exportedFileURL: URL?
    @Published var showingShareSheet = false
    @Published var showingDeleteConfirmation = false
    @Published var showingDataDeletedAlert = false
    @Published var isExporting = false
    @Published var isDeleting = false
    
    // MARK: - Export Format
    enum ExportFormat: String, CaseIterable {
        case json = "JSON"
        case csv = "CSV"
        case ics = "ICS"
        
        var fileExtension: String {
            switch self {
            case .json: return "json"
            case .csv: return "csv"
            case .ics: return "ics"
            }
        }
    }
    
    // MARK: - Methods
    
    func exportData(format: ExportFormat) {
        isExporting = true
        
        _Concurrency.Task {
            do {
                let data = try await fetchAllData()
                let exportedData = try formatData(data, format: format)
                let fileName = "momentum_export_\(Date().timeIntervalSince1970).\(format.fileExtension)"
                
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                try exportedData.write(to: tempURL)
                
                await MainActor.run {
                    self.exportFileURL = tempURL
                    self.exportedFileURL = tempURL
                    self.showingShareSheet = true
                    self.isExporting = false
                }
            } catch {
                print("Export failed: \(error)")
                await MainActor.run {
                    self.isExporting = false
                }
            }
        }
    }
    
    func deleteAllUserData() {
        isDeleting = true
        
        let container = PersistenceController.shared.container
        let coordinator = container.persistentStoreCoordinator
        
        // Delete all Core Data entities
        let entities = ["Event", "Task", "Habit", "Goal", "Category", "Milestone", "HabitLog"]
        
        for entity in entities {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entity)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try coordinator.execute(deleteRequest, with: container.viewContext)
            } catch {
                print("Failed to delete \(entity): \(error)")
            }
        }
        
        // Clear UserDefaults
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        
        // Clear documents directory
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            do {
                let fileURLs = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
                for fileURL in fileURLs {
                    try FileManager.default.removeItem(at: fileURL)
                }
            } catch {
                print("Failed to clear documents: \(error)")
            }
        }
        
        isDeleting = false
        showingDataDeletedAlert = true
        
        // Reset app after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            exit(0)
        }
    }
    
    func performBackup() {
        _Concurrency.Task {
            do {
                let data = try await fetchAllData()
                let backupData = try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
                
                // Save to iCloud Documents
                if let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
                    .appendingPathComponent("Documents")
                    .appendingPathComponent("Backups") {
                    
                    try FileManager.default.createDirectory(at: iCloudURL, withIntermediateDirectories: true)
                    
                    let fileName = "backup_\(Date().timeIntervalSince1970).json"
                    let fileURL = iCloudURL.appendingPathComponent(fileName)
                    
                    try backupData.write(to: fileURL)
                    
                    await MainActor.run {
                        self.lastBackupTimestamp = Date().timeIntervalSince1970
                    }
                }
            } catch {
                print("Backup failed: \(error)")
            }
        }
    }
    
    private func fetchAllData() async throws -> [String: Any] {
        let container = PersistenceController.shared.container
        let context = container.viewContext
        
        var data: [String: Any] = [:]
        
        // Fetch Events
        let eventRequest: NSFetchRequest<Event> = Event.fetchRequest()
        let events = try context.fetch(eventRequest)
        data["events"] = events.map { event in
            [
                "title": event.title ?? "",
                "startTime": event.startTime?.timeIntervalSince1970 ?? TimeInterval(0),
                "endTime": event.endTime?.timeIntervalSince1970 ?? TimeInterval(0),
                "notes": event.notes ?? "",
                "location": event.location ?? ""
            ] as [String: Any]
        }
        
        // Fetch Tasks
        let taskRequest: NSFetchRequest<Task> = Task.fetchRequest()
        let tasks = try context.fetch(taskRequest)
        data["tasks"] = tasks.map { task in
            [
                "title": task.title ?? "",
                "isCompleted": task.isCompleted,
                "priority": task.priority,
                "dueDate": task.dueDate?.timeIntervalSince1970 ?? 0,
                "notes": task.notes ?? ""
            ]
        }
        
        // Add more entities as needed...
        
        return data
    }
    
    private func formatData(_ data: [String: Any], format: ExportFormat) throws -> Data {
        switch format {
        case .json:
            return try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
            
        case .csv:
            // Simple CSV implementation for tasks
            var csv = "Title,Completed,Priority,Due Date,Notes\n"
            
            if let tasks = data["tasks"] as? [[String: Any]] {
                for task in tasks {
                    let title = task["title"] as? String ?? ""
                    let completed = task["isCompleted"] as? Bool ?? false
                    let priority = task["priority"] as? Int ?? 0
                    let dueDate = task["dueDate"] as? Double ?? 0
                    let notes = task["notes"] as? String ?? ""
                    
                    let dateString = dueDate > 0 ? Date(timeIntervalSince1970: dueDate).ISO8601Format() : ""
                    
                    csv += "\"\(title)\",\(completed),\(priority),\"\(dateString)\",\"\(notes)\"\n"
                }
            }
            
            return csv.data(using: .utf8) ?? Data()
            
        case .ics:
            // iCalendar format for events
            var ics = "BEGIN:VCALENDAR\nVERSION:2.0\nPRODID:-//Momentum//EN\n"
            
            if let events = data["events"] as? [[String: Any]] {
                for event in events {
                    let title = event["title"] as? String ?? ""
                    let startTime = event["startTime"] as? TimeInterval ?? 0
                    let endTime = event["endTime"] as? TimeInterval ?? 0
                    let notes = event["notes"] as? String ?? ""
                    
                    ics += "BEGIN:VEVENT\n"
                    ics += "SUMMARY:\(title)\n"
                    ics += "DTSTART:\(formatDateForICS(Date(timeIntervalSince1970: startTime)))\n"
                    ics += "DTEND:\(formatDateForICS(Date(timeIntervalSince1970: endTime)))\n"
                    if !notes.isEmpty {
                        ics += "DESCRIPTION:\(notes)\n"
                    }
                    ics += "END:VEVENT\n"
                }
            }
            
            ics += "END:VCALENDAR"
            return ics.data(using: .utf8) ?? Data()
        }
    }
    
    private func formatDateForICS(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter.string(from: date)
    }
    
    var lastBackupDate: Date? {
        guard lastBackupTimestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: lastBackupTimestamp)
    }
    
    func formatBackupDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}