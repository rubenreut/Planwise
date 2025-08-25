//
//  ErrorView.swift
//  Momentum
//
//  Comprehensive error handling with user-friendly messages and recovery options
//

import SwiftUI

struct ErrorView: View {
    let error: Error
    let retry: (() -> Void)?
    let dismiss: (() -> Void)?
    let additionalActions: [ErrorAction]
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var showDetails = false
    @State private var animateIcon = false
    
    init(
        error: Error,
        retry: (() -> Void)? = nil,
        dismiss: (() -> Void)? = nil,
        additionalActions: [ErrorAction] = []
    ) {
        self.error = error
        self.retry = retry
        self.dismiss = dismiss
        self.additionalActions = additionalActions
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.xl) {
                // Error icon with animation
                ZStack {
                    Circle()
                        .fill(errorColor.opacity(0.1))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: errorIcon)
                        .font(.system(size: 50))
                        .foregroundColor(errorColor)
                        .symbolEffect(.bounce, value: animateIcon)
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        animateIcon = true
                    }
                }
                
                // Error title and message
                VStack(spacing: DesignSystem.Spacing.md) {
                    Text(errorTitle)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                    
                    Text(errorMessage)
                        .scaledFont(size: 17)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Recovery suggestion if available
                    if let suggestion = recoverySuggestion {
                        Text(suggestion)
                            .font(.callout)
                            .foregroundColor(.accentColor)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .padding(.top, DesignSystem.Spacing.xs)
                    }
                }
                
                // Action buttons
                VStack(spacing: DesignSystem.Spacing.sm) {
                    // Primary retry button
                    if let retry = retry {
                        MomentumButton("Try Again", icon: "arrow.clockwise", style: .primary) {
                            HapticFeedback.light.trigger()
                            retry()
                        }
                    }
                    
                    // Additional actions
                    ForEach(additionalActions) { action in
                        MomentumButton(
                            action.title,
                            icon: action.icon,
                            style: action.isDestructive ? .destructive : .secondary
                        ) {
                            HapticFeedback.light.trigger()
                            action.handler()
                        }
                    }
                    
                    // Dismiss button
                    if dismiss != nil || retry == nil {
                        MomentumButton("Dismiss", style: .tertiary) {
                            HapticFeedback.light.trigger()
                            dismiss?() ?? ({})()
                        }
                    }
                }
                .padding(.horizontal)
                
                // Error details (for debugging)
                if !isProductionBuild {
                    errorDetailsView
                }
            }
            .padding(.vertical)
        }
        .background(Color.adaptiveBackground)
    }
    
    private var errorIcon: String {
        switch error {
        case is NetworkError:
            return "wifi.exclamationmark"
        case is ValidationError:
            return "exclamationmark.triangle"
        case is DataError:
            return "externaldrive.badge.exclamationmark"
        case is URLError:
            return "link.badge.plus"
        case is CocoaError:
            return "doc.badge.gearshape"
        default:
            return "exclamationmark.circle"
        }
    }
    
    private var errorColor: Color {
        switch error {
        case is NetworkError:
            return .adaptiveOrange
        case is ValidationError:
            return .adaptiveRed
        case is DataError:
            return .adaptivePurple
        default:
            return .adaptiveRed
        }
    }
    
    private var errorTitle: String {
        switch error {
        case is NetworkError:
            return "Connection Problem"
        case is ValidationError:
            return "Invalid Information"
        case is DataError:
            return "Data Error"
        case is URLError:
            return "Network Issue"
        case is CocoaError:
            return "System Error"
        case let nsError as NSError where nsError.domain == "OpenAI":
            return "AI Service Error"
        default:
            return "Something Went Wrong"
        }
    }
    
    private var errorMessage: String {
        switch error {
        case NetworkError.noConnection:
            return "Please check your internet connection and try again."
        case NetworkError.timeout:
            return "The request took too long. Please try again."
        case NetworkError.serverError(let code):
            return serverErrorMessage(for: code)
        case ValidationError.invalidInput:
            return "Please check your input and try again."
        case ValidationError.missingRequired(let field):
            return "Please provide a value for \(field)."
        case DataError.fetchFailed:
            return "We couldn't load your data. Please try again."
        case DataError.saveFailed:
            return "Your changes couldn't be saved. Please try again."
        case DataError.notFound:
            return "The requested item doesn't exist."
        case DataError.unauthorized:
            return "You don't have permission to access this."
        case DataError.syncFailed:
            return "We couldn't sync your data. Changes will be saved locally."
        case let urlError as URLError:
            return urlErrorMessage(for: urlError)
        case let nsError as NSError where nsError.domain == "OpenAI":
            return openAIErrorMessage(for: nsError)
        default:
            // Try to get localized description or fallback
            return error.localizedDescription.isEmpty
                ? "We're having trouble completing your request. Please try again."
                : error.localizedDescription
        }
    }
    
    private var recoverySuggestion: String? {
        if let error = error as? DataError {
            return error.recoverySuggestion
        }
        
        switch error {
        case is NetworkError:
            return "Check your connection or try again later."
        case is ValidationError:
            return "Review your input and make corrections."
        default:
            return nil
        }
    }
    
    private func serverErrorMessage(for code: Int) -> String {
        switch code {
        case 400:
            return "The request was invalid. Please check your input."
        case 401:
            return "Authentication failed. Please sign in again."
        case 403:
            return "You don't have permission to perform this action."
        case 404:
            return "The requested resource was not found."
        case 429:
            return "Too many requests. Please wait a moment and try again."
        case 500...599:
            return "Our servers are experiencing issues. Please try again later."
        default:
            return "Server error (\(code)). Please try again."
        }
    }
    
    private func urlErrorMessage(for error: URLError) -> String {
        switch error.code {
        case .notConnectedToInternet:
            return "No internet connection available."
        case .timedOut:
            return "The connection timed out. Please try again."
        case .cannotFindHost:
            return "Cannot reach the server. Please check your connection."
        case .networkConnectionLost:
            return "Network connection was lost. Please try again."
        case .dnsLookupFailed:
            return "Cannot resolve server address. Please try again later."
        default:
            return "Network error. Please check your connection."
        }
    }
    
    private func openAIErrorMessage(for error: NSError) -> String {
        if let message = error.userInfo["message"] as? String {
            return message
        }
        
        switch error.code {
        case 429:
            return "AI service rate limit reached. Please try again later."
        case 401:
            return "AI service authentication failed."
        case 500...599:
            return "AI service is temporarily unavailable."
        default:
            return "AI service error. Please try again."
        }
    }
    
    private var errorDetailsView: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Button(action: {
                withAnimation {
                    showDetails.toggle()
                }
            }) {
                HStack {
                    Text("Error Details")
                        .font(.caption)
                    Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
            .buttonStyle(GhostButtonStyle())
            
            if showDetails {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Type: \(String(describing: type(of: error)))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("Description: \(error.localizedDescription)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if let nsError = error as NSError? {
                        Text("Domain: \(nsError.domain)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("Code: \(nsError.code)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.1))
                )
            }
        }
        .padding(.horizontal)
    }
    
    private var isProductionBuild: Bool {
        #if DEBUG
        return false
        #else
        return true
        #endif
    }
}

