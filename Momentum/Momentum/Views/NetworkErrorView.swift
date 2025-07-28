//
//  NetworkErrorView.swift
//  Momentum
//
//  Specialized view for network-related errors with recovery options
//

import SwiftUI
import Network

// MARK: - NetworkErrorView

struct NetworkErrorView: View {
    let error: NetworkError
    let retry: (() -> Void)?
    let goOffline: (() -> Void)?
    
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @State private var showTroubleshooting = false
    @State private var animateIcon = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.xl) {
                // Animated icon
                errorIcon
                    .scaleEffect(animateIcon ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: animateIcon)
                    .onAppear { animateIcon = true }
                
                // Error title and message
                VStack(spacing: DesignSystem.Spacing.md) {
                    Text(errorTitle)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                    
                    Text(errorMessage)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Connection status
                if !networkMonitor.isConnected {
                    connectionStatusView
                }
                
                // Action buttons
                actionButtons
                
                // Troubleshooting tips
                if showTroubleshooting {
                    troubleshootingView
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding()
        }
        .background(Color.adaptiveBackground)
    }
    
    // MARK: - Components
    
    private var errorIcon: some View {
        ZStack {
            Circle()
                .fill(Color.adaptiveOrange.opacity(0.1))
                .frame(width: 120, height: 120)
            
            Image(systemName: iconName)
                .font(.system(size: 60))
                .foregroundColor(.adaptiveOrange)
                .symbolEffect(.pulse, options: .repeating.speed(0.5))
        }
    }
    
    private var iconName: String {
        switch error {
        case .noConnection:
            return "wifi.exclamationmark"
        case .timeout:
            return "clock.badge.exclamationmark"
        case .serverError:
            return "server.rack"
        }
    }
    
    private var errorTitle: String {
        switch error {
        case .noConnection:
            return "No Internet Connection"
        case .timeout:
            return "Request Timed Out"
        case .serverError(let code):
            return "Server Error (\(code))"
        }
    }
    
    private var errorMessage: String {
        switch error {
        case .noConnection:
            return "Please check your internet connection and try again. You can also work offline with limited functionality."
        case .timeout:
            return "The request took too long to complete. This might be due to a slow connection or server issues."
        case .serverError(let code):
            if code >= 500 {
                return "Our servers are experiencing issues. Please try again later."
            } else if code == 429 {
                return "Too many requests. Please wait a moment before trying again."
            } else {
                return "Something went wrong on our end. Please try again."
            }
        }
    }
    
    private var connectionStatusView: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        .scaleEffect(animateIcon ? 2 : 1)
                        .opacity(animateIcon ? 0 : 1)
                        .animation(.easeOut(duration: 1.5).repeatForever(autoreverses: false), value: animateIcon)
                )
            
            Text("Currently Offline")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(Color.red.opacity(0.1))
        .clipShape(Capsule())
    }
    
    private var actionButtons: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            // Primary retry button
            if let retry = retry {
                Button(action: {
                    HapticFeedback.light.trigger()
                    retry()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Try Again")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.adaptiveBlue)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Secondary actions
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Go offline button
                if let goOffline = goOffline {
                    Button(action: {
                        HapticFeedback.light.trigger()
                        goOffline()
                    }) {
                        HStack {
                            Image(systemName: "icloud.slash")
                            Text("Work Offline")
                        }
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.secondary.opacity(0.1))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Troubleshooting button
                Button(action: {
                    withAnimation {
                        showTroubleshooting.toggle()
                    }
                }) {
                    HStack {
                        Image(systemName: showTroubleshooting ? "chevron.up" : "questionmark.circle")
                        Text("Help")
                    }
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.secondary.opacity(0.1))
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal)
    }
    
    private var troubleshootingView: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Troubleshooting Tips")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                TroubleshootingTip(
                    icon: "wifi",
                    title: "Check Wi-Fi",
                    description: "Make sure Wi-Fi is turned on and you're connected to a network"
                )
                
                TroubleshootingTip(
                    icon: "antenna.radiowaves.left.and.right",
                    title: "Check Cellular",
                    description: "If using cellular data, ensure it's enabled for this app"
                )
                
                TroubleshootingTip(
                    icon: "airplane",
                    title: "Airplane Mode",
                    description: "Make sure Airplane Mode is turned off"
                )
                
                TroubleshootingTip(
                    icon: "arrow.clockwise",
                    title: "Restart App",
                    description: "Try closing and reopening the app"
                )
                
                if case .serverError = error {
                    TroubleshootingTip(
                        icon: "clock",
                        title: "Wait & Retry",
                        description: "Server issues are usually temporary. Try again in a few minutes"
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.secondary.opacity(0.05))
        )
    }
}

// MARK: - Troubleshooting Tip Component

private struct TroubleshootingTip: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.accentColor)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
}

// MARK: - Network Error Type Extension

extension NetworkError {
    var isRetryable: Bool {
        switch self {
        case .noConnection, .timeout:
            return true
        case .serverError(let code):
            // Retry on 5xx errors and rate limiting
            return code >= 500 || code == 429
        }
    }
    
    var suggestedRetryDelay: TimeInterval? {
        switch self {
        case .serverError(429): // Rate limited
            return 60 // Wait 1 minute
        case .serverError(let code) where code >= 500:
            return 30 // Wait 30 seconds for server errors
        default:
            return nil
        }
    }
}

// MARK: - View Extension

extension View {
    func networkErrorAlert(
        error: Binding<NetworkError?>,
        retry: (() -> Void)? = nil,
        goOffline: (() -> Void)? = nil
    ) -> some View {
        self.fullScreenCover(item: error) { networkError in
            NetworkErrorView(
                error: networkError,
                retry: retry,
                goOffline: goOffline
            )
        }
    }
}

// MARK: - Preview

#Preview("No Connection") {
    NetworkErrorView(
        error: .noConnection,
        retry: { print("Retry") },
        goOffline: { print("Go offline") }
    )
}

#Preview("Timeout") {
    NetworkErrorView(
        error: .timeout,
        retry: { print("Retry") },
        goOffline: nil
    )
}

#Preview("Server Error") {
    NetworkErrorView(
        error: .serverError(503),
        retry: { print("Retry") },
        goOffline: nil
    )
}