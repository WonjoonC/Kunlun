import SwiftUI
import SwiftData

/**
 * @fileoverview Note Detail View
 * @description View for displaying and editing notes with SwiftData integration
 * 
 * Features:
 * - SwiftData integration for automatic persistence
 * - Inline editing with validation
 * - Clean, minimal design
 * - Proper accessibility support
 */

struct NoteDetailView: View {
    
    // MARK: - Environment Objects
    @EnvironmentObject var notesManager: NotesManager
    
    // MARK: - Environment
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - Properties
    let note: Note
    
    // MARK: - State
    @State private var title: String
    @State private var content: String
    @State private var isEditing = false
    @State private var hasChanges = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    // MARK: - Initialization
    init(note: Note) {
        self.note = note
        self._title = State(initialValue: note.title)
        self._content = State(initialValue: note.content)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if isEditing {
                editingView
            } else {
                readingView
            }
        }
        .navigationTitle(isEditing ? "Edit Note" : note.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isEditing {
                    Button("Save") {
                        Task {
                            await saveChanges()
                        }
                    }
                    .disabled(!hasChanges || isSaving)
                } else {
                    Button("Edit") {
                        startEditing()
                    }
                }
            }
            
            if isEditing {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        cancelEditing()
                    }
                    .disabled(isSaving)
                }
            }
        }
        .onChange(of: title) { _, _ in
            checkForChanges()
        }
        .onChange(of: content) { _, _ in
            checkForChanges()
        }
    }
    
    // MARK: - Reading View
    
    private var readingView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .kunlunLarge) {
                // Note content
                Text(note.displayContent)
                    .font(.kunlunBody)
                    .foregroundColor(.kunlunBlack)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Tags display
                if !note.tags.isEmpty {
                    VStack(alignment: .leading, spacing: .kunlunSmall) {
                        Text("Tags")
                            .font(.kunlunHeadline)
                            .foregroundColor(.kunlunBlack)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(note.tags) { tag in
                                    Text(tag.name)
                                        .font(.kunlunCaption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.kunlunJade.opacity(0.2))
                                        .foregroundColor(.kunlunJade)
                                        .cornerRadius(12)
                                }
                            }
                        }
                    }
                }
                
                Spacer(minLength: 100)
            }
            .padding(.kunlunMedium)
        }
        .overlay(
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: .kunlunSmall) {
                        if note.isModified {
                            Text("Modified \(note.modifiedAt, style: .relative)")
                                .font(.kunlunCaption)
                                .foregroundColor(.kunlunBlack)
                        }
                        
                        Text("Created \(note.createdAt, style: .relative)")
                            .font(.kunlunCaption)
                            .foregroundColor(.kunlunBlack)
                    }
                    .padding(.horizontal, .kunlunMedium)
                    .padding(.bottom, .kunlunSmall)
                }
            }
        )
    }
    
    // MARK: - Editing View
    
    private var editingView: some View {
        VStack(spacing: .kunlunLarge) {
            // Title field
            VStack(alignment: .leading, spacing: .kunlunSmall) {
                Text("Title")
                    .font(.kunlunHeadline)
                    .foregroundColor(.kunlunBlack)
                
                TextField("Note title", text: $title)
                    .font(.kunlunBody)
                    .foregroundColor(.kunlunBlack)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(.kunlunMedium)
                    .background(Color.kunlunWhite)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.kunlunBlack.opacity(0.2))
                    }
            }
            
            // Content field
            VStack(alignment: .leading, spacing: .kunlunSmall) {
                Text("Content")
                    .font(.kunlunHeadline)
                    .foregroundColor(.kunlunBlack)
                
                TextEditor(text: $content)
                    .font(.kunlunBody)
                    .foregroundColor(.kunlunBlack)
                    .frame(minHeight: 200)
                    .padding(.kunlunMedium)
                    .background(Color.kunlunWhite)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.kunlunBlack.opacity(0.2))
                    }
            }
            
            // Error message
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.kunlunCaption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.kunlunMedium)
            }
            
            Spacer()
        }
        .padding(.kunlunMedium)
    }
    
    // MARK: - Actions
    
    private func startEditing() {
        isEditing = true
        hasChanges = false
        errorMessage = nil
    }
    
    private func saveChanges() async {
        isSaving = true
        errorMessage = nil
        
        do {
            // Update note using SwiftData
            note.update(title: title, content: content)
            try modelContext.save()
            // Push update to Firestore
            await MainActor.run {
                SyncManager.shared.syncNote(note) { result in
                    switch result {
                    case .success:
                        print("✅ Firestore note updated via SyncManager: \(note.id.uuidString)")
                    case .failure(let error):
                        print("❌ SyncManager.syncNote (update) failed: \(error.localizedDescription)")
                    }
                }
            }
            
            await MainActor.run {
                isEditing = false
                hasChanges = false
                isSaving = false
            }
            
        } catch {
            await MainActor.run {
                errorMessage = "Failed to save changes: \(error.localizedDescription)"
                isSaving = false
            }
            print("Error saving note changes: \(error)")
        }
    }
    
    private func cancelEditing() {
        title = note.title
        content = note.content
        isEditing = false
        hasChanges = false
        errorMessage = nil
    }
    
    private func checkForChanges() {
        hasChanges = title != note.title || content != note.content
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        NoteDetailView(note: Note(title: "Sample Note", content: "This is a sample note content."))
            .environmentObject(NotesManager())
    }
}
