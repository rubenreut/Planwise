import SwiftUI

struct PremiumHeaderView: View {
    let dateTitle: String
    let selectedDate: Date
    let onPreviousDay: () -> Void
    let onNextDay: () -> Void
    let onToday: () -> Void
    let onSettings: () -> Void
    let onAddEvent: () -> Void
    let onDateSelected: ((Date) -> Void)?
    var showViewToggle: Bool = false // For iPad view toggle
    var isWeekView: Bool = false // To show correct icon
    
    @Environment(\.colorScheme) var colorScheme
    @State private var currentTime = Date()
    @State private var showDatePicker = false
    @State private var tempSelectedDate: Date = Date()
    @AppStorage("dayViewDateSelectorExpanded") private var isDateSelectorExpanded = true
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var animationProgress: CGFloat = 1
    @State private var weekSwipeOffset: CGFloat = 0
    @State private var isSwipingWeek = false
    @State private var weekTransition: Bool = false
    @State private var weekScale: CGFloat = 1.0
    @State private var weekOpacity: Double = 1.0
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let expandedHeight: CGFloat = 100
    private let collapsedHeight: CGFloat = 12
    
    // Calculate progress based on drag or animation
    private var dragProgress: CGFloat {
        if isDragging {
            if isDateSelectorExpanded {
                // When expanded, dragging up (negative) should decrease progress
                let progress = 1 + (dragOffset / expandedHeight)
                return min(1, max(0, progress))
            } else {
                // When collapsed, dragging down (positive) should increase progress
                let progress = dragOffset / expandedHeight
                return min(1, max(0, progress))
            }
        } else {
            return animationProgress
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Add extra spacing at the top to move title higher
            Spacer()
                .frame(height: 1)
            
            // Date header - always visible
            HStack {
                Text(dateTitle)
                    .scaledFont(size: 18, weight: .semibold)
                    .foregroundColor(.white)
                    .animation(.easeInOut(duration: 0.2), value: dragProgress)
                
                Spacer()
                
                // View toggle menu for iPad
                if showViewToggle && DeviceType.isIPad {
                    Menu {
                        Button(action: {
                            // Navigate to Day view
                            if isWeekView {
                                NotificationCenter.default.post(
                                    name: Notification.Name("NavigateToDayView"),
                                    object: nil
                                )
                            }
                        }) {
                            Label("Day View", systemImage: "calendar.day.timeline.left")
                        }
                        
                        Button(action: {
                            // Navigate to Week view
                            if !isWeekView {
                                NotificationCenter.default.post(
                                    name: Notification.Name("NavigateToWeekView"),
                                    object: nil
                                )
                            }
                        }) {
                            Label("Week View", systemImage: "calendar")
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isWeekView ? "calendar" : "calendar.day.timeline.left")
                                .font(.system(size: 14, weight: .medium))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.2))
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .offset(y: 20)
            
            // Date selector content with smooth height (hide content for Week view on iPad but keep space)
            if isWeekView && DeviceType.isIPad {
                // Empty spacer to maintain header height - add extra 43px for iPad
                Spacer()
                    .frame(height: max(0, collapsedHeight + (dragProgress * CGFloat(expandedHeight - collapsedHeight)) + 43))
            } else {
                VStack(spacing: 0) {
                    // Always render both states, control visibility with opacity
                    ZStack(alignment: .top) {
                        // Expanded content
                        VStack(spacing: 0) {
                            // Week view - shows current week only
                            HStack(spacing: 8) {
                            let calendar = Calendar.current
                            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
                            
                            ForEach(0..<7, id: \.self) { dayIndex in
                                let date = calendar.date(byAdding: .day, value: dayIndex, to: startOfWeek) ?? startOfWeek
                                let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                                let isToday = calendar.isDateInToday(date)
                                    
                                    Button(action: {
                                        if let onDateSelected = onDateSelected {
                                            onDateSelected(date)
                                        }
                                    }) {
                                        VStack(spacing: 2) {
                                            Text(dayOfWeek(for: date))
                                                .scaledFont(size: 11, weight: .medium)
                                                .foregroundColor(isSelected ? Color(red: 0.05, green: 0.1, blue: 0.25) : .white.opacity(0.7))
                                            
                                            Text("\(Calendar.current.component(.day, from: date))")
                                                .scaledFont(size: 18, weight: .semibold)
                                                .foregroundColor(isSelected ? Color(red: 0.05, green: 0.1, blue: 0.25) : .white)
                                            
                                            if isToday {
                                                Circle()
                                                    .fill(isSelected ? Color(red: 0.05, green: 0.1, blue: 0.25) : Color.white)
                                                    .frame(width: 4, height: 4)
                                            } else {
                                                Spacer().frame(height: 4)
                                            }
                                        }
                                        .frame(width: 50, height: 70)
                                        .background(
                                            isSelected ? 
                                            RoundedRectangle(cornerRadius: 25)
                                                .fill(Color.white) : nil
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 16)
                        .offset(x: weekSwipeOffset)
                        .scaleEffect(weekScale)
                        .opacity(weekOpacity)
                        .blur(radius: weekTransition ? 2 : 0)
                        .rotation3DEffect(
                            .degrees(Double(weekSwipeOffset) * 0.05),
                            axis: (x: 0, y: 1, z: 0),
                            perspective: 0.5
                        )
                        .overlay(
                            // Week navigation hint arrows
                            HStack {
                                // Previous week arrow
                                if weekSwipeOffset > 10 {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.white)
                                        .opacity(min(1.0, Double(weekSwipeOffset) / 50.0))
                                        .transition(.scale.combined(with: .opacity))
                                }
                                
                                Spacer()
                                
                                // Next week arrow
                                if weekSwipeOffset < -10 {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.white)
                                        .opacity(min(1.0, Double(abs(weekSwipeOffset)) / 50.0))
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .padding(.horizontal, 20)
                            .animation(.easeOut(duration: 0.2), value: weekSwipeOffset)
                        )
                        .contentShape(Rectangle()) // Make entire area tappable
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 15)
                                .onChanged { value in
                                    // Only handle horizontal swipes
                                    if abs(value.translation.width) > abs(value.translation.height) {
                                        if !isSwipingWeek {
                                            isSwipingWeek = true
                                            withAnimation(.easeOut(duration: 0.15)) {
                                                weekScale = 0.95
                                            }
                                        }
                                        // Add visual feedback during swipe with elastic feel
                                        let resistance = 1.0 - min(0.5, abs(value.translation.width) / 200.0)
                                        weekSwipeOffset = value.translation.width * 0.4 * resistance
                                        
                                        // Fade out as we swipe further
                                        withAnimation(.easeOut(duration: 0.1)) {
                                            weekOpacity = 1.0 - min(0.3, abs(value.translation.width) / 300.0)
                                        }
                                    }
                                }
                                .onEnded { value in
                                    // Only process if it was a horizontal swipe
                                    if abs(value.translation.width) > abs(value.translation.height) {
                                        let calendar = Calendar.current
                                        // Lower threshold for easier swiping
                                        if value.translation.width > 25 {
                                            // Swipe right - previous week
                                            HapticFeedback.medium.trigger()
                                            
                                            // Animate transition
                                            withAnimation(.easeInOut(duration: 0.15)) {
                                                weekTransition = true
                                                weekSwipeOffset = UIScreen.main.bounds.width
                                                weekOpacity = 0
                                            }
                                            
                                            // Change week after animation starts
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                                if let previousWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedDate) {
                                                    onDateSelected?(previousWeek)
                                                }
                                                
                                                // Slide in from left
                                                weekSwipeOffset = -UIScreen.main.bounds.width
                                                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                                    weekSwipeOffset = 0
                                                    weekOpacity = 1
                                                    weekScale = 1
                                                    weekTransition = false
                                                }
                                            }
                                        } else if value.translation.width < -25 {
                                            // Swipe left - next week  
                                            HapticFeedback.medium.trigger()
                                            
                                            // Animate transition
                                            withAnimation(.easeInOut(duration: 0.15)) {
                                                weekTransition = true
                                                weekSwipeOffset = -UIScreen.main.bounds.width
                                                weekOpacity = 0
                                            }
                                            
                                            // Change week after animation starts
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                                if let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedDate) {
                                                    onDateSelected?(nextWeek)
                                                }
                                                
                                                // Slide in from right
                                                weekSwipeOffset = UIScreen.main.bounds.width
                                                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                                    weekSwipeOffset = 0
                                                    weekOpacity = 1
                                                    weekScale = 1
                                                    weekTransition = false
                                                }
                                            }
                                        } else {
                                            // Not enough swipe - bounce back
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                weekSwipeOffset = 0
                                                weekScale = 1
                                                weekOpacity = 1
                                            }
                                        }
                                    } else {
                                        // Reset if not horizontal swipe
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            weekSwipeOffset = 0
                                            weekScale = 1
                                            weekOpacity = 1
                                        }
                                    }
                                    
                                    isSwipingWeek = false
                                }
                        )
                        .padding(.bottom, 12)
                    }
                    .opacity(dragProgress)
                    .scaleEffect(CGFloat(0.9 + (dragProgress * 0.1)), anchor: .top)
                    .offset(y: 18)
                    
                    // No navigation buttons when collapsed
                }
            }
            .frame(height: max(0, collapsedHeight + (dragProgress * CGFloat(expandedHeight - collapsedHeight))))
            .clipped()
            
            // Swipe indicator at the bottom center with larger hit box
            VStack(spacing: 0) {
                // Invisible expanded hit area
                Color.clear
                    .frame(height: 20)
                    .contentShape(Rectangle())
                
                // Visual indicator - drag handle
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 36, height: 5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(Color.white.opacity(0.6))
                            .frame(width: 36, height: 5)
                            .scaleEffect(x: CGFloat(0.6 + (dragProgress * 0.4)), y: 1.0)
                    )
                    .offset(y: isDragging ? dragOffset * 0.1 : 0)
                
                // Invisible expanded hit area
                Color.clear
                    .frame(height: 20)
                    .contentShape(Rectangle())
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                        }
                        // Add rubber band effect
                        let resistance = isDateSelectorExpanded ? 
                            (value.translation.height > 0 ? 0.5 : 1.0) :
                            (value.translation.height < 0 ? 0.5 : 1.0)
                        
                        // Smooth out rapid changes
                        let targetOffset = value.translation.height * resistance
                        dragOffset = dragOffset * 0.8 + targetOffset * 0.2
                    }
                    .onEnded { value in
                        let threshold: CGFloat = 50
                        let velocity = value.predictedEndLocation.y - value.location.y
                        
                        let shouldToggle = isDateSelectorExpanded ? 
                            (dragOffset < -threshold || velocity < -100) :
                            (dragOffset > threshold || velocity > 100)
                        
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            if shouldToggle {
                                isDateSelectorExpanded.toggle()
                            }
                            dragOffset = 0
                        }
                        
                        // Delay clearing isDragging to let animation complete
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isDragging = false
                        }
                    }
            )
            .onTapGesture {
                isDateSelectorExpanded.toggle()
            }
            } // End of else
        }
        .onChange(of: isDateSelectorExpanded) { _, newValue in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                animationProgress = newValue ? 1 : 0
            }
        }
        .onAppear {
            animationProgress = isDateSelectorExpanded ? 1 : 0
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
        .gesture(
            DragGesture()
                .onChanged { _ in
                    // Block day swiping in header area
                }
                .onEnded { _ in
                    // Do nothing - this prevents the gesture from propagating
                }
        )
        .highPriorityGesture(
            DragGesture()
                .onChanged { _ in }
                .onEnded { _ in }
        )
        .sheet(isPresented: $showDatePicker) {
            NavigationView {
                DatePicker(
                    "Select Date",
                    selection: $tempSelectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(GraphicalDatePickerStyle())
                .padding()
                .navigationTitle("Select Date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            showDatePicker = false
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            if let onDateSelected = onDateSelected {
                                onDateSelected(tempSelectedDate)
                            } else {
                                // Fallback to old behavior
                                let calendar = Calendar.current
                                let days = calendar.dateComponents([.day], from: selectedDate, to: tempSelectedDate).day ?? 0
                                
                                if days > 0 {
                                    for _ in 0..<days {
                                        onNextDay()
                                    }
                                } else if days < 0 {
                                    for _ in 0..<abs(days) {
                                        onPreviousDay()
                                    }
                                }
                            }
                            
                            showDatePicker = false
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: currentTime)
    }
    
    private func dayOfWeek(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }
    
    private func monthString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: date)
    }
    
    private func yearString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: date)
    }
    
}


#Preview {
    VStack {
        PremiumHeaderView(
            dateTitle: "Monday, June 29",
            selectedDate: Date(),
            onPreviousDay: {},
            onNextDay: {},
            onToday: {},
            onSettings: {},
            onAddEvent: {},
            onDateSelected: nil
        )
        
        Spacer()
    }
    .background(Color(UIColor.systemGroupedBackground))
}