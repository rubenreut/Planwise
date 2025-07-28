//
//  URL+Widget.swift
//  MomentumWidget
//
//  Helper for safe URL creation in widgets
//

import Foundation

extension URL {
    static let addEvent = URL(string: "momentum://add-event") ?? URL(string: "momentum://")!
    static let schedule = URL(string: "momentum://schedule") ?? URL(string: "momentum://")!
    static let addTask = URL(string: "momentum://add-task") ?? URL(string: "momentum://")!
    static let habits = URL(string: "momentum://habits") ?? URL(string: "momentum://")!
    static let quickAdd = URL(string: "momentum://quick-add") ?? URL(string: "momentum://")!
    static let quickCapture = URL(string: "momentum://quick-capture") ?? URL(string: "momentum://")!
    static let momentum = URL(string: "momentum://") ?? URL(fileURLWithPath: "/")
    
    static func momentum(path: String) -> URL {
        return URL(string: "momentum://\(path)") ?? URL.momentum
    }
}