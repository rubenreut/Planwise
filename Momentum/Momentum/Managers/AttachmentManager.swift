//
//  AttachmentManager.swift
//  Momentum
//
//  Handles file and photo attachments for tasks
//

import Foundation
import SwiftUI
import PhotosUI
import CoreData
import UniformTypeIdentifiers

@MainActor
class AttachmentManager: ObservableObject {
    static let shared = AttachmentManager()
    
    @Published var isLoadingAttachment = false
    @Published var lastError: String?
    
    private let persistence: PersistenceProviding
    private let maxFileSize: Int64 = 50 * 1024 * 1024 // 50MB limit
    private let maxImageSize: CGSize = CGSize(width: 2048, height: 2048)
    
    private init(persistence: PersistenceProviding? = nil) {
        self.persistence = persistence ?? PersistenceController.shared
    }
    
    // MARK: - Add Photo Attachment
    
    func addPhotoAttachment(to task: Task, photo: PhotosPickerItem) async -> Result<TaskAttachment, AttachmentError> {
        isLoadingAttachment = true
        defer { isLoadingAttachment = false }
        
        do {
            // Load the image data
            guard let data = try await photo.loadTransferable(type: Data.self) else {
                return .failure(.loadFailed)
            }
            
            // Check file size
            if data.count > maxFileSize {
                return .failure(.fileTooLarge)
            }
            
            // Create thumbnail
            let thumbnailData = createThumbnail(from: data)
            
            // Get filename
            let fileName = photo.itemIdentifier ?? "photo_\(UUID().uuidString).jpg"
            
            // Create attachment entity
            let context = persistence.container.viewContext
            let attachment = TaskAttachment(context: context)
            attachment.id = UUID()
            attachment.createdAt = Date()
            attachment.fileName = fileName
            attachment.fileType = "image"
            attachment.fileData = data
            attachment.thumbnailData = thumbnailData
            attachment.fileSize = Int64(data.count)
            attachment.isImage = true
            attachment.mimeType = "image/jpeg"
            attachment.task = task
            
            // Save
            try persistence.save()
            
            return .success(attachment)
            
        } catch {
            lastError = error.localizedDescription
            return .failure(.saveFailed)
        }
    }
    
    // MARK: - Add File Attachment
    
    func addFileAttachment(to task: Task, url: URL) -> Result<TaskAttachment, AttachmentError> {
        isLoadingAttachment = true
        defer { isLoadingAttachment = false }
        
        do {
            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                return .failure(.accessDenied)
            }
            defer { url.stopAccessingSecurityScopedResource() }
            
            // Read file data
            let data = try Data(contentsOf: url)
            
            // Check file size
            if data.count > maxFileSize {
                return .failure(.fileTooLarge)
            }
            
            let fileName = url.lastPathComponent
            let fileExtension = url.pathExtension
            let mimeType = UTType(filenameExtension: fileExtension)?.preferredMIMEType ?? "application/octet-stream"
            let isImage = UTType(filenameExtension: fileExtension)?.conforms(to: .image) ?? false
            
            // Create thumbnail if it's an image
            let thumbnailData: Data? = isImage ? createThumbnail(from: data) : nil
            
            // Create attachment entity
            let context = persistence.container.viewContext
            let attachment = TaskAttachment(context: context)
            attachment.id = UUID()
            attachment.createdAt = Date()
            attachment.fileName = fileName
            attachment.fileType = fileExtension
            attachment.fileData = data
            attachment.thumbnailData = thumbnailData
            attachment.fileSize = Int64(data.count)
            attachment.isImage = isImage
            attachment.mimeType = mimeType
            attachment.task = task
            
            // Save
            try persistence.save()
            
            return .success(attachment)
            
        } catch {
            lastError = error.localizedDescription
            return .failure(.saveFailed)
        }
    }
    
    // MARK: - Delete Attachment
    
    func deleteAttachment(_ attachment: TaskAttachment) -> Result<Void, AttachmentError> {
        let context = persistence.container.viewContext
        context.delete(attachment)
        
        do {
            try persistence.save()
            return .success(())
        } catch {
            lastError = error.localizedDescription
            return .failure(.deleteFailed)
        }
    }
    
    // MARK: - Export Attachment
    
    func exportAttachment(_ attachment: TaskAttachment) -> URL? {
        guard let data = attachment.fileData else { return nil }
        
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(attachment.fileName ?? "attachment")
        
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }
    
    // MARK: - Helper Methods
    
    func createThumbnail(from imageData: Data) -> Data? {
        guard let uiImage = UIImage(data: imageData) else { return nil }
        
        let maxDimension: CGFloat = 200
        let scale = min(maxDimension / uiImage.size.width, maxDimension / uiImage.size.height)
        let newSize = CGSize(width: uiImage.size.width * scale, height: uiImage.size.height * scale)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        uiImage.draw(in: CGRect(origin: .zero, size: newSize))
        let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return thumbnail?.jpegData(compressionQuality: 0.7)
    }
    
    func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Attachment Error

enum AttachmentError: LocalizedError {
    case loadFailed
    case fileTooLarge
    case accessDenied
    case saveFailed
    case deleteFailed
    case unsupportedType
    
    var errorDescription: String? {
        switch self {
        case .loadFailed:
            return "Failed to load the file"
        case .fileTooLarge:
            return "File is too large (max 50MB)"
        case .accessDenied:
            return "Access to the file was denied"
        case .saveFailed:
            return "Failed to save the attachment"
        case .deleteFailed:
            return "Failed to delete the attachment"
        case .unsupportedType:
            return "This file type is not supported"
        }
    }
}

// MARK: - TaskAttachment Extensions

extension TaskAttachment {
    var displayName: String {
        fileName ?? "Unnamed Attachment"
    }
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
    
    var icon: String {
        if isImage {
            return "photo"
        }
        
        switch fileType?.lowercased() {
        case "pdf":
            return "doc.text"
        case "doc", "docx":
            return "doc.richtext"
        case "xls", "xlsx":
            return "tablecells"
        case "txt":
            return "doc.plaintext"
        case "zip", "rar":
            return "doc.zipper"
        case "mp3", "wav", "m4a":
            return "music.note"
        case "mp4", "mov", "avi":
            return "video"
        default:
            return "paperclip"
        }
    }
    
    var thumbnail: UIImage? {
        guard let data = thumbnailData else { return nil }
        return UIImage(data: data)
    }
    
    var fullImage: UIImage? {
        guard isImage, let data = fileData else { return nil }
        return UIImage(data: data)
    }
}