// Simplified AI Functions - 5 functions to replace 103
// Each handles full CRUD + bulk operations

export const SIMPLIFIED_FUNCTIONS = [
  {
    name: 'manage_events',
    description: 'Manage events - create, update, delete, list events. Handles single and bulk operations.',
    parameters: {
      type: 'object',
      properties: {
        action: {
          type: 'string',
          enum: ['create', 'update', 'delete', 'list', 'search'],
          description: 'The operation to perform'
        },
        parameters: {
          type: 'object',
          description: 'Parameters for the action. For bulk operations with different values per item, use items:[]. For bulk operations with same value for all, use updateAll:true.',
          properties: {
            // Single event fields
            id: { type: 'string', description: 'Event ID (for update/delete)' },
            title: { type: 'string', description: 'Event title' },
            startTime: { type: 'string', description: 'ISO 8601 datetime' },
            endTime: { type: 'string', description: 'ISO 8601 datetime' },
            location: { type: 'string', description: 'Event location' },
            notes: { type: 'string', description: 'Event notes' },
            isAllDay: { type: 'boolean', description: 'All-day event flag' },
            isCompleted: { type: 'boolean', description: 'Completion status' },
            category: { type: 'string', description: 'Category name' },
            categoryId: { type: 'string', description: 'Category ID' },
            colorHex: { type: 'string', description: 'Event color (hex)' },
            iconName: { type: 'string', description: 'Event icon name' },
            priority: { type: 'string', description: 'Event priority' },
            tags: { type: 'string', description: 'Event tags (comma-separated)' },
            url: { type: 'string', description: 'Event URL' },
            energyLevel: { type: 'string', description: 'Energy level required' },
            weatherRequired: { type: 'string', description: 'Weather requirement' },
            bufferTimeBefore: { type: 'integer', description: 'Buffer minutes before event' },
            bufferTimeAfter: { type: 'integer', description: 'Buffer minutes after event' },
            recurrenceRule: { type: 'string', description: 'Recurrence rule string' },
            recurrenceEndDate: { type: 'string', description: 'Recurrence end date' },
            
            // Bulk operation fields
            updateAll: { type: 'boolean', description: 'Update all items with same values' },
            ids: { type: 'array', items: { type: 'string' }, description: 'Multiple event IDs' },
            items: { 
              type: 'array', 
              items: { type: 'object' },
              description: 'Multiple events for bulk create/update with different values per item' 
            },
            
            // Filter fields for list/search and bulk update
            filter: { 
              type: 'object', 
              description: 'Filter for bulk operations',
              properties: {
                date: { type: 'string', description: 'Specific date (ISO 8601)' },
                all_tomorrow: { type: 'boolean', description: 'Select all tomorrow\'s events' },
                all_today: { type: 'boolean', description: 'Select all today\'s events' }
              }
            },
            timeShift: { type: 'number', description: 'Time shift in seconds (negative to move earlier, positive to move later)' },
            date: { type: 'string', description: 'Date to filter events (ISO 8601)' },
            startDate: { type: 'string', description: 'Start date for range' },
            endDate: { type: 'string', description: 'End date for range' },
            completed: { type: 'boolean', description: 'Filter by completion status' },
          }
        }
      },
      required: ['action', 'parameters']
    }
  },
  {
    name: 'manage_tasks',
    description: 'Manage tasks - create, update, delete, list tasks. Handles single and bulk operations.',
    parameters: {
      type: 'object',
      properties: {
        action: {
          type: 'string',
          enum: ['create', 'update', 'delete', 'list', 'search', 'complete', 'uncomplete'],
          description: 'The operation to perform'
        },
        parameters: {
          type: 'object',
          description: 'Parameters for the action. For bulk operations with different values per item, use items:[]. For bulk operations with same value for all, use updateAll:true.',
          properties: {
            // Single task fields
            id: { type: 'string', description: 'Task ID (for update/delete)' },
            title: { type: 'string', description: 'Task title' },
            description: { type: 'string', description: 'Task description/notes' },
            notes: { type: 'string', description: 'Task notes (alias for description)' },
            dueDate: { type: 'string', description: 'Due date (ISO 8601)' },
            priority: { type: 'integer', min: 1, max: 3, description: 'Priority (1=low, 2=medium, 3=high)' },
            estimatedMinutes: { type: 'integer', description: 'Estimated duration in minutes' },
            estimatedDuration: { type: 'integer', description: 'Estimated duration (alias for estimatedMinutes)' },
            scheduledTime: { type: 'string', description: 'Scheduled time (ISO 8601)' },
            goalId: { type: 'string', description: 'Associated goal ID' },
            categoryId: { type: 'string', description: 'Category ID' },
            category: { type: 'string', description: 'Category name' },
            tags: { type: 'array', items: { type: 'string' }, description: 'Task tags' },
            isCompleted: { type: 'boolean', description: 'Completion status' },
            linkedEventId: { type: 'string', description: 'Link to event ID' },
            parentTaskId: { type: 'string', description: 'Parent task ID for subtasks' },
            
            // Bulk operation fields
            updateAll: { type: 'boolean', description: 'Update all tasks with same values' },
            ids: { type: 'array', items: { type: 'string' }, description: 'Multiple task IDs' },
            items: { 
              type: 'array', 
              items: { type: 'object' },
              description: 'Multiple tasks for bulk create/update with different values per item' 
            },
            
            // Filter fields
            completed: { type: 'boolean', description: 'Filter by completion status' },
          }
        }
      },
      required: ['action', 'parameters']
    }
  },
  {
    name: 'manage_habits',
    description: 'Manage habits - create, update, delete, list, log completions. Handles single and bulk operations.',
    parameters: {
      type: 'object',
      properties: {
        action: {
          type: 'string',
          enum: ['create', 'update', 'delete', 'list', 'log', 'complete', 'pause', 'resume'],
          description: 'The operation to perform'
        },
        parameters: {
          type: 'object',
          description: 'Parameters for the action. For create/update: name, description, frequency, targetCount, reminderTime, categoryId, color, icon, isActive. For list: active, frequency, categoryId. For log/complete: id (habit ID). For delete: id or ids array. For bulk operations, pass items array.',
          properties: {
            // Single habit fields
            id: { type: 'string', description: 'Habit ID (for update/delete/log)' },
            name: { type: 'string', description: 'Habit name' },
            description: { type: 'string', description: 'Habit description/notes' },
            notes: { type: 'string', description: 'Habit notes (alias for description)' },
            frequency: { type: 'string', enum: ['daily', 'weekly', 'monthly'], description: 'Habit frequency' },
            trackingType: { type: 'string', description: 'Tracking type (binary, quantity, duration, quality)' },
            goalTarget: { type: 'number', description: 'Goal target value' },
            targetCount: { type: 'integer', description: 'Target count per period' },
            reminderTime: { type: 'string', description: 'Reminder time (HH:MM)' },
            categoryId: { type: 'string', description: 'Category ID' },
            category: { type: 'string', description: 'Category name' },
            colorHex: { type: 'string', description: 'Habit color (hex)' },
            color: { type: 'string', description: 'Habit color (hex) - alias' },
            iconName: { type: 'string', description: 'Habit icon name' },
            icon: { type: 'string', description: 'Habit icon - alias' },
            isActive: { type: 'boolean', description: 'Active status' },
            isPaused: { type: 'boolean', description: 'Paused status' },
            currentStreak: { type: 'integer', description: 'Current streak count' },
            bestStreak: { type: 'integer', description: 'Best streak count' },
            
            // Bulk operation fields
            updateAll: { type: 'boolean', description: 'Update all habits with same values' },
            ids: { type: 'array', items: { type: 'string' }, description: 'Multiple habit IDs' },
            items: { 
              type: 'array', 
              items: { type: 'object' },
              description: 'Multiple habits for bulk create/update with different values per item' 
            },
            
            // Filter fields
            active: { type: 'boolean', description: 'Filter by active status' },
          }
        }
      },
      required: ['action', 'parameters']
    }
  },
  {
    name: 'manage_goals',
    description: 'Manage goals and milestones - create, update, delete, list goals and their milestones. Handles single and bulk operations.',
    parameters: {
      type: 'object',
      properties: {
        action: {
          type: 'string',
          enum: ['create', 'update', 'delete', 'list', 'create_milestone', 'update_milestone', 'delete_milestone', 'complete'],
          description: 'The operation to perform'
        },
        parameters: {
          type: 'object',
          description: 'Parameters for the action. For goals: title, description, targetDate, priority, categoryId, category, unit, targetValue. For milestones: goalId (for create), id/milestoneId (for update/delete), title, description, dueDate. For delete: id or ids array. For bulk operations, pass items array.',
          properties: {
            // Goal fields
            id: { type: 'string', description: 'Goal ID (for update/delete)' },
            title: { type: 'string', description: 'Goal title' },
            description: { type: 'string', description: 'Goal description' },
            targetDate: { type: 'string', description: 'Target date (ISO 8601)' },
            priority: { type: 'integer', description: 'Priority level (1=low, 2=medium, 3=high)' },
            categoryId: { type: 'string', description: 'Category ID' },
            category: { type: 'string', description: 'Category name (assigns goal to category for color/icon)' },
            unit: { type: 'string', description: 'Measurement unit' },
            targetValue: { type: 'number', description: 'Target value' },
            currentValue: { type: 'number', description: 'Current progress value' },
            isCompleted: { type: 'boolean', description: 'Completion status' },
            
            // Milestone fields
            goalId: { type: 'string', description: 'Parent goal ID (for milestone operations)' },
            milestoneId: { type: 'string', description: 'Milestone ID' },
            milestones: { 
              type: 'array', 
              items: { type: 'object' },
              description: 'Milestones array for goal creation' 
            },
            dueDate: { type: 'string', description: 'Milestone due date' },
            
            // Bulk operation fields
            updateAll: { type: 'boolean', description: 'Update all goals with same values' },
            ids: { type: 'array', items: { type: 'string' }, description: 'Multiple goal IDs' },
            items: { 
              type: 'array', 
              items: { type: 'object' },
              description: 'Multiple goals for bulk create/update with different values per item' 
            },
            
            // Filter fields
            completed: { type: 'boolean', description: 'Filter by completion status' },
          }
        }
      },
      required: ['action', 'parameters']
    }
  },
  {
    name: 'manage_categories',
    description: 'Manage categories - create, update, delete, list categories for organizing items.',
    parameters: {
      type: 'object',
      properties: {
        action: {
          type: 'string',
          enum: ['create', 'update', 'delete', 'list', 'merge'],
          description: 'The operation to perform'
        },
        parameters: {
          type: 'object',
          description: 'Parameters for the action. For create/update: name, color, icon. For delete: id. For list: no parameters needed. For merge: sourceIds, targetId.',
          properties: {
            // Single category fields
            id: { type: 'string', description: 'Category ID (for update/delete)' },
            name: { type: 'string', description: 'Category name' },
            color: { type: 'string', description: 'Category color (hex)' },
            icon: { type: 'string', description: 'Category icon' },
            
            // Merge operation
            sourceIds: { type: 'array', items: { type: 'string' }, description: 'Source category IDs to merge from' },
            targetId: { type: 'string', description: 'Target category ID to merge into' },
            
            // Bulk operation fields
            ids: { type: 'array', items: { type: 'string' }, description: 'Multiple category IDs' },
            items: { 
              type: 'array', 
              items: { type: 'object' },
              description: 'Multiple categories for bulk create/update' 
            },
          }
        }
      },
      required: ['action', 'parameters']
    }
  }
];