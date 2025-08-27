//
//  DTOs.swift
//  Momentum
//
//  Data Transfer Objects for AI Coordinator
//

import Foundation

// MARK: - Event DTOs

struct EventCreateRequest: Decodable {
    var title: String = "New Event"
    var startTime: String?
    var endTime: String?
    var notes: String?
    var location: String?
    var isAllDay: Bool = false
    var categoryId: String?
    var category: String?
    var colorHex: String?
    var iconName: String?
    
    // Custom decoding to handle both snake_case and camelCase
    enum CodingKeys: String, CodingKey {
        case title
        case startTime = "start_time"
        case endTime = "end_time"
        case notes
        case location
        case isAllDay = "is_all_day"
        case categoryId = "category_id"
        case category
        case colorHex = "color_hex"
        case iconName = "icon_name"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "New Event"
        startTime = try container.decodeIfPresent(String.self, forKey: .startTime)
        endTime = try container.decodeIfPresent(String.self, forKey: .endTime)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        isAllDay = try container.decodeIfPresent(Bool.self, forKey: .isAllDay) ?? false
        categoryId = try container.decodeIfPresent(String.self, forKey: .categoryId)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex)
        iconName = try container.decodeIfPresent(String.self, forKey: .iconName)
    }
}

struct EventUpdateRequest: Decodable {
    var id: String
    var eventId: String? // Support both "id" and "eventId"
    var title: String?
    var startTime: String?
    var endTime: String?
    var notes: String?
    var location: String?
    var isAllDay: Bool?
    var isCompleted: Bool?
    var categoryId: String?
    var category: String?
    var colorHex: String?
    var iconName: String?
    var priority: String?
    var tags: String?
    var url: String?
    var energyLevel: String?
    var weatherRequired: String?
    var bufferTimeBefore: Int32?
    var bufferTimeAfter: Int32?
    var recurrenceRule: String?
    var recurrenceEndDate: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case eventId = "event_id"
        case title
        case startTime = "start_time"
        case endTime = "end_time"
        case notes
        case location
        case isAllDay = "is_all_day"
        case isCompleted = "is_completed"
        case categoryId = "category_id"
        case category
        case colorHex = "color_hex"
        case iconName = "icon_name"
        case priority
        case tags
        case url
        case energyLevel = "energy_level"
        case weatherRequired = "weather_required"
        case bufferTimeBefore = "buffer_time_before"
        case bufferTimeAfter = "buffer_time_after"
        case recurrenceRule = "recurrence_rule"
        case recurrenceEndDate = "recurrence_end_date"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle both "id" and "eventId"
        if let directId = try container.decodeIfPresent(String.self, forKey: .id) {
            id = directId
        } else if let eventIdValue = try container.decodeIfPresent(String.self, forKey: .eventId) {
            id = eventIdValue
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.id,
                DecodingError.Context(codingPath: [CodingKeys.id], debugDescription: "Neither 'id' nor 'eventId' found")
            )
        }
        
        eventId = try container.decodeIfPresent(String.self, forKey: .eventId)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        startTime = try container.decodeIfPresent(String.self, forKey: .startTime)
        endTime = try container.decodeIfPresent(String.self, forKey: .endTime)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        isAllDay = try container.decodeIfPresent(Bool.self, forKey: .isAllDay)
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted)
        categoryId = try container.decodeIfPresent(String.self, forKey: .categoryId)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex)
        iconName = try container.decodeIfPresent(String.self, forKey: .iconName)
        priority = try container.decodeIfPresent(String.self, forKey: .priority)
        tags = try container.decodeIfPresent(String.self, forKey: .tags)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        energyLevel = try container.decodeIfPresent(String.self, forKey: .energyLevel)
        weatherRequired = try container.decodeIfPresent(String.self, forKey: .weatherRequired)
        bufferTimeBefore = try container.decodeIfPresent(Int32.self, forKey: .bufferTimeBefore)
        bufferTimeAfter = try container.decodeIfPresent(Int32.self, forKey: .bufferTimeAfter)
        recurrenceRule = try container.decodeIfPresent(String.self, forKey: .recurrenceRule)
        recurrenceEndDate = try container.decodeIfPresent(String.self, forKey: .recurrenceEndDate)
    }
}

