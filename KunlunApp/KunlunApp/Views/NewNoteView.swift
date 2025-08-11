import SwiftUI
import SwiftData

/**
 * @fileoverview New Note View
 * @description View for creating new notes with SwiftData integration
 * 
 * Features:
 * - SwiftData integration for automatic persistence
 * - Clean, minimal form design
 * - Validation and error handling
 * - Proper accessibility support
 */

struct NewNoteView: View {
    
    // MARK: - Environment Objects
    @EnvironmentObject var notesManager: NotesManager
    
    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - State
    @State private var title = ""
    @State private var content = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
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
                        .frame(minHeight: 300)
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
            .navigationTitle("New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await saveNote()
                        }
                    }
                    .disabled(title.isEmpty && content.isEmpty || isSaving)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func saveNote() async {
        isSaving = true
        errorMessage = nil
        
        do {
            // Create note using SwiftData
            let note = Note(title: title, content: content)
            modelContext.insert(note)
            
            try modelContext.save()
            // Push to Firestore
            await MainActor.run {
                SyncManager.shared.syncNote(note) { result in
                    switch result {
                    case .success:
                        print("✅ Firestore note created via SyncManager: \(note.id.uuidString)")
                    case .failure(let error):
                        print("❌ SyncManager.syncNote failed: \(error.localizedDescription)")
                    }
                }
            }
            
            await MainActor.run {
                isSaving = false
                dismiss()
            }
            
        } catch {
            await MainActor.run {
                errorMessage = "Failed to save note: \(error.localizedDescription)"
                isSaving = false
            }
            print("Error saving note: \(error)")
        }
    }
}

// MARK: - Preview
#Preview {
    NewNoteView()
        .environmentObject(NotesManager())
}
