//
//  LoadingView.swift
//  Momentum
//
//  Comprehensive loading states with skeleton animations
//

import SwiftUI

// MARK: - LoadingView

struct LoadingView: View {
    let message: String?
    let style: LoadingStyle
    
    @State private var isAnimating = false
    
    init(message: String? = nil, style: LoadingStyle = .default) {
        self.message = message
        self.style = style
    }
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            switch style {
            case .default:
                defaultLoader
            case .circular:
                circularLoader
            case .dots:
                dotsLoader
            case .skeleton(let type):
                SkeletonLoader(type: type)
            }
            
            if let message = message {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.adaptiveBackground)
        .onAppear {
            isAnimating = true
        }
        .onDisappear {
            isAnimating = false
        }
    }
    
    // Default loading indicator
    private var defaultLoader: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
            .scaleEffect(1.5)
    }
    
    // Circular loader with custom animation
    private var circularLoader: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.3), lineWidth: 3)
                .frame(width: 50, height: 50)
            
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(
                    LinearGradient(
                        colors: [.accentColor, .accentColor.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: 50, height: 50)
                .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                .animation(
                    Animation.linear(duration: 1)
                        .repeatForever(autoreverses: false),
                    value: isAnimating
                )
        }
    }
    
    // Dots loader animation
    private var dotsLoader: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 12, height: 12)
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: isAnimating
                    )
            }
        }
    }
}

// MARK: - Loading Styles

enum LoadingStyle {
    case `default`
    case circular
    case dots
    case skeleton(SkeletonType)
}

// MARK: - Skeleton Types

enum SkeletonType {
    case taskList
    case dayView
    case eventDetail
    case chat
    case habitGrid
    case custom([SkeletonRow])
}

// MARK: - Skeleton Loader

struct SkeletonLoader: View {
    let type: SkeletonType
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            switch type {
            case .taskList:
                taskListSkeleton
            case .dayView:
                dayViewSkeleton
            case .eventDetail:
                eventDetailSkeleton
            case .chat:
                chatSkeleton
            case .habitGrid:
                habitGridSkeleton
            case .custom(let rows):
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    SkeletonRowView(row: row, isAnimating: isAnimating)
                }
            }
        }
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever()) {
                isAnimating = true
            }
        }
    }
    
    // Task list skeleton
    private var taskListSkeleton: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Filter pills skeleton
            HStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(0..<4) { _ in
                    Capsule()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 80, height: 32)
                        .shimmer(isAnimating: isAnimating)
                }
            }
            .padding(.horizontal)
            
            // Task items skeleton
            ForEach(0..<5) { _ in
                taskItemSkeleton
                    .padding(.horizontal)
            }
        }
    }
    
    private var taskItemSkeleton: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Circle()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 24, height: 24)
                .shimmer(isAnimating: isAnimating)
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 200, height: 16)
                    .shimmer(isAnimating: isAnimating)
                
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 120, height: 12)
                    .shimmer(isAnimating: isAnimating)
            }
            
            Spacer()
            
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 60, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shimmer(isAnimating: isAnimating)
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // Day view skeleton
    private var dayViewSkeleton: some View {
        VStack(spacing: 0) {
            // Header skeleton
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(height: 60)
                .shimmer(isAnimating: isAnimating)
            
            // Timeline skeleton
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(0..<8) { index in
                        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                            // Time label
                            Rectangle()
                                .fill(Color.secondary.opacity(0.2))
                                .frame(width: 50, height: 16)
                                .shimmer(isAnimating: isAnimating)
                            
                            // Event blocks
                            if index % 3 == 0 {
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.3))
                                    .frame(height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .shimmer(isAnimating: isAnimating)
                            } else {
                                Color.clear
                            }
                        }
                        .frame(height: 68)
                        .padding(.horizontal)
                    }
                }
            }
        }
    }
    
    // Event detail skeleton
    private var eventDetailSkeleton: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Title
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(height: 28)
                .shimmer(isAnimating: isAnimating)
            
            // Time
            HStack(spacing: DesignSystem.Spacing.sm) {
                Circle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 20, height: 20)
                    .shimmer(isAnimating: isAnimating)
                
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 150, height: 20)
                    .shimmer(isAnimating: isAnimating)
            }
            
            // Description
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 16)
                    .shimmer(isAnimating: isAnimating)
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 16)
                    .shimmer(isAnimating: isAnimating)
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 200, height: 16)
                    .shimmer(isAnimating: isAnimating)
            }
            
            Spacer()
        }
        .padding()
    }
    
    // Chat skeleton
    private var chatSkeleton: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            ForEach(0..<3) { index in
                HStack {
                    if index % 2 == 0 {
                        Spacer()
                    }
                    
                    VStack(alignment: index % 2 == 0 ? .trailing : .leading, spacing: DesignSystem.Spacing.xs) {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(width: 250, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shimmer(isAnimating: isAnimating)
                        
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: 80, height: 12)
                            .shimmer(isAnimating: isAnimating)
                    }
                    
                    if index % 2 != 0 {
                        Spacer()
                    }
                }
            }
        }
        .padding()
    }
    
    // Habit grid skeleton
    private var habitGridSkeleton: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignSystem.Spacing.md) {
            ForEach(0..<6) { _ in
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Circle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 60, height: 60)
                        .shimmer(isAnimating: isAnimating)
                    
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 16)
                        .shimmer(isAnimating: isAnimating)
                    
                    Rectangle()
                        .fill(Color.secondary.opacity(0.1))
                        .frame(width: 80, height: 12)
                        .shimmer(isAnimating: isAnimating)
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
    }
}

