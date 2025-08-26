import XCTest
@testable import Momentum

class FileAttachmentTests: XCTestCase {
    
    func testChatRequestMessageWithImageData() {
        // Test image attachment initialization
        let imageData = Data([0xFF, 0xD8, 0xFF]) // Simple JPEG header
        let message = ChatRequestMessage(
            role: "user",
            content: "Please analyze this image",
            imageData: imageData
        )
        
        XCTAssertEqual(message.role, "user")
        
        // Verify content is array type with image
        if case .array(let contentArray) = message.content {
            XCTAssertEqual(contentArray.count, 2)
            
            // Check text part
            if let textPart = contentArray.first,
               let type = textPart["type"] as? String,
               let text = textPart["text"] as? String {
                XCTAssertEqual(type, "text")
                XCTAssertEqual(text, "Please analyze this image")
            } else {
                XCTFail("Text part not found or invalid")
            }
            
            // Check image part
            if let imagePart = contentArray.last,
               let type = imagePart["type"] as? String,
               let imageUrl = imagePart["image_url"] as? [String: Any],
               let url = imageUrl["url"] as? String {
                XCTAssertEqual(type, "image_url")
                XCTAssertTrue(url.hasPrefix("data:image/jpeg;base64,"))
            } else {
                XCTFail("Image part not found or invalid")
            }
        } else {
            XCTFail("Content should be array type for image attachment")
        }
    }
    
    func testChatRequestMessageWithoutImageData() {
        // Test initialization without image data
        let message = ChatRequestMessage(
            role: "user",
            content: "Just a text message",
            imageData: nil
        )
        
        XCTAssertEqual(message.role, "user")
        
        // Verify content is text type
        if case .text(let content) = message.content {
            XCTAssertEqual(content, "Just a text message")
        } else {
            XCTFail("Content should be text type when no image data")
        }
    }
    
    func testChatRequestMessageWithFileData() {
        // Test file attachment initialization
        let fileData = Data("Test file content".utf8)
        let message = ChatRequestMessage(
            role: "user",
            content: "Please analyze this document",
            fileData: fileData,
            fileName: "test.pdf",
            mimeType: "application/pdf"
        )
        
        XCTAssertEqual(message.role, "user")
        
        // Verify content includes file info
        if case .text(let content) = message.content {
            XCTAssertTrue(content.contains("Please analyze this document"))
            XCTAssertTrue(content.contains("[File Attachment: test.pdf (application/pdf)]"))
        } else {
            XCTFail("Content should be text type for file attachment")
        }
    }
    
    func testChatRequestMessageWithoutFileData() {
        // Test initialization without file data
        let message = ChatRequestMessage(
            role: "user",
            content: "Just a text message",
            fileData: nil,
            fileName: nil,
            mimeType: nil
        )
        
        XCTAssertEqual(message.role, "user")
        
        // Verify content is just the text
        if case .text(let content) = message.content {
            XCTAssertEqual(content, "Just a text message")
        } else {
            XCTFail("Content should be text type when no file data")
        }
    }
}