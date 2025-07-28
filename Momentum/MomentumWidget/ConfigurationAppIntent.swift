//
//  ConfigurationAppIntent.swift
//  MomentumWidget
//
//  Configuration intent for widgets
//

import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Configuration"
    static var description = IntentDescription("Configure the widget settings")
    
    // Add any configuration parameters here in the future
}