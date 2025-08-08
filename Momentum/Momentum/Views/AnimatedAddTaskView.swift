//
//  AnimatedAddTaskView.swift
//  Momentum
//
//  Custom animated presentation wrapper for AddTaskView
//

import SwiftUI

struct AnimatedAddTaskView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        AddTaskView()
    }
}