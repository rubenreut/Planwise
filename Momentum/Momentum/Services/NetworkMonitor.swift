import Foundation
import Network
import SwiftUI

// Type alias to avoid naming conflict with Core Data Task entity

@MainActor
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isConnected = true
    @Published var connectionType = ConnectionType.unknown
    @Published var isExpensive = false
    
    enum ConnectionType {
        case wifi
        case cellular
        case wired
        case unknown
    }
    
    private init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            AsyncTask { @MainActor in
                self?.isConnected = path.status == .satisfied
                self?.isExpensive = path.isExpensive
                
                if path.usesInterfaceType(.wifi) {
                    self?.connectionType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self?.connectionType = .cellular
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self?.connectionType = .wired
                } else {
                    self?.connectionType = .unknown
                }
                
                // Log network changes
                CrashReporter.shared.addBreadcrumb(
                    message: "Network status changed",
                    category: "network",
                    level: .info,
                    data: [
                        "connected": path.status == .satisfied,
                        "type": self?.connectionType.description ?? "unknown",
                        "expensive": path.isExpensive
                    ]
                )
            }
        }
        
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
}

extension NetworkMonitor.ConnectionType {
    var description: String {
        switch self {
        case .wifi: return "WiFi"
        case .cellular: return "Cellular"
        case .wired: return "Wired"
        case .unknown: return "Unknown"
        }
    }
}

// MARK: - Network Error Alert Modifier

struct NetworkErrorAlert: ViewModifier {
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    @State private var showingOfflineAlert = false
    
    func body(content: Content) -> some View {
        content
            .onChange(of: networkMonitor.isConnected) { isConnected in
                if !isConnected && !showingOfflineAlert {
                    showingOfflineAlert = true
                }
            }
            .alert("No Internet Connection", isPresented: $showingOfflineAlert) {
                Button("OK") {
                    showingOfflineAlert = false
                }
            } message: {
                Text("Please check your internet connection and try again.")
            }
    }
}

extension View {
    func networkErrorAlert() -> some View {
        modifier(NetworkErrorAlert())
    }
}

// MARK: - Offline Banner

struct OfflineBanner: View {
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    
    var body: some View {
        if !networkMonitor.isConnected {
            HStack {
                Image(systemName: "wifi.slash")
                    .foregroundColor(.white)
                Text("No Internet Connection")
                    .font(.caption)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.red)
            .cornerRadius(20)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.easeInOut, value: networkMonitor.isConnected)
        }
    }
}