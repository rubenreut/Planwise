//
//  CrashReporter.swift
//  Momentum
//
//  Created by Claude on 01/07/2025.
//

import Foundation
import UIKit
import os.log

/// A privacy-conscious crash reporting service that provides local crash logging
/// This service provides comprehensive crash reporting, breadcrumb logging, and user tracking
/// while respecting user privacy preferences
/// 
/// Note: This is a local implementation that can be easily replaced with Firebase Crashlytics later
public final class CrashReporter {
    
    // MARK: - Singleton
    
    /// Shared instance of the crash reporter
    public static let shared = CrashReporter()
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.rubenreut.momentum", category: "CrashReporter")
    private var breadcrumbs: [Breadcrumb] = []
    private let maxBreadcrumbs = 100
    private let breadcrumbQueue = DispatchQueue(label: "com.rubenreut.momentum.crashreporter.breadcrumbs", attributes: .concurrent)
    
    // Local storage properties
    private let crashLogDirectory: URL
    private let maxCrashLogs = 50
    private let crashLogQueue = DispatchQueue(label: "com.rubenreut.momentum.crashreporter.logs")
    private var customValues: [String: Any] = [:]
    private let customValuesQueue = DispatchQueue(label: "com.rubenreut.momentum.crashreporter.customvalues", attributes: .concurrent)
    
    /// Whether crash reporting is enabled (respects user privacy settings)
    private(set) var isEnabled: Bool = false
    
    /// Privacy-safe user identifier (anonymized)
    private var userIdentifier: String?
    
    // MARK: - Initialization
    
    private init() {
        // Set up crash log directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.crashLogDirectory = documentsPath.appendingPathComponent("CrashLogs")
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: crashLogDirectory, withIntermediateDirectories: true)
        
        // Clean old logs on initialization
        cleanOldCrashLogs()
        
