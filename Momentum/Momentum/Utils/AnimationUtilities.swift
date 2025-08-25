import SwiftUI
import UIKit

// MARK: - Task Completion Animation Modifier
struct TaskCompletionAnimation: ViewModifier {
    @Binding var isCompleted: Bool
    let onComplete: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 1.0
    @State private var checkmarkScale: CGFloat = 0.0
    @State private var particleOpacity: Double = 0.0
    @State private var particleOffset: CGFloat = 0.0
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .opacity(opacity)
            .overlay(
                // Checkmark overlay
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundColor(.green)
                    .scaleEffect(checkmarkScale)
                    .opacity(checkmarkScale)
            )
            .overlay(
                // Particle effects
                ParticleEffectView(isActive: $isCompleted)
                    .opacity(particleOpacity)
                    .offset(y: particleOffset)
                    .allowsHitTesting(false)
            )
            .onChange(of: isCompleted) { _, newValue in
                if newValue {
                    performCompletionAnimation()
                }
            }
    }
    
    private func performCompletionAnimation() {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Main animation sequence
        withAnimation(.easeInOut(duration: 0.3)) {
            scale = 0.95
        }
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1)) {
            scale = 1.0
            checkmarkScale = 1.2
        }
        
        withAnimation(.easeOut(duration: 0.3).delay(0.3)) {
            checkmarkScale = 1.0
        }
        
        // Particle animation
        withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
            particleOpacity = 1.0
            particleOffset = -20
        }
        
        withAnimation(.easeIn(duration: 0.5).delay(0.7)) {
            particleOpacity = 0.0
            particleOffset = -40
        }
        
        // Fade out and callback
        withAnimation(.easeOut(duration: 0.4).delay(0.8)) {
            opacity = 0.5
            checkmarkScale = 0.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            onComplete()
            
            // Reset for next use
            withAnimation(.easeIn(duration: 0.2)) {
                opacity = 1.0
                scale = 1.0
                checkmarkScale = 0.0
                particleOpacity = 0.0
                particleOffset = 0.0
            }
        }
    }
}

// MARK: - Particle Effect View
struct ParticleEffectView: View {
    @Binding var isActive: Bool
    @State private var particles: [Particle] = []
    
    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .offset(x: particle.x, y: particle.y)
                    .opacity(particle.opacity)
                    .animation(.easeOut(duration: particle.duration), value: isActive)
            }
        }
        .onAppear {
            createParticles()
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                animateParticles()
            }
        }
    }
    
    private func createParticles() {
        particles = (0..<12).map { _ in
            Particle(
                x: 0,
                y: 0,
                size: CGFloat.random(in: 4...8),
                color: [Color.green, Color.blue, Color.purple, Color.orange, Color.pink].randomElement()!,
                opacity: 0,
                duration: Double.random(in: 0.6...1.0),
                destinationX: CGFloat.random(in: -50...50),
                destinationY: CGFloat.random(in: -50...50)
            )
        }
    }
    
    private func animateParticles() {
        for index in particles.indices {
            particles[index].opacity = 1.0
            particles[index].x = particles[index].destinationX
            particles[index].y = particles[index].destinationY
            
            // Fade out
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                particles[index].opacity = 0
            }
        }
    }
}

struct Particle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    let size: CGFloat
    let color: Color
    var opacity: Double
    let duration: Double
    let destinationX: CGFloat
    let destinationY: CGFloat
}

// MARK: - Streak Celebration Animation
struct StreakCelebrationModifier: ViewModifier {
    let streakCount: Int
    @State private var isAnimating = false
    @State private var confettiParticles: [ConfettiParticle] = []
    
    func body(content: Content) -> some View {
        content
            .overlay(
                ZStack {
                    if isAnimating {
                        // Streak number animation
                        Text("\(streakCount) 🔥")
                            .font(.system(size: 60, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                            .scaleEffect(isAnimating ? 1.5 : 0.5)
                            .opacity(isAnimating ? 0 : 1)
                            .animation(.spring(response: 0.5, dampingFraction: 0.5), value: isAnimating)
                        
                        // Confetti
                        ForEach(confettiParticles) { particle in
                            ConfettiPiece(particle: particle)
                        }
                    }
                }
            )
            .onAppear {
                if streakCount > 0 && streakCount % 5 == 0 {
                    celebrate()
                }
            }
    }
    
    private func celebrate() {
        // Generate confetti
        confettiParticles = (0..<30).map { _ in
            ConfettiParticle()
        }
        
        // Trigger animation
        isAnimating = true
        
        // Heavy haptic for milestone
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        // Reset after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isAnimating = false
            confettiParticles = []
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id = UUID()
    let color: Color = [.red, .blue, .green, .yellow, .purple, .orange, .pink].randomElement()!
    let size: CGFloat = CGFloat.random(in: 4...10)
    let startX: CGFloat = CGFloat.random(in: -150...150)
    let startY: CGFloat = -200
    let endX: CGFloat = CGFloat.random(in: -200...200)
    let endY: CGFloat = 400
    let rotation: Double = Double.random(in: 0...360)
    let duration: Double = Double.random(in: 1.5...2.5)
}

struct ConfettiPiece: View {
    let particle: ConfettiParticle
    @State private var isAnimating = false
    
    var body: some View {
        Rectangle()
            .fill(particle.color)
            .frame(width: particle.size, height: particle.size * 2)
            .rotationEffect(.degrees(isAnimating ? particle.rotation + 360 : particle.rotation))
            .offset(x: isAnimating ? particle.endX : particle.startX,
                   y: isAnimating ? particle.endY : particle.startY)
            .opacity(isAnimating ? 0 : 1)
            .onAppear {
                withAnimation(.easeIn(duration: particle.duration)) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - Simple Slide & Fade Animation
struct SlideAndFadeModifier: AnimatableModifier {
    var progress: Double
    
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }
    
    func body(content: Content) -> some View {
        content
            .offset(x: progress * 50)
            .opacity(1 - progress)
    }
}

// MARK: - View Extensions
extension View {
    func taskCompletionAnimation(isCompleted: Binding<Bool>, onComplete: @escaping () -> Void) -> some View {
        self.modifier(TaskCompletionAnimation(isCompleted: isCompleted, onComplete: onComplete))
    }
    
    func streakCelebration(count: Int) -> some View {
        self.modifier(StreakCelebrationModifier(streakCount: count))
    }
    
    func slideAndFade(progress: Double) -> some View {
        self.modifier(SlideAndFadeModifier(progress: progress))
    }
}

// MARK: - Bounce Animation for Buttons
struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Progress Ring Animation
struct AnimatedProgressRing: View {
    let progress: Double
    let lineWidth: CGFloat = 8
    @State private var animatedProgress: Double = 0
    
    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: lineWidth)
            
            // Progress ring
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 1.0, dampingFraction: 0.8), value: animatedProgress)
            
            // Center text
            Text("\(Int(animatedProgress * 100))%")
                .font(.system(.title3, design: .rounded))
                .fontWeight(.semibold)
        }
        .onAppear {
            animatedProgress = progress
        }
        .onChange(of: progress) { _, newValue in
            animatedProgress = newValue
        }
    }
}