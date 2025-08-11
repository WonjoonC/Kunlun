import Foundation
import SwiftData
import FirebaseFirestore

/// FirestoreIntegration provides a high-level interface for integrating SwiftData with Firestore
/// Handles data synchronization, conflict resolution, and provides a unified API for data operations
@MainActor
class FirestoreIntegration: ObservableObject {
    
    // MARK: - Properties
    /// Reference to the Firestore client
    private let firestoreClient: FirestoreClient
    
    /// SwiftData context for local operations
    private let context: ModelContext
    
    /// Queue for managing Firestore operations
    private let operationQueue = DispatchQueue(label: "com.kunlun.firestore.integration", qos: .userInitiated)
    
    /// Track pending operations to avoid conflicts
    private var pendingOperations: Set<String> = []
    
    // MARK: - Initialization
    init(context: ModelContext) {
        self.firestoreClient = FirestoreClient.shared
        self.context = context
    }
    
    // MARK: - Note Integration
    
    /// Create a note both locally and in Firestore
    /// - Parameters:
    ///   - title: Note title
    ///   - content: Note content
    ///   - tags: Array of tag names
    ///   - completion: Completion handler with the created note or error
    func createNote(title: String, content: String, tags: [String] = [], completion: @escaping (Result<Note, Error>) -> Void) {
        // Create note locally first
        let note = Note(title: title, content: content)
        
        // Add tags if provided
        if !tags.isEmpty {
            for tagName in tags {
                let tag = getOrCreateTag(name: tagName)
                note.addTag(tag)
            }
        }
        
        // Insert into context
        context.insert(note)
        
        // Save locally
        do {
            try context.save()
        } catch {
            completion(.failure(error))
            return
        }
        
        // Sync to Firestore
        firestoreClient.createNote(note) { result in
            switch result {
            case .success:
                print("✅ Firestore note created: \(note.id.uuidString)")
                completion(.success(note))
            case .failure(let error):
                print("❌ Firestore createNote failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    /// Update a note both locally and in Firestore
    /// - Parameters:
    ///   - note: The note to update
    ///   - title: New title (optional)
    ///   - content: New content (optional)
    ///   - tags: New tags (optional)
    ///   - completion: Completion handler with success/failure result
    func updateNote(_ note: Note, title: String? = nil, content: String? = nil, tags: [String]? = nil, completion: @escaping (Result<Void, Error>) -> Void) {
        // Update locally first
        note.update(title: title, content: content)
        
        // Update tags if provided
        if let tags = tags {
            // Clear existing tags
            note.tags.removeAll()
            
            // Add new tags
            for tagName in tags {
                let tag = getOrCreateTag(name: tagName)
                note.addTag(tag)
            }
        }
        
        // Save locally
        do {
            try context.save()
        } catch {
            completion(.failure(error))
            return
        }
        
        // Sync to Firestore
        firestoreClient.updateNote(note) { result in
            switch result {
            case .success:
                print("✅ Firestore note updated: \(note.id.uuidString)")
                completion(.success(()))
            case .failure(let error):
                print("❌ Firestore updateNote failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    /// Delete a note both locally and in Firestore
    /// - Parameters:
    ///   - note: The note to delete
    ///   - completion: Completion handler with success/failure result
    func deleteNote(_ note: Note, completion: @escaping (Result<Void, Error>) -> Void) {
        let noteId = note.id.uuidString
        
        // Delete from Firestore first
        firestoreClient.deleteNote(noteId: noteId) { [weak self] result in
            switch result {
            case .success:
                // Delete locally after successful Firestore deletion
                Task { @MainActor in
                    self?.context.delete(note)
                    do {
                        try self?.context.save()
                        completion(.success(()))
                    } catch {
                        completion(.failure(error))
                    }
                }
                
            case .failure(let error):
                // If Firestore deletion fails, we could implement retry logic
                completion(.failure(error))
            }
        }
    }
    
    /// Fetch notes from Firestore and sync with local SwiftData
    /// - Parameter completion: Completion handler with success/failure result
    func syncNotesFromFirestore(completion: @escaping (Result<Void, Error>) -> Void) {
        firestoreClient.fetchAllNotes { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let notesData):
                // Process the fetched data
                Task {
                    await MainActor.run {
                        self.processFirestoreNotes(notesData, completion: completion)
                    }
                }
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Tag Integration
    
    /// Create a tag both locally and in Firestore
    /// - Parameters:
    ///   - name: Tag name
    ///   - completion: Completion handler with the created tag or error
    func createTag(name: String, completion: @escaping (Result<Tag, Error>) -> Void) {
        // Create tag locally first
        let tag = Tag(name: name)
        
        // Insert into context
        context.insert(tag)
        
        // Save locally
        do {
            try context.save()
        } catch {
            completion(.failure(error))
            return
        }
        
        // Sync to Firestore
        firestoreClient.createTag(tag) { result in
            switch result {
            case .success:
                completion(.success(tag))
            case .failure(let error):
                // If Firestore fails, we still have the local tag
                print("Warning: Failed to sync tag to Firestore: \(error)")
                completion(.success(tag))
            }
        }
    }
    
    /// Update a tag both locally and in Firestore
    /// - Parameters:
    ///   - tag: The tag to update
    ///   - name: New name
    ///   - completion: Completion handler with success/failure result
    func updateTag(_ tag: Tag, name: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // Update locally first
        tag.name = name
        
        // Save locally
        do {
            try context.save()
        } catch {
            completion(.failure(error))
            return
        }
        
        // Sync to Firestore
        firestoreClient.updateTag(tag) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                // If Firestore fails, we still have the local update
                print("Warning: Failed to sync tag update to Firestore: \(error)")
                completion(.success(()))
            }
        }
    }
    
    /// Delete a tag both locally and in Firestore
    /// - Parameters:
    ///   - tag: The tag to delete
    ///   - completion: Completion handler with success/failure result
    func deleteTag(_ tag: Tag, completion: @escaping (Result<Void, Error>) -> Void) {
        let tagId = tag.id.uuidString
        
        // Delete from Firestore first
        firestoreClient.deleteTag(tagId: tagId) { [weak self] result in
            switch result {
            case .success:
                // Delete locally after successful Firestore deletion
                self?.context.delete(tag)
                do {
                    try self?.context.save()
                    completion(.success(()))
                } catch {
                    completion(.failure(error))
                }
                
            case .failure(let error):
                // If Firestore deletion fails, we could implement retry logic
                completion(.failure(error))
            }
        }
    }
    
    /// Fetch tags from Firestore and sync with local Core Data
    /// - Parameter completion: Completion handler with success/failure result
    func syncTagsFromFirestore(completion: @escaping (Result<Void, Error>) -> Void) {
        firestoreClient.fetchAllTags { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let tagsData):
                Task {
                    await MainActor.run {
                        self.processFirestoreTags(tagsData, completion: completion)
                    }
                }
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Fetch note links from Firestore and sync with local Core Data
    /// - Parameter completion: Completion handler with success/failure result
    func syncNoteLinksFromFirestore(completion: @escaping (Result<Void, Error>) -> Void) {
        firestoreClient.fetchAllNoteLinks { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let linksData):
                Task {
                    await MainActor.run {
                        self.processFirestoreNoteLinks(linksData, completion: completion)
                    }
                }
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - NoteLink Integration
    
    /// Create a link between two notes both locally and in Firestore
    /// - Parameters:
    ///   - sourceNote: The source note
    ///   - targetNote: The target note
    ///   - completion: Completion handler with the created link or error
    func createNoteLink(sourceNote: Note, targetNote: Note, completion: @escaping (Result<NoteLink, Error>) -> Void) {
        // Create link locally first
        let link = NoteLink(source: sourceNote, target: targetNote)
        
        // Update the notes' link collections
        sourceNote.outgoingLinks.append(link)
        targetNote.incomingLinks.append(link)
        
        // Save locally
        do {
            try context.save()
        } catch {
            completion(.failure(error))
            return
        }
        
        // Sync to Firestore
        firestoreClient.createNoteLink(link) { result in
            switch result {
            case .success:
                completion(.success(link))
            case .failure(let error):
                // If Firestore fails, we still have the local link
                print("Warning: Failed to sync note link to Firestore: \(error)")
                completion(.success(link))
            }
        }
    }
    
    /// Delete a note link both locally and in Firestore
    /// - Parameters:
    ///   - link: The link to delete
    ///   - completion: Completion handler with success/failure result
    func deleteNoteLink(_ link: NoteLink, completion: @escaping (Result<Void, Error>) -> Void) {
        let linkId = link.id.uuidString
        
        // Delete from Firestore first
        firestoreClient.deleteNoteLink(linkId: linkId) { [weak self] result in
            switch result {
            case .success:
                // Remove from notes' collections
                if let sourceNote = link.source {
                    // Remove the link from source note's outgoing links
                    if let index = sourceNote.outgoingLinks.firstIndex(of: link) {
                        sourceNote.outgoingLinks.remove(at: index)
                    }
                }
                if let targetNote = link.target {
                    // Remove the link from target note's incoming links
                    if let index = targetNote.incomingLinks.firstIndex(of: link) {
                        targetNote.incomingLinks.remove(at: index)
                    }
                }
                
                // Delete locally
                self?.context.delete(link)
                do {
                    try self?.context.save()
                    completion(.success(()))
                } catch {
                    completion(.failure(error))
                }
                
            case .failure(let error):
                // If Firestore deletion fails, we could implement retry logic
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Data Synchronization
    
    /// Perform a full sync from Firestore to local Core Data
    /// - Parameter completion: Completion handler with success/failure result
    func performFullSync(completion: @escaping (Result<Void, Error>) -> Void) {
        let group = DispatchGroup()
        var syncError: Error?
        
        // Sync notes
        group.enter()
        syncNotesFromFirestore { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                syncError = error
            }
            group.leave()
        }
        
        // Sync tags
        group.enter()
        syncTagsFromFirestore { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                syncError = error
            }
            group.leave()
        }
        
        // Sync note links
        group.enter()
        firestoreClient.fetchAllNoteLinks { [weak self] result in
            guard let self = self else {
                group.leave()
                return
            }
            
            switch result {
            case .success(let linksData):
                Task {
                    await MainActor.run {
                        self.processFirestoreNoteLinks(linksData) { result in
                            switch result {
                            case .success:
                                break
                            case .failure(let error):
                                syncError = error
                            }
                            group.leave()
                        }
                    }
                }
                
            case .failure(let error):
                syncError = error
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            if let error = syncError {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Get or create a tag with the given name
    /// - Parameter name: Tag name
    /// - Returns: The Tag object
    private func getOrCreateTag(name: String) -> Tag {
        var descriptor = FetchDescriptor<Tag>(
            predicate: #Predicate<Tag> { tag in
                tag.name == name
            }
        )
        descriptor.fetchLimit = 1
        
        if let existingTag = try? context.fetch(descriptor).first {
            return existingTag
        } else {
            let newTag = Tag(name: name)
            context.insert(newTag)
            return newTag
        }
    }
    
    /// Process Firestore notes data and sync with local SwiftData
    /// - Parameters:
    ///   - notesData: Array of note data from Firestore
    ///   - completion: Completion handler with success/failure result
    private func processFirestoreNotes(_ notesData: [[String: Any]], completion: @escaping (Result<Void, Error>) -> Void) {
        for noteData in notesData {
            guard let noteIdString = noteData["id"] as? String,
                  let noteId = UUID(uuidString: noteIdString) else { continue }
            
            // Check if note already exists locally
            var descriptor = FetchDescriptor<Note>(
                predicate: #Predicate<Note> { note in
                    note.id.uuidString == noteIdString
                }
            )
            descriptor.fetchLimit = 1
            
            if let existingNote = try? context.fetch(descriptor).first {
                // Update existing note if Firestore version is newer
                if let firestoreModifiedAt = (noteData["modifiedAt"] as? Timestamp)?.dateValue() ?? (noteData["modifiedAt"] as? Date),
                   firestoreModifiedAt > existingNote.modifiedAt {
                    updateNoteFromFirestore(existingNote, with: noteData)
                }
            } else {
                // Create new note from Firestore data
                createNoteFromFirestore(noteData)
            }
        }
        
        // Save all changes
        do {
            try context.save()
            completion(.success(()))
        } catch {
            completion(.failure(error))
        }
    }
    
    /// Process Firestore tags data and sync with local SwiftData
    /// - Parameters:
    ///   - tagsData: Array of tag data from Firestore
    ///   - completion: Completion handler with success/failure result
    private func processFirestoreTags(_ tagsData: [[String: Any]], completion: @escaping (Result<Void, Error>) -> Void) {
        for tagData in tagsData {
            guard let tagIdString = tagData["id"] as? String,
                  let tagId = UUID(uuidString: tagIdString) else { continue }
            
            // Check if tag already exists locally
            var descriptor = FetchDescriptor<Tag>(
                predicate: #Predicate<Tag> { tag in
                    tag.id.uuidString == tagIdString
                }
            )
            descriptor.fetchLimit = 1
            
            if let existingTag = try? context.fetch(descriptor).first {
                // Update existing tag
                existingTag.name = tagData["name"] as? String ?? existingTag.name
            } else {
                // Create new tag from Firestore data
                let newTag = Tag(name: tagData["name"] as? String ?? "Untitled Tag")
                newTag.id = tagId
                context.insert(newTag)
            }
        }
        
        // Save all changes
        do {
            try context.save()
            completion(.success(()))
        } catch {
            completion(.failure(error))
        }
    }
    
    /// Process Firestore note links data and sync with local SwiftData
    /// - Parameters:
    ///   - linksData: Array of link data from Firestore
    ///   - completion: Completion handler with success/failure result
    private func processFirestoreNoteLinks(_ linksData: [[String: Any]], completion: @escaping (Result<Void, Error>) -> Void) {
        for linkData in linksData {
            guard let linkIdString = linkData["id"] as? String,
                  let linkId = UUID(uuidString: linkIdString),
                  let sourceIdString = linkData["sourceId"] as? String,
                  let sourceId = UUID(uuidString: sourceIdString),
                  let targetIdString = linkData["targetId"] as? String,
                  let targetId = UUID(uuidString: targetIdString) else { continue }
            
            // Check if link already exists locally
            var descriptor = FetchDescriptor<NoteLink>(
                predicate: #Predicate<NoteLink> { link in
                    link.id.uuidString == linkIdString
                }
            )
            descriptor.fetchLimit = 1
            
            if (try? context.fetch(descriptor).first) != nil {
                continue // Link already exists
            }
            
            // Find source and target notes
            var sourceDescriptor = FetchDescriptor<Note>(
                predicate: #Predicate<Note> { note in
                    note.id.uuidString == sourceIdString
                }
            )
            sourceDescriptor.fetchLimit = 1
            
            var targetDescriptor = FetchDescriptor<Note>(
                predicate: #Predicate<Note> { note in
                    note.id.uuidString == targetIdString
                }
            )
            targetDescriptor.fetchLimit = 1
            
            if let sourceNote = try? context.fetch(sourceDescriptor).first,
               let targetNote = try? context.fetch(targetDescriptor).first {
                // Create new link from Firestore data
                let newLink = NoteLink(source: sourceNote, target: targetNote)
                newLink.id = linkId
                if let ts = linkData["createdAt"] as? Timestamp {
                    newLink.createdAt = ts.dateValue()
                } else if let d = linkData["createdAt"] as? Date {
                    newLink.createdAt = d
                } else {
                    newLink.createdAt = Date()
                }
                
                // Update notes' link collections
                sourceNote.outgoingLinks.append(newLink)
                targetNote.incomingLinks.append(newLink)
                
                // Insert the link into context
                context.insert(newLink)
            }
        }
        
        // Save all changes
        do {
            try context.save()
            completion(.success(()))
        } catch {
            completion(.failure(error))
        }
    }
    
    /// Update a local note with data from Firestore
    /// - Parameters:
    ///   - note: The local note to update
    ///   - firestoreData: The data from Firestore
    private func updateNoteFromFirestore(_ note: Note, with firestoreData: [String: Any]) {
        note.title = firestoreData["title"] as? String ?? note.title
        note.content = firestoreData["content"] as? String ?? note.content
        if let ts = firestoreData["modifiedAt"] as? Timestamp {
            note.modifiedAt = ts.dateValue()
        } else if let d = firestoreData["modifiedAt"] as? Date {
            note.modifiedAt = d
        }
        
        // Note: Tags and links are handled separately to maintain relationships
    }
    
    /// Create a new local note from Firestore data
    /// - Parameter firestoreData: The data from Firestore
    private func createNoteFromFirestore(_ firestoreData: [String: Any]) {
        let note = Note(
            title: firestoreData["title"] as? String ?? "",
            content: firestoreData["content"] as? String ?? ""
        )
        
        if let idString = firestoreData["id"] as? String,
           let id = UUID(uuidString: idString) {
            note.id = id
        }
        
        if let ts = firestoreData["createdAt"] as? Timestamp {
            note.createdAt = ts.dateValue()
        } else if let d = firestoreData["createdAt"] as? Date {
            note.createdAt = d
        }
        if let ts = firestoreData["modifiedAt"] as? Timestamp {
            note.modifiedAt = ts.dateValue()
        } else if let d = firestoreData["modifiedAt"] as? Date {
            note.modifiedAt = d
        }
        
        // Insert into context
        context.insert(note)
        
        // Note: Tags and links are handled separately to maintain relationships
    }
}

// MARK: - Notes for Developers

// FirestoreIntegration now requires a SwiftData ModelContext to be passed in during initialization
// This is because the app uses SwiftUI app lifecycle with SwiftData instead of Core Data
// 
// Usage in SwiftUI views:
// let integration = FirestoreIntegration(context: notesManager.context)
// integration.createNote(title: "Title", content: "Content") { result in
//     // Handle result
// }
