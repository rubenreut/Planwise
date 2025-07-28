//
//  ViewState.swift
//  Momentum
//
//  Unified view state management for consistent UI states
//

import SwiftUI

// MARK: - ViewState Enum

enum ViewState<T> {
    case loading
    case loaded(T)
    case error(Error)
    case empty
    
    // Computed properties for easy state checking
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
    
    var isLoaded: Bool {
        if case .loaded = self { return true }
        return false
    }
    
    var isError: Bool {
        if case .error = self { return true }
        return false
    }
    
    var isEmpty: Bool {
        if case .empty = self { return true }
        return false
    }
    
    // Get the loaded value if available
    var value: T? {
        if case .loaded(let value) = self { return value }
        return nil
    }
    
    // Get the error if available
    var error: Error? {
        if case .error(let error) = self { return error }
        return nil
    }
    
    // Map the loaded value to a new type
    func map<U>(_ transform: (T) -> U) -> ViewState<U> {
        switch self {
        case .loading:
            return .loading
        case .loaded(let value):
            return .loaded(transform(value))
        case .error(let error):
            return .error(error)
        case .empty:
            return .empty
        }
    }
}

// MARK: - ViewState Extensions

extension ViewState: Equatable where T: Equatable {
    static func == (lhs: ViewState<T>, rhs: ViewState<T>) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading), (.empty, .empty):
            return true
        case let (.loaded(a), .loaded(b)):
            return a == b
        case let (.error(a), .error(b)):
            return a.localizedDescription == b.localizedDescription
        default:
            return false
        }
    }
}

// MARK: - Observable ViewState Wrapper

@MainActor
class ViewStateObject<T>: ObservableObject {
    @Published var state: ViewState<T> = .loading
    
    init(state: ViewState<T> = .loading) {
        self.state = state
    }
    
    // Convenience methods
    func setLoading() {
        state = .loading
    }
    
    func setLoaded(_ value: T) {
        state = .loaded(value)
    }
    
    func setError(_ error: Error) {
        state = .error(error)
    }
    
    func setEmpty() {
        state = .empty
    }
    
    // Load data with error handling
    func load(_ operation: @escaping () async throws -> T) {
        _Concurrency.Task {
            state = .loading
            do {
                let value = try await operation()
                state = .loaded(value)
            } catch {
                state = .error(error)
            }
        }
    }
    
    // Load data with empty state handling
    func loadWithEmpty(_ operation: @escaping () async throws -> T?, emptyCheck: ((T?) -> Bool)? = nil) {
        _Concurrency.Task {
            state = .loading
            do {
                let value = try await operation()
                
                // Custom empty check or default nil check
                let isEmpty = emptyCheck?(value) ?? (value == nil)
                
                if isEmpty {
                    state = .empty
                } else if let value = value {
                    state = .loaded(value)
                } else {
                    state = .empty
                }
            } catch {
                state = .error(error)
            }
        }
    }
}

// MARK: - View Extension for ViewState

extension View {
    @ViewBuilder
    func viewState<T>(
        _ state: ViewState<T>,
        loadingView: @escaping () -> some View = { ProgressView() },
        errorView: @escaping (Error) -> some View = { error in
            ErrorView(error: error, retry: nil)
        },
        emptyView: @escaping () -> some View = { EmptyView() },
        @ViewBuilder content: @escaping (T) -> some View
    ) -> some View {
        switch state {
        case .loading:
            loadingView()
        case .loaded(let value):
            content(value)
        case .error(let error):
            errorView(error)
        case .empty:
            emptyView()
        }
    }
}

// MARK: - Common Error Types

enum DataError: LocalizedError {
    case fetchFailed
    case saveFailed
    case notFound
    case unauthorized
    case syncFailed
    
    var errorDescription: String? {
        switch self {
        case .fetchFailed:
            return "Failed to load data"
        case .saveFailed:
            return "Failed to save changes"
        case .notFound:
            return "Data not found"
        case .unauthorized:
            return "You don't have permission to access this"
        case .syncFailed:
            return "Failed to sync data"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .fetchFailed, .syncFailed:
            return "Please check your connection and try again."
        case .saveFailed:
            return "Your changes couldn't be saved. Please try again."
        case .notFound:
            return "The requested item doesn't exist."
        case .unauthorized:
            return "Please sign in or check your permissions."
        }
    }
}