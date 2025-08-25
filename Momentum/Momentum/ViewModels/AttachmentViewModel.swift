import Foundation
import SwiftUI
import PhotosUI
import UIKit
import PDFKit
import UniformTypeIdentifiers

/// Handles all file and image attachment functionality
@MainActor
class AttachmentViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var selectedImage: UIImage?
    @Published var selectedFileURL: URL?
    @Published var selectedFileName: String?
    @Published var selectedFileData: Data?
    @Published var selectedFileExtension: String?
    @Published var selectedFileText: String?
    @Published var pdfFileName: String?
    @Published var pdfPageCount: Int = 1
    @Published var isProcessingAttachment: Bool = false
    @Published var attachmentError: String?
    
    // Image picker states
    @Published var showImagePicker: Bool = false
    @Published var showCamera: Bool = false
    @Published var showDocumentPicker: Bool = false
    
    // MARK: - Constants
    
    private let maxImageSize: CGFloat = 1024
    private let compressionQuality: CGFloat = 0.8
    private let maxFileSize: Int = 10 * 1024 * 1024 // 10MB
    
    // MARK: - Public Methods
    
    func handleImageSelection(_ image: UIImage) {
        isProcessingAttachment = true
        attachmentError = nil
        
        // Compress and resize image
        if let compressedImage = compressImage(image, maxSize: maxImageSize) {
            selectedImage = compressedImage
            
            // Clear file-related properties
            clearFileProperties()
        } else {
            attachmentError = "Failed to process image"
        }
        
        isProcessingAttachment = false
    }
    
    func processSelectedFile(_ url: URL) {
        isProcessingAttachment = true
        attachmentError = nil
        
        // Start accessing security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            attachmentError = "Cannot access file"
            isProcessingAttachment = false
            return
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        do {
            // Check file size
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int ?? 0
            
            if fileSize > maxFileSize {
                attachmentError = "File too large (max 10MB)"
                isProcessingAttachment = false
                return
            }
            
            // Store file info
            selectedFileURL = url
            selectedFileName = url.lastPathComponent
            selectedFileExtension = url.pathExtension.lowercased()
            
            // Process based on file type
            if selectedFileExtension == "pdf" {
                processPDFFile(url)
            } else if isTextFile(extension: selectedFileExtension ?? "") {
                processTextFile(url)
            } else if isImageFile(extension: selectedFileExtension ?? "") {
                processImageFile(url)
            } else {
                // Store raw data for other file types
                selectedFileData = try Data(contentsOf: url)
            }
            
            // Clear image if file is selected
            selectedImage = nil
            
        } catch {
            attachmentError = "Failed to process file: \(error.localizedDescription)"
        }
        
        isProcessingAttachment = false
    }
    
    func clearAttachments() {
        selectedImage = nil
        clearFileProperties()
        attachmentError = nil
    }
    
    func clearFileAttachment() {
        clearFileProperties()
    }
    
    func getAttachmentSummary() -> String? {
        if let image = selectedImage {
            return "Image attached (\(Int(image.size.width))x\(Int(image.size.height)))"
        } else if let fileName = selectedFileName {
            if pdfPageCount > 1 {
                return "\(fileName) (\(pdfPageCount) pages)"
            }
            return fileName
        }
        return nil
    }
    
    func getBase64EncodedImage() -> String? {
        guard let image = selectedImage else { return nil }
        guard let imageData = image.jpegData(compressionQuality: compressionQuality) else { return nil }
        return imageData.base64EncodedString()
    }
    
    func getFileContent() -> String? {
        return selectedFileText
    }
    
    // MARK: - Private Methods
    
    private func clearFileProperties() {
        selectedFileURL = nil
        selectedFileName = nil
        selectedFileData = nil
        selectedFileExtension = nil
        selectedFileText = nil
        pdfFileName = nil
        pdfPageCount = 1
    }
    
    private func compressImage(_ image: UIImage, maxSize: CGFloat) -> UIImage? {
        let size = image.size
        let widthRatio = maxSize / size.width
        let heightRatio = maxSize / size.height
        
        let ratio = min(widthRatio, heightRatio)
        
        // Don't upscale
        if ratio >= 1.0 {
            return image
        }
        
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let compressedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return compressedImage
    }
    
    private func processPDFFile(_ url: URL) {
        guard let pdfDocument = PDFDocument(url: url) else {
            attachmentError = "Failed to load PDF"
            return
        }
        
        pdfPageCount = pdfDocument.pageCount
        pdfFileName = url.lastPathComponent
        
        // Extract text from PDF
        var extractedText = ""
        for i in 0..<min(pdfDocument.pageCount, 50) { // Limit to 50 pages
            if let page = pdfDocument.page(at: i) {
                if let pageText = page.string {
                    extractedText += "Page \(i + 1):\n\(pageText)\n\n"
                }
            }
        }
        
        selectedFileText = extractedText.isEmpty ? nil : extractedText
        
        // Convert first page to image for preview
        if let firstPage = pdfDocument.page(at: 0) {
            let pageRect = firstPage.bounds(for: .mediaBox)
            let renderer = UIGraphicsImageRenderer(size: pageRect.size)
            
            let image = renderer.image { ctx in
                UIColor.white.set()
                ctx.fill(pageRect)
                
                ctx.cgContext.translateBy(x: 0.0, y: pageRect.size.height)
                ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
                
                firstPage.draw(with: .mediaBox, to: ctx.cgContext)
            }
            
            selectedImage = compressImage(image, maxSize: maxImageSize)
        }
    }
    
    private func processTextFile(_ url: URL) {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            selectedFileText = content
            selectedFileData = content.data(using: .utf8)
        } catch {
            // Try other encodings
            if let content = try? String(contentsOf: url, encoding: .ascii) {
                selectedFileText = content
                selectedFileData = content.data(using: .utf8)
            } else if let content = try? String(contentsOf: url, encoding: .isoLatin1) {
                selectedFileText = content
                selectedFileData = content.data(using: .utf8)
            } else {
                attachmentError = "Failed to read text file"
            }
        }
    }
    
    private func processImageFile(_ url: URL) {
        if let imageData = try? Data(contentsOf: url),
           let image = UIImage(data: imageData) {
            selectedImage = compressImage(image, maxSize: maxImageSize)
            selectedFileData = imageData
        } else {
            attachmentError = "Failed to load image file"
        }
    }
    
    private func isTextFile(extension ext: String) -> Bool {
        let textExtensions = ["txt", "md", "markdown", "json", "xml", "csv", "log", "rtf", "swift", "py", "js", "html", "css"]
        return textExtensions.contains(ext)
    }
    
    private func isImageFile(extension ext: String) -> Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp"]
        return imageExtensions.contains(ext)
    }
    
    func mimeType(for fileExtension: String) -> String {
        let mimeTypes: [String: String] = [
            "pdf": "application/pdf",
            "txt": "text/plain",
            "md": "text/markdown",
            "json": "application/json",
            "xml": "application/xml",
            "csv": "text/csv",
            "jpg": "image/jpeg",
            "jpeg": "image/jpeg",
            "png": "image/png",
            "gif": "image/gif",
            "doc": "application/msword",
            "docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            "xls": "application/vnd.ms-excel",
            "xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        ]
        
        return mimeTypes[fileExtension] ?? "application/octet-stream"
    }
}
