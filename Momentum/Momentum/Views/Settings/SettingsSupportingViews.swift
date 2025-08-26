import SwiftUI
import MessageUI
import PhotosUI

// MARK: - Settings Section Component
struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: Content
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Header
            HStack(spacing: 8) {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(color)
                    )
                
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                Spacer()
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.bottom, DesignSystem.Spacing.xs)
            
            // Section Content
            VStack(spacing: 0) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .shadow(
                        color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.06),
                        radius: 8,
                        x: 0,
                        y: 2
                    )
            )
        }
    }
}

// MARK: - Settings Row Component
struct SettingsRow<TrailingContent: View>: View {
    let icon: String
    let title: String
    var value: String? = nil
    var valueColor: Color = .secondary
    var textColor: Color = .primary
    var showChevron: Bool = false
    var isLoading: Bool = false
    var action: (() -> Void)? = nil
    var trailingContent: (() -> TrailingContent)?
    
    @State private var isPressed = false
    @AppStorage("accentColor") private var selectedAccentColor = "blue"
    
    init(
        icon: String,
        title: String,
        value: String? = nil,
        valueColor: Color = .secondary,
        textColor: Color = .primary,
        showChevron: Bool = false,
        isLoading: Bool = false,
        action: (() -> Void)? = nil
    ) where TrailingContent == EmptyView {
        self.icon = icon
        self.title = title
        self.value = value
        self.valueColor = valueColor
        self.textColor = textColor
        self.showChevron = showChevron
        self.isLoading = isLoading
        self.action = action
        self.trailingContent = nil
    }
    
    init(
        icon: String,
        title: String,
        value: String? = nil,
        valueColor: Color = .secondary,
        textColor: Color = .primary,
        showChevron: Bool = false,
        isLoading: Bool = false,
        action: (() -> Void)? = nil,
        @ViewBuilder trailingContent: @escaping () -> TrailingContent
    ) {
        self.icon = icon
        self.title = title
        self.value = value
        self.valueColor = valueColor
        self.textColor = textColor
        self.showChevron = showChevron
        self.isLoading = isLoading
        self.action = action
        self.trailingContent = trailingContent
    }
    
    var body: some View {
        Button(action: {
            action?()
        }) {
            HStack(spacing: 12) {
                // Icon with background
                Circle()
                    .fill(textColor == .red ? Color.red.opacity(0.1) : Color.gray.opacity(0.08))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 16))
                            .foregroundColor(textColor == .primary ? Color.fromAccentString(selectedAccentColor) : textColor)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15))
                        .foregroundColor(textColor)
                    
                    if let value = value {
                        Text(value)
                            .font(.system(size: 13))
                            .foregroundColor(valueColor)
                    }
                }
                
                Spacer()
                
                if let trailing = trailingContent {
                    trailing()
                }
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
                
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .background(
                Color.primary.opacity(isPressed ? 0.05 : 0)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(action == nil)
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity,
            pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressing
                }
            },
            perform: {}
        )
    }
}

// MARK: - Sheet Views

struct ScreenTimeSettingsView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Text("Screen Time Settings")
                .navigationTitle("Screen Time")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}

struct NotificationSettingsDetailView: View {
    @ObservedObject var viewModel: NotificationSettingsViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Default Reminder") {
                    Picker("Reminder Time", selection: $viewModel.defaultReminderMinutes) {
                        ForEach(Array(viewModel.reminderOptions.keys.sorted()), id: \.self) { minutes in
                            Text(viewModel.reminderOptions[minutes] ?? "")
                                .tag(minutes)
                        }
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct ExportOptionsView: View {
    @ObservedObject var viewModel: DataManagementViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Button("Export as ICS") {
                    viewModel.exportData(format: DataManagementViewModel.ExportFormat.ics)
                    dismiss()
                }
                Button("Export as CSV") {
                    viewModel.exportData(format: DataManagementViewModel.ExportFormat.csv)
                    dismiss()
                }
                Button("Export as JSON") {
                    viewModel.exportData(format: DataManagementViewModel.ExportFormat.json)
                    dismiss()
                }
            }
            .navigationTitle("Export Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct AIContextSheet: View {
    @Binding var aiContextInfo: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextEditor(text: Binding(
                        get: { aiContextInfo },
                        set: { newValue in
                            if newValue.count <= 500 {
                                aiContextInfo = newValue
                            } else {
                                aiContextInfo = String(newValue.prefix(500))
                            }
                        }
                    ))
                    .frame(minHeight: 200)
                    .padding(DesignSystem.Spacing.xxs)
                } header: {
                    HStack {
                        Text("Personal Information")
                        Spacer()
                        Text("\(aiContextInfo.count)/500")
                            .font(.caption)
                            .foregroundColor(aiContextInfo.count >= 500 ? .red : .secondary)
                    }
                } footer: {
                    Text("This information helps the AI assistant understand your preferences and provide better suggestions.")
                        .font(.caption)
                }
            }
            .navigationTitle("AI Context")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

struct ProfileEditorSheet: View {
    @Binding var userName: String
    @Binding var userAvatar: String
    @Environment(\.dismiss) var dismiss
    @State private var tempName: String = ""
    @State private var tempAvatar: String = ""
    
    let avatarOptions = [
        "person.circle.fill",
        "person.crop.circle.fill",
        "face.smiling.fill",
        "star.circle.fill",
        "heart.circle.fill",
        "bolt.circle.fill",
        "flame.circle.fill",
        "leaf.circle.fill",
        "pawprint.circle.fill",
        "airplane.circle.fill",
        "bicycle.circle.fill",
        "car.circle.fill"
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Profile Name") {
                    TextField("Enter your name", text: $tempName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Section("Choose Avatar") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: DesignSystem.Spacing.md) {
                        ForEach(avatarOptions, id: \.self) { icon in
                            Button(action: {
                                tempAvatar = icon
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(tempAvatar == icon ? Color.blue : Color(UIColor.secondarySystemBackground))
                                        .frame(width: 60, height: 60)
                                    
                                    Image(systemName: icon)
                                        .font(.title2)
                                        .foregroundColor(tempAvatar == icon ? .white : .primary)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.vertical, DesignSystem.Spacing.xs)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        userName = tempName.isEmpty ? "Momentum User" : tempName
                        userAvatar = tempAvatar.isEmpty ? "person.circle.fill" : tempAvatar
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(tempName.isEmpty && tempAvatar.isEmpty)
                }
            }
        }
        .onAppear {
            tempName = userName
            tempAvatar = userAvatar
        }
    }
}

struct ColorPickerSheet: View {
    @State var selectedColor: Color
    let onSave: (Color) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var tempColor: Color = .blue
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Choose Your Accent Color")
                    .font(.headline)
                    .padding(.top)
                
                ColorPicker("Select Color", selection: $tempColor)
                    .labelsHidden()
                    .frame(width: 200, height: 200)
                    .scaleEffect(2.0)
                
                // Preview
                HStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Circle()
                            .fill(tempColor)
                            .frame(width: 60, height: 60)
                        Text("New Color")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(tempColor)
                        Text("Preview")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("Custom Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(tempColor)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            tempColor = selectedColor
        }
    }
}

// MARK: - UIKit Representables

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct MailView: UIViewControllerRepresentable {
    let recipients: [String]
    let subject: String
    
    func makeUIViewController(context: Context) -> UIViewController {
        guard MFMailComposeViewController.canSendMail() else {
            return UIViewController()
        }
        
        let composer = MFMailComposeViewController()
        composer.setToRecipients(recipients)
        composer.setSubject(subject)
        composer.mailComposeDelegate = context.coordinator
        return composer
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true)
        }
    }
}