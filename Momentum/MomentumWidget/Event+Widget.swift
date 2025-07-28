import Foundation
import CoreData
import SwiftUI

// MARK: - Widget Event Extensions

extension Event {
    /// Calculate duration in seconds
    var duration: TimeInterval? {
        guard let start = startTime, let end = endTime else { return nil }
        return end.timeIntervalSince(start)
    }
    
    static func todayEvents() -> [Event] {
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest: NSFetchRequest<Event> = Event.fetchRequest()
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }
        
        fetchRequest.predicate = NSPredicate(
            format: "startTime >= %@ AND startTime < %@",
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Event.startTime, ascending: true)]
        
        do {
            return try context.fetch(fetchRequest)
        } catch {
            return []
        }
    }
    
    static func placeholderEvents() -> [Event] {
        // Create placeholder events for widget previews
        let context = PersistenceController.preview.container.viewContext
        
        let event1 = Event(context: context)
        event1.id = UUID()
        event1.title = "Team Meeting"
        event1.startTime = Calendar.current.date(byAdding: .hour, value: 1, to: Date())
        event1.endTime = Calendar.current.date(byAdding: .hour, value: 2, to: Date())
        event1.isCompleted = false
        
        let event2 = Event(context: context)
        event2.id = UUID()
        event2.title = "Lunch with Sarah"
        event2.startTime = Calendar.current.date(byAdding: .hour, value: 4, to: Date())
        event2.endTime = Calendar.current.date(byAdding: .hour, value: 5, to: Date())
        event2.location = "Downtown Cafe"
        event2.isCompleted = false
        
        let event3 = Event(context: context)
        event3.id = UUID()
        event3.title = "Project Review"
        event3.startTime = Calendar.current.date(byAdding: .hour, value: 6, to: Date())
        event3.endTime = Calendar.current.date(byAdding: .hour, value: 7, to: Date())
        event3.isCompleted = false
        
        return [event1, event2, event3]
    }
}

// Color extension is already provided by the main app target