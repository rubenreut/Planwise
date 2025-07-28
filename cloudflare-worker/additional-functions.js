// Additional CRUD functions for complete AI access to all app entities

// Category Management Functions (missing from main worker)
export const CATEGORY_FUNCTIONS = [
  {
    name: 'list_categories',
    description: 'List all available categories (both built-in and custom)',
    parameters: {
      type: 'object',
      properties: {
        includeBuiltIn: { 
          type: 'boolean', 
          description: 'Include built-in categories (default: true)' 
        },
        includeStats: { 
          type: 'boolean', 
          description: 'Include usage statistics for each category' 
        },
      },
    },
  },
  {
    name: 'update_category',
    description: 'Update an existing category (name, color, or icon)',
    parameters: {
      type: 'object',
      properties: {
        categoryName: { 
          type: 'string', 
          description: 'Current name of the category to update' 
        },
        newName: { 
          type: 'string', 
          description: 'New name for the category' 
        },
        color: { 
          type: 'string', 
          description: 'New color (hex code or color name)' 
        },
        icon: { 
          type: 'string', 
          description: 'New SF Symbol icon name' 
        },
      },
      required: ['categoryName'],
    },
  },
  {
    name: 'delete_category',
    description: 'Delete a custom category and optionally reassign its events',
    parameters: {
      type: 'object',
      properties: {
        categoryName: { 
          type: 'string', 
          description: 'Name of the category to delete' 
        },
        reassignTo: { 
          type: 'string', 
          description: 'Category to reassign events to (if not provided, events become uncategorized)' 
        },
      },
      required: ['categoryName'],
    },
  },
  {
    name: 'merge_categories',
    description: 'Merge multiple categories into one',
    parameters: {
      type: 'object',
      properties: {
        sourceCategories: { 
          type: 'array',
          items: { type: 'string' },
          description: 'Categories to merge from' 
        },
        targetCategory: { 
          type: 'string', 
          description: 'Category to merge into' 
        },
      },
      required: ['sourceCategories', 'targetCategory'],
    },
  },
];

// User Preferences and Settings Functions
export const SETTINGS_FUNCTIONS = [
  {
    name: 'get_user_preferences',
    description: 'Get all user preferences and settings',
    parameters: {
      type: 'object',
      properties: {
        category: { 
          type: 'string', 
          enum: ['all', 'calendar', 'tasks', 'habits', 'notifications', 'ai', 'appearance'],
          description: 'Specific category of preferences to retrieve' 
        },
      },
    },
  },
  {
    name: 'update_user_preferences',
    description: 'Update user preferences and settings',
    parameters: {
      type: 'object',
      properties: {
        preferences: {
          type: 'object',
          properties: {
            // Calendar preferences
            defaultEventDuration: { type: 'number', description: 'Default event duration in minutes' },
            workingHoursStart: { type: 'string', description: 'Start of working hours (HH:MM)' },
            workingHoursEnd: { type: 'string', description: 'End of working hours (HH:MM)' },
            weekStartsOn: { type: 'string', enum: ['sunday', 'monday'] },
            defaultEventCategory: { type: 'string' },
            
            // Task preferences
            defaultTaskPriority: { type: 'string', enum: ['low', 'medium', 'high'] },
            tasksDueTimeDefault: { type: 'string', description: 'Default due time for tasks (HH:MM)' },
            
            // Habit preferences
            habitReminderTime: { type: 'string', description: 'Default reminder time for habits (HH:MM)' },
            habitStreakNotifications: { type: 'boolean' },
            
            // Notification preferences
            enableNotifications: { type: 'boolean' },
            notificationSound: { type: 'string' },
            reminderMinutesBefore: { type: 'array', items: { type: 'number' } },
            
            // AI preferences
            aiContextInfo: { type: 'string', description: 'Personal context for AI assistant' },
            aiAutoSuggestions: { type: 'boolean' },
            
            // Appearance
            theme: { type: 'string', enum: ['system', 'light', 'dark'] },
            accentColor: { type: 'string' },
          },
        },
      },
      required: ['preferences'],
    },
  },
];

// Analytics and Insights Functions
export const ANALYTICS_FUNCTIONS = [
  {
    name: 'get_productivity_insights',
    description: 'Get detailed productivity insights and analytics',
    parameters: {
      type: 'object',
      properties: {
        period: { 
          type: 'string', 
          enum: ['today', 'week', 'month', 'quarter', 'year', 'custom'],
          description: 'Time period for analytics' 
        },
        startDate: { type: 'string', description: 'ISO 8601 date for custom period' },
        endDate: { type: 'string', description: 'ISO 8601 date for custom period' },
        includeCategories: { type: 'boolean', description: 'Include category breakdown' },
        includePatterns: { type: 'boolean', description: 'Include behavior patterns' },
        includeSuggestions: { type: 'boolean', description: 'Include AI suggestions' },
      },
      required: ['period'],
    },
  },
  {
    name: 'get_time_tracking_report',
    description: 'Get detailed time tracking report',
    parameters: {
      type: 'object',
      properties: {
        groupBy: { 
          type: 'string', 
          enum: ['category', 'day', 'week', 'project'],
          description: 'How to group the time data' 
        },
        period: { type: 'string', enum: ['week', 'month', 'quarter', 'year'] },
        includeCompleted: { type: 'boolean' },
        includeIncomplete: { type: 'boolean' },
      },
      required: ['period'],
    },
  },
];

