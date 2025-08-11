import Foundation
import SwiftData

/**
 * @fileoverview NoteLink Model
 * @description Core data model for note links using SwiftData @Model for iOS 18+
 * 
 * Features:
 * - SwiftData @Model integration for automatic persistence
 * - Bidirectional relationships with notes
 * - Automatic timestamp management
 * - Proper SwiftData relationship attributes with delete rules
 */

@Model
final class NoteLink {
    
    // MARK: - Properties
    var id: UUID
    var createdAt: Date
    var linkType: LinkType
    
    // MARK: - Relationships
    @Relationship(deleteRule: .nullify)
    var source: Note?
    
    @Relationship(deleteRule: .nullify)
    var target: Note?
    
    // MARK: - Initialization
    init(source: Note, target: Note, linkType: LinkType = .reference) {
        self.id = UUID()
        self.createdAt = Date()
        self.source = source
        self.target = target
        self.linkType = linkType
    }
}

// MARK: - Enums
extension NoteLink {
    enum LinkType: String, CaseIterable, Codable {
        case reference = "reference"
        case related = "related"
        case parent = "parent"
        case child = "child"
        
        var displayName: String {
            switch self {
            case .reference: return "Reference"
            case .related: return "Related"
            case .parent: return "Parent"
            case .child: return "Child"
            }
        }
    }
}

// MARK: - Computed Properties
extension NoteLink {
    var isBidirectional: Bool {
        return source != nil && target != nil
    }
    
    var linkDescription: String {
        guard let sourceTitle = source?.displayTitle,
              let targetTitle = target?.displayTitle else {
            return "Invalid Link"
        }
        return "\(sourceTitle) → \(targetTitle)"
    }
    
    var isValid: Bool {
        return source != nil && target != nil && source?.id != target?.id
    }
    
    var sourceTitle: String {
        return source?.displayTitle ?? "Unknown Source"
    }
    
    var targetTitle: String {
        return target?.displayTitle ?? "Unknown Target"
    }
}

// MARK: - Helper Methods
extension NoteLink {
    func updateLinkType(_ newType: LinkType) {
        self.linkType = newType
    }
    
    func getOppositeNote(from note: Note) -> Note? {
        if source?.id == note.id {
            return target
        } else if target?.id == note.id {
            return source
        }
        return nil
    }
    
    func containsNote(_ note: Note) -> Bool {
        return source?.id == note.id || target?.id == note.id
    }
}

