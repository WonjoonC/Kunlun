/**
 * @fileoverview Kunlun App Main Entry Point
 * @description Main SwiftUI application entry point for Kunlun notes app
 * 
 * Architecture:
 * - SwiftUI-based iOS app with iOS 18.0+ deployment target
 * - MVVM architecture with ObservableObject state management
 * - SwiftData integration with @Model for automatic persistence
 * - Clean, minimal UI following Apple's Human Interface Guidelines
 * - Performance-focused with sub-16ms response targets
 */

import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseFirestore

@main
struct KunlunAppApp: App {
    
    // MARK: - Environment Objects
    @StateObject private var notesManager: NotesManager
    @StateObject private var themeManager = ThemeManager()
    
    // MARK: - SwiftData Configuration
    private var modelContainer: ModelContainer
    
    // MARK: - Firebase Configuration
    init() {
        // Configure Firebase when the app starts
        print("🚀 Initializing Kunlun App...")
        FirebaseManager.configure()
        
        // Verify Firebase configuration
        if FirebaseApp.app() != nil {
            print("✅ Firebase is properly configured")
        } else {
            print("❌ Firebase configuration failed")
        }
        
        // Initialize SwiftData
        do {
            let schema = Schema([
                Note.self,
                Tag.self,
                NoteLink.self
            ])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            
            print("✅ SwiftData ModelContainer initialized successfully")
            // Initialize managers that depend on SwiftData context
            let nm = NotesManager(modelContext: modelContainer.mainContext)
            _notesManager = StateObject(wrappedValue: nm)
            
        } catch {
            print("❌ Failed to initialize SwiftData: \(error)")
            fatalError("Could not initialize SwiftData")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(notesManager)
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.currentColorScheme)
                .modelContainer(modelContainer)
                .onAppear {
                    // Configure app appearance and settings
                    configureAppAppearance()
                }
        }
    }
    
    // MARK: - App Configuration
    private func configureAppAppearance() {
        // Set up global navigation bar appearance
        let navigationBarAppearance = UINavigationBarAppearance()
        navigationBarAppearance.configureWithDefaultBackground()
        navigationBarAppearance.backgroundColor = UIColor.systemBackground
        
        UINavigationBar.appearance().standardAppearance = navigationBarAppearance
        UINavigationBar.appearance().compactAppearance = navigationBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBarAppearance
        
        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()
        tabBarAppearance.backgroundColor = UIColor.systemBackground
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }
}