        logger.debug("CrashReporter initialized with local storage at: \(self.crashLogDirectory.path)")
    }
    
    // MARK: - Configuration
    
    /// Configure the crash reporter with user preferences
    /// - Parameters:
    ///   - enabled: Whether crash reporting should be enabled
    ///   - userIdentifier: Optional anonymized user identifier for crash grouping
    public func configure(enabled: Bool, userIdentifier: String? = nil) {
        self.isEnabled = enabled
        self.userIdentifier = userIdentifier
        
        if enabled {
            logger.info("Crash reporting enabled (local storage)")
            
            // Set user identifier if provided
            if let userIdentifier = userIdentifier {
                self.userIdentifier = userIdentifier
                setCustomValue(userIdentifier, forKey: "user_id")
                logger.debug("User identifier set for crash reporting")
            }
            
            // Log initial device and app state
            logDeviceInfo()
            logAppInfo()
            
            // Write initial configuration log
            writeCrashLog(
                type: .configuration,
                message: "Crash reporting configured",
                error: nil,
                context: ["enabled": true, "has_user_id": userIdentifier != nil]
            )
        } else {
            logger.info("Crash reporting disabled")
            clearUserData()
        }
    }
    
    // MARK: - Crash Logging
    
    /// Log a non-fatal error with additional context
    /// - Parameters:
    ///   - error: The error to log
    ///   - userInfo: Additional context about the error
    ///   - function: The function where the error occurred (auto-populated)
    ///   - file: The file where the error occurred (auto-populated)
    ///   - line: The line where the error occurred (auto-populated)
    public func logError(
        _ error: Error,
        userInfo: [String: Any]? = nil,
        function: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        guard isEnabled else { return }
        
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        
        // Add context to the error
        var context: [String: Any] = [
            "function": function,
            "file": fileName,
            "line": line,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if let userInfo = userInfo {
            context.merge(userInfo) { _, new in new }
        }
        
        // Log to system logger
        logger.error("Non-fatal error: \(error.localizedDescription) at \(fileName):\(line) in \(function)")
        
        // Write to local crash log
        writeCrashLog(
            type: .nonFatalError,
            message: error.localizedDescription,
            error: error,
            context: context
        )
        
        // Add breadcrumb
        addBreadcrumb(
            message: "Error: \(error.localizedDescription)",
            category: "error",
            level: .error,
            data: context
        )
    }
    
    /// Force a crash for testing purposes (DEBUG only)
    public func testCrash() {
        #if DEBUG
        logger.fault("Test crash initiated")
        fatalError("Test crash initiated by CrashReporter")
        #else
        logger.warning("Test crash called in release build - ignoring")
        #endif
    }
    
    // MARK: - Breadcrumb Logging
    
    /// Add a breadcrumb for better crash context
    /// - Parameters:
    ///   - message: The breadcrumb message
    ///   - category: The category of the breadcrumb (e.g., "navigation", "network", "user_action")
    ///   - level: The severity level of the breadcrumb
    ///   - data: Additional data to include with the breadcrumb
    public func addBreadcrumb(
        message: String,
        category: String,
        level: BreadcrumbLevel = .info,
        data: [String: Any]? = nil
    ) {
        guard isEnabled else { return }
        
        let breadcrumb = Breadcrumb(
            timestamp: Date(),
            message: message,
            category: category,
            level: level,
            data: data
        )
        
        breadcrumbQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            self.breadcrumbs.append(breadcrumb)
            
            // Limit breadcrumb count
            if self.breadcrumbs.count > self.maxBreadcrumbs {
                self.breadcrumbs.removeFirst(self.breadcrumbs.count - self.maxBreadcrumbs)
            }
        }
        
        // Also log to system logger at appropriate level
        switch level {
        case .debug:
            logger.debug("Breadcrumb: [\(category)] \(message)")
        case .info:
            logger.info("Breadcrumb: [\(category)] \(message)")
        case .warning:
            logger.warning("Breadcrumb: [\(category)] \(message)")
        case .error:
            logger.error("Breadcrumb: [\(category)] \(message)")
        }
    }
    
    // MARK: - Custom Attributes
    
    /// Set a custom key-value pair for crash reports
    /// - Parameters:
    ///   - value: The value to set
    ///   - key: The key for the value
    public func setCustomValue(_ value: Any?, forKey key: String) {
        guard isEnabled else { return }
        
        customValuesQueue.async(flags: .barrier) { [weak self] in
            if let value = value {
                self?.customValues[key] = value
                self?.logger.debug("Set custom value for key: \(key)")
            } else {
                self?.customValues.removeValue(forKey: key)
                self?.logger.debug("Cleared custom value for key: \(key)")
            }
        }
    }
    
    /// Set multiple custom key-value pairs
    /// - Parameter keysAndValues: Dictionary of keys and values
    public func setCustomValues(_ keysAndValues: [String: Any]) {
        guard isEnabled else { return }
        
        customValuesQueue.async(flags: .barrier) { [weak self] in
            self?.customValues.merge(keysAndValues) { _, new in new }
            self?.logger.debug("Set \(keysAndValues.count) custom values")
        }
    }
    
    // MARK: - User Tracking
    
    /// Update the privacy-safe user identifier
    /// - Parameter identifier: The new user identifier (should be anonymized)
    public func updateUserIdentifier(_ identifier: String?) {
        guard isEnabled else { return }
        
        self.userIdentifier = identifier
        
        if let identifier = identifier {
            setCustomValue(identifier, forKey: "user_id")
            logger.debug("Updated user identifier")
        } else {
            setCustomValue(nil, forKey: "user_id")
            logger.debug("Cleared user identifier")
        }
    }
    
    /// Set user properties for better crash grouping
    /// - Parameter properties: Dictionary of user properties (should not contain PII)
    public func setUserProperties(_ properties: [String: String]) {
        guard isEnabled else { return }
        
        for (key, value) in properties {
            setCustomValue(value, forKey: "user_\(key)")
        }
        
        logger.debug("Set \(properties.count) user properties")
    }
    
    // MARK: - Privacy
    
    /// Clear all user data from crash reports
    public func clearUserData() {
        userIdentifier = nil
        
        customValuesQueue.async(flags: .barrier) { [weak self] in
            // Clear custom keys that might contain user data
            let userKeys = ["user_id", "user_email", "user_name", "user_subscription"]
            for key in userKeys {
                self?.customValues.removeValue(forKey: key)
            }
            
            // Also clear any keys starting with "user_"
            let keysToRemove = self?.customValues.keys.filter { $0.hasPrefix("user_") } ?? []
            for key in keysToRemove {
                self?.customValues.removeValue(forKey: key)
            }
        }
        
        logger.info("Cleared all user data from crash reporter")
    }
    
    /// Opt out of crash reporting and clear all data
    public func optOut() {
        configure(enabled: false)
        clearUserData()
        breadcrumbs.removeAll()
        logger.info("User opted out of crash reporting")
    }
    
    // MARK: - Performance Tracking
    
    /// Log a performance metric
    /// - Parameters:
    ///   - name: The name of the metric
    ///   - value: The value of the metric
    ///   - unit: The unit of measurement
    public func logPerformanceMetric(name: String, value: Double, unit: String) {
        guard isEnabled else { return }
        
        let metric = "\(name): \(value) \(unit)"
        
        addBreadcrumb(
            message: metric,
            category: "performance",
            level: .info,
            data: ["name": name, "value": value, "unit": unit]
        )
        
        // Write performance metrics to log periodically
        if name.contains("memory") || name.contains("cpu") || value > 1000 {
            writeCrashLog(
                type: .performance,
                message: metric,
                error: nil,
                context: ["name": name, "value": value, "unit": unit]
            )
        }
    }
    
    // MARK: - Private Helpers
    
    private func logDeviceInfo() {
        let device = UIDevice.current
        
        setCustomValues([
            "device_model": device.model,
            "device_name": device.name.replacingOccurrences(of: "'s", with: ""), // Remove possessive
            "system_version": device.systemVersion,
            "system_name": device.systemName,
            "battery_level": device.batteryLevel,
            "battery_state": batteryStateString(device.batteryState),
            "multitasking_supported": device.isMultitaskingSupported
        ])
    }
    
    private func logAppInfo() {
        guard let info = Bundle.main.infoDictionary else { return }
        
        setCustomValues([
            "app_version": info["CFBundleShortVersionString"] as? String ?? "Unknown",
            "app_build": info["CFBundleVersion"] as? String ?? "Unknown",
            "app_name": info["CFBundleName"] as? String ?? "Unknown"
        ])
    }
    
    private func batteryStateString(_ state: UIDevice.BatteryState) -> String {
        switch state {
        case .unknown:
            return "unknown"
        case .unplugged:
            return "unplugged"
        case .charging:
            return "charging"
        case .full:
            return "full"
        @unknown default:
            return "unknown"
        }
    }
    
    // MARK: - Local Storage Implementation
    
    /// Types of crash logs
    private enum CrashLogType: String {
        case crash = "CRASH"
        case nonFatalError = "ERROR"
        case configuration = "CONFIG"
        case performance = "PERF"
    }
    
    /// Write a crash log to local storage
    private func writeCrashLog(type: CrashLogType, message: String, error: Error?, context: [String: Any]) {
        crashLogQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Create log entry
            var logEntry: [String: Any] = [
                "timestamp": ISO8601DateFormatter().string(from: Date()),
                "type": type.rawValue,
                "message": message,
                "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
                "app_build": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown",
                "os_version": UIDevice.current.systemVersion,
                "device_model": UIDevice.current.model
            ]
            
            // Add error details if present
            if let error = error {
                let nsError = error as NSError
                logEntry["error_domain"] = nsError.domain
                logEntry["error_code"] = nsError.code
                logEntry["error_description"] = error.localizedDescription
                logEntry["error_user_info"] = nsError.userInfo
            }
            
            // Add context
            logEntry["context"] = context
            
            // Add user identifier if available
            if let userId = self.userIdentifier {
                logEntry["user_id"] = userId
            }
            
            // Add custom values
            self.customValuesQueue.sync {
                logEntry["custom_values"] = self.customValues
            }
            
            // Add recent breadcrumbs
            self.breadcrumbQueue.sync {
                let recentBreadcrumbs = Array(self.breadcrumbs.suffix(20))
                logEntry["breadcrumbs"] = recentBreadcrumbs.map { breadcrumb in
                    [
                        "timestamp": ISO8601DateFormatter().string(from: breadcrumb.timestamp),
                        "message": breadcrumb.message,
                        "category": breadcrumb.category,
                        "level": breadcrumb.level.rawValue,
                        "data": breadcrumb.data ?? [:]
                    ]
                }
            }
            
            // Generate filename
            let filename = "\(type.rawValue)_\(Date().timeIntervalSince1970).json"
            let fileURL = self.crashLogDirectory.appendingPathComponent(filename)
            
            // Write to file
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: logEntry, options: .prettyPrinted)
                try jsonData.write(to: fileURL)
                self.logger.debug("Wrote crash log: \(filename)")
            } catch {
                self.logger.error("Failed to write crash log: \(error.localizedDescription)")
            }
            
            // Clean old logs if needed
            self.cleanOldCrashLogs()
        }
    }
    
    /// Clean old crash logs to maintain storage limits
    private func cleanOldCrashLogs() {
        crashLogQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                let files = try FileManager.default.contentsOfDirectory(
                    at: self.crashLogDirectory,
                    includingPropertiesForKeys: [.creationDateKey],
                    options: []
                )
                
                // Sort by creation date (oldest first)
                let sortedFiles = try files.sorted { url1, url2 in
                    let date1 = try url1.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
                    let date2 = try url2.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
                    return date1 < date2
                }
                
                // Remove oldest files if we exceed the limit
                if sortedFiles.count > self.maxCrashLogs {
                    let filesToDelete = sortedFiles.prefix(sortedFiles.count - self.maxCrashLogs)
                    for file in filesToDelete {
                        try FileManager.default.removeItem(at: file)
                        self.logger.debug("Removed old crash log: \(file.lastPathComponent)")
                    }
                }
            } catch {
                self.logger.error("Failed to clean old crash logs: \(error.localizedDescription)")
            }
        }
    }
    
    /// Get all crash logs (for debugging or sending to server later)
    public func getAllCrashLogs() -> [[String: Any]] {
        var logs: [[String: Any]] = []
        
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: crashLogDirectory,
                includingPropertiesForKeys: nil,
                options: []
            )
            
            for file in files where file.pathExtension == "json" {
                if let data = try? Data(contentsOf: file),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    logs.append(json)
                }
            }
        } catch {
            logger.error("Failed to read crash logs: \(error.localizedDescription)")
        }
        
        return logs
    }
    
    /// Clear all crash logs
    public func clearAllCrashLogs() {
        crashLogQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                let files = try FileManager.default.contentsOfDirectory(
                    at: self.crashLogDirectory,
                    includingPropertiesForKeys: nil,
                    options: []
                )
                
                for file in files {
                    try FileManager.default.removeItem(at: file)
                }
                
                self.logger.info("Cleared all crash logs")
            } catch {
                self.logger.error("Failed to clear crash logs: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Supporting Types

/// Breadcrumb severity levels
public enum BreadcrumbLevel: String, Codable {
    case debug
    case info
    case warning
    case error
}

/// A breadcrumb for tracking user actions and app state
private struct Breadcrumb: Codable {
    let timestamp: Date
    let message: String
    let category: String
    let level: BreadcrumbLevel
    let data: [String: Any]?
    
    enum CodingKeys: String, CodingKey {
        case timestamp, message, category, level, data
    }
    
    init(timestamp: Date, message: String, category: String, level: BreadcrumbLevel, data: [String: Any]?) {
        self.timestamp = timestamp
        self.message = message
        self.category = category
        self.level = level
        self.data = data
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        message = try container.decode(String.self, forKey: .message)
        category = try container.decode(String.self, forKey: .category)
        level = try container.decode(BreadcrumbLevel.self, forKey: .level)
        data = nil // Skip decoding complex data for now
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(message, forKey: .message)
        try container.encode(category, forKey: .category)
        try container.encode(level, forKey: .level)
        // Skip encoding complex data for now
    }
}

// MARK: - Convenience Extensions

extension CrashReporter {
    
    /// Log a user action breadcrumb
    /// - Parameters:
    ///   - action: The action performed
    ///   - target: The target of the action
    ///   - data: Additional data
    public func logUserAction(_ action: String, target: String? = nil, data: [String: Any]? = nil) {
        var message = "User \(action)"
        if let target = target {
            message += " on \(target)"
        }
        
        addBreadcrumb(
            message: message,
            category: "user_action",
            level: .info,
            data: data
        )
    }
    
    /// Log a navigation event
    /// - Parameters:
    ///   - from: The source view/screen
    ///   - to: The destination view/screen
    public func logNavigation(from: String? = nil, to: String) {
        var message = "Navigated to \(to)"
        if let from = from {
            message = "Navigated from \(from) to \(to)"
        }
        
        addBreadcrumb(
            message: message,
            category: "navigation",
            level: .info,
            data: ["from": from ?? "unknown", "to": to]
        )
    }
    
    /// Log a network request
    /// - Parameters:
    ///   - method: The HTTP method
    ///   - url: The URL being requested
    ///   - statusCode: The response status code (if available)
    ///   - error: Any error that occurred
    public func logNetworkRequest(
        method: String,
        url: String,
        statusCode: Int? = nil,
        error: Error? = nil
    ) {
        var message = "\(method) \(url)"
        var data: [String: Any] = ["method": method, "url": url]
        
        if let statusCode = statusCode {
            message += " (\(statusCode))"
            data["status_code"] = statusCode
        }
        
        if let error = error {
            message += " - Failed: \(error.localizedDescription)"
            data["error"] = error.localizedDescription
        }
        
        addBreadcrumb(
            message: message,
            category: "network",
            level: error != nil ? .error : .info,
            data: data
        )
    }
}