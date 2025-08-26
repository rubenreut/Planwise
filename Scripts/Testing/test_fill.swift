import SwiftUI

struct TestView: View {
    var body: some View {
        VStack {
            // Test 1: Simple fill
            Circle()
                .fill(Color.red)
                .frame(width: 50, height: 50)
            
            // Test 2: Fill with UIColor
            Circle()
                .fill(Color(UIColor.systemBackground))
                .frame(width: 50, height: 50)
            
            // Test 3: Fill with style
            Circle()
                .fill(style: FillStyle(antialiased: true))
                .foregroundColor(.blue)
                .frame(width: 50, height: 50)
        }
    }
}