// MARK: - Error Action

struct ErrorAction: Identifiable {
    let id = UUID()
    let title: String
    let icon: String?
    let isDestructive: Bool
    let handler: () -> Void
    
    init(
        title: String,
        icon: String? = nil,
        isDestructive: Bool = false,
        handler: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isDestructive = isDestructive
        self.handler = handler
    }
}

// MARK: - Error Types

enum NetworkError: LocalizedError, Identifiable {
    case noConnection
    case timeout
    case serverError(Int)
    
    var id: String {
        switch self {
        case .noConnection:
            return "noConnection"
        case .timeout:
            return "timeout"
        case .serverError(let code):
            return "serverError_\(code)"
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .noConnection:
            return "No internet connection"
        case .timeout:
            return "Request timed out"
        case .serverError(let code):
            return "Server error (\(code))"
        }
    }
}

enum ValidationError: LocalizedError {
    case invalidInput
    case missingRequired(String)
    case outOfRange(String, min: Any?, max: Any?)
    case invalidFormat(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidInput:
            return "Invalid input"
        case .missingRequired(let field):
            return "Missing required field: \(field)"
        case .outOfRange(let field, let min, let max):
            if let min = min, let max = max {
                return "\(field) must be between \(min) and \(max)"
            } else if let min = min {
                return "\(field) must be at least \(min)"
            } else if let max = max {
                return "\(field) must be at most \(max)"
            } else {
                return "\(field) is out of range"
            }
        case .invalidFormat(let field):
            return "Invalid format for \(field)"
        }
    }
}

