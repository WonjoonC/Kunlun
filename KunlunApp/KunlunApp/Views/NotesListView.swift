import SwiftUI
import SwiftData

/**
 * @fileoverview Notes List View
 * @description Main view displaying all notes with SwiftData @Query integration
 * 
 * Features:
 * - SwiftData @Query for automatic data fetching and updates
 * - Clean, minimal design following Apple's HIG
 * - Mobile-first layout optimized for iOS
 * - Proper accessibility and navigation patterns
 */

struct NotesListView: View {
    
    // MARK: - Environment Objects
    @EnvironmentObject var notesManager: NotesManager
    @EnvironmentObject var themeManager: ThemeManager
    
    // MARK: - SwiftData Query
    @Query(sort: \Note.modifiedAt, order: .reverse) private var notes: [Note]
    
    // MARK: - State
    @State private var showingNewNote = false
    
    var body: some View {
        List {
            if notes.isEmpty {
                VStack(spacing: .kunlunLarge) {
                    Image(systemName: "note.text")
                        .font(.system(size: 48))
                        .foregroundColor(.kunlunBlack)
                    
                    Text("No Notes Yet")
                        .font(.kunlunTitle2)
                        .fontWeight(.medium)
                        .foregroundColor(.kunlunBlack)
                    
                    Text("Tap the + button to create your first note")
                        .font(.kunlunBody)
                        .foregroundColor(.kunlunBlack)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .listRowBackground(Color.kunlunWhite)
            } else {
                ForEach(notes) { note in
                    NavigationLink(destination: NoteDetailView(note: note)) {
                        NoteRowView(note: note)
                    }
                }
                .onDelete(perform: deleteNotes)
            }
        }
        .navigationTitle("Notes")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingNewNote = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewNote) {
            NewNoteView()
        }
        .refreshable {
            // Refresh data by triggering a context save
            await notesManager.saveContext()
        }
    }
    
    // MARK: - Actions
    
    private func deleteNotes(offsets: IndexSet) {
        Task {
            for index in offsets {
                let note = notes[index]
                await notesManager.deleteNote(note)
            }
        }
    }
}

// MARK: - Note Row View
struct NoteRowView: View {
    let note: Note
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(note.displayTitle)
                    .font(.kunlunHeadline)
                    .foregroundColor(.kunlunBlack)
                    .lineLimit(1)
                
                Spacer()
                
                if note.isModified {
                    Text("Modified")
                        .font(.kunlunCaption)
                        .foregroundColor(.kunlunBlack)
                }
            }
            
            Text(note.displayContent)
                .font(.kunlunBody)
                .foregroundColor(.kunlunBlack)
                .lineLimit(2)
            
            HStack {
                Text(note.modifiedAt, style: .relative)
                    .font(.kunlunCaption)
                    .foregroundColor(.kunlunBlack)
                
                Spacer()
                
                // Display tags if any
                if !note.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(note.tags) { tag in
                                Text(tag.name)
                                    .font(.kunlunCaption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.kunlunJade.opacity(0.2))
                                    .foregroundColor(.kunlunJade)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, .kunlunTiny)
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        NotesListView()
            .environmentObject(NotesManager())
            .environmentObject(ThemeManager())
    }
}
