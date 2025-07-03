import SwiftUI

struct LazyView<Content: View>: View {
    let build: () -> Content
    
    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }
    
    init(@ViewBuilder _ build: @escaping () -> Content) {
        self.build = build
    }
    
    var body: some View {
        build()
    }
}