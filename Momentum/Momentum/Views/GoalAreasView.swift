//
//  GoalAreasView.swift
//  Momentum
//
//  Manage goal areas/categories
//

import SwiftUI

struct GoalAreasView: View {
    @StateObject private var areaManager = GoalAreaManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddArea = false
    @State private var editingArea: Category?
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(areaManager.categories) { category in
                        GoalAreaRow(category: category) {
                            editingArea = category
                        }
                    }
                } header: {
                    Text("Goal Areas")
                        .textCase(nil)
                        .font(.headline)
                } footer: {
                    Text("Goal areas help you organize your goals by life domains")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Manage Areas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddArea = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddArea) {
                AddGoalAreaView()
            }
            .sheet(item: $editingArea) { area in
                EditGoalAreaView(category: area)
            }
        }
    }
}

struct GoalAreaRow: View {
    let category: Category
    let onEdit: () -> Void
    @StateObject private var areaManager = GoalAreaManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: category.iconName ?? "folder.fill")
                .font(.system(size: 20))
                .foregroundColor(Color(hex: category.colorHex ?? "#007AFF"))
                .frame(width: 32, height: 32)
                .background(
                    Color(hex: category.colorHex ?? "#007AFF").opacity(0.1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Name
            Text(category.name ?? "")
                .scaledFont(size: 17)
                .foregroundColor(category.isActive ? .primary : .secondary)
            
            Spacer()
            
            // Active toggle
            Toggle("", isOn: Binding(
                get: { category.isActive },
                set: { _ in areaManager.toggleCategoryActive(category) }
            ))
            .labelsHidden()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit()
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if !category.isDefault {
                Button(role: .destructive) {
                    areaManager.deleteCategory(category)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}

struct AddGoalAreaView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var areaManager = GoalAreaManager.shared
    
    @State private var name = ""
    @State private var selectedIcon = "folder.fill"
    @State private var selectedColor = "#007AFF"
    
    private let icons = [
        "folder.fill", "star.fill", "flag.fill", "heart.fill",
        "bolt.fill", "flame.fill", "leaf.fill", "globe",
        "book.fill", "graduationcap.fill", "briefcase.fill",
        "dollarsign.circle.fill", "chart.line.uptrend.xyaxis",
        "person.fill", "person.2.fill", "house.fill",
        "airplane", "car.fill", "bicycle", "figure.walk",
        "figure.run", "sportscourt.fill", "dumbbell.fill",
        "brain.head.profile", "sparkles", "lightbulb.fill",
        "paintbrush.fill", "music.note", "camera.fill",
        "gamecontroller.fill", "tv.fill", "headphones"
    ]
    
    private let colors = [
        "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4",
        "#FECA57", "#FF9FF3", "#54A0FF", "#A29BFE",
        "#FD79A8", "#00D2D3", "#6C5CE7", "#FDCB6E",
        "#E17055", "#74B9FF", "#A29BFE", "#81ECEC"
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Area Details") {
                    TextField("Area Name", text: $name)
                        .textFieldStyle(.plain)
                }
                
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 16) {
                        ForEach(icons, id: \.self) { icon in
                            Button(action: { selectedIcon = icon }) {
                                Image(systemName: icon)
                                    .font(.system(size: 24))
                                    .foregroundColor(selectedIcon == icon ? .white : Color(hex: selectedColor))
                                    .frame(width: 44, height: 44)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedIcon == icon ? Color(hex: selectedColor) : Color(hex: selectedColor).opacity(0.1))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 16) {
                        ForEach(colors, id: \.self) { color in
                            Button(action: { selectedColor = color }) {
                                Circle()
                                    .fill(Color(hex: color))
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary, lineWidth: selectedColor == color ? 2 : 0)
                                            .padding(2)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("New Goal Area")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        areaManager.createCategory(
                            name: name,
                            iconName: selectedIcon,
                            colorHex: selectedColor
                        )
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

struct EditGoalAreaView: View {
    let category: Category
    @Environment(\.dismiss) private var dismiss
    @StateObject private var areaManager = GoalAreaManager.shared
    
    @State private var name: String
    @State private var selectedIcon: String
    @State private var selectedColor: String
    
    init(category: Category) {
        self.category = category
        _name = State(initialValue: category.name ?? "")
        _selectedIcon = State(initialValue: category.iconName ?? "folder.fill")
        _selectedColor = State(initialValue: category.colorHex ?? "#007AFF")
    }
    
    private let icons = [
        "folder.fill", "star.fill", "flag.fill", "heart.fill",
        "bolt.fill", "flame.fill", "leaf.fill", "globe",
        "book.fill", "graduationcap.fill", "briefcase.fill",
        "dollarsign.circle.fill", "chart.line.uptrend.xyaxis",
        "person.fill", "person.2.fill", "house.fill",
        "airplane", "car.fill", "bicycle", "figure.walk",
        "figure.run", "sportscourt.fill", "dumbbell.fill",
        "brain.head.profile", "sparkles", "lightbulb.fill",
        "paintbrush.fill", "music.note", "camera.fill",
        "gamecontroller.fill", "tv.fill", "headphones"
    ]
    
    private let colors = [
        "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4",
        "#FECA57", "#FF9FF3", "#54A0FF", "#A29BFE",
        "#FD79A8", "#00D2D3", "#6C5CE7", "#FDCB6E",
        "#E17055", "#74B9FF", "#A29BFE", "#81ECEC"
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Area Details") {
                    TextField("Area Name", text: $name)
                        .textFieldStyle(.plain)
                }
                
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 16) {
                        ForEach(icons, id: \.self) { icon in
                            Button(action: { selectedIcon = icon }) {
                                Image(systemName: icon)
                                    .font(.system(size: 24))
                                    .foregroundColor(selectedIcon == icon ? .white : Color(hex: selectedColor))
                                    .frame(width: 44, height: 44)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedIcon == icon ? Color(hex: selectedColor) : Color(hex: selectedColor).opacity(0.1))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 16) {
                        ForEach(colors, id: \.self) { color in
                            Button(action: { selectedColor = color }) {
                                Circle()
                                    .fill(Color(hex: color))
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary, lineWidth: selectedColor == color ? 2 : 0)
                                            .padding(2)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Edit Goal Area")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        areaManager.updateCategory(
                            category,
                            name: name,
                            iconName: selectedIcon,
                            colorHex: selectedColor
                        )
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}