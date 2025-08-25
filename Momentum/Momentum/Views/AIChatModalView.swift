//
//  AIChatModalView.swift
//  Momentum
//
//  Modal wrapper for AI Chat view
//

import SwiftUI

struct AIChatModalView: View {
    @Binding var isPresented: Bool
    @StateObject private var viewModel = ChatViewModel()
    
    var body: some View {
        NavigationStack {
            AIChatView()
                .navigationTitle("AI Assistant")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            isPresented = false
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            isPresented = false
                        }
                        .fontWeight(.semibold)
                    }
                }
        }
    }
}

#Preview {
    AIChatModalView(isPresented: .constant(true))
}