import SwiftUI
import LocalAuthentication

/// Manages privacy and security settings
@MainActor
class PrivacySettingsViewModel: ObservableObject {
    // MARK: - Privacy Settings
    @AppStorage("useFaceID") var useFaceID = false
    @AppStorage("hideNotificationContent") var hideNotificationContent = false
    @AppStorage("enableAnalytics") var enableAnalytics = true
    
    // MARK: - Published Properties
    @Published var biometricType: LABiometryType = .none
    @Published var isBiometricAvailable = false
    
    init() {
        checkBiometricAvailability()
    }
    
    // MARK: - Methods
    
    func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?
        
        isBiometricAvailable = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        biometricType = context.biometryType
    }
    
    func toggleBiometricAuth() {
        if !useFaceID {
            // Request biometric authentication to enable
            authenticateWithBiometrics { success in
                if success {
                    self.useFaceID = true
                }
            }
        } else {
            // Disable without authentication
            useFaceID = false
        }
    }
    
    func authenticateWithBiometrics(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        let reason = "Authenticate to access Momentum"
        
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                completion(success)
                if let error = error {
                    print("Biometric authentication error: \(error)")
                }
            }
        }
    }
    
    func openPrivacySettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    var biometricIconName: String {
        switch biometricType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .opticID:
            return "opticid"
        case .none:
            return "lock.shield"
        @unknown default:
            return "lock.shield"
        }
    }
    
    var biometricDisplayName: String {
        switch biometricType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        case .none:
            return "Biometric Authentication"
        @unknown default:
            return "Biometric Authentication"
        }
    }
}