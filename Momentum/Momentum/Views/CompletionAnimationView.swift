//
//  CompletionAnimationView.swift
//  Momentum
//
//  Delightful completion animations with haptic feedback
//

import SwiftUI

struct CompletionAnimationView: View {
    @Binding var isCompleted: Bool
    var style: CompletionStyle = .checkmark
    var onComplete: (() -> Void)?
    
    @State private var scale: CGFloat = 1.0
    @State private var rotation: Double = 0
    @State private var opacity: Double = 1.0
    @State private var particleSystem = CompletionParticleSystem()
    @State private var showCheckmark = false
    @State private var checkmarkScale: CGFloat = 0.0
    @State private var rippleScale: CGFloat = 0.0
    @State private var rippleOpacity: Double = 0.8
    
    enum CompletionStyle {
        case checkmark
        case star
        case celebration
        case subtle
    }
    
    var body: some View {
        ZStack {
            // Ripple effect
            if isCompleted && style != .subtle {
                Circle()
                    .stroke(lineWidth: 2)
                    .foregroundColor(Color.green.opacity(rippleOpacity))
                    .scaleEffect(rippleScale)
                    .onAppear {
                        withAnimation(.easeOut(duration: 0.6)) {
                            rippleScale = 2.5
                            rippleOpacity = 0
                        }
                    }
            }
            
            // Main content
            mainContent
                .scaleEffect(scale)
                .rotationEffect(.degrees(rotation))
                .opacity(opacity)
            
            // Particle effects for celebration style
            if style == .celebration && isCompleted {
                CompletionParticleEffectView(particleSystem: particleSystem)
                    .allowsHitTesting(false)
            }
        }
        .onChange(of: isCompleted) { _, newValue in
            if newValue {
                triggerCompletionAnimation()
            } else {
                resetAnimation()
            }
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        switch style {
        case .checkmark:
            checkmarkAnimation
        case .star:
            starAnimation
        case .celebration:
            celebrationAnimation
        case .subtle:
            subtleAnimation
        }
    }
    
    @ViewBuilder
    private var checkmarkAnimation: some View {
        ZStack {
            Circle()
                .fill(isCompleted ? Color.green : Color.clear)
                .overlay(
                    Circle()
                        .stroke(isCompleted ? Color.green : Color.gray.opacity(0.3), lineWidth: 2)
                )
                .frame(width: 24, height: 24)
            
            if showCheckmark {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .scaleEffect(checkmarkScale)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    @ViewBuilder
    private var starAnimation: some View {
        Image(systemName: isCompleted ? "star.fill" : "star")
            .font(.system(size: 24))
            .foregroundColor(isCompleted ? .yellow : .gray)
            .symbolEffect(.bounce, value: isCompleted)
    }
    
    @ViewBuilder
    private var celebrationAnimation: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: isCompleted ? [Color.green, Color.mint] : [Color.gray.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 30, height: 30)
            
            Image(systemName: "checkmark")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .opacity(isCompleted ? 1 : 0)
                .scaleEffect(isCompleted ? 1 : 0.5)
        }
    }
    
    @ViewBuilder
    private var subtleAnimation: some View {
        Circle()
            .fill(isCompleted ? Color.green.opacity(0.2) : Color.clear)
            .overlay(
                Circle()
                    .stroke(isCompleted ? Color.green : Color.gray.opacity(0.3), lineWidth: 1.5)
            )
            .frame(width: 20, height: 20)
            .overlay(
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isCompleted ? .green : .clear)
            )
    }
    
    private func triggerCompletionAnimation() {
        // Trigger haptic feedback
        HapticFeedback.success.trigger()
        
        switch style {
        case .checkmark:
            animateCheckmark()
        case .star:
            animateStar()
        case .celebration:
            animateCelebration()
        case .subtle:
            animateSubtle()
        }
        
        onComplete?()
    }
    
    private func animateCheckmark() {
        // Initial bounce
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            scale = 1.3
        }
        
        // Show checkmark with spring
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.1)) {
            showCheckmark = true
            checkmarkScale = 1.2
        }
        
        // Settle to normal size
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.3)) {
            scale = 1.0
            checkmarkScale = 1.0
        }
    }
    
    private func animateStar() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            scale = 1.4
            rotation = 360
        }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.2)) {
            scale = 1.0
        }
    }
    
    private func animateCelebration() {
        // Trigger particle burst
        particleSystem.burst(at: .zero)
        
        // Bounce animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
            scale = 1.5
        }
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.2)) {
            scale = 1.0
        }
        
        // Additional haptic for celebration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            HapticFeedback.light.trigger()
        }
    }
    
    private func animateSubtle() {
        withAnimation(.easeInOut(duration: 0.2)) {
            scale = 1.1
        }
        
        withAnimation(.easeInOut(duration: 0.2).delay(0.1)) {
            scale = 1.0
        }
    }
    
    private func resetAnimation() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showCheckmark = false
            checkmarkScale = 0.0
            scale = 1.0
            rotation = 0
            rippleScale = 0.0
            rippleOpacity = 0.8
        }
    }
}