struct EventDeleteRequest: Decodable {
    var id: String?
    var ids: [String]?
    var deleteAll: Bool?
    var confirm: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id
        case ids
        case deleteAll = "delete_all"
        case confirm
    }
}

struct EventListRequest: Decodable {
    var date: String?
    var startDate: String?
    var endDate: String?
    var filter: String?
    
    enum CodingKeys: String, CodingKey {
        case date
        case startDate = "start_date"
        case endDate = "end_date"
        case filter
    }
}

// MARK: - Event Response DTO

struct EventView: Encodable {
    let id: String
    let title: String
    let startTime: String
    let endTime: String
    let location: String
    let notes: String
    let isCompleted: Bool
    let colorHex: String
    let iconName: String
    let category: String
    let priority: String?
    let energyLevel: String?
    let weatherRequired: String
    let url: String
    let tags: [String]
    let bufferTimeBefore: Int
    let bufferTimeAfter: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case startTime = "start_time"
        case endTime = "end_time"
        case location
        case notes
        case isCompleted = "is_completed"
        case colorHex = "color_hex"
        case iconName = "icon_name"
        case category
        case priority
        case energyLevel = "energy_level"
        case weatherRequired = "weather_required"
        case url
        case tags
        case bufferTimeBefore = "buffer_time_before"
        case bufferTimeAfter = "buffer_time_after"
    }
}

// MARK: - Task DTOs

struct TaskCreateRequest: Decodable {
    var title: String = "New Task"
    var desc: String?
    var dueDate: String?
    var isCompleted: Bool = false
    var priority: String = "medium"
    var categoryId: String?
    var category: String?
    var estimatedDuration: Int32?
    var completedAt: String?
    var parentTaskId: String?
    var linkedEventId: String?
    var notes: String?
    var tags: String?
    var recurrenceRule: String?
    var reminder: String?
    
    enum CodingKeys: String, CodingKey {
        case title
        case desc, description
        case dueDate = "due_date"
        case isCompleted = "is_completed"
        case priority
        case categoryId = "category_id"
        case category
        case estimatedDuration = "estimated_duration"
        case completedAt = "completed_at"
        case parentTaskId = "parent_task_id"
        case linkedEventId = "linked_event_id"
        case notes
        case tags
        case recurrenceRule = "recurrence_rule"
        case reminder
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "New Task"
        desc = try container.decodeIfPresent(String.self, forKey: .desc) ?? container.decodeIfPresent(String.self, forKey: .description)
        dueDate = try container.decodeIfPresent(String.self, forKey: .dueDate)
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        priority = try container.decodeIfPresent(String.self, forKey: .priority) ?? "medium"
        categoryId = try container.decodeIfPresent(String.self, forKey: .categoryId)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        estimatedDuration = try container.decodeIfPresent(Int32.self, forKey: .estimatedDuration)
        completedAt = try container.decodeIfPresent(String.self, forKey: .completedAt)
        parentTaskId = try container.decodeIfPresent(String.self, forKey: .parentTaskId)
        linkedEventId = try container.decodeIfPresent(String.self, forKey: .linkedEventId)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        tags = try container.decodeIfPresent(String.self, forKey: .tags)
        recurrenceRule = try container.decodeIfPresent(String.self, forKey: .recurrenceRule)
        reminder = try container.decodeIfPresent(String.self, forKey: .reminder)
    }
}

