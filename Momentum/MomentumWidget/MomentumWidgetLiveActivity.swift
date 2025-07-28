//
//  MomentumWidgetLiveActivity.swift
//  MomentumWidget
//
//  Created by Ruben Reut on 03/07/2025.
//

#if !targetEnvironment(macCatalyst)
import ActivityKit
#endif
import WidgetKit
import SwiftUI

#if !targetEnvironment(macCatalyst)
struct MomentumWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct MomentumWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MomentumWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension MomentumWidgetAttributes {
    fileprivate static var preview: MomentumWidgetAttributes {
        MomentumWidgetAttributes(name: "World")
    }
}

extension MomentumWidgetAttributes.ContentState {
    fileprivate static var smiley: MomentumWidgetAttributes.ContentState {
        MomentumWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: MomentumWidgetAttributes.ContentState {
         MomentumWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: MomentumWidgetAttributes.preview) {
   MomentumWidgetLiveActivity()
} contentStates: {
    MomentumWidgetAttributes.ContentState.smiley
    MomentumWidgetAttributes.ContentState.starEyes
}
#endif
