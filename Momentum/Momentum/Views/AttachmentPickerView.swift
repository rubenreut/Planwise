//
//  AttachmentPickerView.swift
//  Momentum
//
//  UI for selecting and adding attachments to tasks
//

import SwiftUI
import PhotosUI

struct AttachmentPickerView: View {
    let task: Task
    @Binding var isPresented: Bool
    
    @StateObject private var attachmentManager = AttachmentManager.shared
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var showingFilePicker = false
    @State private var showingCamera = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Photo picker
                PhotosPicker(
                    selection: $selectedPhotos,
                    maxSelectionCount: 10,
                    matching: .images
                ) {
                    AttachmentOptionRow(
                        icon: "photo.on.rectangle.angled",
                        title: "Choose Photos",
                        subtitle: "Select from your photo library",
                        color: .blue
                    )
                }
                .onChange(of: selectedPhotos) { _, newItems in
                    _Concurrency.Task { @MainActor in
                        await processSelectedPhotos(newItems)
                    }
                }
                
                // Camera option
                Button(action: {
                    showingCamera = true
                }) {
                    AttachmentOptionRow(
                        icon: "camera.fill",
                        title: "Take Photo",
                        subtitle: "Capture a new photo",
                        color: .green
                    )
                }
                
                // File picker
                Button(action: {
                    showingFilePicker = true
                }) {
                    AttachmentOptionRow(
                        icon: "doc.fill",
                        title: "Choose Files",
                        subtitle: "Select documents or files",
                        color: .orange
                    )
                }
                
                Spacer()
                
                // Loading indicator
                if attachmentManager.isLoadingAttachment {
                    ProgressView("Adding attachment...")
                        .padding()
                }
            }
            .padding()
            .navigationTitle("Add Attachment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            handleFileSelection(result)
        }
        .sheet(isPresented: $showingCamera) {
            CameraView { image in
                handleCapturedPhoto(image)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Process Photos
    
    private func processSelectedPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            let result = await attachmentManager.addPhotoAttachment(to: task, photo: item)
            
            if case .failure(let error) = result {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
                break
            }
        }
        
        // Clear selection
        await MainActor.run {
            selectedPhotos = []
            if !attachmentManager.isLoadingAttachment {
                dismiss()
            }
        }
    }
    
    // MARK: - Handle File Selection
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                let attachmentResult = attachmentManager.addFileAttachment(to: task, url: url)
                
                if case .failure(let error) = attachmentResult {
                    errorMessage = error.localizedDescription
                    showError = true
                    break
                }
            }
            
            if !attachmentManager.isLoadingAttachment {
                dismiss()
            }
            
        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    // MARK: - Handle Captured Photo
    
    private func handleCapturedPhoto(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            errorMessage = "Failed to process captured photo"
            showError = true
            return
        }
        
        // Create a temporary photo item and process it
        // This would need a custom implementation since PhotosPickerItem doesn't have a public initializer
        // For now, we'll save directly as data
        _Concurrency.Task { @MainActor in
            await saveImageData(data, fileName: "photo_\(Date().timeIntervalSince1970).jpg")
        }
    }
    
    private func saveImageData(_ data: Data, fileName: String) async {
        // Create attachment directly with data
        await MainActor.run {
            let context = PersistenceController.shared.container.viewContext
            let attachment = TaskAttachment(context: context)
            attachment.id = UUID()
            attachment.createdAt = Date()
            attachment.fileName = fileName
            attachment.fileType = "jpg"
            attachment.fileData = data
            attachment.thumbnailData = attachmentManager.createThumbnail(from: data)
            attachment.fileSize = Int64(data.count)
            attachment.isImage = true
            attachment.mimeType = "image/jpeg"
            attachment.task = task
            
            do {
                try context.save()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - Attachment Option Row

struct AttachmentOptionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(color)
                .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

// MARK: - Camera View

struct CameraView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

