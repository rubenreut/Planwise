import SwiftUI
import os.log

struct PerformanceMonitor: ViewModifier {
    let label: String
    @State private var renderTime: TimeInterval = 0
    
    private let logger = Logger(subsystem: "com.rubenreut.momentum", category: "Performance")
    
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { _ in
                    Color.clear
                        .onAppear {
                            let start = CFAbsoluteTimeGetCurrent()
                            DispatchQueue.main.async {
                                let elapsed = CFAbsoluteTimeGetCurrent() - start
                                renderTime = elapsed
                                if elapsed > 0.016 { // More than 16ms (60fps threshold)
                                    logger.warning("⚠️ SLOW RENDER: \(label) took \(String(format: "%.3f", elapsed * 1000))ms")
                                }
                            }
                        }
                }
            )
            .onChange(of: renderTime) { _, newValue in
                if newValue > 0.016 {
                }
            }
    }
}

extension View {
    func measurePerformance(_ label: String) -> some View {
        modifier(PerformanceMonitor(label: label))
    }
}

// FPS Monitor overlay
struct FPSView: View {
    @State private var fps: Double = 60
    private let updateTimer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack {
            Text("FPS: \(Int(fps))")
                .font(.caption)
                .padding(4)
                .background(fps < 30 ? Color.red : fps < 50 ? Color.orange : Color.green)
                .foregroundColor(.white)
                .cornerRadius(4)
        }
        .onReceive(updateTimer) { _ in
            // This is a simple approximation
            fps = 1.0 / (CACurrentMediaTime() - previousTime)
            previousTime = CACurrentMediaTime()
        }
    }
    
    @State private var previousTime = CACurrentMediaTime()
}