// MARK: - View Extensions

extension View {
    // Alert-based error handling
    func errorAlert(error: Binding<Error?>, retry: (() -> Void)? = nil) -> some View {
        self.alert(
            "Error",
            isPresented: .constant(error.wrappedValue != nil)
        ) {
            if let retry = retry {
                Button("Try Again", action: retry)
            }
            Button("OK", role: .cancel) {
                error.wrappedValue = nil
            }
        } message: {
            if let errorValue = error.wrappedValue {
                Text(ErrorView.friendlyMessage(for: errorValue))
            } else {
                Text("An error occurred")
            }
        }
    }
    
    // Full-screen error handling
    func fullScreenError(
        error: Binding<Error?>,
        retry: (() -> Void)? = nil,
        dismiss: (() -> Void)? = nil,
        additionalActions: [ErrorAction] = []
    ) -> some View {
        self.fullScreenCover(isPresented: .constant(error.wrappedValue != nil)) {
            if let errorValue = error.wrappedValue {
                ErrorView(
                    error: errorValue,
                    retry: retry,
                    dismiss: {
                        dismiss?()
                        error.wrappedValue = nil
                    },
                    additionalActions: additionalActions
                )
            }
        }
    }
    
    // Overlay-based error handling
    func errorOverlay(
        error: Error?,
        retry: (() -> Void)? = nil
    ) -> some View {
        self.overlay {
            if let error = error {
                ErrorView(error: error, retry: retry)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
            }
        }
    }
}

extension ErrorView {
    static func friendlyMessage(for error: Error) -> String {
        let errorView = ErrorView(error: error)
        return errorView.errorMessage
    }
    
    static func icon(for error: Error) -> String {
        let errorView = ErrorView(error: error)
        return errorView.errorIcon
    }
    
    static func color(for error: Error) -> Color {
        let errorView = ErrorView(error: error)
        return errorView.errorColor
    }
}

// MARK: - Error Recovery Protocol

protocol RecoverableError: Error {
    var recoveryOptions: [ErrorAction] { get }
}


extension Binding where Value == Error? {
    init<T>(_ base: Binding<T?>) where T: Error {
        self.init(
            get: { base.wrappedValue },
            set: { base.wrappedValue = $0 as? T }
        )
    }
}

// MARK: - Previews

#Preview("Network Error") {
    ErrorView(
        error: NetworkError.noConnection,
        retry: {
            print("Retry tapped")
        }
    )
}

#Preview("Validation Error") {
    ErrorView(
        error: ValidationError.missingRequired("Title"),
        retry: {
            print("Retry tapped")
        }
    )
}

#Preview("Data Error") {
    ErrorView(
        error: DataError.syncFailed,
        retry: {
            print("Retry tapped")
        },
        additionalActions: [
            ErrorAction(
                title: "Work Offline",
                icon: "icloud.slash",
                handler: { print("Work offline") }
            ),
            ErrorAction(
                title: "Contact Support",
                icon: "questionmark.circle",
                handler: { print("Contact support") }
            )
        ]
    )
}

#Preview("Server Error") {
    ErrorView(
        error: NetworkError.serverError(503),
        retry: {
            print("Retry tapped")
        }
    )
}