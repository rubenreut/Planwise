import SwiftUI

struct CategoryManagementView: View {
    @EnvironmentObject var scheduleManager: ScheduleManager
    @Environment(\.dismiss) var dismiss
    @State private var showingAddCategory = false
    @State private var newCategoryName = ""
    @State private var selectedIcon = "folder.fill"
    @State private var selectedColor = "#007AFF"
    @State private var showingDeleteAlert = false
    @State private var categoryToDelete: Category?
    
    // Predefined colors
    let colors = [
        ("#007AFF", "Blue"),
        ("#34C759", "Green"),
        ("#FF3B30", "Red"),
        ("#FF9500", "Orange"),
        ("#AF52DE", "Purple"),
        ("#FFD60A", "Yellow"),
        ("#FF2D55", "Pink"),
        ("#5856D6", "Indigo"),
        ("#00C7BE", "Teal"),
        ("#32ADE6", "Light Blue"),
        ("#30B0C7", "Cyan"),
        ("#A2845E", "Brown")
    ]
    
    // Predefined icons
    let icons = [
        "folder.fill",
        "briefcase.fill",
        "person.fill",
        "heart.fill",
        "star.fill",
        "flag.fill",
        "tag.fill",
        "bookmark.fill",
        "calendar",
        "clock.fill",
        "bell.fill",
        "envelope.fill",
        "phone.fill",
        "message.fill",
        "bubble.left.fill",
        "video.fill",
        "mic.fill",
        "headphones",
        "music.note",
        "house.fill",
        "building.2.fill",
        "airplane",
        "car.fill",
        "tram.fill",
        "bicycle",
        "figure.walk",
        "figure.run",
        "sportscourt.fill",
        "dumbbell.fill",
        "heart.text.square.fill",
        "cross.case.fill",
        "pills.fill",
        "bed.double.fill",
        "fork.knife",
        "cup.and.saucer.fill",
        "cart.fill",
        "bag.fill",
        "creditcard.fill",
        "dollarsign.circle.fill",
        "book.fill",
        "graduation.cap.fill",
        "pencil",
        "paintbrush.fill",
        "camera.fill",
        "photo.fill",
        "tv.fill",
        "gamecontroller.fill",
        "gift.fill",
        "balloon.fill",
        "sparkles",
        "flame.fill",
        "bolt.fill",
        "cloud.fill",
        "sun.max.fill",
        "moon.fill",
        "leaf.fill",
        "pawprint.fill"
    ]
    
    var body: some View {
        NavigationView {
            List {
                Section("Categories") {
                    ForEach(scheduleManager.categories) { category in
                        CategoryRow(category: category) {
                            categoryToDelete = category
                            showingDeleteAlert = true
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        showingAddCategory = true
                    }) {
                        Label("Add New Category", systemImage: "plus.circle.fill")
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .navigationTitle("Manage Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAddCategory) {
                AddCategorySheet(
                    categoryName: $newCategoryName,
                    selectedIcon: $selectedIcon,
                    selectedColor: $selectedColor,
                    icons: icons,
                    colors: colors
                ) {
                    // Save action
                    createNewCategory()
                }
            }
            .alert("Delete Category", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let category = categoryToDelete {
                        deleteCategory(category)
                    }
                }
            } message: {
                Text("Are you sure you want to delete this category? Events using this category will have their category removed.")
            }
        }
    }
    
    private func createNewCategory() {
        let result = scheduleManager.createCategory(
            name: newCategoryName,
            icon: selectedIcon,
            colorHex: selectedColor
        )
        
        switch result {
        case .success:
            showingAddCategory = false
            // Reset form
            newCategoryName = ""
            selectedIcon = "folder.fill"
            selectedColor = "#007AFF"
        case .failure(let error): break
        }
    }
    
    private func deleteCategory(_ category: Category) {
        // For now, just deactivate the category instead of deleting
        category.isActive = false
        do {
            try PersistenceController.shared.container.viewContext.save()
        } catch {
        }
    }
}

// MARK: - Category Row
struct CategoryRow: View {
    let category: Category
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            // Icon
            Image(systemName: category.iconName ?? "folder.fill")
                .font(.system(size: 20))
                .foregroundColor(Color(hex: category.colorHex ?? "#007AFF"))
                .frame(width: 30)
            
            // Name
            Text(category.name ?? "Untitled")
                .font(.system(size: 16, weight: .medium))
            
            Spacer()
            
            // Default badge
            if category.isDefault {
                Text("Default")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
            }
            
            // Delete button (only for non-default categories)
            if !category.isDefault {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Category Sheet
struct AddCategorySheet: View {
    @Binding var categoryName: String
    @Binding var selectedIcon: String
    @Binding var selectedColor: String
    let icons: [String]
    let colors: [(String, String)]
    let onSave: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Category Details") {
                    TextField("Category Name", text: $categoryName)
                }
                
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 16) {
                        ForEach(icons, id: \.self) { icon in
                            Button(action: {
                                selectedIcon = icon
                            }) {
                                Image(systemName: icon)
                                    .font(.system(size: 20))
                                    .foregroundColor(selectedIcon == icon ? .white : Color(hex: selectedColor))
                                    .frame(width: 36, height: 36)
                                    .background(
                                        Circle()
                                            .fill(selectedIcon == icon ? Color(hex: selectedColor) : Color.clear)
                                            .overlay(
                                                Circle()
                                                    .strokeBorder(Color(hex: selectedColor), lineWidth: selectedIcon == icon ? 0 : 1)
                                            )
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 16) {
                        ForEach(colors, id: \.0) { color in
                            Button(action: {
                                selectedColor = color.0
                            }) {
                                Circle()
                                    .fill(Color(hex: color.0))
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(Color.primary, lineWidth: selectedColor == color.0 ? 2 : 0)
                                            .padding(2)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Preview
                Section("Preview") {
                    HStack {
                        Image(systemName: selectedIcon)
                            .font(.system(size: 24))
                            .foregroundColor(Color(hex: selectedColor))
                        
                        Text(categoryName.isEmpty ? "Category Name" : categoryName)
                            .font(.system(size: 18, weight: .medium))
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave()
                    }
                    .fontWeight(.semibold)
                    .disabled(categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}


#Preview {
    CategoryManagementView()
        .environmentObject(ScheduleManager.shared)
}