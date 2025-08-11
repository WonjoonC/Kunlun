import SwiftUI
import SwiftData

/**
 * @fileoverview Profile View
 * @description View for app settings and database management with SwiftData integration
 * 
 * Features:
 * - Theme and appearance settings
 * - SwiftData database statistics
 * - Database management options
 * - App information
 */

struct ProfileView: View {
    
    // MARK: - Environment Objects
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var notesManager: NotesManager
    
    // MARK: - Sync Manager (observe status)
    @ObservedObject private var syncManager = SyncManager.shared
    
    // MARK: - SwiftData Query
    @Query private var notes: [Note]
    @Query private var tags: [Tag]
    @Query private var noteLinks: [NoteLink]
    
    var body: some View {
        List {
            // Theme Section
            Section("Appearance") {
                HStack(spacing: .kunlunMedium) {
                    Image(systemName: "paintbrush")
                        .foregroundColor(.kunlunJade)
                        .frame(width: 24)
                    
                    Text("Theme")
                        .font(.kunlunBody)
                        .foregroundColor(.kunlunBlack)
                    
                    Spacer()
                    
                    Picker("Theme", selection: $themeManager.currentColorScheme) {
                        Text("Light").tag(ColorScheme.light)
                        Text("Dark").tag(ColorScheme.dark)
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                HStack(spacing: .kunlunMedium) {
                    Image(systemName: "circle.lefthalf.filled")
                        .foregroundColor(.kunlunJade)
                        .frame(width: 24)
                    
                    Text("Accent Color")
                        .font(.kunlunBody)
                        .foregroundColor(.kunlunBlack)
                    
                    Spacer()
                    
                    ColorPicker("", selection: $themeManager.accentColor, supportsOpacity: false)
                        .labelsHidden()
                }
            }
            
            // Database Section
            Section("Database") {
                HStack(spacing: .kunlunMedium) {
                    Image(systemName: "doc.text")
                        .foregroundColor(.kunlunJade)
                        .frame(width: 24)
                    
                    Text("Notes")
                        .font(.kunlunBody)
                        .foregroundColor(.kunlunBlack)
                    
                    Spacer()
                    
                    Text("\(notes.count)")
                        .font(.kunlunBody)
                        .foregroundColor(.kunlunBlack)
                }
                
                HStack(spacing: .kunlunMedium) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(.kunlunJade)
                        .frame(width: 24)
                    Text("Sync Status")
                        .font(.kunlunBody)
                        .foregroundColor(.kunlunBlack)
                    Spacer()
                    Text(statusText(syncManager.syncStatus))
                        .font(.kunlunBody)
                        .foregroundColor(.kunlunBlack)
                }
                
                HStack(spacing: .kunlunMedium) {
                    Image(systemName: "clock")
                        .foregroundColor(.kunlunJade)
                        .frame(width: 24)
                    Text("Last Sync")
                        .font(.kunlunBody)
                        .foregroundColor(.kunlunBlack)
                    Spacer()
                    Text(lastSyncText(syncManager.lastSyncTimestamp))
                        .font(.kunlunBody)
                        .foregroundColor(.kunlunBlack)
                }
                
                HStack(spacing: .kunlunMedium) {
                    Image(systemName: "tag")
                        .foregroundColor(.kunlunJade)
                        .frame(width: 24)
                    
                    Text("Tags")
                        .font(.kunlunBody)
                        .foregroundColor(.kunlunBlack)
                    
                    Spacer()
                    
                    Text("\(tags.count)")
                        .font(.kunlunBody)
                        .foregroundColor(.kunlunBlack)
                }
                
                HStack(spacing: .kunlunMedium) {
                    Image(systemName: "link")
                        .foregroundColor(.kunlunJade)
                        .frame(width: 24)
                    
                    Text("Note Links")
                        .font(.kunlunBody)
                        .foregroundColor(.kunlunBlack)
                    
                    Spacer()
                    
                    Text("\(noteLinks.count)")
                        .font(.kunlunBody)
                        .foregroundColor(.kunlunBlack)
                }
                
                // Database management buttons
                Button(action: {
                    Task {
                        await notesManager.saveContext()
                    }
                }) {
                    HStack(spacing: .kunlunMedium) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.kunlunJade)
                            .frame(width: 24)
                        
                        Text("Sync Database")
                            .font(.kunlunBody)
                            .foregroundColor(.kunlunBlack)
                    }
                }
                
                Button(action: {
                    notesManager.resetContext()
                }) {
                    HStack(spacing: .kunlunMedium) {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        
                        Text("Reset Changes")
                            .font(.kunlunBody)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            // App Info Section
            Section("App Info") {
                HStack(spacing: .kunlunMedium) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.kunlunJade)
                        .frame(width: 24)
                    
                    Text("Version")
                        .font(.kunlunBody)
                        .foregroundColor(.kunlunBlack)
                    
                    Spacer()
                    
                    Text("1.0.0")
                        .font(.kunlunBody)
                        .foregroundColor(.kunlunBlack)
                }
                
                HStack(spacing: .kunlunMedium) {
                    Image(systemName: "doc.text")
                        .foregroundColor(.kunlunJade)
                        .frame(width: 24)
                    
                    Text("Build")
                        .font(.kunlunBody)
                        .foregroundColor(.kunlunBlack)
                    
                    Spacer()
                    
                    Text("1")
                        .font(.kunlunBody)
                        .foregroundColor(.kunlunBlack)
                }
            }
            
            // About Section
            Section("About") {
                HStack(spacing: .kunlunMedium) {
                    Image(systemName: "heart")
                        .foregroundColor(.kunlunJade)
                        .frame(width: 24)
                    
                    Text("Made with ❤️")
                        .font(.kunlunBody)
                        .foregroundColor(.kunlunBlack)
                }
                
                HStack(spacing: .kunlunMedium) {
                    Image(systemName: "globe")
                        .foregroundColor(.kunlunJade)
                        .frame(width: 24)
                    
                    Text("Kunlun Notes")
                        .font(.kunlunBody)
                        .foregroundColor(.kunlunBlack)
                }
            }
            
            // Add crash test button in debug builds
            crashTestButton
        }
        .navigationTitle("Profile")
    }
}

