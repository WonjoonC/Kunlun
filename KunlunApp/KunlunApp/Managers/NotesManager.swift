import Foundation
import SwiftData
import SwiftUI

/**
 * @fileoverview Notes Manager
 * @description Manages notes using SwiftData for iOS 18+ with @Model integration
 * 
 * Features:
 * - SwiftData ModelContainer integration
 * - Automatic persistence and sync
 * - CRUD operations for notes
 * - Search functionality
 * - Error handling and loading states
 */

@MainActor
class NotesManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - SwiftData Context (provided by App)
    private let modelContext: ModelContext
    
    // MARK: - Cloud Integration
    // Use FirestoreIntegration to mirror local changes to Firestore
    private lazy var firestoreIntegration = FirestoreIntegration(context: modelContext)
    
    // MARK: - Initialization
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        print("✅ NotesManager using provided SwiftData context")
    }
    
    // Convenience init for previews (in-memory store)
    convenience init() {
        do {
            let schema = Schema([
                Note.self,
                Tag.self,
                NoteLink.self
            ])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            self.init(modelContext: container.mainContext)
            print("✅ NotesManager preview context initialized (in-memory)")
        } catch {
            fatalError("Failed to initialize in-memory SwiftData for previews: \(error)")
        }
    }
    
    // MARK: - Context Access
    var context: ModelContext { modelContext }
    
    // MARK: - CRUD Operations
    
    func loadNotes() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch notes with sorting
            let descriptor = FetchDescriptor<Note>(
                sortBy: [SortDescriptor(\.modifiedAt, order: .reverse)]
            )
            
            let notes = try modelContext.fetch(descriptor)
            
            // Update UI on main thread
            await MainActor.run {
                self.isLoading = false
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load notes: \(error.localizedDescription)"
                self.isLoading = false
            }
            print("Error loading notes: \(error)")
        }
    }
    
    func addNote(title: String = "", content: String = "") async {
        do {
            let note = Note(title: title, content: content)
            modelContext.insert(note)
            
            try modelContext.save()
            print("✅ Note saved successfully")
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to save note: \(error.localizedDescription)"
            }
            print("Error saving note: \(error)")
        }
    }
    
    func updateNote(_ note: Note, title: String? = nil, content: String? = nil) async {
        do {
            note.update(title: title, content: content)
            try modelContext.save()
            print("✅ Note updated successfully")
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to update note: \(error.localizedDescription)"
            }
            print("Error updating note: \(error)")
        }
    }
    
    func deleteNote(_ note: Note) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            firestoreIntegration.deleteNote(note) { result in
                switch result {
                case .success:
                    print("✅ Note deleted in Firestore and locally: \(note.id.uuidString)")
                    continuation.resume()
                case .failure(let error):
                    Task { @MainActor in
                        self.errorMessage = "Failed to delete note in Firestore: \(error.localizedDescription)"
                    }
                    print("Error deleting note in Firestore: \(error)")
                    // Fallback: keep local note to avoid divergence
                    continuation.resume()
                }
            }
        }
    }
    
    // MARK: - Tag Operations
    
    func addTag(name: String) async -> Tag? {
        do {
            let tag = Tag(name: name)
            modelContext.insert(tag)
            try modelContext.save()
            print("✅ Tag created: \(name)")
            return tag
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to create tag: \(error.localizedDescription)"
            }
            print("Error creating tag: \(error)")
            return nil
        }
    }
    
    func deleteTag(_ tag: Tag) async {
        do {
            modelContext.delete(tag)
            try modelContext.save()
            print("✅ Tag deleted: \(tag.name)")
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to delete tag: \(error.localizedDescription)"
            }
            print("Error deleting tag: \(error)")
        }
    }
    
    // MARK: - Search
    func searchNotes(query: String) async -> [Note] {
        guard !query.isEmpty else { return [] }
        
        do {
            let descriptor = FetchDescriptor<Note>(
                predicate: #Predicate<Note> { note in
                    note.title.localizedStandardContains(query) ||
                    note.content.localizedStandardContains(query)
                },
                sortBy: [SortDescriptor(\.modifiedAt, order: .reverse)]
            )
            
            return try modelContext.fetch(descriptor)
            
        } catch {
            print("Error searching notes: \(error)")
            return []
        }
    }
    
    // MARK: - Utility Methods
    
    func saveContext() async {
        do {
            try modelContext.save()
            print("✅ Context saved successfully")
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to save context: \(error.localizedDescription)"
            }
            print("Error saving context: \(error)")
        }
    }
    
    func resetContext() {
        modelContext.rollback()
        print("✅ Context reset")
    }
}
