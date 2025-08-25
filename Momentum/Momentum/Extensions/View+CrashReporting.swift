//
//  View+CrashReporting.swift
//  Momentum
//
//  Created by Claude on 01/07/2025.
//

import SwiftUI

extension View {
    
    /// Log when this view appears
    /// - Parameters:
    ///   - viewName: The name of the view
    ///   - additionalData: Any additional data to log
    func trackViewAppearance(_ viewName: String, additionalData: [String: Any]? = nil) -> some View {
        self.onAppear {
            CrashReporter.shared.logNavigation(to: viewName)
            
            if let data = additionalData {
                CrashReporter.shared.addBreadcrumb(
                    message: "View appeared: \(viewName)",
                    category: "ui",
                    level: .debug,
                    data: data
                )
            }
        }
    }
    
    /// Log a user action performed in this view
    /// - Parameters:
    ///   - action: The action name
    ///   - target: The target element
    ///   - perform: The action to perform
    func trackAction(_ action: String, target: String? = nil, perform: @escaping () -> Void) -> some View {
        self.onTapGesture {
            CrashReporter.shared.logUserAction(action, target: target)
            perform()
        }
    }
    
    /// Track errors that occur in this view
    /// - Parameters:
    ///   - error: The error binding to track
    ///   - context: Additional context about where the error occurred
    func trackError(_ error: Binding<Error?>, context: String) -> some View {
        self.onChange(of: error.wrappedValue != nil) { _, hasError in
            if hasError, let error = error.wrappedValue {
                CrashReporter.shared.logError(
                    error,
                    userInfo: ["context": context, "view": String(describing: type(of: self))]
                )
            }
        }
    }
    
    /// Track performance of an async operation
    /// - Parameters:
    ///   - operationName: Name of the operation
    ///   - operation: The async operation to track
    func trackAsyncOperation<T>(_ operationName: String, operation: @escaping () async throws -> T) -> some View {
        self.task {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            do {
                _ = try await operation()
                let elapsed = CFAbsoluteTimeGetCurrent() - startTime
                
                CrashReporter.shared.logPerformanceMetric(
                    name: operationName,
                    value: elapsed,
                    unit: "seconds"
                )
                
                if elapsed > 1.0 {
                    CrashReporter.shared.addBreadcrumb(
                        message: "Slow operation: \(operationName) took \(String(format: "%.2f", elapsed))s",
                        category: "performance",
                        level: .warning,
                        data: ["duration": elapsed, "operation": operationName]
                    )
                }
            } catch {
                let elapsed = CFAbsoluteTimeGetCurrent() - startTime
                
                CrashReporter.shared.logError(
                    error,
                    userInfo: [
                        "operation": operationName,
                        "duration": elapsed,
                        "context": "async_operation"
                    ]
                )
            }
        }
    }
}

// MARK: - Button Extensions

extension Button {
    
    /// Track when this button is tapped
    /// - Parameter action: The action name to log
    func trackTap(_ action: String) -> some View {
        self.simultaneousGesture(
            TapGesture().onEnded { _ in
                CrashReporter.shared.logUserAction(action, target: "button")
            }
        )
    }
}