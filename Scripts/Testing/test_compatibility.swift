import SwiftUI

// Test iOS 17 compatible approaches
struct TestCompatibility: View {
    var body: some View {
        VStack {
            // Approach 1: Using overlay with cornerRadius
            Color.clear
                .frame(width: 50, height: 50)
                .overlay(
                    Color.red
                        .cornerRadius(10)
                )
            
            // Approach 2: Using background with cornerRadius  
            Color.clear
                .frame(width: 50, height: 50)
                .background(
                    Color.blue
                        .cornerRadius(10)
                )
            
            // Approach 3: Using ZStack
            ZStack {
                Color.green
                    .cornerRadius(10)
            }
            .frame(width: 50, height: 50)
            
            // Approach 4: For circles specifically
            Color.orange
                .frame(width: 50, height: 50)
                .mask(Circle())
        }
    }
}