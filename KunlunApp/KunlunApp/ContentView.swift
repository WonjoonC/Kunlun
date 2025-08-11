/**
 * @fileoverview Main Content View
 * @description Root view with tab navigation for the Kunlun app
 * 
 * Features:
 * - Tab-based navigation (Notes, Search, Profile)
 * - Clean, minimal design following Apple's HIG
 * - Mobile-first layout optimized for iOS
 * - Proper accessibility and navigation patterns
 */

import SwiftUI

struct ContentView: View {
    
    // MARK: - Environment Objects
    @EnvironmentObject var notesManager: NotesManager
    @EnvironmentObject var themeManager: ThemeManager
    
    // MARK: - State
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // MARK: - Notes Tab
            NavigationView {
                NotesListView()
                    .navigationTitle("Notes")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Image(systemName: "note.text")
                Text("Notes")
            }
            .tag(0)
            
            // MARK: - Search Tab
            NavigationView {
                SearchView()
                    .navigationTitle("Search")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Image(systemName: "magnifyingglass")
                Text("Search")
            }
            .tag(1)
            
            // MARK: - Profile Tab
            NavigationView {
                ProfileView()
                    .navigationTitle("Profile")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Image(systemName: "person.circle")
                Text("Profile")
            }
            .tag(2)
        }
        .accentColor(themeManager.accentColor)
        .onAppear {
            // Load initial data
            Task {
                await notesManager.loadNotes()
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ContentView()
        .environmentObject(NotesManager())
        .environmentObject(ThemeManager())
}