struct TaskUpdateRequest: Decodable {
    var id: String
    var taskId: String?
    var title: String?
    var desc: String?
    var dueDate: String?
    var isCompleted: Bool?
    var priority: String?
    var categoryId: String?
    var category: String?
    var estimatedDuration: Int32?
    var completedAt: String?
    var parentTaskId: String?
    var linkedEventId: String?
    var notes: String?
    var tags: String?
    var recurrenceRule: String?
    var reminder: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case taskId = "task_id"
        case title
        case desc, description
        case dueDate = "due_date"
        case isCompleted = "is_completed"
        case priority
        case categoryId = "category_id"
        case category
        case estimatedDuration = "estimated_duration"
        case completedAt = "completed_at"
        case parentTaskId = "parent_task_id"
        case linkedEventId = "linked_event_id"
        case notes
        case tags
        case recurrenceRule = "recurrence_rule"
        case reminder
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle both "id" and "taskId"
        if let directId = try container.decodeIfPresent(String.self, forKey: .id) {
            id = directId
        } else if let taskIdValue = try container.decodeIfPresent(String.self, forKey: .taskId) {
            id = taskIdValue
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.id,
                DecodingError.Context(codingPath: [CodingKeys.id], debugDescription: "Neither 'id' nor 'taskId' found")
            )
        }
        
        taskId = try container.decodeIfPresent(String.self, forKey: .taskId)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        desc = try container.decodeIfPresent(String.self, forKey: .desc) ?? container.decodeIfPresent(String.self, forKey: .description)
        dueDate = try container.decodeIfPresent(String.self, forKey: .dueDate)
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted)
        priority = try container.decodeIfPresent(String.self, forKey: .priority)
        categoryId = try container.decodeIfPresent(String.self, forKey: .categoryId)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        estimatedDuration = try container.decodeIfPresent(Int32.self, forKey: .estimatedDuration)
        completedAt = try container.decodeIfPresent(String.self, forKey: .completedAt)
        parentTaskId = try container.decodeIfPresent(String.self, forKey: .parentTaskId)
        linkedEventId = try container.decodeIfPresent(String.self, forKey: .linkedEventId)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        tags = try container.decodeIfPresent(String.self, forKey: .tags)
        recurrenceRule = try container.decodeIfPresent(String.self, forKey: .recurrenceRule)
        reminder = try container.decodeIfPresent(String.self, forKey: .reminder)
    }
}

struct TaskView: Encodable {
    let id: String
    let title: String
    let description: String
    let dueDate: String?
    let isCompleted: Bool
    let priority: String
    let category: String
    let estimatedDuration: Int
    let completedAt: String?
    let parentTaskId: String?
    let linkedEventId: String?
    let notes: String
    let tags: [String]
    let recurrenceRule: String?
    let reminder: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case dueDate = "due_date"
        case isCompleted = "is_completed"
        case priority
        case category
        case estimatedDuration = "estimated_duration"
        case completedAt = "completed_at"
        case parentTaskId = "parent_task_id"
        case linkedEventId = "linked_event_id"
        case notes
        case tags
        case recurrenceRule = "recurrence_rule"
        case reminder
    }
}

// MARK: - Habit DTOs

struct HabitCreateRequest: Decodable {
    var name: String = "New Habit"
    var notes: String?
    var frequency: String = "daily"
    var goalTarget: Int32 = 1
    var unit: String?
    var color: String?
    var icon: String?
    var categoryId: String?
    var category: String?
    var reminder: String?
    var startDate: String?
    var endDate: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case notes, description
        case frequency
        case goalTarget = "goal_target"
        case targetCount = "target_count"
        case unit
        case color
        case icon
        case categoryId = "category_id"
        case category
        case reminder
        case startDate = "start_date"
        case endDate = "end_date"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "New Habit"
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? container.decodeIfPresent(String.self, forKey: .description)
        frequency = try container.decodeIfPresent(String.self, forKey: .frequency) ?? "daily"
        goalTarget = try container.decodeIfPresent(Int32.self, forKey: .goalTarget) ?? container.decodeIfPresent(Int32.self, forKey: .targetCount) ?? 1
        unit = try container.decodeIfPresent(String.self, forKey: .unit)
        color = try container.decodeIfPresent(String.self, forKey: .color)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        categoryId = try container.decodeIfPresent(String.self, forKey: .categoryId)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        reminder = try container.decodeIfPresent(String.self, forKey: .reminder)
        startDate = try container.decodeIfPresent(String.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(String.self, forKey: .endDate)
    }
}