// MARK: - Crashlytics Test Extension
extension ProfileView {
    /// Adds a test crash button for Crashlytics testing
    /// Only visible in debug builds
    private var crashTestButton: some View {
        #if DEBUG
        Section("Development") {
            Button(action: {
                // Force a test crash for Crashlytics testing
                let numbers = [0]
                let _ = numbers[1] // This will cause a crash
            }) {
                HStack(spacing: .kunlunMedium) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                        .frame(width: 24)
                    
                    Text("Test Crash (Debug Only)")
                        .font(.kunlunBody)
                        .foregroundColor(.red)
                }
            }
            
            Button("Full Sync Now") {
                SyncManager.shared.performFullSync { result in
                    print("Full Sync result: \(result)")
                }
            }
            
            Button("Incremental Sync (Notes + Tags)") {
                SyncManager.shared.performIncrementalSync(dataTypes: [.notes, .tags]) { result in
                    print("Incremental Sync result: \(result)")
                }
            }
        }
        #else
        EmptyView()
        #endif
    }
}

// MARK: - Helpers
extension ProfileView {
    fileprivate func statusText(_ status: SyncStatus) -> String {
        switch status {
        case .idle: return "Idle"
        case .syncing: return "Syncing"
        case .completed: return "Completed"
        case .failed(let error): return "Failed: \(error.localizedDescription)"
        }
    }
    
    fileprivate func lastSyncText(_ date: Date?) -> String {
        guard let date = date else { return "—" }
        return DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .short)
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        ProfileView()
            .environmentObject(ThemeManager())
            .environmentObject(NotesManager())
    }
}
