//
//  SheetOptimizer.swift
//  Momentum
//
//  Optimizes sheet presentations for better performance
//

import SwiftUI

// Custom ViewModifier for optimized sheet presentation
struct OptimizedSheet<SheetContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    @ViewBuilder let content: () -> SheetContent
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                self.content()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(20)
                    .presentationBackground(.regularMaterial)
                    .interactiveDismissDisabled(false)
            }
    }
}

// Extension for easier usage
extension View {
    func optimizedSheet<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(OptimizedSheet(isPresented: isPresented, content: content))
    }
    
    func optimizedSheet<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        sheet(item: item) { item in
            content(item)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(20)
                .presentationBackground(.regularMaterial)
                .interactiveDismissDisabled(false)
        }
    }
}

// Use LazyView from Views/LazyView.swift instead of redefining it