struct HabitUpdateRequest: Decodable {
    var id: String
    var habitId: String?
    var name: String?
    var notes: String?
    var frequency: String?
    var goalTarget: Int32?
    var unit: String?
    var color: String?
    var icon: String?
    var categoryId: String?
    var category: String?
    var reminder: String?
    var startDate: String?
    var endDate: String?
    var isArchived: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id
        case habitId = "habit_id"
        case name
        case notes, description
        case frequency
        case goalTarget = "goal_target"
        case targetCount = "target_count"
        case unit
        case color
        case icon
        case categoryId = "category_id"
        case category
        case reminder
        case startDate = "start_date"
        case endDate = "end_date"
        case isArchived = "is_archived"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle both "id" and "habitId"
        if let directId = try container.decodeIfPresent(String.self, forKey: .id) {
            id = directId
        } else if let habitIdValue = try container.decodeIfPresent(String.self, forKey: .habitId) {
            id = habitIdValue
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.id,
                DecodingError.Context(codingPath: [CodingKeys.id], debugDescription: "Neither 'id' nor 'habitId' found")
            )
        }
        
        habitId = try container.decodeIfPresent(String.self, forKey: .habitId)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? container.decodeIfPresent(String.self, forKey: .description)
        frequency = try container.decodeIfPresent(String.self, forKey: .frequency)
        goalTarget = try container.decodeIfPresent(Int32.self, forKey: .goalTarget) ?? container.decodeIfPresent(Int32.self, forKey: .targetCount)
        unit = try container.decodeIfPresent(String.self, forKey: .unit)
        color = try container.decodeIfPresent(String.self, forKey: .color)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        categoryId = try container.decodeIfPresent(String.self, forKey: .categoryId)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        reminder = try container.decodeIfPresent(String.self, forKey: .reminder)
        startDate = try container.decodeIfPresent(String.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(String.self, forKey: .endDate)
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived)
    }
}

struct HabitLogRequest: Decodable {
    var habitId: String
    var date: String?
    var value: Int32?
    
    enum CodingKeys: String, CodingKey {
        case habitId = "habit_id"
        case id
        case date
        case value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        habitId = try container.decodeIfPresent(String.self, forKey: .habitId) ?? container.decode(String.self, forKey: .id)
        date = try container.decodeIfPresent(String.self, forKey: .date)
        value = try container.decodeIfPresent(Int32.self, forKey: .value)
    }
}

struct HabitView: Encodable {
    let id: String
    let name: String
    let notes: String
    let frequency: String
    let goalTarget: Int
    let unit: String
    let color: String
    let icon: String
    let category: String
    let reminder: String?
    let startDate: String?
    let endDate: String?
    let isArchived: Bool
    let currentStreak: Int
    let longestStreak: Int
    let todayProgress: Int
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case notes
        case frequency
        case goalTarget = "goal_target"
        case unit
        case color
        case icon
        case category
        case reminder
        case startDate = "start_date"
        case endDate = "end_date"
        case isArchived = "is_archived"
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
        case todayProgress = "today_progress"
        case createdAt = "created_at"
    }
}

// MARK: - Goal DTOs

struct GoalCreateRequest: Decodable {
    var title: String = "New Goal"
    var desc: String?
    var targetValue: Double = 100
    var currentValue: Double = 0
    var unit: String?
    var targetDate: String?
    var categoryId: String?
    var category: String?
    var priority: String = "medium"
    
    enum CodingKeys: String, CodingKey {
        case title
        case desc, description
        case targetValue = "target_value"
        case currentValue = "current_value"
        case unit
        case targetDate = "target_date"
        case categoryId = "category_id"
        case category
        case priority
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "New Goal"
        desc = try container.decodeIfPresent(String.self, forKey: .desc) ?? container.decodeIfPresent(String.self, forKey: .description)
        targetValue = try container.decodeIfPresent(Double.self, forKey: .targetValue) ?? 100
        currentValue = try container.decodeIfPresent(Double.self, forKey: .currentValue) ?? 0
        unit = try container.decodeIfPresent(String.self, forKey: .unit)
        targetDate = try container.decodeIfPresent(String.self, forKey: .targetDate)
        categoryId = try container.decodeIfPresent(String.self, forKey: .categoryId)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        priority = try container.decodeIfPresent(String.self, forKey: .priority) ?? "medium"
    }
}

