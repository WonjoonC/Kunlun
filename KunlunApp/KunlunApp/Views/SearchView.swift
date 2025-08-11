import SwiftUI
import SwiftData

/**
 * @fileoverview Search View
 * @description View for searching notes with SwiftData integration
 * 
 * Features:
 * - SwiftData integration for efficient searching
 * - Real-time search results
 * - Clean, minimal design
 * - Proper accessibility support
 */

struct SearchView: View {
    
    // MARK: - Environment Objects
    @EnvironmentObject var notesManager: NotesManager
    
    // MARK: - State
    @State private var searchText = ""
    @State private var searchResults: [Note] = []
    @State private var isSearching = false
    
    var body: some View {
        VStack {
            // Search Bar
            HStack(spacing: .kunlunSmall) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.kunlunJade)
                    .font(.kunlunBody)
                
                TextField("Search notes...", text: $searchText)
                    .font(.kunlunBody)
                    .foregroundColor(.kunlunBlack)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onChange(of: searchText) { _, _ in
                        Task {
                            await performSearch()
                        }
                    }
                
                if !searchText.isEmpty {
                    Button("Clear") {
                        searchText = ""
                        searchResults = []
                    }
                    .foregroundColor(.kunlunJade)
                }
            }
            .padding(.horizontal, .kunlunMedium)
            
            // Search Results
            if searchText.isEmpty {
                VStack(spacing: .kunlunLarge) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.kunlunBlack)
                    
                    Text("Search Notes")
                        .font(.kunlunTitle2)
                        .fontWeight(.medium)
                        .foregroundColor(.kunlunBlack)
                    
                    Text("Type in the search bar above to find your notes")
                        .font(.kunlunBody)
                        .foregroundColor(.kunlunBlack)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isSearching {
                VStack(spacing: .kunlunLarge) {
                    ProgressView()
                        .scaleEffect(1.5)
                    
                    Text("Searching...")
                        .font(.kunlunBody)
                        .foregroundColor(.kunlunBlack)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchResults.isEmpty {
                VStack(spacing: .kunlunLarge) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.kunlunBlack)
                    
                    Text("No Results")
                        .font(.kunlunTitle2)
                        .fontWeight(.medium)
                        .foregroundColor(.kunlunBlack)
                    
                    Text("Try different keywords or check your spelling")
                        .font(.kunlunBody)
                        .foregroundColor(.kunlunBlack)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(searchResults) { note in
                    NavigationLink(destination: NoteDetailView(note: note)) {
                        NoteRowView(note: note)
                    }
                }
            }
            
            Spacer()
        }
        .navigationTitle("Search")
    }
    
    // MARK: - Search Logic
    
    private func performSearch() async {
        guard !searchText.isEmpty else {
            await MainActor.run {
                searchResults = []
            }
            return
        }
        
        await MainActor.run {
            isSearching = true
        }
        
        let results = await notesManager.searchNotes(query: searchText)
        
        await MainActor.run {
            searchResults = results
            isSearching = false
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        SearchView()
            .environmentObject(NotesManager())
    }
}
