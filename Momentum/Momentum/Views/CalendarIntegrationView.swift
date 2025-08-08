//
//  CalendarIntegrationView.swift
//  Momentum
//
//  UI for managing calendar integrations and syncing
//

import SwiftUI
import EventKit

struct CalendarIntegrationView: View {
    @StateObject private var calendarManager = CalendarIntegrationManager.shared
    @State private var showingPermissionAlert = false
    @State private var isSyncing = false
    @State private var showingSyncSuccess = false
    @State private var syncDateRange = DateRange.thisMonth
    
    enum DateRange: String, CaseIterable {
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        case next3Months = "Next 3 Months"
        
        var dateRange: (start: Date, end: Date) {
            let calendar = Calendar.current
            let now = Date()
            
            switch self {
            case .thisWeek:
                let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
                let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek) ?? now
                return (startOfWeek, endOfWeek)
                
            case .thisMonth:
                let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
                let endOfMonth = calendar.dateInterval(of: .month, for: now)?.end ?? now
                return (startOfMonth, endOfMonth)
                
            case .next3Months:
                let start = now
                let end = calendar.date(byAdding: .month, value: 3, to: start) ?? now
                return (start, end)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Gradient background
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(hex: "#667eea"),
                            Color(hex: "#764ba2")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                    
                    LinearGradient(
                        colors: [
                            Color(hex: "#f093fb").opacity(0.4),
                            Color(hex: "#f5576c").opacity(0.4)
                        ],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                    .ignoresSafeArea()
                    .blendMode(.overlay)
                }
                
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // Permission status card
                        if calendarManager.authorizationStatus != .authorized && 
                           calendarManager.authorizationStatus != .fullAccess {
                            permissionCard
                        }
                        
                        // Calendar list
                        if calendarManager.integratedCalendars.isEmpty && !calendarManager.isLoading {
                            emptyStateCard
                        } else {
                            calendarListSection
                        }
                        
                        // Sync controls
                        if !calendarManager.selectedCalendarIds.isEmpty {
                            syncControlsSection
                        }
                        
                        // Last sync info
                        if let lastSync = calendarManager.lastSyncDate {
                            lastSyncCard(date: lastSync)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Calendar Integration")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if calendarManager.isLoading {
                        ProgressView()
                    }
                }
            }
            .alert("Calendar Permission Required", isPresented: $showingPermissionAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Please grant calendar access in Settings to sync your events.")
            }
            .task {
                await loadCalendars()
            }
        }
    }
    
    // MARK: - Components
    
    private var permissionCard: some View {
        GlassCard(cornerRadius: DesignSystem.CornerRadius.lg, padding: DesignSystem.Spacing.lg) {
            VStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)
                
                Text("Calendar Access Required")
                    .font(.headline)
                
                Text("Grant calendar access to import and sync your events")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button {
                    _Concurrency.Task {
                        let granted = await calendarManager.requestCalendarAccess()
                        if granted {
                            await loadCalendars()
                        } else {
                            showingPermissionAlert = true
                        }
                    }
                } label: {
                    Label("Grant Access", systemImage: "lock.open")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(FloatingActionButtonStyle())
            }
        }
    }
    
    private var emptyStateCard: some View {
        GlassCard(cornerRadius: DesignSystem.CornerRadius.lg, padding: DesignSystem.Spacing.lg) {
            VStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                
                Text("No Calendars Found")
                    .font(.headline)
                
                Text("Add calendars in your device settings or connect your accounts")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button {
                    if let url = URL(string: "prefs:root=ACCOUNTS_AND_PASSWORDS") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Manage Accounts", systemImage: "gear")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(FloatingActionButtonStyle())
            }
        }
    }
    
    private var calendarListSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Available Calendars")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(calendarManager.integratedCalendars) { calendar in
                    CalendarRowView(
                        calendar: calendar,
                        isSelected: calendarManager.selectedCalendarIds.contains(calendar.calendarIdentifier)
                    ) {
                        calendarManager.toggleCalendarSelection(calendar)
                    }
                }
            }
        }
    }
    
    private var syncControlsSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Date range picker
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Sync Range")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                
                Picker("Date Range", selection: $syncDateRange) {
                    ForEach(DateRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // Sync button
            Button {
                _Concurrency.Task {
                    await syncCalendars()
                }
            } label: {
                HStack {
                    Image(systemName: isSyncing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                        .rotationEffect(.degrees(isSyncing ? 360 : 0))
                        .animation(isSyncing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isSyncing)
                    
                    Text(isSyncing ? "Syncing..." : "Sync Calendars")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isSyncing || calendarManager.selectedCalendarIds.isEmpty)
            
            if showingSyncSuccess {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("\(calendarManager.syncedEvents.count) events synced")
                        .font(.subheadline)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(DesignSystem.CornerRadius.md)
    }
    
    private func lastSyncCard(date: Date) -> some View {
        HStack {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundColor(.white.opacity(0.8))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Last Sync")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                
                Text(date, style: .relative)
                    .font(.footnote)
                    .foregroundColor(.white)
            }
            
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(DesignSystem.CornerRadius.md)
    }
    
    // MARK: - Methods
    
    private func loadCalendars() async {
        await calendarManager.loadCalendars()
    }
    
    private func syncCalendars() async {
        isSyncing = true
        showingSyncSuccess = false
        
        let range = syncDateRange.dateRange
        await calendarManager.syncEvents(from: range.start, to: range.end)
        
        isSyncing = false
        
        withAnimation {
            showingSyncSuccess = true
        }
        
        // Hide success message after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                showingSyncSuccess = false
            }
        }
    }
}

// MARK: - Calendar Row View
struct CalendarRowView: View {
    let calendar: IntegratedCalendar
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Calendar icon with color
                ZStack {
                    Circle()
                        .fill(calendar.color.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: calendar.type.icon)
                        .font(.system(size: 20))
                        .foregroundColor(calendar.color)
                }
                
                // Calendar info
                VStack(alignment: .leading, spacing: 2) {
                    Text(calendar.title)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Text(calendar.type.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(DesignSystem.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .stroke(
                        isSelected ? Color.accentColor : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview {
    CalendarIntegrationView()
}