import Foundation
import CoreData
@testable import Momentum

// MARK: - Test Core Data Stack
class TestPersistenceController {
    static func createInMemoryContainer() -> NSPersistentContainer {
        let container = NSPersistentContainer(name: "Momentum")
        
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Failed to load test store: \(error), \(error.userInfo)")
            }
        }
        
        return container
    }
    
    static func createTestContext() -> NSManagedObjectContext {
        let container = createInMemoryContainer()
        let context = container.viewContext
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
}

// MARK: - Test Data Factory
class TestDataFactory {
    static func createTestCategory(
        in context: NSManagedObjectContext,
        name: String = "Test Category",
        colorHex: String = "#007AFF",
        iconName: String = "folder.fill"
    ) -> Category {
        let category = Category(context: context)
        category.id = UUID()
        category.name = name
        category.colorHex = colorHex
        category.iconName = iconName
        category.isActive = true
        category.isDefault = false
        category.sortOrder = 0
        category.createdAt = Date()
        return category
    }
    
    static func createTestEvent(
        in context: NSManagedObjectContext,
        title: String = "Test Event",
        startTime: Date = Date(),
        endTime: Date = Date().addingTimeInterval(3600),
        category: Category? = nil
    ) -> Event {
        let event = Event(context: context)
        event.id = UUID()
        event.title = title
        event.startTime = startTime
        event.endTime = endTime
        event.category = category
        event.dataSource = "manual"
        event.createdAt = Date()
        event.modifiedAt = Date()
        event.isCompleted = false
        event.colorHex = category?.colorHex ?? "#007AFF"
        return event
    }
    
    static func createEventsForDay(
        in context: NSManagedObjectContext,
        date: Date,
        count: Int = 5,
        category: Category? = nil
    ) -> [Event] {
        let calendar = Calendar.current
        var events: [Event] = []
        
        for i in 0..<count {
            let startTime = calendar.date(
                bySettingHour: 9 + (i * 2),
                minute: 0,
                second: 0,
                of: date
            )!
            let endTime = startTime.addingTimeInterval(3600) // 1 hour
            
            let event = createTestEvent(
                in: context,
                title: "Event \(i + 1)",
                startTime: startTime,
                endTime: endTime,
                category: category
            )
            events.append(event)
        }
        
        return events
    }
}


// MARK: - Date Test Helpers
extension Date {
    static func testDate(year: Int = 2025, month: Int = 6, day: Int = 30, hour: Int = 12, minute: Int = 0) -> Date {
        let calendar = Calendar.current
        let components = DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )
        return calendar.date(from: components)!
    }
    
    static func todayAt(hour: Int, minute: Int = 0) -> Date {
        let calendar = Calendar.current
        return calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: Date()
        )!
    }
}

// MARK: - XCTest Helpers
import XCTest

extension XCTestCase {
    func waitForAsync(timeout: TimeInterval = 5.0, action: @escaping () async throws -> Void) {
        let expectation = XCTestExpectation(description: "Async operation")
        
        Task {
            do {
                try await action()
                expectation.fulfill()
            } catch {
                XCTFail("Async operation failed: \(error)")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: timeout)
    }
}