// MARK: - Skeleton Row

struct SkeletonRow {
    let elements: [SkeletonElement]
    let spacing: CGFloat
    
    init(elements: [SkeletonElement], spacing: CGFloat = DesignSystem.Spacing.sm) {
        self.elements = elements
        self.spacing = spacing
    }
}

struct SkeletonElement {
    let shape: SkeletonShape
    let width: CGFloat?
    let height: CGFloat
    let opacity: Double
    
    init(shape: SkeletonShape = .rectangle, width: CGFloat? = nil, height: CGFloat, opacity: Double = 0.3) {
        self.shape = shape
        self.width = width
        self.height = height
        self.opacity = opacity
    }
}

enum SkeletonShape {
    case rectangle
    case circle
    case capsule
}

struct SkeletonRowView: View {
    let row: SkeletonRow
    let isAnimating: Bool
    
    var body: some View {
        HStack(spacing: row.spacing) {
            ForEach(Array(row.elements.enumerated()), id: \.offset) { _, element in
                elementView(for: element)
            }
        }
    }
    
    @ViewBuilder
    private func elementView(for element: SkeletonElement) -> some View {
        switch element.shape {
        case .rectangle:
            Rectangle()
                .fill(Color.secondary.opacity(element.opacity))
                .frame(width: element.width, height: element.height)
                .shimmer(isAnimating: isAnimating)
        case .circle:
            Circle()
                .fill(Color.secondary.opacity(element.opacity))
                .frame(width: element.width, height: element.height)
                .shimmer(isAnimating: isAnimating)
        case .capsule:
            Capsule()
                .fill(Color.secondary.opacity(element.opacity))
                .frame(width: element.width, height: element.height)
                .shimmer(isAnimating: isAnimating)
        }
    }
}

// MARK: - Shimmer Effect

extension View {
    func shimmer(isAnimating: Bool) -> some View {
        self.overlay(
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.white.opacity(0.3),
                    Color.clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .rotationEffect(.degrees(30))
            .offset(x: isAnimating ? 300 : -300)
            .mask(self)
        )
    }
}

// MARK: - Preview

#Preview("Default Loading") {
    LoadingView(message: "Loading your data...")
}

#Preview("Skeleton Loaders") {
    ScrollView {
        VStack(spacing: 40) {
            LoadingView(style: .skeleton(.taskList))
            Divider()
            LoadingView(style: .skeleton(.dayView))
            Divider()
            LoadingView(style: .skeleton(.chat))
        }
    }
}