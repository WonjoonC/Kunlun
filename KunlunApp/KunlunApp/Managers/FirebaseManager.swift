import Foundation
import FirebaseCore
import FirebaseFirestore
import FirebaseAppCheck
import FirebaseCrashlytics
import FirebaseAuth

/// Manages Firebase configuration and initialization for the Kunlun app
/// Handles Firestore database setup and provides access to Firestore instances
class FirebaseManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = FirebaseManager()
    
    // MARK: - Properties
    /// Main Firestore database instance
    let db: Firestore
    
    /// Firestore settings for optimal performance
    private let firestoreSettings: FirestoreSettings
    
    // MARK: - Initialization
    private init() {
        // Ensure Firebase is configured before initializing Firestore
        FirebaseManager.configure()
        
        // Configure Firestore settings for optimal performance
        firestoreSettings = FirestoreSettings()
        
        // Use modern cache settings instead of deprecated properties
        let cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: FirestoreCacheSizeUnlimited))
        firestoreSettings.cacheSettings = cacheSettings
        
        // Initialize Firestore with custom settings
        db = Firestore.firestore()
        db.settings = firestoreSettings
        
        // Configure offline persistence
        configureOfflinePersistence()
    }
    
    // MARK: - Configuration
    /// Configure Firebase app if not already configured
    /// This should be called in the app's main entry point
    static func configure() {
        // Only configure if Firebase hasn't been configured yet
        if FirebaseApp.app() == nil {
            // Configure App Check with debug provider for development
            let providerFactory = AppCheckDebugProviderFactory()
            AppCheck.setAppCheckProviderFactory(providerFactory)
            
            // Configure Firebase
            FirebaseApp.configure()
            
            // Configure Crashlytics for crash reporting
            Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
            
            print("✅ Firebase configured successfully")
            print("✅ App Check configured with debug provider")
            print("✅ Crashlytics enabled for crash reporting")

            // Sign in anonymously for development so Firestore rules with request.auth work
            Auth.auth().signInAnonymously { result, error in
                if let error = error {
                    print("❌ Firebase anonymous sign-in failed: \(error)")
                } else if let user = result?.user {
                    print("✅ Firebase anonymous user signed in: uid=\(user.uid)")
                }
            }
        } else {
            print("ℹ️ Firebase already configured")
        }
    }
    
    /// Configure offline persistence for better user experience
    private func configureOfflinePersistence() {
        // Enable offline persistence with unlimited cache size
        // This allows the app to work offline and sync when connection is restored
        // Note: enableNetwork() doesn't throw errors in current Firebase SDK
        db.enableNetwork()
    }
    
    // MARK: - Database Access
    /// Get a reference to a specific collection
    /// - Parameter path: Collection path (e.g., "notes", "users")
    /// - Returns: CollectionReference for the specified path
    func collection(_ path: String) -> CollectionReference {
        return db.collection(path)
    }
    
    /// Get a reference to a specific document
    /// - Parameters:
    ///   - path: Collection path
    ///   - documentId: Document ID within the collection
    /// - Returns: DocumentReference for the specified document
    func document(_ path: String, documentId: String) -> DocumentReference {
        return db.collection(path).document(documentId)
    }
    
    // MARK: - Utility Methods
    /// Check if Firebase is properly configured
    var isConfigured: Bool {
        return FirebaseApp.app() != nil
    }
    
    /// Get the current Firebase app instance
    var app: FirebaseApp? {
        return FirebaseApp.app()
    }
}

// MARK: - Firestore Extensions
extension FirebaseManager {
    
    /// Create a batch write operation for multiple document operations
    /// Useful for ensuring atomic updates across multiple documents
    func batch() -> WriteBatch {
        return db.batch()
    }
    
    /// Create a transaction for complex read-write operations
    /// Ensures data consistency across multiple operations
    func runTransaction(_ updateBlock: @escaping (Transaction, NSErrorPointer) -> Any?) async throws -> Any? {
        return try await db.runTransaction(updateBlock)
    }
}
