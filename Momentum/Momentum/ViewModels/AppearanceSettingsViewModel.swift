import SwiftUI
import PhotosUI

/// Manages all appearance-related settings
@MainActor
class AppearanceSettingsViewModel: ObservableObject {
    // MARK: - Theme Settings
    @AppStorage("selectedTheme") var selectedTheme = 0
    @AppStorage("accentColor") var selectedAccentColor = "blue"
    @AppStorage("customAccentColorHex") var customAccentColorHex = ""
    @AppStorage("useAutoGradient") var useAutoGradient = true
    @AppStorage("manualGradientColor") var manualGradientColor = "blue"
    @AppStorage("customGradientColorHex") var customGradientColorHex = ""
    
    // MARK: - Font Settings
    @AppStorage("useSystemFont") var useSystemFont = true
    @AppStorage("appFontSize") var appFontSizeRaw = "regular"
    
    var appFontSize: AppFontSize {
        AppFontSize(rawValue: appFontSizeRaw) ?? .regular
    }
    
    // MARK: - App Icon
    @AppStorage("appIcon") var selectedAppIcon = "AppIcon"
    
    // MARK: - Header Image Settings
    @AppStorage("headerImageName") var headerImageName = ""
    @AppStorage("headerImageRectX") var headerImageRectX: Double = 0.0
    @AppStorage("headerImageRectY") var headerImageRectY: Double = 0.0
    @AppStorage("headerImageRectWidth") var headerImageRectWidth: Double = 0.0
    @AppStorage("headerImageRectHeight") var headerImageRectHeight: Double = 0.0
    
    // MARK: - Published Properties
    @Published var showingColorPicker = false
    @Published var tempCustomColor = Color.blue
    @Published var showingGradientColorPicker = false
    @Published var tempGradientColor = Color.blue
    @Published var showingImagePicker = false
    @Published var selectedImageItem: PhotosPickerItem? {
        didSet {
            if let item = selectedImageItem {
                loadImageDirectly(from: item)
            }
        }
    }
    @Published var showingFontSelector = false
    
    // MARK: - Constants
    let availableIcons = ["AppIcon", "AppIcon2", "AppIcon3", "AppIcon4", "AppIcon5"]
    let accentColors = ["blue", "purple", "pink", "red", "orange", "yellow", "green", "mint", "teal", "cyan", "indigo", "brown", "gray", "custom"]
    
    // MARK: - Methods
    
    func cycleAppIcon() {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        
        let currentIndex = availableIcons.firstIndex(of: selectedAppIcon) ?? 0
        let nextIndex = (currentIndex + 1) % availableIcons.count
        let nextIcon = availableIcons[nextIndex]
        
        let iconName: String? = nextIcon == "AppIcon" ? nil : nextIcon
        
        UIApplication.shared.setAlternateIconName(iconName) { error in
            if let error = error {
                print("Error changing app icon: \(error)")
            } else {
                DispatchQueue.main.async {
                    self.selectedAppIcon = nextIcon
                }
            }
        }
    }
    
    func updateAppearance() {
        // Force UI update
        NotificationCenter.default.post(
            name: Notification.Name("AppearanceChanged"),
            object: nil
        )
        
        // Update tint color
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.tintColor = UIColor(Color.fromAccentString(selectedAccentColor))
        }
    }
    
    func updateGradientColors() {
        // Force gradient update
        NotificationCenter.default.post(
            name: Notification.Name("GradientColorsChanged"),
            object: nil
        )
    }
    
    func saveCustomColor(_ color: Color) {
        // Convert Color to hex string and save
        selectedAccentColor = "custom"
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let hexString = String(format: "#%02X%02X%02X",
                             Int(red * 255),
                             Int(green * 255),
                             Int(blue * 255))
        
        UserDefaults.standard.set(hexString, forKey: "customAccentColorHex")
        updateAppearance()
    }
    
    func loadImageDirectly(from item: PhotosPickerItem) {
        _Concurrency.Task {
            guard let imageData = try? await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: imageData) else {
                print("Failed to load image from PhotosPicker")
                return
            }
            
            await MainActor.run {
                saveHeaderImage(uiImage)
            }
        }
    }
    
    func saveHeaderImage(_ image: UIImage) {
        // Delete old header image if exists
        deleteOldHeaderImage()
        
        // Generate unique filename
        let timestamp = Date().timeIntervalSince1970
        let filename = "header_\(Int(timestamp)).jpg"
        
        // Get documents directory
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Could not find documents directory")
            return
        }
        
        let imagePath = documentsPath.appendingPathComponent(filename)
        
        // Compress and save image
        if let imageData = image.jpegData(compressionQuality: 0.8) {
            do {
                try imageData.write(to: imagePath)
                
                // Save filename and default visible rect
                headerImageName = filename
                headerImageRectX = 0
                headerImageRectY = 0
                headerImageRectWidth = Double(image.size.width)
                headerImageRectHeight = Double(image.size.height)
                
                print("Header image saved successfully: \(filename)")
                
                // Post notification for UI update
                NotificationCenter.default.post(
                    name: Notification.Name("HeaderImageChanged"),
                    object: nil
                )
            } catch {
                print("Error saving header image: \(error)")
            }
        }
    }
    
    private func deleteOldHeaderImage() {
        guard !headerImageName.isEmpty else { return }
        
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        let imagePath = documentsPath.appendingPathComponent(headerImageName)
        
        try? FileManager.default.removeItem(at: imagePath)
    }
    
    static func loadHeaderImage() -> (image: UIImage, visibleRect: CGRect)? {
        let headerImageName = UserDefaults.standard.string(forKey: "headerImageName") ?? ""
        guard !headerImageName.isEmpty else { return nil }
        
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        
        let imagePath = documentsPath.appendingPathComponent(headerImageName)
        
        guard let image = UIImage(contentsOfFile: imagePath.path) else { return nil }
        
        let rectX = UserDefaults.standard.double(forKey: "headerImageRectX")
        let rectY = UserDefaults.standard.double(forKey: "headerImageRectY")
        let rectWidth = UserDefaults.standard.double(forKey: "headerImageRectWidth")
        let rectHeight = UserDefaults.standard.double(forKey: "headerImageRectHeight")
        
        let visibleRect = CGRect(x: rectX, y: rectY, width: rectWidth, height: rectHeight)
        
        return (image, visibleRect)
    }
}

// MARK: - Font Size Enum
enum AppFontSize: String, CaseIterable {
    case verySmall = "verySmall"
    case small = "small"
    case regular = "regular"
    case large = "large"
    
    var displayName: String {
        switch self {
        case .verySmall: return "Very Small"
        case .small: return "Small"
        case .regular: return "Regular"
        case .large: return "Large"
        }
    }
    
    var scale: CGFloat {
        switch self {
        case .verySmall: return 0.85
        case .small: return 0.92
        case .regular: return 1.0
        case .large: return 1.15
        }
    }
    
    var iconScale: CGFloat {
        switch self {
        case .verySmall: return 0.8
        case .small: return 0.9
        case .regular: return 1.0
        case .large: return 1.2
        }
    }
}