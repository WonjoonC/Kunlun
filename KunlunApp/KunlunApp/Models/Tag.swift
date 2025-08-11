import Foundation
import SwiftData

/**
 * @fileoverview Tag Model
 * @description Core data model for tags using SwiftData @Model for iOS 18+
 * 
 * Features:
 * - SwiftData @Model integration for automatic persistence
 * - Many-to-many relationship with notes
 * - Automatic ID generation
 * - Proper SwiftData relationship attributes with delete rules
 */

@Model
final class Tag {
    
    // MARK: - Properties
    var id: UUID
    var name: String
    var createdAt: Date
    
    // MARK: - Relationships
    @Relationship(deleteRule: .nullify)
    var notes: [Note] = []
    
    // MARK: - Initialization
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
    }
}

// MARK: - Computed Properties
extension Tag {
    var noteCount: Int {
        return notes.count
    }
    
    var isEmpty: Bool {
        return notes.isEmpty
    }
    
    var lastUsed: Date? {
        return notes.map { $0.lastActivity }.max()
    }
}

// MARK: - Helper Methods
extension Tag {
    func addNote(_ note: Note) {
        if !notes.contains(where: { $0.id == note.id }) {
            notes.append(note)
            // Ensure bidirectional relationship
            if !note.tags.contains(where: { $0.id == self.id }) {
                note.tags.append(self)
            }
        }
    }
    
    func removeNote(_ note: Note) {
        notes.removeAll { $0.id == note.id }
        // Remove from note's tags as well
        note.tags.removeAll { $0.id == self.id }
    }
    
    func getNoteTitles() -> [String] {
        return notes.map { $0.displayTitle }
    }
}

