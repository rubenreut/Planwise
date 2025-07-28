//
//  ViewStateModifier.swift
//  Momentum
//
//  SwiftUI view modifier for elegant view state management
//

import SwiftUI

typealias ConcurrencyTask = _Concurrency.Task

// MARK: - ViewStateModifier

struct ViewStateModifier<T>: ViewModifier {
    let state: ViewState<T>
    let loadingView: AnyView?
    let errorView: ((Error) -> AnyView)?
    let emptyView: AnyView?
    let retryAction: (() -> Void)?
    
    func body(content: Content) -> some View {
        ZStack {
            switch state {
            case .loading:
                if let loadingView = loadingView {
                    loadingView
                } else {
                    LoadingView()
                }
                
            case .loaded:
                content
                
            case .error(let error):
                if let errorView = errorView {
                    errorView(error)
                } else {
                    ErrorView(error: error, retry: retryAction)
                }
                
            case .empty:
                if let emptyView = emptyView {
                    emptyView
                } else {
                    EmptyStateView(config: EmptyStateConfig(
                        illustration: AnyView(Image(systemName: "tray")),
                        title: "No Data",
                        subtitle: "There's nothing to display at the moment"
                    ))
                }
            }
        }
        .animation(.default, value: state.isLoading)
    }
}

// MARK: - View Extension

extension View {
    func viewStateModifier<T, LoadingContent: View, ErrorContent: View, EmptyContent: View>(
        state: ViewState<T>,
        @ViewBuilder loadingView: @escaping () -> LoadingContent,
        @ViewBuilder errorView: @escaping (Error) -> ErrorContent,
        @ViewBuilder emptyView: @escaping () -> EmptyContent,
        retryAction: (() -> Void)? = nil
    ) -> some View {
        self.modifier(
            ViewStateModifier(
                state: state,
                loadingView: AnyView(loadingView()),
                errorView: { error in AnyView(errorView(error)) },
                emptyView: AnyView(emptyView()),
                retryAction: retryAction
            )
        )
    }
}

// MARK: - Async View State Modifier

struct AsyncViewStateModifier<T>: ViewModifier {
    @StateObject private var viewState = ViewStateObject<T>()
    let loadData: () async throws -> T
    let emptyCheck: ((T) -> Bool)?
    let loadingView: AnyView?
    let errorView: ((Error) -> AnyView)?
    let emptyView: AnyView?
    
    func body(content: Content) -> some View {
        content
            .modifier(
                ViewStateModifier(
                    state: viewState.state,
                    loadingView: loadingView,
                    errorView: errorView,
                    emptyView: emptyView,
                    retryAction: {
                        ConcurrencyTask {
                            await loadDataAsync()
                        }
                    }
                )
            )
            .task {
                await loadDataAsync()
            }
    }
    
    @MainActor
    private func loadDataAsync() async {
        viewState.state = .loading
        do {
            let data = try await loadData()
            if let emptyCheck = emptyCheck, emptyCheck(data) {
                viewState.state = .empty
            } else {
                viewState.state = .loaded(data)
            }
        } catch {
            viewState.state = .error(error)
        }
    }
}

extension View {
    func asyncViewState<T>(
        loadData: @escaping () async throws -> T,
        emptyCheck: ((T) -> Bool)? = nil,
        loadingView: (() -> some View)? = nil,
        errorView: ((Error) -> some View)? = nil,
        emptyView: (() -> some View)? = nil
    ) -> some View {
        self.modifier(
            AsyncViewStateModifier(
                loadData: loadData,
                emptyCheck: emptyCheck,
                loadingView: loadingView.map { AnyView($0()) },
                errorView: errorView.map { errorViewBuilder in
                    { error in AnyView(errorViewBuilder(error)) }
                },
                emptyView: emptyView.map { AnyView($0()) }
            )
        )
    }
}

// MARK: - Refreshable View State Modifier

struct RefreshableViewStateModifier<T>: ViewModifier {
    @Binding var state: ViewState<T>
    let refreshAction: () async -> Void
    
    func body(content: Content) -> some View {
        content
            .refreshable {
                await refreshAction()
            }
            .overlay(alignment: .top) {
                if state.isLoading {
                    refreshIndicator
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                }
            }
    }
    
