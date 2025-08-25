import SwiftUI
import UIKit

struct ImageCropperView: View {
    let image: UIImage
    let targetHeight: CGFloat = 180 // Match actual header height
    @Binding var isPresented: Bool
    let onComplete: (UIImage, CGRect) -> Void // Image and visible rect
    
    @State private var verticalOffset: CGFloat = 0
    @State private var lastVerticalOffset: CGFloat = 0
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var isInitialized = false
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    // Show the image that can be dragged and scaled
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(y: verticalOffset)
                        .gesture(
                            SimultaneousGesture(
                                DragGesture()
                                    .onChanged { value in
                                        verticalOffset = lastVerticalOffset + value.translation.height
                                    }
                                    .onEnded { _ in
                                        lastVerticalOffset = verticalOffset
                                        constrainOffset(geometry: geometry)
                                    },
                                MagnificationGesture()
                                    .onChanged { value in
                                        let delta = value / lastScale
                                        lastScale = value
                                        scale = min(max(scale * delta, 0.5), 5.0) // Allow more zoom range
                                    }
                                    .onEnded { _ in
                                        lastScale = 1.0
                                        constrainOffset(geometry: geometry)
                                    }
                            )
                        )
                        .onAppear {
                            if !isInitialized {
                                initializePosition(geometry: geometry)
                                isInitialized = true
                            }
                        }
                    
                    // Dark overlay for areas outside crop region
                    VStack(spacing: 0) {
                        // Top overlay - smaller to position crop area near top like actual header
                        Rectangle()
                            .fill(Color.black.opacity(0.6))
                            .frame(height: 0) // No top spacing - header starts at very top
                        
                        // Transparent crop area with thicker border and text
                        ZStack {
                            // Border
                            Rectangle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(height: targetHeight)
                            
                            // Corner decorations
                            VStack {
                                HStack {
                                    // Top left corner
                                    Corner()
                                    Spacer()
                                    // Top right corner
                                    Corner()
                                        .rotationEffect(.degrees(90))
                                }
                                Spacer()
                                HStack {
                                    // Bottom left corner
                                    Corner()
                                        .rotationEffect(.degrees(-90))
                                    Spacer()
                                    // Bottom right corner
                                    Corner()
                                        .rotationEffect(.degrees(180))
                                }
                            }
                            .frame(height: targetHeight)
                            .padding(2)
                            
                            // Center text
                            VStack(spacing: 4) {
                                Text("Position Header")
                                    .scaledFont(size: 16, weight: .semibold)
                                    .foregroundColor(.white)
                                Text("Pinch to zoom • Drag to position")
                                    .scaledFont(size: 12)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.7))
                            )
                        }
                        .frame(height: targetHeight)
                        
                        // Bottom overlay
                        Rectangle()
                            .fill(Color.black.opacity(0.6))
                            .frame(maxHeight: .infinity)
                    }
                    .allowsHitTesting(false)
                }
            }
            .navigationTitle("Position Header Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        savePosition()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func initializePosition(geometry: GeometryProxy) {
        // Start with scale of 1.0 and center the image
        scale = 1.0
        verticalOffset = 0
        lastVerticalOffset = 0
    }
    
    private func constrainOffset(geometry: GeometryProxy) {
        withAnimation(.interactiveSpring()) {
            // Calculate the scaled height of the image when it fills the width
            let imageAspectRatio = image.size.width / image.size.height
            let scaledHeight = (geometry.size.width * scale) / imageAspectRatio
            
            // Crop area is at the very top
            let cropAreaTop: CGFloat = 0
            let cropAreaBottom = cropAreaTop + targetHeight
            
            // Maximum offset is when top of image reaches top of crop area
            let maxOffset = cropAreaTop
            // Minimum offset is when bottom of image reaches bottom of crop area
            let minOffset = cropAreaBottom - scaledHeight
            
            verticalOffset = min(maxOffset, max(minOffset, verticalOffset))
            lastVerticalOffset = verticalOffset
        }
    }
    
    private func savePosition() {
        // For now, just pass the whole image and a simple rect
        // We'll refine this once the image is displaying properly
        let visibleRect = CGRect(
            x: 0,
            y: 0,
            width: image.size.width,
            height: min(image.size.height, image.size.width * (targetHeight / UIScreen.main.bounds.width))
        )
        
        onComplete(image, visibleRect)
        isPresented = false
    }
}

// Corner decoration view
struct Corner: View {
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 20))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 20, y: 0))
        }
        .stroke(Color.white, lineWidth: 4)
        .frame(width: 20, height: 20)
    }
}
