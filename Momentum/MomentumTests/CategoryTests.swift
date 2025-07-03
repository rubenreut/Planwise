import XCTest
import CoreData
@testable import Momentum

class CategoryTests: XCTestCase {
    var context: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        context = TestPersistenceController.createTestContext()
    }
    
    override func tearDown() {
        context = nil
        super.tearDown()
    }
    
    // MARK: - Basic Category Creation Tests
    
    func testCategoryCreation() {
        // Given
        let category = Category(context: context)
        
        // When
        category.id = UUID()
        category.name = "Test Category"
        category.iconName = "folder.fill"
        category.colorHex = "#FF0000"
        category.isActive = true
        category.isDefault = false
        category.sortOrder = 0
        category.createdAt = Date()
        
        // Then
        XCTAssertNotNil(category.id)
        XCTAssertEqual(category.name, "Test Category")
        XCTAssertEqual(category.iconName, "folder.fill")
        XCTAssertEqual(category.colorHex, "#FF0000")
        XCTAssertTrue(category.isActive)
        XCTAssertFalse(category.isDefault)
        XCTAssertEqual(category.sortOrder, 0)
        XCTAssertNotNil(category.createdAt)
    }
    
    func testDefaultCategoryCreation() {
        // Given
        let category = TestDataFactory.createTestCategory(
            in: context,
            name: "Work",
            colorHex: "#007AFF",
            iconName: "briefcase.fill"
        )
        
        // When
        category.isDefault = true
        
        // Then
        XCTAssertTrue(category.isDefault)
        XCTAssertTrue(category.isActive)
    }
    
    // MARK: - Category-Event Relationship Tests
    
    func testCategoryWithEvents() throws {
        // Given
        let category = TestDataFactory.createTestCategory(in: context, name: "Work")
        
        // When
        let event1 = TestDataFactory.createTestEvent(in: context, title: "Meeting", category: category)
        let event2 = TestDataFactory.createTestEvent(in: context, title: "Presentation", category: category)
        let event3 = TestDataFactory.createTestEvent(in: context, title: "Code Review", category: category)
        
        try context.save()
        
        // Then
        XCTAssertNotNil(category.events)
        XCTAssertEqual(category.events?.count, 3)
        
        // Verify inverse relationship
        XCTAssertEqual(event1.category, category)
        XCTAssertEqual(event2.category, category)
        XCTAssertEqual(event3.category, category)
    }
    
    func testCategoryDeletion() throws {
        // Given
        let category = TestDataFactory.createTestCategory(in: context)
        let event = TestDataFactory.createTestEvent(in: context, category: category)
        
        try context.save()
        
        // When
        context.delete(category)
        try context.save()
        
        // Then - Event should still exist but without category (nullify rule)
        XCTAssertNil(event.category)
        XCTAssertFalse(event.isDeleted)
    }
    
    // MARK: - Category Sorting Tests
    
    func testCategorySortOrder() throws {
        // Given
        let category1 = TestDataFactory.createTestCategory(in: context, name: "First")
        category1.sortOrder = 0
        
        let category2 = TestDataFactory.createTestCategory(in: context, name: "Second")
        category2.sortOrder = 1
        
        let category3 = TestDataFactory.createTestCategory(in: context, name: "Third")
        category3.sortOrder = 2
        
        try context.save()
        
        // When
        let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \Category.sortOrder, ascending: true)
        ]
        
        let results = try context.fetch(fetchRequest)
        
        // Then
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results[0].name, "First")
        XCTAssertEqual(results[1].name, "Second")
        XCTAssertEqual(results[2].name, "Third")
    }
    
    // MARK: - Category Filtering Tests
    
    func testActiveCategories() throws {
        // Given
        let activeCategory = TestDataFactory.createTestCategory(in: context, name: "Active")
        activeCategory.isActive = true
        
        let inactiveCategory = TestDataFactory.createTestCategory(in: context, name: "Inactive")
        inactiveCategory.isActive = false
        
        try context.save()
        
        // When
        let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isActive == YES")
        
        let results = try context.fetch(fetchRequest)
        
        // Then
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].name, "Active")
    }
    
    func testDefaultCategories() throws {
        // Given
        let defaultCategory = TestDataFactory.createTestCategory(in: context, name: "Default")
        defaultCategory.isDefault = true
        
        let customCategory = TestDataFactory.createTestCategory(in: context, name: "Custom")
        customCategory.isDefault = false
        
        try context.save()
        
        // When
        let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isDefault == YES")
        
        let results = try context.fetch(fetchRequest)
        
        // Then
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].name, "Default")
    }
    
    // MARK: - Category Validation Tests
    
    func testCategoryWithEmptyName() {
        // Given
        let category = Category(context: context)
        
        // When
        category.id = UUID()
        category.name = ""
        category.iconName = "folder.fill"
        category.colorHex = "#FF0000"
        
        // Then
        XCTAssertEqual(category.name, "")
        // Note: Validation should be handled at the business logic layer
    }
    
    func testCategoryWithLongName() {
        // Given
        let category = Category(context: context)
        let longName = String(repeating: "A", count: 200)
        
        // When
        category.name = longName
        
        // Then
        XCTAssertEqual(category.name?.count, 200)
    }
    
    func testCategoryWithInvalidColorHex() {
        // Given
        let category = Category(context: context)
        
        // When
        category.colorHex = "NotAColor"
        
        // Then
        XCTAssertEqual(category.colorHex, "NotAColor")
        // Note: Color validation should be handled at the UI layer
    }
    
    // MARK: - Category Icon Tests
    
    func testCategoryWithSystemIcon() {
        // Given
        let systemIcons = [
            "folder.fill",
            "briefcase.fill",
            "heart.fill",
            "star.fill",
            "flag.fill",
            "bell.fill"
        ]
        
        // When/Then
        for icon in systemIcons {
            let category = TestDataFactory.createTestCategory(in: context, iconName: icon)
            XCTAssertEqual(category.iconName, icon)
        }
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceOfCategoryFetch() throws {
        // Setup - Create 100 categories
        for i in 0..<100 {
            let category = TestDataFactory.createTestCategory(
                in: context,
                name: "Category \(i)"
            )
            category.sortOrder = Int32(i)
        }
        try context.save()
        
        // Measure
        measure {
            let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
            fetchRequest.sortDescriptors = [
                NSSortDescriptor(keyPath: \Category.sortOrder, ascending: true)
            ]
            _ = try? context.fetch(fetchRequest)
        }
    }
    
    // MARK: - Edge Cases
    
    func testCategoryWithNilOptionalFields() {
        // Given
        let category = Category(context: context)
        
        // When - Set only required fields
        category.name = "Minimal Category"
        category.colorHex = "#000000"
        category.iconName = "folder"
        category.isActive = true
        category.isDefault = false
        category.sortOrder = 0
        category.createdAt = Date()
        // Leave id as nil (it's optional)
        
        // Then
        XCTAssertNil(category.id)
        XCTAssertNotNil(category.name)
        XCTAssertNotNil(category.colorHex)
        XCTAssertNotNil(category.iconName)
    }
    
    func testCategoryEventCount() throws {
        // Given
        let category = TestDataFactory.createTestCategory(in: context)
        
        // Create varying number of events
        for i in 0..<25 {
            _ = TestDataFactory.createTestEvent(
                in: context,
                title: "Event \(i)",
                category: category
            )
        }
        
        try context.save()
        
        // When
        let eventCount = category.events?.count ?? 0
        
        // Then
        XCTAssertEqual(eventCount, 25)
    }
    
    func testDuplicateCategoryNames() throws {
        // Given
        let category1 = TestDataFactory.createTestCategory(in: context, name: "Duplicate")
        let category2 = TestDataFactory.createTestCategory(in: context, name: "Duplicate")
        
        // When
        try context.save()
        
        // Then
        let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", "Duplicate")
        
        let results = try context.fetch(fetchRequest)
        XCTAssertEqual(results.count, 2) // Both should exist
    }
}