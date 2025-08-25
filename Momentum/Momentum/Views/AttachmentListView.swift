//
//  AttachmentListView.swift
//  Momentum
//
//  Displays attachments for a task
//

import SwiftUI
import QuickLook

struct AttachmentListView: View {
    let task: Task
    @State private var showingAttachmentPicker = false
    @State private var selectedAttachment: TaskAttachment?
    @State private var showingQuickLook = false
    @State private var quickLookURL: URL?
    @StateObject private var attachmentManager = AttachmentManager.shared
    
    var attachments: [TaskAttachment] {
        (task.attachments?.allObjects as? [TaskAttachment] ?? [])
            .sorted { ($0.createdAt ?? Date()) > ($1.createdAt ?? Date()) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Label("Attachments", systemImage: "paperclip")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: {
                    showingAttachmentPicker = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal)
            
            if attachments.isEmpty {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: "paperclip.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    Text("No attachments")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button("Add Attachment") {
                        showingAttachmentPicker = true
                    }
                    .font(.caption)
                    .foregroundColor(.accentColor)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                
            } else {
                // Attachment grid
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(attachments, id: \.id) { attachment in
                            AttachmentCard(
                                attachment: attachment,
                                onTap: {
                                    handleAttachmentTap(attachment)
                                },
                                onDelete: {
                                    deleteAttachment(attachment)
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .sheet(isPresented: $showingAttachmentPicker) {
            AttachmentPickerView(task: task, isPresented: $showingAttachmentPicker)
        }
        .quickLookPreview($quickLookURL)
    }
    
    // MARK: - Actions
    
    private func handleAttachmentTap(_ attachment: TaskAttachment) {
        if let url = attachmentManager.exportAttachment(attachment) {
            quickLookURL = url
        }
    }
    
    private func deleteAttachment(_ attachment: TaskAttachment) {
        withAnimation {
            _ = attachmentManager.deleteAttachment(attachment)
        }
    }
}

// MARK: - Attachment Card

struct AttachmentCard: View {
    let attachment: TaskAttachment
    let onTap: () -> Void
    let onDelete: () -> Void
    
    @State private var showingDeleteConfirm = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Thumbnail or icon
            ZStack {
                if attachment.isImage, let thumbnail = attachment.thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipped()
                        .cornerRadius(8)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.1))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: attachment.icon)
                                .font(.system(size: 30))
                                .foregroundColor(.secondary)
                        )
                }
                
                // Delete button
                Button(action: {
                    showingDeleteConfirm = true
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                }
                .position(x: 72, y: 8)
            }
            .frame(width: 80, height: 80)
            
            // File name
            Text(attachment.displayName)
                .font(.caption2)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 80)
            
            // File size
            Text(attachment.formattedSize)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .onTapGesture {
            onTap()
        }
        .confirmationDialog(
            "Delete Attachment",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this attachment?")
        }
    }
}

// MARK: - Inline Attachment View (for compact display)

struct InlineAttachmentView: View {
    let attachments: [TaskAttachment]
    @State private var quickLookURL: URL?
    @StateObject private var attachmentManager = AttachmentManager.shared
    
    var body: some View {
        if !attachments.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(attachments, id: \.id) { attachment in
                        InlineAttachmentItem(attachment: attachment) {
                            if let url = attachmentManager.exportAttachment(attachment) {
                                quickLookURL = url
                            }
                        }
                    }
                }
            }
            .quickLookPreview($quickLookURL)
        }
    }
}

struct InlineAttachmentItem: View {
    let attachment: TaskAttachment
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                if attachment.isImage, let thumbnail = attachment.thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 24, height: 24)
                        .clipped()
                        .cornerRadius(4)
                } else {
                    Image(systemName: attachment.icon)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Text(attachment.displayName)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}