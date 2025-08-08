import SwiftUI

struct TaskHeaderView: View {
    @Binding var selectedFilter: TaskListView.TaskFilter
    let taskCount: (TaskListView.TaskFilter) -> Int
    
    @Environment(\.colorScheme) var colorScheme
    @State private var currentTime = Date()
    @AppStorage("taskViewDateSelectorExpanded") private var isDateSelectorExpanded = true
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var animationProgress: CGFloat = 1
    
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
            
            // Current filter text - always visible (like dateTitle in PremiumHeaderView)
            HStack {
                Text("\(selectedFilter.rawValue) (\(taskCount(selectedFilter)))")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .animation(.easeInOut(duration: 0.2), value: dragProgress)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .offset(y: 20)
            
            // Filter selector content with smooth height
            VStack(spacing: 0) {
                // Always render both states, control visibility with opacity
                ZStack(alignment: .top) {
                    // Expanded content
                    VStack(spacing: 0) {
                        // Filter pills (like week view in PremiumHeaderView)
                        HStack(spacing: 8) {
                            ForEach(TaskListView.TaskFilter.allCases, id: \.self) { filter in
                                let isSelected = selectedFilter == filter
                                let count = taskCount(filter)
                                
                                Button(action: {
                                    selectedFilter = filter
                                }) {
                                    VStack(spacing: 2) {
                                        Image(systemName: filter.icon)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(isSelected ? Color(red: 0.05, green: 0.1, blue: 0.25) : .white.opacity(0.7))
                                        
                                        Text(filter.rawValue)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(isSelected ? Color(red: 0.05, green: 0.1, blue: 0.25) : .white.opacity(0.7))
                                        
                                        Text("\(count)")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(isSelected ? Color(red: 0.05, green: 0.1, blue: 0.25) : .white)
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
                        .padding(.bottom, 12)
                    }
                    .opacity(dragProgress)
                    .scaleEffect(CGFloat(0.9 + (dragProgress * 0.1)), anchor: .top)
                    .offset(y: 18)
                    
                    // No collapsed content - just the title is visible
                }
            }
            .frame(height: collapsedHeight + (dragProgress * CGFloat(expandedHeight - collapsedHeight)))
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
    }
}

#Preview {
    ZStack {
        // Blue gradient background to simulate the actual view
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.1, blue: 0.25),
                Color(red: 0.08, green: 0.15, blue: 0.35)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        
        VStack {
            TaskHeaderView(
                selectedFilter: .constant(.today),
                taskCount: { _ in 5 }
            )
            
            Spacer()
        }
    }
}