    private var refreshIndicator: some View {
        HStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(0.8)
            Text("Refreshing...")
                .font(.caption)
                .foregroundColor(.white)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(
            Capsule()
                .fill(Color.accentColor)
                .shadow(radius: 4)
        )
        .padding(.top, DesignSystem.Spacing.md)
    }
}

extension View {
    func refreshableViewState<T>(
        state: Binding<ViewState<T>>,
        refreshAction: @escaping () async -> Void
    ) -> some View {
        self.modifier(
            RefreshableViewStateModifier(
                state: state,
                refreshAction: refreshAction
            )
        )
    }
}

// MARK: - Skeleton Loading Modifier

struct SkeletonLoadingModifier: ViewModifier {
    let isLoading: Bool
    let skeletonType: SkeletonType
    
    func body(content: Content) -> some View {
        ZStack {
            if isLoading {
                SkeletonLoader(type: skeletonType)
                    .transition(.opacity)
            } else {
                content
                    .transition(.opacity)
            }
        }
        .animation(.default, value: isLoading)
    }
}

extension View {
    func skeletonLoading(
        isLoading: Bool,
        type: SkeletonType = .custom([])
    ) -> some View {
        self.modifier(
            SkeletonLoadingModifier(
                isLoading: isLoading,
                skeletonType: type
            )
        )
    }
}

// MARK: - Error Retry Modifier

struct ErrorRetryModifier: ViewModifier {
    @Binding var error: Error?
    let retryAction: () -> Void
    let position: ErrorPosition
    
    enum ErrorPosition {
        case alert
        case banner
        case fullScreen
        case overlay
    }
    
    func body(content: Content) -> some View {
        content
            .onChange(of: error != nil) { _, hasError in
                if hasError {
                    HapticFeedback.error.trigger()
                }
            }
            .modifier(ErrorPositionModifier(
                error: $error,
                retryAction: retryAction,
                position: position
            ))
    }
}

private struct ErrorPositionModifier: ViewModifier {
    @Binding var error: Error?
    let retryAction: () -> Void
    let position: ErrorRetryModifier.ErrorPosition
    
    func body(content: Content) -> some View {
        switch position {
        case .alert:
            content.errorAlert(error: $error, retry: retryAction)
        case .banner:
            content.overlay(alignment: .top) {
                if let error = error {
                    ErrorBanner(
                        title: "Error",
                        message: error.localizedDescription,
                        type: .error,
                        showIcon: true,
                        dismissAction: { self.error = nil },
                        retryAction: retryAction
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                }
            }
        case .fullScreen:
            content.fullScreenError(
                error: $error,
                retry: retryAction,
                dismiss: { error = nil }
            )
        case .overlay:
            content.errorOverlay(error: error, retry: retryAction)
        }
    }
}

// ErrorBanner is defined in ErrorBanner.swift

extension View {
    func errorRetry(
        error: Binding<Error?>,
        retryAction: @escaping () -> Void,
        position: ErrorRetryModifier.ErrorPosition = .alert
    ) -> some View {
        self.modifier(
            ErrorRetryModifier(
                error: error,
                retryAction: retryAction,
                position: position
            )
        )
    }
}

// MARK: - Preview

#Preview("View State Examples") {
    VStack(spacing: 40) {
        // Loading state
        Text("Content")
            .viewStateModifier(
                state: ViewState<String>.loading,
                loadingView: {
                    LoadingView(message: "Loading content...")
                },
                errorView: { _ in
                    EmptyView()
                },
                emptyView: {
                    EmptyView()
                }
            )
            .frame(height: 200)
        
        // Error state
        Text("Content")
            .viewStateModifier(
                state: ViewState<String>.error(NetworkError.noConnection),
                loadingView: {
                    EmptyView()
                },
                errorView: { error in
                    ErrorView(error: error, retry: {
                        print("Retry")
                    })
                },
                emptyView: {
                    EmptyView()
                },
                retryAction: {
                    print("Retry")
                }
            )
            .frame(height: 200)
        
        // Empty state
        Text("Content")
            .viewStateModifier(
                state: ViewState<String>.empty,
                loadingView: {
                    EmptyView()
                },
                errorView: { _ in
                    EmptyView()
                },
                emptyView: {
                    EmptyStateView(config: EmptyStateConfig(
                        illustration: AnyView(Image(systemName: "tray")),
                        title: "No Tasks",
                        subtitle: "Create your first task to get started"
                    ))
                }
            )
            .frame(height: 200)
    }
}