//
//  ErrorBanner.swift
//  Momentum
//
//  Inline error banner for non-intrusive error display
//

import SwiftUI

// MARK: - Error Banner

struct ErrorBanner: View {
    let title: String
    let message: String
    let type: BannerType
    let showIcon: Bool
    var dismissAction: (() -> Void)?
    var retryAction: (() -> Void)?
    
    @State private var isVisible = true
    
    enum BannerType {
        case error
        case warning
        case info
        case success
        
        var color: Color {
            switch self {
            case .error:
                return .adaptiveRed
            case .warning:
                return .adaptiveOrange
            case .info:
                return .adaptiveBlue
            case .success:
                return .adaptiveGreen
            }
        }
        
        var icon: String {
            switch self {
            case .error:
                return "exclamationmark.circle.fill"
            case .warning:
                return "exclamationmark.triangle.fill"
            case .info:
                return "info.circle.fill"
            case .success:
                return "checkmark.circle.fill"
            }
        }
    }
    
    init(
        title: String,
        message: String,
        type: BannerType = .error,
        showIcon: Bool = true,
        dismissAction: (() -> Void)? = nil,
        retryAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.type = type
        self.showIcon = showIcon
        self.dismissAction = dismissAction
        self.retryAction = retryAction
    }
    
    var body: some View {
        if isVisible {
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                    // Icon
                    if showIcon {
                        Image(systemName: type.icon)
                            .font(.system(size: DesignSystem.IconSize.sm))
                            .foregroundColor(type.color)
                            .padding(.top, 2)
                    }
                    
                    // Content
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Actions
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        if let retryAction = retryAction {
                            Button(action: {
                                HapticFeedback.light.trigger()
                                retryAction()
                            }) {
                                Text("Retry")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(type.color)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // Dismiss button
                        if dismissAction != nil || retryAction == nil {
                            Button(action: {
                                HapticFeedback.light.trigger()
                                withAnimation(.easeOut(duration: 0.2)) {
                                    isVisible = false
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    dismissAction?()
                                }
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: DesignSystem.IconSize.xs))
                                    .foregroundColor(.secondary)
                                    .frame(width: 20, height: 20)
                                    .background(Circle().fill(Color.secondary.opacity(0.1)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .fill(type.color.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                .strokeBorder(type.color.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .transition(.asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            ))
            .onAppear {
                // Auto-dismiss info and success banners after delay
                if type == .info || type == .success {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        withAnimation {
                            isVisible = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            dismissAction?()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - View Extension

extension View {
    func errorBanner(
        error: Binding<Error?>,
        retryAction: (() -> Void)? = nil
    ) -> some View {
        self.overlay(alignment: .top) {
            if error.wrappedValue != nil {
                ErrorBanner(
                    title: "Error",
                    message: error.wrappedValue?.localizedDescription ?? "An error occurred",
                    type: .error,
                    dismissAction: {
                        error.wrappedValue = nil
                    },
                    retryAction: retryAction
                )
                .padding(.top, DesignSystem.Spacing.sm)
                .padding(.horizontal, DesignSystem.Spacing.md)
            }
        }
    }
    
    func infoBanner(
        title: String?,
        message: String?,
        isPresented: Binding<Bool>
    ) -> some View {
        self.overlay(alignment: .top) {
            if isPresented.wrappedValue, let title = title, let message = message {
                ErrorBanner(
                    title: title,
                    message: message,
                    type: .info,
                    dismissAction: {
                        isPresented.wrappedValue = false
                    }
                )
                .padding(.top, DesignSystem.Spacing.sm)
                .padding(.horizontal, DesignSystem.Spacing.md)
            }
        }
    }
}

// MARK: - Preview

#Preview("Error Banner") {
    VStack(spacing: 20) {
        ErrorBanner(
            title: "Connection Error",
            message: "Unable to connect to the server. Please check your internet connection.",
            type: .error,
            retryAction: {
                print("Retry")
            }
        )
        
        ErrorBanner(
            title: "Rate Limited",
            message: "Too many requests. Please wait a moment before trying again.",
            type: .warning
        )
        
        ErrorBanner(
            title: "Sync Complete",
            message: "Your data has been successfully synchronized.",
            type: .success
        )
        
        ErrorBanner(
            title: "New Update Available",
            message: "A new version of the app is available. Update now for the latest features.",
            type: .info,
            retryAction: {
                print("Update")
            }
        )
    }
    .padding()
}