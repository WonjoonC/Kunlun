import Foundation
import FirebaseFirestore
import FirebaseAuth
import CoreData

/// FirestoreClient handles all Firestore database operations for the Kunlun app
/// Manages CRUD operations for Notes, Tags, and NoteLinks with proper error handling
/// and data conversion between Core Data models and Firestore documents
class FirestoreClient: ObservableObject {
    
    // MARK: - Singleton
    static let shared = FirestoreClient()
    
    // MARK: - Properties
    /// Reference to the main Firestore database
    private let db: Firestore
    private var uid: String? { Auth.auth().currentUser?.uid }
    
    /// Collection names for Firestore
    private enum Collections {
        static let notes = "notes"
        static let tags = "tags"
        static let noteLinks = "note_links"
    }
    
    // MARK: - Initialization
    private init() {
        self.db = FirebaseManager.shared.db
    }
    
    // MARK: - Note Operations
    
    /// Create a note in Firestore
    /// - Parameters:
    ///   - note: The note to create
    ///   - completion: Completion handler with success/failure result
    func createNote(_ note: Note, completion: @escaping (Result<Void, Error>) -> Void) {
        let noteId = note.id.uuidString
        
        guard let uid = uid, !uid.isEmpty else {
            completion(.failure(FirestoreError.permissionDenied))
            return
        }

        let noteData: [String: Any] = [
            "id": noteId,
            "title": note.title,
            "content": note.content,
            "createdAt": note.createdAt,
            "modifiedAt": note.modifiedAt,
            "tags": note.tags.compactMap { $0.id.uuidString },
            "outgoingLinks": note.outgoingLinks.compactMap { $0.id.uuidString },
            "incomingLinks": note.incomingLinks.compactMap { $0.id.uuidString },
            "userId": uid
        ]
        
        db.collection(Collections.notes).document(noteId).setData(noteData) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    /// Fetch a note by ID from Firestore
    /// - Parameters:
    ///   - noteId: The UUID string of the note to fetch
    ///   - completion: Completion handler with the note data or error
    func fetchNote(noteId: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        db.collection(Collections.notes).document(noteId).getDocument { document, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let document = document, document.exists else {
                completion(.failure(FirestoreError.documentNotFound))
                return
            }
            
            completion(.success(document.data() ?? [:]))
        }
    }
    
    /// Update a note in Firestore
    /// - Parameters:
    ///   - note: The note to update
    ///   - completion: Completion handler with success/failure result
    func updateNote(_ note: Note, completion: @escaping (Result<Void, Error>) -> Void) {
        let noteId = note.id.uuidString
        
        guard let uid = uid, !uid.isEmpty else {
            completion(.failure(FirestoreError.permissionDenied))
            return
        }

        let noteData: [String: Any] = [
            "id": noteId,
            "title": note.title,
            "content": note.content,
            "createdAt": note.createdAt,
            "modifiedAt": note.modifiedAt,
            "tags": note.tags.compactMap { $0.id.uuidString },
            "outgoingLinks": note.outgoingLinks.compactMap { $0.id.uuidString },
            "incomingLinks": note.incomingLinks.compactMap { $0.id.uuidString },
            "userId": uid
        ]
        
        db.collection(Collections.notes).document(noteId).setData(noteData, merge: true) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    /// Delete a note from Firestore
    /// - Parameters:
    ///   - noteId: The UUID string of the note to delete
    ///   - completion: Completion handler with success/failure result
    func deleteNote(noteId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection(Collections.notes).document(noteId).delete { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    /// Fetch all notes from Firestore with optional filtering
    /// - Parameters:
    ///   - limit: Maximum number of notes to fetch (default: 50)
    ///   - completion: Completion handler with array of note data or error
    func fetchAllNotes(limit: Int = 50, completion: @escaping (Result<[[String: Any]], Error>) -> Void) {
        guard let uid = uid else {
            completion(.success([]))
            return
        }
        let filtered = db.collection(Collections.notes).whereField("userId", isEqualTo: uid)
        filtered
            .order(by: "modifiedAt", descending: true)
            .limit(to: limit)
            .getDocuments { querySnapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                let notes = querySnapshot?.documents.compactMap { $0.data() } ?? []
                completion(.success(notes))
            }
    }
    
    // MARK: - Tag Operations
    
    /// Create a tag in Firestore
    /// - Parameters:
    ///   - tag: The tag to create
    ///   - completion: Completion handler with success/failure result
    func createTag(_ tag: Tag, completion: @escaping (Result<Void, Error>) -> Void) {
        let tagId = tag.id.uuidString
        
        guard let uid = uid, !uid.isEmpty else {
            completion(.failure(FirestoreError.permissionDenied))
            return
        }

        let tagData: [String: Any] = [
            "id": tagId,
            "name": tag.name,
            "notes": tag.notes.compactMap { $0.id.uuidString },
            "userId": uid
        ]
        
        db.collection(Collections.tags).document(tagId).setData(tagData) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    /// Fetch a tag by ID from Firestore
    /// - Parameters:
    ///   - tagId: The UUID string of the tag to fetch
    ///   - completion: Completion handler with the tag data or error
    func fetchTag(tagId: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        db.collection(Collections.tags).document(tagId).getDocument { document, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let document = document, document.exists else {
                completion(.failure(FirestoreError.documentNotFound))
                return
            }
            
            completion(.success(document.data() ?? [:]))
        }
    }
    
    /// Update a tag in Firestore
    /// - Parameters:
    ///   - tag: The tag to update
    ///   - completion: Completion handler with success/failure result
    func updateTag(_ tag: Tag, completion: @escaping (Result<Void, Error>) -> Void) {
        let tagId = tag.id.uuidString
        
        guard let uid = uid, !uid.isEmpty else {
            completion(.failure(FirestoreError.permissionDenied))
            return
        }

        let tagData: [String: Any] = [
            "id": tagId,
            "name": tag.name,
            "notes": tag.notes.compactMap { $0.id.uuidString },
            "userId": uid
        ]
        
        db.collection(Collections.tags).document(tagId).setData(tagData, merge: true) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    /// Delete a tag from Firestore
    /// - Parameters:
    ///   - tagId: The UUID string of the tag to delete
    ///   - completion: Completion handler with success/failure result
    func deleteTag(tagId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection(Collections.tags).document(tagId).delete { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    /// Fetch all tags from Firestore
    /// - Parameter completion: Completion handler with array of tag data or error
    func fetchAllTags(completion: @escaping (Result<[[String: Any]], Error>) -> Void) {
        guard let uid = uid else {
            completion(.success([]))
            return
        }
        let filtered = db.collection(Collections.tags).whereField("userId", isEqualTo: uid)
        filtered
            .order(by: "name")
            .getDocuments { querySnapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                let tags = querySnapshot?.documents.compactMap { $0.data() } ?? []
                completion(.success(tags))
            }
    }
    
    // MARK: - NoteLink Operations
    
    /// Create a note link in Firestore
    /// - Parameters:
    ///   - noteLink: The note link to create
    ///   - completion: Completion handler with success/failure result
    func createNoteLink(_ noteLink: NoteLink, completion: @escaping (Result<Void, Error>) -> Void) {
        let linkId = noteLink.id.uuidString
        let sourceId = noteLink.source?.id.uuidString ?? ""
        let targetId = noteLink.target?.id.uuidString ?? ""
        
        guard let uid = uid, !uid.isEmpty else {
            completion(.failure(FirestoreError.permissionDenied))
            return
        }

        let linkData: [String: Any] = [
            "id": linkId,
            "sourceId": sourceId,
            "targetId": targetId,
            "createdAt": noteLink.createdAt,
            "userId": uid
        ]
        
        db.collection(Collections.noteLinks).document(linkId).setData(linkData) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    /// Fetch a note link by ID from Firestore
    /// - Parameters:
    ///   - linkId: The UUID string of the link to fetch
    ///   - completion: Completion handler with the link data or error
    func fetchNoteLink(linkId: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        db.collection(Collections.noteLinks).document(linkId).getDocument { document, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let document = document, document.exists else {
                completion(.failure(FirestoreError.documentNotFound))
                return
            }
            
            completion(.success(document.data() ?? [:]))
        }
    }
    
    /// Delete a note link from Firestore
    /// - Parameters:
    ///   - linkId: The UUID string of the link to delete
    ///   - completion: Completion handler with success/failure result
    func deleteNoteLink(linkId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection(Collections.noteLinks).document(linkId).delete { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    /// Fetch all note links from Firestore
    /// - Parameter completion: Completion handler with array of link data or error
    func fetchAllNoteLinks(completion: @escaping (Result<[[String: Any]], Error>) -> Void) {
        guard let uid = uid else {
            completion(.success([]))
            return
        }
        let filtered = db.collection(Collections.noteLinks).whereField("userId", isEqualTo: uid)
        filtered
            .order(by: "createdAt", descending: true)
            .getDocuments { querySnapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                let links = querySnapshot?.documents.compactMap { $0.data() } ?? []
                completion(.success(links))
            }
    }
    
    // MARK: - Batch Operations
    
    /// Perform batch operations on Firestore
    /// - Parameter operations: Array of batch operations to perform
    /// - Returns: Result indicating success or failure
    func performBatchOperations(_ operations: [BatchOperation]) async throws -> Void {
        let batch = db.batch()
        
        for operation in operations {
            switch operation {
            case .createNote(let note):
                let noteId = note.id.uuidString
                let noteData = convertNoteToFirestore(note)
                batch.setData(noteData, forDocument: db.collection("notes").document(noteId))
                
            case .updateNote(let note):
                let noteId = note.id.uuidString
                let noteData = convertNoteToFirestore(note)
                batch.updateData(noteData, forDocument: db.collection("notes").document(noteId))
                
            case .deleteNote(let noteId):
                batch.deleteDocument(db.collection("notes").document(noteId))
                
            case .createTag(let tag):
                let tagId = tag.id.uuidString
                let tagData = convertTagToFirestore(tag)
                batch.setData(tagData, forDocument: db.collection("tags").document(tagId))
                
            case .updateTag(let tag):
                let tagId = tag.id.uuidString
                let tagData = convertTagToFirestore(tag)
                batch.updateData(tagData, forDocument: db.collection("tags").document(tagId))
                
            case .deleteTag(let tagId):
                batch.deleteDocument(db.collection("tags").document(tagId))
            }
        }
        
        try await batch.commit()
    }
    
    // MARK: - Data Conversion Helpers
    
    /// Convert a Note object to Firestore document data
    /// - Parameter note: The Note object to convert
    /// - Returns: Dictionary representation for Firestore
    private func convertNoteToFirestore(_ note: Note) -> [String: Any] {
        return [
            "id": note.id.uuidString,
            "title": note.title,
            "content": note.content,
            "createdAt": note.createdAt,
            "modifiedAt": note.modifiedAt,
            "tags": note.tags.compactMap { $0.id.uuidString },
            "outgoingLinks": note.outgoingLinks.compactMap { $0.id.uuidString },
            "incomingLinks": note.incomingLinks.compactMap { $0.id.uuidString },
            "userId": uid ?? ""
        ]
    }
    
    /// Convert a Tag object to Firestore document data
    /// - Parameter tag: The Tag object to convert
    /// - Returns: Dictionary representation for Firestore
    private func convertTagToFirestore(_ tag: Tag) -> [String: Any] {
        return [
            "id": tag.id.uuidString,
            "name": tag.name,
            "notes": tag.notes.compactMap { $0.id.uuidString },
            "userId": uid ?? ""
        ]
    }
}

// MARK: - Batch Operation Types

/// Represents different types of batch operations that can be performed
enum BatchOperation {
    case createNote(Note)
    case updateNote(Note)
    case deleteNote(String)
    case createTag(Tag)
    case updateTag(Tag)
    case deleteTag(String)
}

// MARK: - Custom Errors

/// Custom errors for Firestore operations
enum FirestoreError: LocalizedError {
    case documentNotFound
    case invalidData(String)
    case networkError
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .documentNotFound:
            return "Document not found in Firestore"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        case .networkError:
            return "Network error occurred"
        case .permissionDenied:
            return "Permission denied to access Firestore"
        }
    }
}
