# Contextual Bulk Updates Documentation

## Overview
The bulk update functionality now supports contextual content generation, allowing unique values to be generated for each item instead of applying the same value to all.

## How It Works
When updating multiple items, you can use special markers in the update values:
- `{auto}` - Generates automatic content based on the entity
- `{context}` - Generates content based on the entity's context (category, priority, etc.)
- `{unique}` - Generates unique identifiers for each item

## Examples

### Tasks
```
// Static update (same for all):
"Update notes for all tasks to 'Review this week'"

// Contextual update (unique for each):
"Update notes for all tasks to '{auto}'"
// Results:
// Task 1: "Notes for Submit Report"
// Task 2: "Notes for Review Code"
// Task 3: "Notes for Team Meeting"

"Update notes to '{context}'"
// Results:
// Task 1: "High priority task in Work"
// Task 2: "Medium priority task in Personal"
// Task 3: "Low priority task in Health"

"Update notes to 'Task {unique} needs attention'"
// Results:
// Task 1: "Task 1 of 3 needs attention"
// Task 2: "Task 2 of 3 needs attention"
// Task 3: "Task 3 of 3 needs attention"
```

### Events
```
"Update location for all meetings to '{auto}'"
// Results:
// Event 1: "Location for Team Standup"
// Event 2: "Location for Client Meeting"
// Event 3: "Location for Design Review"

"Update URL to '{context}'"
// Results:
// Event 1: "https://meet.example.com/team-standup"
// Event 2: "https://meet.example.com/client-meeting"
// Event 3: "https://meet.example.com/design-review"
```

### Habits
```
"Update notes for all habits to '{auto}'"
// Results:
// Habit 1: "Notes for Morning Exercise"
// Habit 2: "Notes for Read 30 Minutes"
// Habit 3: "Notes for Meditate"
```

### Goals
```
"Update description for all goals to '{context}'"
// Results:
// Goal 1: "High priority milestone goal"
// Goal 2: "Medium priority numeric goal"
// Goal 3: "Low priority habit goal"
```

## Supported Fields

### Events
- title, notes, location, url, tags

### Tasks  
- title, notes, tags

### Habits
- name, notes, goalUnit

### Goals
- title, description, unit

## Implementation Status
✅ Events - Full contextual support for all fields
✅ Tasks - Full contextual support with proper notes handling
✅ Habits - Full contextual support for all fields
✅ Goals - Full contextual support for all fields
✅ Categories - Static updates only (contextual not needed)