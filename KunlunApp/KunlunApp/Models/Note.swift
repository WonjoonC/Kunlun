import Foundation
import SwiftData

/**
 * @fileoverview Note Model
 * @description Core data model for notes using SwiftData @Model for iOS 18+
 * 
 * Features:
 * - SwiftData @Model integration for automatic persistence
 * - Automatic ID generation and timestamp management
 * - Computed properties for display and validation
 * - Helper methods for CRUD operations
 * - Proper SwiftData relationship attributes with delete rules
 */

@Model
final class Note {
    
    // MARK: - Properties
    var id: UUID
    var title: String
    var content: String
    var createdAt: Date
    var modifiedAt: Date
    
    // MARK: - Relationships
    @Relationship(deleteRule: .cascade)
    var tags: [Tag] = []
    
    @Relationship(deleteRule: .cascade)
    var outgoingLinks: [NoteLink] = []
    
    @Relationship(deleteRule: .cascade)
    var incomingLinks: [NoteLink] = []
    
    // MARK: - Initialization
    init(title: String = "", content: String = "") {
        self.id = UUID()
        self.title = title
        self.content = content
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
}

// MARK: - Computed Properties
extension Note {
    var displayTitle: String {
        return title.isEmpty ? "Untitled Note" : title
    }
    
    var displayContent: String {
        return content.isEmpty ? "No content" : content
    }
    
    var isModified: Bool {
        return modifiedAt > createdAt
    }
    
    var tagNames: [String] {
        return tags.map { $0.name }
    }
    
    var hasLinks: Bool {
        return !outgoingLinks.isEmpty || !incomingLinks.isEmpty
    }
    
    var linkCount: Int {
        return outgoingLinks.count + incomingLinks.count
    }
    
    var lastActivity: Date {
        return modifiedAt > createdAt ? modifiedAt : createdAt
    }
}

// MARK: - Helper Methods
extension Note {
    func update(title: String? = nil, content: String? = nil) {
        if let title = title {
            self.title = title
        }
        if let content = content {
            self.content = content
        }
        self.modifiedAt = Date()
    }
    
    func addTag(_ tag: Tag) {
        if !tags.contains(where: { $0.id == tag.id }) {
            tags.append(tag)
            // Ensure bidirectional relationship
            if !tag.notes.contains(where: { $0.id == self.id }) {
                tag.notes.append(self)
            }
        }
    }
    
    func removeTag(_ tag: Tag) {
        tags.removeAll { $0.id == tag.id }
        // Remove from tag's notes as well
        tag.notes.removeAll { $0.id == self.id }
    }
    
    func linkTo(_ targetNote: Note) -> NoteLink? {
        // Check if link already exists
        if outgoingLinks.contains(where: { $0.target?.id == targetNote.id }) {
            return nil
        }
        
        let link = NoteLink(source: self, target: targetNote)
        outgoingLinks.append(link)
        // Ensure bidirectional relationship
        targetNote.incomingLinks.append(link)
        return link
    }
    
    func removeLink(_ link: NoteLink) {
        outgoingLinks.removeAll { $0.id == link.id }
        incomingLinks.removeAll { $0.id == link.id }
    }
    
    func getLinkedNotes() -> [Note] {
        let outgoing = outgoingLinks.compactMap { $0.target }
        let incoming = incomingLinks.compactMap { $0.source }
        return Array(Set(outgoing + incoming))
    }
}
