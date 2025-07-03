import SwiftUI

struct TimelineBackgroundView: View {
    let selectedDate: Date
    
    @Environment(\.colorScheme) var colorScheme
    @State private var animationPhase: CGFloat = 0
    
    // Mathematical constants
    private let φ: CGFloat = 1.618033988749895
    private let baseUnit: CGFloat = 8
    
    private var calendar: Calendar {
        Calendar.current
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Layer 1: Ambient gradient
                ambientGradient
                
                // Layer 2: Time-aware patterns
                timeAwarePattern(size: geometry.size)
                
                // Layer 3: Floating orbs
                floatingOrbs(size: geometry.size)
                
                // Layer 4: Mesh gradient simulation
                meshGradient
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
                animationPhase = 1
            }
        }
    }
    
    // MARK: - Ambient Gradient
    private var ambientGradient: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                stops: gradientStops(),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Radial overlay for depth
            RadialGradient(
                colors: [
                    Color.clear,
                    ambientColor().opacity(0.1)
                ],
                center: .center,
                startRadius: 50,
                endRadius: 500
            )
        }
    }
    
    // MARK: - Time-Aware Pattern
    private func timeAwarePattern(size: CGSize) -> some View {
        Canvas { context, _ in
            let hour = calendar.component(.hour, from: selectedDate)
            
            // Morning mist (6am - 10am)
            if hour >= 6 && hour < 10 {
                let mistGradient = Gradient(colors: [
                    Color.orange.opacity(0.05),
                    Color.clear
                ])
                
                for i in 0..<3 {
                    let y = size.height * (0.2 + CGFloat(i) * 0.3)
                    let phase = animationPhase * .pi * 2 + CGFloat(i) * .pi / 3
                    let offset = Foundation.sin(phase) * 20
                    
                    context.fill(
                        Ellipse()
                            .path(in: CGRect(
                                x: -50 + offset,
                                y: y - 30,
                                width: size.width + 100,
                                height: 60
                            )),
                        with: .radialGradient(
                            mistGradient,
                            center: CGPoint(x: size.width/2, y: y),
                            startRadius: 0,
                            endRadius: 100
                        )
                    )
                }
            }
            
            // Afternoon rays (12pm - 4pm)
            if hour >= 12 && hour < 16 {
                let rayGradient = Gradient(colors: [
                    Color.yellow.opacity(0.1),
                    Color.clear
                ])
                
                for i in 0..<5 {
                    let angle = CGFloat(i) * .pi / 10 - .pi / 4
                    let startX = size.width * 0.8
                    let startY = size.height * 0.2
                    
                    context.fill(
                        Path { path in
                            path.move(to: CGPoint(x: startX, y: startY))
                            path.addLine(to: CGPoint(
                                x: startX + Foundation.cos(angle) * size.width,
                                y: startY + Foundation.sin(angle) * size.width
                            ))
                            path.addLine(to: CGPoint(
                                x: startX + Foundation.cos(angle + 0.05) * size.width,
                                y: startY + Foundation.sin(angle + 0.05) * size.width
                            ))
                            path.closeSubpath()
                        },
                        with: .linearGradient(
                            rayGradient,
                            startPoint: CGPoint(x: startX, y: startY),
                            endPoint: CGPoint(
                                x: startX + Foundation.cos(angle) * 200,
                                y: startY + Foundation.sin(angle) * 200
                            )
                        )
                    )
                }
            }
            
            // Evening gradient (6pm - 10pm)
            if hour >= 18 && hour < 22 {
                let eveningGradient = Gradient(colors: [
                    Color.purple.opacity(0.05),
                    Color.orange.opacity(0.05),
                    Color.clear
                ])
                
                context.fill(
                    Rectangle().path(in: CGRect(origin: .zero, size: size)),
                    with: .radialGradient(
                        eveningGradient,
                        center: CGPoint(x: size.width * 0.7, y: size.height * 0.3),
                        startRadius: 0,
                        endRadius: size.width * 0.8
                    )
                )
            }
        }
    }
    
    // MARK: - Floating Orbs
    private func floatingOrbs(size: CGSize) -> some View {
        ZStack {
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                orbColor(for: index).opacity(0.3),
                                orbColor(for: index).opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 50
                        )
                    )
                    .frame(width: orbSize(for: index), height: orbSize(for: index))
                    .blur(radius: 10)
                    .position(orbPosition(for: index, in: size))
                    .opacity(0.6)
            }
        }
    }
    
    // MARK: - Mesh Gradient
    private var meshGradient: some View {
        ZStack {
            // Top-left gradient
            RadialGradient(
                colors: [
                    meshColor(0).opacity(0.2),
                    Color.clear
                ],
                center: UnitPoint(x: 0, y: 0),
                startRadius: 0,
                endRadius: 300
            )
            
            // Bottom-right gradient
            RadialGradient(
                colors: [
                    meshColor(1).opacity(0.2),
                    Color.clear
                ],
                center: UnitPoint(x: 1, y: 1),
                startRadius: 0,
                endRadius: 300
            )
            
            // Center gradient
            RadialGradient(
                colors: [
                    meshColor(2).opacity(0.1),
                    Color.clear
                ],
                center: UnitPoint(x: 0.5, y: 0.5),
                startRadius: 50,
                endRadius: 200
            )
        }
        .blendMode(.plusLighter)
    }
    
    // MARK: - Helper Functions
    
    private func gradientStops() -> [Gradient.Stop] {
        let hour = calendar.component(.hour, from: selectedDate)
        
        if colorScheme == .dark {
            // Dark mode: Deep, rich backgrounds
            switch hour {
            case 6..<12: // Morning
                return [
                    .init(color: Color(red: 0.05, green: 0.05, blue: 0.08), location: 0),
                    .init(color: Color(red: 0.03, green: 0.03, blue: 0.05), location: 1)
                ]
            case 12..<18: // Afternoon
                return [
                    .init(color: Color(red: 0.06, green: 0.05, blue: 0.08), location: 0),
                    .init(color: Color(red: 0.03, green: 0.03, blue: 0.06), location: 1)
                ]
            case 18..<22: // Evening
                return [
                    .init(color: Color(red: 0.08, green: 0.05, blue: 0.08), location: 0),
                    .init(color: Color(red: 0.05, green: 0.03, blue: 0.05), location: 1)
                ]
            default: // Night
                return [
                    .init(color: Color(red: 0.03, green: 0.03, blue: 0.05), location: 0),
                    .init(color: Color(red: 0.02, green: 0.02, blue: 0.03), location: 1)
                ]
            }
        } else {
            // Light mode: Subtle, elegant backgrounds
            switch hour {
            case 6..<12: // Morning
                return [
                    .init(color: Color(red: 0.98, green: 0.98, blue: 0.97), location: 0),
                    .init(color: Color(red: 0.96, green: 0.96, blue: 0.95), location: 1)
                ]
            case 12..<18: // Afternoon
                return [
                    .init(color: Color(red: 0.98, green: 0.97, blue: 0.96), location: 0),
                    .init(color: Color(red: 0.95, green: 0.95, blue: 0.94), location: 1)
                ]
            case 18..<22: // Evening
                return [
                    .init(color: Color(red: 0.97, green: 0.96, blue: 0.97), location: 0),
                    .init(color: Color(red: 0.94, green: 0.94, blue: 0.95), location: 1)
                ]
            default: // Night
                return [
                    .init(color: Color(red: 0.96, green: 0.96, blue: 0.97), location: 0),
                    .init(color: Color(red: 0.94, green: 0.94, blue: 0.95), location: 1)
                ]
            }
        }
    }
    
    private func ambientColor() -> Color {
        let hour = calendar.component(.hour, from: selectedDate)
        
        switch hour {
        case 6..<10: return .orange
        case 10..<14: return .yellow
        case 14..<18: return .blue
        case 18..<22: return .purple
        default: return .indigo
        }
    }
    
    private func orbColor(for index: Int) -> Color {
        let colors: [Color] = [.blue, .purple, .orange, .pink, .teal]
        return colors[index % colors.count]
    }
    
    private func orbSize(for index: Int) -> CGFloat {
        let baseSizes: [CGFloat] = [80, 120, 100, 90, 110]
        return baseSizes[index % baseSizes.count]
    }
    
    private func orbPosition(for index: Int, in size: CGSize) -> CGPoint {
        let phase = animationPhase * .pi * 2
        let indexPhase = CGFloat(index) * .pi / 2.5
        
        let centerX = size.width * (0.2 + CGFloat(index % 3) * 0.3)
        let centerY = size.height * (0.2 + CGFloat(index % 2) * 0.6)
        
        let radius = 50 * (1 + Foundation.sin(phase + indexPhase) * 0.3)
        let angle = phase + indexPhase
        
        return CGPoint(
            x: centerX + Foundation.cos(angle) * radius,
            y: centerY + Foundation.sin(angle * 0.7) * radius * 0.5
        )
    }
    
    private func meshColor(_ index: Int) -> Color {
        let hour = calendar.component(.hour, from: selectedDate)
        let colors: [[Color]] = [
            [.blue, .purple, .teal], // Morning
            [.orange, .yellow, .pink], // Day
            [.purple, .indigo, .blue] // Evening
        ]
        
        let colorSet = hour < 12 ? 0 : (hour < 18 ? 1 : 2)
        return colors[colorSet][index % 3]
    }
}

// MARK: - Preview
#Preview("Light Mode") {
    TimelineBackgroundView(selectedDate: Date())
        .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    TimelineBackgroundView(selectedDate: Date())
        .preferredColorScheme(.dark)
}