// MARK: - Particle System

struct CompletionParticleSystem {
    var particles: [CompletionParticle] = []
    
    mutating func burst(at position: CGPoint) {
        let colors: [Color] = [.green, .mint, .yellow, .orange, .pink, .purple]
        
        for _ in 0..<12 {
            let particle = CompletionParticle(
                position: position,
                velocity: CGPoint(
                    x: Double.random(in: -100...100),
                    y: Double.random(in: -150...(-50))
                ),
                color: colors.randomElement()!,
                size: CGFloat.random(in: 4...8)
            )
            particles.append(particle)
        }
    }
}

struct CompletionParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGPoint
    var color: Color
    var size: CGFloat
    var opacity: Double = 1.0
}

struct CompletionParticleEffectView: View {
    let particleSystem: CompletionParticleSystem
    @State private var particles: [CompletionParticle] = []
    
    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .position(particle.position)
                    .opacity(particle.opacity)
            }
        }
        .onAppear {
            particles = particleSystem.particles
            animateParticles()
        }
    }
    
    private func animateParticles() {
        for index in particles.indices {
            withAnimation(.easeOut(duration: 1.0)) {
                particles[index].position.x += particles[index].velocity.x
                particles[index].position.y += particles[index].velocity.y
                particles[index].opacity = 0
            }
        }
        
        // Remove particles after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            particles.removeAll()
        }
    }
}


// MARK: - Preview

#Preview("Completion Animations") {
    struct PreviewWrapper: View {
        @State private var isCompleted1 = false
        @State private var isCompleted2 = false
        @State private var isCompleted3 = false
        @State private var isCompleted4 = false
        
        var body: some View {
            VStack(spacing: 40) {
                // Checkmark style
                HStack {
                    CompletionAnimationView(isCompleted: $isCompleted1, style: .checkmark)
                    Text("Checkmark Style")
                    Spacer()
                    Toggle("", isOn: $isCompleted1)
                }
                
                // Star style
                HStack {
                    CompletionAnimationView(isCompleted: $isCompleted2, style: .star)
                    Text("Star Style")
                    Spacer()
                    Toggle("", isOn: $isCompleted2)
                }
                
                // Celebration style
                HStack {
                    CompletionAnimationView(isCompleted: $isCompleted3, style: .celebration)
                    Text("Celebration Style")
                    Spacer()
                    Toggle("", isOn: $isCompleted3)
                }
                
                // Subtle style
                HStack {
                    CompletionAnimationView(isCompleted: $isCompleted4, style: .subtle)
                    Text("Subtle Style")
                    Spacer()
                    Toggle("", isOn: $isCompleted4)
                }
            }
            .padding()
        }
    }
    
    return PreviewWrapper()
}