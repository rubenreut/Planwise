//
//  HabitDetailView.swift
//  Momentum
//
//  Simplified habit detail view with GitHub-style heatmap
//

import SwiftUI
import Charts

struct HabitDetailView: View {
    let habit: Habit
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject private var habitManager: HabitManager
    @State private var showingEditView = false
    @State private var showingDeleteAlert = false
    @State private var showingJournalEntry = false
    @State private var entries: [HabitEntry] = []
    @AppStorage("accentColor") private var selectedAccentColor = "blue"
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Simple header
                    heroHeader
                        .padding(.top)
                    
                    // Full width GitHub heatmap
                    GitHubHeatmap(habit: habit, entries: entries)
                    
                    // Recent entries
                    if !entries.isEmpty {
                        recentEntriesSection
                    }
                    
                    // Quick actions
                    actionButtons
                        .padding(.horizontal)
                    
                    Spacer(minLength: 100)
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(habit.name ?? "Habit")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.large])
        .onAppear {
            loadData()
        }
        .sheet(isPresented: $showingEditView) {
            EditHabitView(habit: habit)
        }
        .sheet(isPresented: $showingJournalEntry) {
            JournalEntryView(entity: habit)
                .environmentObject(JournalManager.shared)
        }
        .alert("Delete Habit", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteHabit()
            }
        } message: {
            Text("Are you sure you want to delete this habit? All data will be lost.")
        }
    }
    
    @ViewBuilder
    private var heroHeader: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            // Header with icon and name
            HStack(spacing: DesignSystem.Spacing.md) {
                // Show category icon if available, otherwise nothing
                if let category = habit.category {
                    ZStack {
                        Circle()
                            .fill(Color(hex: category.colorHex ?? "#007AFF").opacity(0.1))
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: category.iconName ?? "folder")
                            .font(.system(size: 24))
                            .foregroundColor(Color(hex: category.colorHex ?? "#007AFF"))
                    }
                    
                    Text(category.name ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Small streak indicator
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                    Text("\(habit.currentStreak)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.orange.opacity(0.1))
                )
            }
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Journal button
            Button(action: { showingJournalEntry = true }) {
                Label("Add Journal Entry", systemImage: "book.fill")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                            .fill(Color.fromAccentString(selectedAccentColor))
                    )
            }
            
            HStack(spacing: 12) {
                Button(action: { showingEditView = true }) {
                    Label("Edit", systemImage: "pencil")
                        .font(.subheadline)
                        .foregroundColor(Color.fromAccentString(selectedAccentColor))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                .fill(Color.fromAccentString(selectedAccentColor).opacity(0.1))
                        )
                }
                
                Button(action: { showingDeleteAlert = true }) {
                    Label("Delete", systemImage: "trash")
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                .fill(Color.red.opacity(0.1))
                        )
                }
            }
        }
    }
    
    @ViewBuilder
    private var recentEntriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Entries")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 8) {
                ForEach(entries.prefix(10).sorted(by: { ($0.date ?? Date()) > ($1.date ?? Date()) }), id: \.self) { entry in
                    HStack {
                        // Date
                        Text(entry.date ?? Date(), style: .date)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        // Time
                        Text(entry.date ?? Date(), style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // Value for non-binary habits
                        if habit.trackingTypeEnum != .binary {
                            Text("\(Int(entry.value))")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(Color(hex: habit.category?.colorHex ?? "#007AFF"))
                        }
                        
                        // Checkmark for completion
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                            .fill(Color(UIColor.tertiarySystemFill))
                    )
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func loadData() {
        let endDate = Date()
        let startDate = Calendar.current.date(
            byAdding: .day,
            value: -90,
            to: endDate
        ) ?? endDate
        
        entries = habitManager.entriesForHabit(habit, in: startDate...endDate)
    }
    
    private func deleteHabit() {
        _ = habitManager.deleteHabit(habit)
        dismiss()
    }
}

// MARK: - GitHub Heatmap

struct GitHubHeatmap: View {
    let habit: Habit
    let entries: [HabitEntry]
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("accentColor") private var selectedAccentColor = "blue"
    
    private let columns = 13 // 13 weeks ≈ 90 days
    private let rows = 7 // 7 days per week
    
    private var heatmapData: [[Double]] {
        var data: [[Double]] = Array(repeating: Array(repeating: 0, count: columns), count: rows)
        let calendar = Calendar.current
        let today = Date()
        
        // Go back 90 days
        for col in 0..<columns {
            for row in 0..<rows {
                let daysAgo = (columns - 1 - col) * 7 + (6 - row)
                if let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) {
                    // Check if there's an entry for this date and get its value
                    if let entry = entries.first(where: { entry in
                        guard let entryDate = entry.date else { return false }
                        return calendar.isDate(entryDate, inSameDayAs: date)
                    }) {
                        // Normalize the value for intensity
                        if habit.trackingTypeEnum == .binary {
                            data[row][col] = 1.0
                        } else {
                            // For quantity/duration, show intensity based on goal
                            data[row][col] = min(1.0, entry.value / max(habit.goalTarget, 1))
                        }
                    }
                }
            }
        }
        return data
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 4) {
                // Day labels
                VStack(spacing: 4) {
                    ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { day in
                        Text(day)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(width: 10, height: 10)
                    }
                }
                .padding(.trailing, 4)
                
                // Heatmap grid
                HStack(spacing: 4) {
                    ForEach(0..<columns, id: \.self) { col in
                        VStack(spacing: 4) {
                            ForEach(0..<rows, id: \.self) { row in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(cellColor(for: heatmapData[row][col]))
                                    .frame(width: 18, height: 18)
                            }
                        }
                    }
                }
            }
            
            // Legend
            HStack(spacing: 8) {
                Text("Less")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 3) {
                    ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { intensity in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(cellColor(for: intensity))
                            .frame(width: 10, height: 10)
                    }
                }
                
                Text("More")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(.thinMaterial)
        )
        .padding(.horizontal)
    }
    
    private func cellColor(for intensity: Double) -> Color {
        // Use accent color instead of category/default color
        let accentColor = Color.fromAccentString(selectedAccentColor)
        if intensity == 0 {
            return colorScheme == .dark ? Color.gray.opacity(0.1) : Color.gray.opacity(0.15)
        } else {
            // Scale opacity based on intensity
            return accentColor.opacity(0.2 + (intensity * 0.8))
        }
    }
}