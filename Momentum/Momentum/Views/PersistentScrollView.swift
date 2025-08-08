import SwiftUI
import UIKit

// UIKit-based ScrollView that maintains position
struct PersistentScrollView<Content: View>: UIViewRepresentable {
    @Binding var offset: CGFloat
    let content: Content
    let isScrollEnabled: Bool
    
    init(offset: Binding<CGFloat>, isScrollEnabled: Bool = true, @ViewBuilder content: () -> Content) {
        self._offset = offset
        self.isScrollEnabled = isScrollEnabled
        self.content = content()
    }
    
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bounces = false // Disable bounce to prevent overscroll
        scrollView.alwaysBounceVertical = false
        scrollView.alwaysBounceHorizontal = false
        
        let hostingController = UIHostingController(rootView: content)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        
        scrollView.addSubview(hostingController.view)
        
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: scrollView.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            hostingController.view.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
        
        context.coordinator.hostingController = hostingController
        context.coordinator.targetInitialOffset = offset
        context.coordinator.hasSetInitialOffset = false
        
        return scrollView
    }
    
    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        // Update content
        context.coordinator.hostingController?.rootView = content
        
        // Update scroll enabled state
        scrollView.isScrollEnabled = isScrollEnabled
        
        
        // Set initial offset once content is ready
        if !context.coordinator.hasSetInitialOffset {
            // Force layout first
            scrollView.layoutIfNeeded()
            
            // Wait for next run loop to ensure layout is complete
            DispatchQueue.main.async {
                // Double-check content size after layout
                scrollView.layoutIfNeeded()
                
                if scrollView.contentSize.height > 0 {
                    let safeOffset = min(max(0, self.offset), scrollView.contentSize.height - scrollView.bounds.height)
                    context.coordinator.isSettingInitialOffset = true
                    UIView.performWithoutAnimation {
                        scrollView.setContentOffset(CGPoint(x: 0, y: safeOffset), animated: false)
                    }
                    context.coordinator.hasSetInitialOffset = true
                    context.coordinator.isSettingInitialOffset = false
                }
            }
            return
        }
        
        // Only log significant updates
        if !scrollView.isDragging && !scrollView.isDecelerating && context.coordinator.hasSetInitialOffset {
            let currentOffset = scrollView.contentOffset.y
            let targetOffset = max(0, offset)
            
            // Only update if difference is significant (more than 10 points)
            if abs(currentOffset - targetOffset) > 10 {
                scrollView.setContentOffset(CGPoint(x: 0, y: targetOffset), animated: false)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: PersistentScrollView
        var hostingController: UIHostingController<Content>?
        var targetInitialOffset: CGFloat = 0
        var hasSetInitialOffset = false
        var isSettingInitialOffset = false
        
        init(_ parent: PersistentScrollView) {
            self.parent = parent
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            // Don't update while setting initial offset
            guard !isSettingInitialOffset else { return }
            
            // Ensure we never report negative offsets
            let newOffset = max(0, scrollView.contentOffset.y)
            
            // Only update if there's an actual change to prevent feedback loops
            if abs(parent.offset - newOffset) > 0.1 {
                // Don't log every scroll update, only significant jumps
                if abs(parent.offset - newOffset) > 100 {
                }
                parent.offset = newOffset
            }
        }
    }
}