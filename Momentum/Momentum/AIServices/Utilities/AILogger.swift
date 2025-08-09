//
//  AILogger.swift
//  Momentum
//
//  Centralized logging for AI services
//

import Foundation
import os.log

class AILogger {
    static let shared = AILogger()
    
    enum LogLevel: String {
        case debug = "🔍"
        case info = "ℹ️"
        case warning = "⚠️"
        case error = "❌"
        case success = "✅"
    }
    
    private let subsystem = "com.momentum.ai"
    private let logger: Logger
    
    private init() {
        self.logger = Logger(subsystem: subsystem, category: "AIServices")
    }
    
    func log(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "\(level.rawValue) [\(fileName):\(line)] \(function) - \(message)"
        
        #if DEBUG
        print(logMessage)
        #endif
        
        switch level {
        case .debug:
            logger.debug("\(logMessage)")
        case .info:
            logger.info("\(logMessage)")
        case .warning:
            logger.warning("\(logMessage)")
        case .error:
            logger.error("\(logMessage)")
        case .success:
            logger.info("\(logMessage)")
        }
    }
}