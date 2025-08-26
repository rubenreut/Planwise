import SwiftUI

// Test to verify Shape API behavior
struct TestShapeAPI: View {
    var body: some View {
        VStack {
            // Test 1: Direct fill on shape
            Circle()
                .fill(Color.red)
                .frame(width: 50, height: 50)
            
            // Test 2: Using cornerRadius
            Color.blue
                .frame(width: 50, height: 50)
                .cornerRadius(10)
            
            // Test 3: Using clipShape
            Color.green
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            
            // Test 4: RoundedRectangle with cornerRadius
            Color.orange
                .frame(width: 50, height: 50)
                .cornerRadius(10)
        }
    }
}