import SwiftUI

struct CurrentTimeIndicator: View {
    @State private var currentTime = Date()
    
    // Constants - MUST match device type
    private let hourHeight: CGFloat = DeviceType.isIPad ? 80 : 68
    private let timeColumnWidth: CGFloat = DeviceType.isIPad ? 70 : 58
    private let ballSize: CGFloat = 8
    
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    private var calendar: Calendar {
        var cal = Calendar.current
        cal.timeZone = TimeZone.current
        return cal
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Spacer to push indicator to correct position
            Color.clear
                .frame(height: calculateTimePosition(for: currentTime))
            
            // The indicator itself
            HStack(spacing: 0) {
                // Ball centered on the vertical separator line
                Circle()
                    .fill(Color.adaptiveRed)
                    .frame(width: ballSize, height: ballSize)
                    .padding(.leading, timeColumnWidth - (ballSize / 2))
                
                // Red line extending to the right
                Rectangle()
                    .fill(Color.adaptiveRed)
                    .frame(height: 1)
            }
            
            Spacer(minLength: 0)
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }
    
    private func calculateTimePosition(for date: Date) -> CGFloat {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hour = CGFloat(components.hour ?? 0)
        let minute = CGFloat(components.minute ?? 0)
        
        return (hour * hourHeight) + (minute * (hourHeight / 60))
    }
    
    private func formatCurrentTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: currentTime)
    }
}

#Preview {
    CurrentTimeIndicator()
        .frame(height: 800)
        .background(Color.gray.opacity(0.1))
}