import Foundation
import UIKit

// Photo attachment model for tasks
struct TaskPhoto: Identifiable, Equatable, Codable {
    let id: UUID
    let taskId: UUID
    let imageData: Data
    let thumbnailData: Data?
    let caption: String?
    let createdAt: Date
    
    init(
        id: UUID = UUID(),
        taskId: UUID,
        imageData: Data,
        thumbnailData: Data? = nil,
        caption: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.taskId = taskId
        self.imageData = imageData
        self.thumbnailData = thumbnailData
        self.caption = caption
        self.createdAt = createdAt
    }
    
    // Create thumbnail from full image
    static func createThumbnail(from imageData: Data, maxSize: CGFloat = 200) -> Data? {
        guard let image = UIImage(data: imageData) else { return nil }
        
        let size = image.size
        let targetSize: CGSize
        
        if size.width > size.height {
            let ratio = maxSize / size.width
            targetSize = CGSize(width: maxSize, height: size.height * ratio)
        } else {
            let ratio = maxSize / size.height
            targetSize = CGSize(width: size.width * ratio, height: maxSize)
        }
        
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: targetSize))
        let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return thumbnail?.jpegData(compressionQuality: 0.7)
    }
}

// Photo storage manager
class TaskPhotoManager {
    static let shared = TaskPhotoManager()
    private let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    private let photosDirectory: URL
    
    private init() {
        photosDirectory = documentsDirectory.appendingPathComponent("TaskPhotos")
        try? FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
    }
    
    func savePhoto(_ photo: TaskPhoto) throws {
        let photoURL = photosDirectory.appendingPathComponent("\(photo.id.uuidString).json")
        let data = try JSONEncoder().encode(photo)
        try data.write(to: photoURL)
    }
    
    func loadPhotos(for taskId: UUID) -> [TaskPhoto] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: photosDirectory, includingPropertiesForKeys: nil) else {
            return []
        }
        
        return files.compactMap { url in
            guard let data = try? Data(contentsOf: url),
                  let photo = try? JSONDecoder().decode(TaskPhoto.self, from: data),
                  photo.taskId == taskId else {
                return nil
            }
            return photo
        }
    }
    
    func deletePhoto(_ photoId: UUID) throws {
        let photoURL = photosDirectory.appendingPathComponent("\(photoId.uuidString).json")
        try FileManager.default.removeItem(at: photoURL)
    }
}