struct GoalUpdateRequest: Decodable {
    var id: String
    var goalId: String?
    var title: String?
    var desc: String?
    var targetValue: Double?
    var currentValue: Double?
    var unit: String?
    var targetDate: String?
    var isCompleted: Bool?
    var categoryId: String?
    var category: String?
    var priority: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case goalId = "goal_id"
        case title
        case desc, description
        case targetValue = "target_value"
        case currentValue = "current_value"
        case unit
        case targetDate = "target_date"
        case isCompleted = "is_completed"
        case categoryId = "category_id"
        case category
        case priority
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle both "id" and "goalId"
        if let directId = try container.decodeIfPresent(String.self, forKey: .id) {
            id = directId
        } else if let goalIdValue = try container.decodeIfPresent(String.self, forKey: .goalId) {
            id = goalIdValue
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.id,
                DecodingError.Context(codingPath: [CodingKeys.id], debugDescription: "Neither 'id' nor 'goalId' found")
            )
        }
        
        goalId = try container.decodeIfPresent(String.self, forKey: .goalId)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        desc = try container.decodeIfPresent(String.self, forKey: .desc) ?? container.decodeIfPresent(String.self, forKey: .description)
        targetValue = try container.decodeIfPresent(Double.self, forKey: .targetValue)
        currentValue = try container.decodeIfPresent(Double.self, forKey: .currentValue)
        unit = try container.decodeIfPresent(String.self, forKey: .unit)
        targetDate = try container.decodeIfPresent(String.self, forKey: .targetDate)
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted)
        categoryId = try container.decodeIfPresent(String.self, forKey: .categoryId)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        priority = try container.decodeIfPresent(String.self, forKey: .priority)
    }
}

struct GoalProgressRequest: Decodable {
    var id: String
    var value: Double?
    var increment: Double?
    
    enum CodingKeys: String, CodingKey {
        case id
        case goalId = "goal_id"
        case value
        case increment
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? container.decode(String.self, forKey: .goalId)
        value = try container.decodeIfPresent(Double.self, forKey: .value)
        increment = try container.decodeIfPresent(Double.self, forKey: .increment)
    }
}

struct GoalView: Encodable {
    let id: String
    let title: String
    let description: String
    let targetValue: Double
    let currentValue: Double
    let unit: String
    let targetDate: String?
    let isCompleted: Bool
    let category: String
    let priority: String
    let progress: Double
    let createdAt: String
    let completedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case targetValue = "target_value"
        case currentValue = "current_value"
        case unit
        case targetDate = "target_date"
        case isCompleted = "is_completed"
        case category
        case priority
        case progress
        case createdAt = "created_at"
        case completedAt = "completed_at"
    }
}

// MARK: - Category DTOs

struct CategoryCreateRequest: Decodable {
    var name: String = "New Category"
    var colorHex: String?
    var iconName: String?
    var orderIndex: Int32?
    
    enum CodingKeys: String, CodingKey {
        case name
        case colorHex = "color_hex"
        case color
        case iconName = "icon_name"
        case icon
        case orderIndex = "order_index"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "New Category"
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex) ?? container.decodeIfPresent(String.self, forKey: .color)
        iconName = try container.decodeIfPresent(String.self, forKey: .iconName) ?? container.decodeIfPresent(String.self, forKey: .icon)
        orderIndex = try container.decodeIfPresent(Int32.self, forKey: .orderIndex)
    }
}

struct CategoryUpdateRequest: Decodable {
    var id: String
    var categoryId: String?
    var name: String?
    var colorHex: String?
    var iconName: String?
    var orderIndex: Int32?
    
    enum CodingKeys: String, CodingKey {
        case id
        case categoryId = "category_id"
        case name
        case colorHex = "color_hex"
        case color
        case iconName = "icon_name"
        case icon
        case orderIndex = "order_index"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle both "id" and "categoryId"
        if let directId = try container.decodeIfPresent(String.self, forKey: .id) {
            id = directId
        } else if let categoryIdValue = try container.decodeIfPresent(String.self, forKey: .categoryId) {
            id = categoryIdValue
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.id,
                DecodingError.Context(codingPath: [CodingKeys.id], debugDescription: "Neither 'id' nor 'categoryId' found")
            )
        }
        
        categoryId = try container.decodeIfPresent(String.self, forKey: .categoryId)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex) ?? container.decodeIfPresent(String.self, forKey: .color)
        iconName = try container.decodeIfPresent(String.self, forKey: .iconName) ?? container.decodeIfPresent(String.self, forKey: .icon)
        orderIndex = try container.decodeIfPresent(Int32.self, forKey: .orderIndex)
    }
}

struct CategoryView: Encodable {
    let id: String
    let name: String
    let colorHex: String
    let iconName: String
    let orderIndex: Int
    let eventCount: Int
    let taskCount: Int
    let habitCount: Int
    let goalCount: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case colorHex = "color_hex"
        case iconName = "icon_name"
        case orderIndex = "order_index"
        case eventCount = "event_count"
        case taskCount = "task_count"
        case habitCount = "habit_count"
        case goalCount = "goal_count"
    }
}