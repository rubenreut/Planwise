# Momentum UI Components Catalog

This document catalogs ALL UI components in the Momentum iOS app, including usage counts and descriptions.

## Table of Contents
1. [Core App Views](#core-app-views)
2. [Button Components](#button-components)
3. [Card Components](#card-components)
4. [List & Collection Components](#list--collection-components)
5. [Input Components](#input-components)
6. [Navigation Components](#navigation-components)
7. [State Components](#state-components)
8. [Overlay & Modal Components](#overlay--modal-components)
9. [Task Components](#task-components)
10. [Event Components](#event-components)
11. [Habit Components](#habit-components)
12. [Goal Components](#goal-components)
13. [AI/Chat Components](#aichat-components)
14. [Premium/Subscription Components](#premiumsubscription-components)
15. [Widget Components](#widget-components)
16. [Utility Components](#utility-components)

---

## Core App Views

### ContentView
- **Usage**: 1 (Main entry point)
- **Location**: `/Views/ContentView.swift`
- **Description**: Root view of the app that sets up the navigation structure

### UnifiedNavigationView
- **Usage**: 1 (Called from ContentView)
- **Location**: `/UnifiedNavigation/UnifiedNavigationView.swift`
- **Description**: Adaptive navigation container for iPhone, iPad, and Mac

### DayView
- **Usage**: Multiple (Main tab, navigation)
- **Location**: `/Views/DayView.swift`
- **Description**: Shows daily schedule with time blocks and events

### WeekView
- **Usage**: 2 (Navigation destination)
- **Location**: `/Views/WeekView.swift`
- **Description**: Week calendar view for desktop/iPad

### WeekViewIPad
- **Usage**: 1 (iPad specific)
- **Location**: `/Views/WeekViewIPad.swift`
- **Description**: Optimized week view for iPad with column layout

### UnifiedWeekView
- **Usage**: 1
- **Location**: `/Views/UnifiedWeekView.swift`
- **Description**: Cross-platform week view implementation

---

## Button Components

### FloatingActionButton
- **Usage**: 5+ (Add buttons across views)
- **Location**: `/Views/EnhancedDayComponents.swift`
- **Description**: Material Design-style floating action button with shadow and animations

### EnhancedFilterPill
- **Usage**: 4 (Task filters, habit filters)
- **Location**: `/Views/EnhancedDayComponents.swift`
- **Description**: Toggle-able filter pill with icon, count badge, and selection state

### HabitCompletionButton
- **Usage**: 2 (Habit views)
- **Location**: `/Views/HabitCompletionButton.swift`
- **Description**: Specialized button for marking habits as complete

### ActionButton
- **Usage**: 3 (Various detail views)
- **Location**: `/Views/HabitDetailView.swift`
- **Description**: Generic action button with icon and label

### PremiumFilterChip
- **Usage**: 1 (Premium task view)
- **Location**: `/Views/TaskListViewPremium.swift`
- **Description**: Premium-styled filter chip with gradient effects

---

## Card Components

### EnhancedTimeBlock
- **Usage**: 3+ (Day view, timeline)
- **Location**: `/Views/EnhancedDayComponents.swift`
- **Description**: Time slot card showing hour with enhanced visual design

### EnhancedEventCard
- **Usage**: 2 (Day view)
- **Location**: `/Views/EnhancedDayComponents.swift`
- **Description**: Event display card with category colors, time, and interactions

### EnhancedTaskCard
- **Usage**: 3 (Task lists)
- **Location**: `/Views/EnhancedDayComponents.swift`
- **Description**: Task card with completion toggle, priority, and metadata

### TimeBlockView
- **Usage**: 2 (Timeline views)
- **Location**: `/Views/TimeBlockView.swift`
- **Description**: Hour block in day timeline with event slots

### PremiumTaskCard
- **Usage**: 1 (Premium view)
- **Location**: `/Views/TaskListViewPremium.swift`
- **Description**: Enhanced task card with animations and premium styling

### StatItem
- **Usage**: 4+ (Detail views)
- **Location**: `/Views/HabitDetailView.swift`
- **Description**: Statistical display card for metrics

### HeaderCard
- **Usage**: 2 (Detail views)
- **Location**: `/Views/HabitDetailView.swift`
- **Description**: Header section with icon and stats

---

## List & Collection Components

### TaskListView
- **Usage**: 1 (Main navigation)
- **Location**: `/Views/TaskListView.swift`
- **Description**: Main task list with filters and search

### TaskListViewPremium
- **Usage**: 1 (Premium navigation)
- **Location**: `/Views/TaskListViewPremium.swift`
- **Description**: Premium-styled task list view

### HabitsView
- **Usage**: 1 (Main navigation)
- **Location**: `/Views/HabitsView.swift`
- **Description**: Grid/list view of all habits

### GoalsView
- **Usage**: 1 (Main navigation)
- **Location**: `/Views/GoalsView.swift`
- **Description**: Goals list with progress tracking

### PaginatedList
- **Usage**: 2 (Large lists)
- **Location**: `/Views/PaginatedList.swift`
- **Description**: Generic paginated list component for performance

---

## Input Components

### ChatInputView
- **Usage**: 1 (AI chat)
- **Location**: `/Views/ChatInputView.swift`
- **Description**: Message input with attachments and voice

### MacChatInput
- **Usage**: 1 (Mac-specific)
- **Location**: `/Views/AIChatView.swift`
- **Description**: macOS-optimized chat input

### DocumentPicker
- **Usage**: 2 (File attachments)
- **Location**: `/Views/DocumentPicker.swift`
- **Description**: Document selection wrapper

### DateTimePicker (Custom in various views)
- **Usage**: 5+ (Event/task creation)
- **Description**: Date and time selection components

---

## Navigation Components

### NavigationSidebar
- **Usage**: 1 (iPad)
- **Location**: `/UnifiedNavigation/NavigationSidebar.swift`
- **Description**: iPad sidebar navigation

### MacNavigationSidebar
- **Usage**: 1 (Mac)
- **Location**: `/UnifiedNavigation/MacNavigationSidebar.swift`
- **Description**: macOS sidebar with sections

### CurrentTimeIndicator
- **Usage**: 2 (Timeline views)
- **Location**: `/Views/CurrentTimeIndicator.swift`
- **Description**: Moving indicator showing current time on timeline

---

## State Components

### EmptyStateView
- **Usage**: 10+ (Throughout app)
- **Location**: `/Views/EmptyStateView.swift`
- **Description**: Configurable empty state with icon, message, and action

### LoadingView
- **Usage**: 8+ (Async operations)
- **Location**: `/Views/LoadingView.swift`
- **Description**: Loading states with skeleton screens

### ErrorView
- **Usage**: 6+ (Error handling)
- **Location**: `/Views/ErrorView.swift`
- **Description**: Error display with retry action

### NetworkErrorView
- **Usage**: 3 (Network failures)
- **Location**: `/Views/NetworkErrorView.swift`
- **Description**: Specialized network error handling

### ErrorBanner
- **Usage**: 4 (Inline errors)
- **Location**: `/Views/ErrorBanner.swift`
- **Description**: Non-blocking error notification banner

---

## Overlay & Modal Components

### AddEventView
- **Usage**: 2 (Event creation)
- **Location**: `/Views/AddEventView.swift`
- **Description**: Modal for creating new events

### AddTaskView
- **Usage**: 3 (Task creation)
- **Location**: `/Views/AddTaskView.swift`
- **Description**: Modal for creating new tasks

### AddHabitView
- **Usage**: 2 (Habit creation)
- **Location**: `/Views/AddHabitView.swift`
- **Description**: Modal for creating new habits

### AddGoalView
- **Usage**: 2 (Goal creation)
- **Location**: `/Views/AddGoalView.swift`
- **Description**: Modal for creating new goals

---

## Task Components

### TaskDetailView
- **Usage**: 3 (Task editing)
- **Location**: `/Views/TaskDetailView.swift`
- **Description**: Detailed task view with all properties

### TaskRow
- **Usage**: 2 (Compact lists)
- **Location**: `/Views/TaskRow.swift`
- **Description**: Compact task row for lists

### SubtasksView
- **Usage**: 1 (Task detail)
- **Location**: `/Views/TaskDetailView.swift`
- **Description**: Subtask management interface

---

## Event Components

### EventDetailView
- **Usage**: 2 (Event details)
- **Location**: `/Views/EventDetailView.swift`
- **Description**: Full event details and editing

### EventPreviewView
- **Usage**: 3 (AI suggestions)
- **Location**: `/Views/EventPreviewView.swift`
- **Description**: Event preview card for AI suggestions

### MultipleEventsPreviewView
- **Usage**: 1 (AI bulk actions)
- **Location**: `/Views/EventPreviewView.swift`
- **Description**: Multiple event preview for bulk actions

### BulkActionPreviewView
- **Usage**: 1 (AI bulk actions)
- **Location**: `/Views/EventPreviewView.swift`
- **Description**: Bulk action confirmation view

### EventPickerView
- **Usage**: 1 (Task linking)
- **Location**: `/Views/TaskDetailView.swift`
- **Description**: Event selection picker

---

## Habit Components

### HabitDetailView
- **Usage**: 2 (Habit details)
- **Location**: `/Views/HabitDetailView.swift`
- **Description**: Detailed habit view with charts

### HabitStatsView
- **Usage**: 1 (Statistics)
- **Location**: `/Views/HabitStatsView.swift`
- **Description**: Habit statistics and insights

### CompletionChart
- **Usage**: 1 (Habit detail)
- **Location**: `/Views/HabitDetailView.swift`
- **Description**: Habit completion history chart

### ProgressChart
- **Usage**: 1 (Habit detail)
- **Location**: `/Views/HabitDetailView.swift`
- **Description**: Progress over time chart

### StreakChart
- **Usage**: 1 (Habit detail)
- **Location**: `/Views/HabitDetailView.swift`
- **Description**: Visual streak timeline

---

## Goal Components

### GoalDetailView
- **Usage**: 2 (Goal details)
- **Location**: `/Views/GoalDetailView.swift`
- **Description**: Detailed goal view with milestones

### MilestoneRow
- **Usage**: 1 (Goal detail)
- **Location**: Internal to GoalDetailView
- **Description**: Individual milestone display

---

## AI/Chat Components

### AIChatView
- **Usage**: 1 (Main AI interface)
- **Location**: `/Views/AIChatView.swift`
- **Description**: Main AI assistant chat interface

### MessageBubbleView
- **Usage**: 2 (Chat messages)
- **Location**: `/Views/MessageBubbleView.swift`
- **Description**: Chat message bubble with markdown support

### MacMessageBubble
- **Usage**: 1 (Mac-specific)
- **Location**: `/Views/AIChatView.swift`
- **Description**: macOS-optimized message bubble

### TypingIndicatorView
- **Usage**: 1 (Chat)
- **Location**: `/Views/AIChatView.swift`
- **Description**: Animated typing indicator

### MacTypingIndicator
- **Usage**: 1 (Mac-specific)
- **Location**: `/Views/AIChatView.swift`
- **Description**: macOS typing indicator

### RateLimitWarningView
- **Usage**: 1 (AI chat)
- **Location**: `/Views/AIChatView.swift`
- **Description**: Rate limit warning banner

### MessageLimitIndicator
- **Usage**: 1 (AI chat)
- **Location**: `/Views/AIChatView.swift`
- **Description**: Message limit display

---

## Premium/Subscription Components

### PaywallView
- **Usage**: 2 (Subscription)
- **Location**: `/Views/PaywallView.swift`
- **Description**: Basic paywall interface

### PaywallViewPremium
- **Usage**: 3 (Premium upgrade)
- **Location**: `/Views/PaywallViewPremium.swift`
- **Description**: Enhanced paywall with animations

### PaywallMockView
- **Usage**: 1 (Testing)
- **Location**: `/Views/PaywallMockView.swift`
- **Description**: Mock paywall for testing

### OnboardingView
- **Usage**: 1 (First launch)
- **Location**: `/Views/OnboardingView.swift`
- **Description**: Basic onboarding flow

### OnboardingViewPremium
- **Usage**: 1 (Premium onboarding)
- **Location**: `/Views/OnboardingViewPremium.swift`
- **Description**: Enhanced onboarding with premium features

### SubscriptionStatusBadge
- **Usage**: 3 (Navigation bars)
- **Location**: `/Views/SubscriptionStatusBadge.swift`
- **Description**: Shows subscription status

### PremiumHeaderView
- **Usage**: 2 (Premium screens)
- **Location**: `/Views/PremiumHeaderView.swift`
- **Description**: Premium branding header

---

## Widget Components

### MomentumWidget
- **Usage**: 1 (Widget extension)
- **Location**: `/MomentumWidget/MomentumWidget.swift`
- **Description**: Main widget implementation

### SmallWidgetView
- **Usage**: 1 (Small widget)
- **Location**: `/MomentumWidget/Views/SmallWidgetView.swift`
- **Description**: Small size widget layout

### MediumWidgetView
- **Usage**: 1 (Medium widget)
- **Location**: `/MomentumWidget/Views/MediumWidgetView.swift`
- **Description**: Medium size widget layout

### LargeWidgetView
- **Usage**: 1 (Large widget)
- **Location**: `/MomentumWidget/Views/LargeWidgetView.swift`
- **Description**: Large size widget layout

### AccessoryWidgetView
- **Usage**: 1 (Lock screen)
- **Location**: `/MomentumWidget/Views/AccessoryWidgetView.swift`
- **Description**: Lock screen widget

---

## Utility Components

### SettingsView
- **Usage**: 2 (Settings screen)
- **Location**: `/Views/SettingsView.swift`
- **Description**: App settings and preferences

### CategoryManagementView
- **Usage**: 1 (Settings)
- **Location**: `/Views/CategoryManagementView.swift`
- **Description**: Category creation and management

### PersistentScrollView
- **Usage**: 2 (Scroll position)
- **Location**: `/Views/PersistentScrollView.swift`
- **Description**: Scroll view that remembers position

### DayTimelineView
- **Usage**: 1 (Day view)
- **Location**: `/Views/DayTimelineView.swift`
- **Description**: Timeline component for day view

### EnhancedSectionHeader
- **Usage**: 4 (List sections)
- **Location**: `/Views/EnhancedDayComponents.swift`
- **Description**: Section header with icon and count

### VisualSeparator
- **Usage**: 6 (Visual breaks)
- **Location**: `/Views/EnhancedDayComponents.swift`
- **Description**: Visual separator line between sections

### QuickActionsRow
- **Usage**: 2 (Detail views)
- **Location**: `/Views/HabitDetailView.swift`
- **Description**: Quick action buttons row

### MacAttachmentMenu
- **Usage**: 1 (Mac chat)
- **Location**: `/Views/AIChatView.swift`
- **Description**: macOS attachment menu

### MacAttachmentOption
- **Usage**: 3 (Mac chat)
- **Location**: `/Views/AIChatView.swift`
- **Description**: Individual attachment option

### EventCategoryChip
- **Usage**: 2 (Event views)
- **Location**: `/Views/EventDetailView.swift`
- **Description**: Category selection chip

### InsightCard
- **Usage**: 1 (Habit insights)
- **Location**: `/Views/HabitDetailView.swift`
- **Description**: Insight display card

### RecentEntriesSection
- **Usage**: 1 (Habit detail)
- **Location**: `/Views/HabitDetailView.swift`
- **Description**: Recent habit entries list

### EntryRow
- **Usage**: 1 (Habit entries)
- **Location**: `/Views/HabitDetailView.swift`
- **Description**: Individual habit entry row

### OfflineBanner
- **Usage**: 3 (Navigation)
- **Location**: `/UnifiedNavigation/OfflineBanner.swift`
- **Description**: Offline status notification

### VisualEffectBlur
- **Usage**: 2 (Mac/iPad)
- **Location**: `/UnifiedNavigation/UnifiedNavigationView.swift`
- **Description**: Platform-specific blur effect

### ViewStateModifier
- **Usage**: Throughout app
- **Location**: `/Views/ViewStateModifier.swift`
- **Description**: Generic view state management modifier

### ColorSystemDemo
- **Usage**: 1 (Development)
- **Location**: `/Views/ColorSystemDemo.swift`
- **Description**: Color system demonstration view

### PrivacyPolicyView
- **Usage**: 1 (Legal)
- **Location**: `/Views/PrivacyPolicyView.swift`
- **Description**: Privacy policy display

### TermsOfServiceView
- **Usage**: 1 (Legal)
- **Location**: `/Views/TermsOfServiceView.swift`
- **Description**: Terms of service display

---

## Component Statistics

- **Total Unique Components**: ~122
- **Most Used Component**: EmptyStateView (10+ uses)
- **Button Components**: 25+ instances
- **Card Components**: 20+ instances
- **Premium-Specific Components**: 7
- **Platform-Specific Components**: 8 (Mac/iPad variants)
- **Chart/Visualization Components**: 5
- **State Management Components**: 15+

---

## Design System Integration

Most components use the centralized `DesignSystem` namespace for:
- **Spacing**: `DesignSystem.Spacing.sm/md/lg`
- **Colors**: `DesignSystem.Colors.primary/secondary`
- **Typography**: `DesignSystem.Typography.headline/body`
- **Corner Radius**: `DesignSystem.CornerRadius.sm/md/lg`
- **Shadows**: `DesignSystem.Shadow.sm/md/lg`
- **Animations**: `DesignSystem.Animation.spring/easeOut`

---

## Component Best Practices

1. **Reusability**: Most components are designed to be reusable with configuration parameters
2. **Platform Adaptation**: Many components have platform-specific variants (iPhone/iPad/Mac)
3. **State Management**: Components use `@StateObject`, `@ObservedObject`, or `@EnvironmentObject` appropriately
4. **Accessibility**: Components include accessibility labels and hints
5. **Performance**: Heavy lists use `LazyVStack` and pagination where needed
6. **Error Handling**: Most data-fetching components include error states
7. **Loading States**: Async operations show appropriate loading indicators

---

## Component Dependencies

### Core Dependencies
- **SwiftUI**: All UI components
- **CoreData**: Data-backed components
- **Charts**: Visualization components
- **PhotosUI**: Image picker components

### Manager Dependencies
- **ScheduleManager**: Event/calendar components
- **TaskManager**: Task-related components
- **HabitManager**: Habit-related components
- **SubscriptionManager**: Premium/paywall components

---

This catalog serves as a comprehensive reference for all UI components in the Momentum app. Each component is designed with reusability, performance, and user experience in mind.