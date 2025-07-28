//
//  DeviceUtilities.swift
//  Momentum
//
//  Device detection and adaptive layout utilities
//

import SwiftUI

enum DeviceType {
    case iPhone
    case iPad
    case mac
    
    static var current: DeviceType {
        #if targetEnvironment(macCatalyst)
        return .mac
        #else
        if UIDevice.current.userInterfaceIdiom == .pad {
            return .iPad
        } else {
            return .iPhone
        }
        #endif
    }
    
    static var isIPad: Bool {
        current == .iPad
    }
    
    static var isMac: Bool {
        current == .mac
    }
    
    static var isIPhone: Bool {
        current == .iPhone
    }
}

// Size classes for adaptive layouts
extension View {
    func adaptiveHorizontalPadding() -> some View {
        self.padding(.horizontal, DeviceType.isIPad ? 40 : 20)
    }
    
    func adaptiveMaxWidth() -> some View {
        self.frame(maxWidth: DeviceType.isIPad ? 700 : .infinity)
    }
    
    @ViewBuilder
    func navigationViewStyle() -> some View {
        if DeviceType.isIPad || DeviceType.isMac {
            self.navigationViewStyle(.columns)
        } else {
            self.navigationViewStyle(.stack)
        }
    }
}

// Adaptive grid layouts
struct AdaptiveGrid {
    static var twoColumnGrid: [GridItem] {
        if DeviceType.isIPad {
            return [
                GridItem(.flexible()),
                GridItem(.flexible())
            ]
        } else {
            return [GridItem(.flexible())]
        }
    }
    
    static var threeColumnGrid: [GridItem] {
        if DeviceType.isIPad {
            return [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ]
        } else if DeviceType.isMac {
            return [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ]
        } else {
            return [GridItem(.flexible())]
        }
    }
}

// Adaptive font sizes
extension Font {
    static func adaptiveTitle() -> Font {
        if DeviceType.isIPad {
            return .largeTitle
        } else {
            return .title
        }
    }
    
    static func adaptiveBody() -> Font {
        if DeviceType.isIPad {
            return .body
        } else {
            return .callout
        }
    }
}