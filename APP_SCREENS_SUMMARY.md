# Momentum App - Screen Inventory

## 📱 Main Navigation Screens

### 1. Day View
**Purpose**: Daily schedule timeline
- **Time blocks**: Hourly slots (5 AM - 11 PM)
- **Event cards**: Shows scheduled events with colors
- **Current time indicator**: Red line showing now
- **Floating (+) button**: Add new event
- **Header**: Date selector, today button
- **Gestures**: Swipe between days, tap events

### 2. Week View (iPad/Mac)
**Purpose**: 7-day calendar overview
- **Column layout**: Mon-Sun columns
- **Event blocks**: Color-coded by category
- **Navigation**: Previous/Next week buttons
- **Quick add**: Tap empty slot to create event
- **Sidebar**: Categories filter

### 3. Tasks
**Purpose**: Task management hub
- **Filter pills**: All/Today/Upcoming/Overdue/Unscheduled
- **Search bar**: Find tasks
- **Task cards**: Title, due date, priority flag, completion checkbox
- **Context menu**: Delete/Complete on long press
- **Floating (+) button**: Create task
- **Empty states**: Different messages per filter

### 4. Habits
**Purpose**: Habit tracking
- **Grid/List toggle**: View switcher
- **Habit cards**: Icon, name, streak count, completion button
- **Quick complete**: Tap to mark done
- **Stats preview**: Current/best streak
- **Filter**: Active/Paused/All
- **Floating (+) button**: Create habit

### 5. Goals
**Purpose**: Long-term goal tracking
- **Goal cards**: Progress bar, milestone count, due date
- **Milestone indicators**: Completed/pending dots
- **Priority sorting**: High/Medium/Low sections
- **Progress percentage**: Visual indicator
- **Floating (+) button**: Create goal

### 6. AI Assistant (Planwise)
**Purpose**: AI chat interface
- **Message bubbles**: User (right) / AI (left)
- **Event preview cards**: Accept/Reject buttons
- **Input bar**: Text field, attachment button, mic
- **Typing indicator**: Three dots animation
- **Message limit badge**: For free users
- **Settings button**: Top right

---

## 🔧 Settings & Management

### 7. Settings
**Purpose**: App configuration (1,392 lines!)
- **Sections**: Account, General, Notifications, Data, About
- **Subscription status**: Premium badge or upgrade button
- **Category management**: Add/edit/delete categories
- **Data export**: Export to JSON
- **Danger zone**: Delete account
- **Toggle switches**: Various preferences

### 8. Category Management
**Purpose**: Event/task categories
- **Category list**: Name, color, icon
- **Add button**: Create new category
- **Edit mode**: Reorder/delete categories
- **Color picker**: 12 color options
- **Icon picker**: SF Symbols selection

---

## ➕ Creation Screens (Modal Sheets)

### 9. Add Event
**Purpose**: Create calendar event
- **Title field**: Required
- **Date/time pickers**: Start and end
- **All-day toggle**: Disables time selection
- **Category selector**: Horizontal pills
- **Location field**: Optional
- **Notes field**: Multi-line optional
- **Save/Cancel buttons**: Top bar

### 10. Add Task
**Purpose**: Create new task
- **Title field**: Required
- **Priority selector**: High/Medium/Low flags
- **Due date toggle**: Optional date/time
- **Category picker**: Dropdown menu
- **Tags field**: Comma-separated
- **Estimated duration**: 15min to 4hr options
- **Subtasks section**: Add multiple
- **Save/Cancel buttons**: Top bar

### 11. Add Habit
**Purpose**: Create trackable habit
- **Name field**: Required
- **Icon picker**: SF Symbols grid
- **Color selector**: Color dots
- **Tracking type**: Binary/Quantity/Duration/Quality
- **Goal setting**: Target value and unit
- **Frequency**: Daily/Weekly/Custom
- **Reminder toggle**: Time picker
- **Save/Cancel buttons**: Top bar

### 12. Add Goal
**Purpose**: Create long-term goal
- **Title field**: Required  
- **Description**: Multi-line optional
- **Target date**: Date picker
- **Priority**: High/Medium/Low
- **Milestones**: Add multiple checkpoints
- **Category**: Optional selection
- **Save/Cancel buttons**: Top bar

---

## 📋 Detail/Edit Screens

### 13. Event Detail
**Purpose**: View/edit event
- **Title display**: Large header
- **Time info**: Duration, date
- **Category badge**: Colored pill
- **Location**: If provided
- **Notes**: Markdown supported
- **Edit button**: Top right
- **Delete button**: Bottom red

### 14. Task Detail
**Purpose**: View/edit task
- **Title/notes**: Editable fields
- **Properties card**: Priority, category, duration
- **Scheduling card**: Due date, scheduled time toggles
- **Tags section**: Editable tags
- **Linked event**: Optional connection
- **Subtasks button**: Manage subtasks
- **Complete/Delete buttons**: Action buttons

### 15. Habit Detail
**Purpose**: Habit analytics
- **Header stats**: Current/best streak, total
- **Charts**: Completion history, progress, streak timeline
- **Period selector**: Week/Month/Year/All
- **Insights**: AI-generated tips
- **Recent entries**: History list
- **Edit/Delete buttons**: Quick actions

### 16. Goal Detail
**Purpose**: Goal progress
- **Progress ring**: Visual percentage
- **Milestone list**: Check off progress
- **Notes section**: Updates/thoughts
- **Edit button**: Modify goal
- **Complete/Delete**: Action buttons

---

## 💰 Premium/Onboarding

### 17. Paywall
**Purpose**: Subscription upgrade
- **Feature list**: Premium benefits
- **Price display**: Monthly/yearly toggle
- **Subscribe button**: Primary CTA
- **Restore purchases**: Bottom link
- **Close (X)**: Top right

### 18. Onboarding
**Purpose**: First launch flow
- **Welcome screen**: App intro
- **Feature cards**: Swipeable benefits
- **Permission requests**: Notifications, calendar
- **Get started button**: Enter app

---

## 🔔 State Screens

### 19. Empty States
**Purpose**: No content guidance
- **Icon**: Relevant SF Symbol
- **Title**: Context message
- **Subtitle**: Helper text
- **Action button**: Create first item

### 20. Error States
**Purpose**: Error handling
- **Error icon**: Warning symbol
- **Message**: What went wrong
- **Retry button**: Try again
- **Offline banner**: No connection indicator

### 21. Loading States
**Purpose**: Async feedback
- **Skeleton screens**: Content placeholders
- **Progress indicators**: Spinners
- **Loading messages**: Context text

---

## 🎯 Quick Stats

- **Total Unique Screens**: ~21 main screens
- **Modal Sheets**: 8 creation/detail flows
- **Empty States**: 10+ contextual variations
- **Platform Variants**: 3 (iPhone/iPad/Mac)
- **Navigation Tabs**: 5 main + settings

**Most Complex**: Settings (1,392 lines)
**Most Interactive**: Day View (gestures + timeline)
**Most Data Dense**: Week View (7-day grid)
**Most Animated**: AI Chat (typing, messages)