// Bulk Search and Filter Functions
export const SEARCH_FUNCTIONS = [
  {
    name: 'search_all',
    description: 'Search across all entities (events, tasks, habits, goals)',
    parameters: {
      type: 'object',
      properties: {
        query: { type: 'string', description: 'Search query' },
        entityTypes: { 
          type: 'array', 
          items: { type: 'string', enum: ['events', 'tasks', 'habits', 'goals'] },
          description: 'Types to search (default: all)' 
        },
        dateRange: {
          type: 'object',
          properties: {
            startDate: { type: 'string', description: 'ISO 8601 date' },
            endDate: { type: 'string', description: 'ISO 8601 date' },
          },
        },
        limit: { type: 'number', description: 'Maximum results to return' },
      },
      required: ['query'],
    },
  },
  {
    name: 'get_all_data',
    description: 'Get all user data for backup or analysis',
    parameters: {
      type: 'object',
      properties: {
        includeEvents: { type: 'boolean', default: true },
        includeTasks: { type: 'boolean', default: true },
        includeHabits: { type: 'boolean', default: true },
        includeGoals: { type: 'boolean', default: true },
        includeCategories: { type: 'boolean', default: true },
        includePreferences: { type: 'boolean', default: true },
        format: { type: 'string', enum: ['json', 'summary'], default: 'summary' },
      },
    },
  },
  {
    name: 'get_context_for_scheduling',
    description: 'Get user context (tasks, goals, habits, recent events) to create intelligent schedules',
    parameters: {
      type: 'object',
      properties: {
        daysAhead: { type: 'number', description: 'How many days ahead to plan for', default: 7 },
      },
    },
  },
];

// Advanced Bulk Operations
export const ADVANCED_BULK_FUNCTIONS = [
  {
    name: 'bulk_time_shift',
    description: 'Shift times for multiple entities (events, tasks) by a specified amount',
    parameters: {
      type: 'object',
      properties: {
        entityType: { type: 'string', enum: ['events', 'tasks', 'both'] },
        filter: {
          type: 'object',
          properties: {
            date: { type: 'string', description: 'ISO 8601 date' },
            dateRange: {
              type: 'object',
              properties: {
                startDate: { type: 'string' },
                endDate: { type: 'string' },
              },
            },
            category: { type: 'string' },
            ids: { type: 'array', items: { type: 'string' } },
          },
        },
        shiftAmount: { type: 'number', description: 'Minutes to shift (positive = later, negative = earlier)' },
        shiftDays: { type: 'number', description: 'Days to shift (positive = future, negative = past)' },
      },
      required: ['entityType', 'filter'],
    },
  },
  {
    name: 'bulk_duplicate',
    description: 'Duplicate events or tasks to another date or with modifications',
    parameters: {
      type: 'object',
      properties: {
        entityType: { type: 'string', enum: ['events', 'tasks'] },
        sourceIds: { type: 'array', items: { type: 'string' } },
        targetDate: { type: 'string', description: 'ISO 8601 date to duplicate to' },
        modifications: {
          type: 'object',
          properties: {
            titlePrefix: { type: 'string' },
            titleSuffix: { type: 'string' },
            category: { type: 'string' },
            adjustTimes: { type: 'boolean', description: 'Adjust times to fit target date' },
          },
        },
        count: { type: 'number', description: 'Number of copies to create' },
      },
      required: ['entityType', 'sourceIds'],
    },
  },
  {
    name: 'template_operations',
    description: 'Save current schedule as template or apply a template',
    parameters: {
      type: 'object',
      properties: {
        operation: { type: 'string', enum: ['save', 'apply', 'list', 'delete'] },
        templateName: { type: 'string' },
        sourceDate: { type: 'string', description: 'Date to save as template (for save operation)' },
        targetDate: { type: 'string', description: 'Date to apply template to (for apply operation)' },
        includeEvents: { type: 'boolean', default: true },
        includeTasks: { type: 'boolean', default: true },
        adjustTimes: { type: 'boolean', default: true },
      },
      required: ['operation'],
    },
  },
];

// System and Maintenance Functions
export const SYSTEM_FUNCTIONS = [
  {
    name: 'cleanup_data',
    description: 'Clean up old or duplicate data',
    parameters: {
      type: 'object',
      properties: {
        removeDuplicates: { type: 'boolean' },
        removeOldCompleted: {
          type: 'object',
          properties: {
            olderThanDays: { type: 'number' },
            entityTypes: { type: 'array', items: { type: 'string', enum: ['events', 'tasks'] } },
          },
        },
        removeEmptyCategories: { type: 'boolean' },
        compactDatabase: { type: 'boolean' },
      },
    },
  },
  {
    name: 'reset_data',
    description: 'Reset specific types of data (use with extreme caution)',
    parameters: {
      type: 'object',
      properties: {
        resetType: { 
          type: 'string', 
          enum: ['events', 'tasks', 'habits', 'goals', 'categories', 'preferences', 'all'] 
        },
        confirm: { type: 'boolean', description: 'Must be true to confirm reset' },
        createDefaults: { type: 'boolean', description: 'Create default categories after reset' },
      },
      required: ['resetType', 'confirm'],
    },
  },
];

// Export all additional functions
export const ALL_ADDITIONAL_FUNCTIONS = [
  ...CATEGORY_FUNCTIONS,
  ...SETTINGS_FUNCTIONS,
  ...ANALYTICS_FUNCTIONS,
  ...SEARCH_FUNCTIONS,
  ...ADVANCED_BULK_FUNCTIONS,
  ...SYSTEM_FUNCTIONS,
];