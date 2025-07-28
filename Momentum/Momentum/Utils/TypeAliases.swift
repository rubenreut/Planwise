//
//  TypeAliases.swift
//  Momentum
//
//  Global type aliases to avoid naming conflicts
//

import Foundation

// Type alias to avoid conflicts with Core Data Task entity
// Use this for Swift's concurrency Task throughout the app
public typealias AsyncTask = _Concurrency.Task