import Foundation
import SwiftUI
import Combine
import Speech
import AVFoundation
import CoreData
import PhotosUI
import UIKit
import PDFKit

// MARK: - Chat View Model

@MainActor
class ChatViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var messages: [String] = []
    @Published var inputText: String = ""
}