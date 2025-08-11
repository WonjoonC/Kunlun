import Foundation
import SwiftData
import FirebaseFirestore
import Combine
import UIKit
import Network

/// SyncManager coordinates all data synchronization operations between SwiftData and Firestore
/// Provides centralized sync control, history tracking, conflict resolution, and sync status monitoring
@MainActor
class SyncManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = SyncManager()
    
    // MARK: - Published Properties
    /// Current sync status for UI updates
    @Published var syncStatus: SyncStatus = .idle
    
    /// Last sync timestamp
    @Published var lastSyncTimestamp: Date?
    
    /// Sync history for debugging and user information
    @Published var syncHistory: [SyncHistoryEntry] = []
    
    /// Current sync progress (0.0 to 1.0)
    @Published var syncProgress: Double = 0.0
    
    /// Network connectivity status
    @Published var isOnline: Bool = true
    
    // MARK: - Private Properties
    /// Reference to the Firestore integration layer
    private let firestoreIntegration: FirestoreIntegration
    
    /// SwiftData context for local operations
    private let context: ModelContext
    
    /// Queue for managing sync operations
    private let syncQueue = DispatchQueue(label: "com.kunlun.sync.manager", qos: .userInitiated)
    
    /// Timer for periodic sync operations
    private var periodicSyncTimer: Timer?
    
    /// Network reachability monitor
    private var networkMonitor: NetworkMonitor?
    
    /// Pending sync operations
    private var pendingOperations: [SyncOperation] = []
    
    /// Sync operation queue
    private let operationQueue = OperationQueue()
    
    // MARK: - Initialization
    private init() {
        // Get the SwiftData context from NotesManager
        let notesManager = NotesManager()
        self.context = notesManager.context
        self.firestoreIntegration = FirestoreIntegration(context: context)
        
        // Setup network monitoring
        setupNetworkMonitoring()
        
        // Setup periodic sync
        setupPeriodicSync()
        
        // Load sync history
        loadSyncHistory()
    }
    
    // MARK: - Public Sync Methods
    
    /// Perform a full sync from Firestore to local SwiftData
    /// - Parameter completion: Completion handler with sync result
    func performFullSync(completion: @escaping (Result<Void, Error>) -> Void) {
        guard isOnline else {
            let error = SyncError.noNetworkConnection
            addSyncHistoryEntry(.failure(error), operation: "Full Sync")
            completion(.failure(error))
            return
        }
        
        updateSyncStatus(.syncing)
        syncProgress = 0.0
        
        // Run serially to avoid main-thread deadlocks
        runFullSyncSequence { progress in
            self.syncProgress = progress
        } completion: { error in
            if let error = error {
                self.updateSyncStatus(.failed(error))
                self.addSyncHistoryEntry(.failure(error), operation: "Full Sync")
                completion(.failure(error))
            } else {
                self.updateSyncStatus(.completed)
                self.syncProgress = 1.0
                self.lastSyncTimestamp = Date()
                self.addSyncHistoryEntry(.success, operation: "Full Sync")
                completion(.success(()))
            }
        }
    }
    
    /// Perform incremental sync for specific data types
    /// - Parameters:
    ///   - dataTypes: Array of data types to sync
    ///   - completion: Completion handler with sync result
    func performIncrementalSync(dataTypes: [DataType], completion: @escaping (Result<Void, Error>) -> Void) {
        guard isOnline else {
            let error = SyncError.noNetworkConnection
            addSyncHistoryEntry(.failure(error), operation: "Incremental Sync")
            completion(.failure(error))
            return
        }
        
        updateSyncStatus(.syncing)
        syncProgress = 0.0
        
        runIncrementalSyncSequence(dataTypes: dataTypes) { progress in
            self.syncProgress = progress
        } completion: { error in
            if let error = error {
                self.updateSyncStatus(.failed(error))
                self.addSyncHistoryEntry(.failure(error), operation: "Incremental Sync")
                completion(.failure(error))
            } else {
                self.updateSyncStatus(.completed)
                self.syncProgress = 1.0
                self.lastSyncTimestamp = Date()
                self.addSyncHistoryEntry(.success, operation: "Incremental Sync")
                completion(.success(()))
            }
        }
    }
    
    /// Sync specific note to Firestore
    /// - Parameters:
    ///   - note: The note to sync
    ///   - completion: Completion handler with sync result
    func syncNote(_ note: Note, completion: @escaping (Result<Void, Error>) -> Void) {
        guard isOnline else {
            let error = SyncError.noNetworkConnection
            addSyncHistoryEntry(.failure(error), operation: "Note Sync")
            completion(.failure(error))
            return
        }
        
        updateSyncStatus(.syncing)
        
        // Upsert without pre-read to avoid rules failure on missing userId
        Task {
            let upsertResult = await withCheckedContinuation { continuation in
                self.firestoreIntegration.updateNote(note) { result in
                    continuation.resume(returning: result)
                }
            }
            await MainActor.run {
                self.handleSyncResult(upsertResult, operation: "Note Upsert", completion: completion)
            }
        }
    }
    
    /// Sync specific tag to Firestore
    /// - Parameters:
    ///   - tag: The tag to sync
    ///   - completion: Completion handler with sync result
    func syncTag(_ tag: Tag, completion: @escaping (Result<Void, Error>) -> Void) {
        guard isOnline else {
            let error = SyncError.noNetworkConnection
            addSyncHistoryEntry(.failure(error), operation: "Tag Sync")
            completion(.failure(error))
            return
        }
        
        updateSyncStatus(.syncing)
        
        // Use Task to handle async operations properly
        Task {
            // Check if tag exists in Firestore
            let result = await withCheckedContinuation { continuation in
                FirestoreClient.shared.fetchTag(tagId: tag.id.uuidString) { result in
                    continuation.resume(returning: result)
                }
            }
            
            switch result {
            case .success:
                // Tag exists, update it using FirestoreClient directly
                let updateResult = await withCheckedContinuation { continuation in
                    FirestoreClient.shared.updateTag(tag) { result in
                        continuation.resume(returning: result)
                    }
                }
                await MainActor.run {
                    self.handleSyncResult(updateResult, operation: "Tag Update", completion: completion)
                }
            case .failure:
                // Tag doesn't exist, create it
                let createResult = await withCheckedContinuation { continuation in
                    FirestoreClient.shared.createTag(tag) { result in
                        continuation.resume(returning: result)
                    }
                }
                await MainActor.run {
                    self.handleSyncResult(createResult, operation: "Tag Create", completion: completion)
                }
            }
        }
    }
    
    /// Resolve sync conflicts between local and remote data
    /// - Parameters:
    ///   - localData: Local SwiftData object
    ///   - remoteData: Remote Firestore data
    ///   - resolution: Conflict resolution strategy
    ///   - completion: Completion handler with resolution result
    func resolveConflict<T>(
        localData: T,
        remoteData: [String: Any],
        resolution: ConflictResolution,
        completion: @escaping (Result<T, Error>) -> Void
    ) where T: PersistentModel {
        // Use Task to handle async operations properly
        Task {
            let operation = ConflictResolutionOperation(
                localData: localData,
                remoteData: remoteData,
                resolution: resolution,
                context: self.context
            )
            
            // Execute the operation
            operation.main()
            
            await MainActor.run {
                if let error = operation.error {
                    self.addSyncHistoryEntry(.failure(error), operation: "Conflict Resolution")
                    completion(.failure(error))
                } else if let resolvedData = operation.resolvedData as? T {
                    self.addSyncHistoryEntry(.success, operation: "Conflict Resolution")
                    completion(.success(resolvedData))
                } else {
                    let error = SyncError.conflictResolutionFailed
                    self.addSyncHistoryEntry(.failure(error), operation: "Conflict Resolution")
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Get sync statistics for the current session
    /// - Returns: SyncStatistics object with current metrics
    func getSyncStatistics() -> SyncStatistics {
        let totalOperations = syncHistory.count
        let successfulOperations = syncHistory.filter { $0.result == .success }.count
        let failedOperations = totalOperations - successfulOperations
        let successRate = totalOperations > 0 ? Double(successfulOperations) / Double(totalOperations) : 0.0
        
        return SyncStatistics(
            totalOperations: totalOperations,
            successfulOperations: successfulOperations,
            failedOperations: failedOperations,
            successRate: successRate,
            lastSyncTimestamp: lastSyncTimestamp,
            averageSyncDuration: calculateAverageSyncDuration()
        )
    }
    
    /// Clear sync history
    func clearSyncHistory() {
        syncHistory.removeAll()
        saveSyncHistory()
    }
    
    /// Force sync status to idle (useful for testing or manual reset)
    func resetSyncStatus() {
        updateSyncStatus(.idle)
        syncProgress = 0.0
    }
    
    // MARK: - Private Methods
    
    /// Update sync status and notify observers
    private func updateSyncStatus(_ status: SyncStatus) {
        // Since this class is @MainActor, we can directly update the property
        self.syncStatus = status
    }
    
    /// Handle sync operation results
    private func handleSyncResult(
        _ result: Result<Void, Error>,
        operation: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        switch result {
        case .success:
            updateSyncStatus(.completed)
            lastSyncTimestamp = Date()
            addSyncHistoryEntry(.success, operation: operation)
            completion(.success(()))
        case .failure(let error):
            updateSyncStatus(.failed(error))
            addSyncHistoryEntry(.failure(error), operation: operation)
            completion(.failure(error))
        }
    }
    
    /// Add entry to sync history
    private func addSyncHistoryEntry(_ result: SyncResult, operation: String) {
        let entry = SyncHistoryEntry(
            timestamp: Date(),
            operation: operation,
            result: result,
            dataType: determineDataType(from: operation)
        )
        
        syncHistory.append(entry)
        
        // Keep only last 100 entries to prevent memory issues
        if syncHistory.count > 100 {
            syncHistory.removeFirst(syncHistory.count - 100)
        }
        
        saveSyncHistory()
    }
    
    /// Determine data type from operation string
    private func determineDataType(from operation: String) -> DataType {
        if operation.contains("Note") {
            return .notes
        } else if operation.contains("Tag") {
            return .tags
        } else if operation.contains("Link") {
            return .noteLinks
        } else {
            return .all
        }
    }
    
    /// Calculate average sync duration from history
    private func calculateAverageSyncDuration() -> TimeInterval? {
        let successfulEntries = syncHistory.filter { $0.result == .success }
        guard !successfulEntries.isEmpty else { return nil }
        
        // This would need to be implemented with actual duration tracking
        // For now, return nil
        return nil
    }
    
    /// Setup network monitoring
    private func setupNetworkMonitoring() {
        networkMonitor = NetworkMonitor()
        networkMonitor?.onStatusChange = { [weak self] isOnline in
            Task { @MainActor in
                // Since this class is @MainActor, we can directly update the property
                self?.isOnline = isOnline
                
                // If we come back online and have pending operations, trigger sync
                if isOnline == true && !(self?.pendingOperations.isEmpty ?? true) {
                    self?.performFullSync { _ in }
                }
            }
        }
    }
    
    /// Setup periodic sync timer
    private func setupPeriodicSync() {
        // Sync every 5 minutes when app is active
        periodicSyncTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isOnline else { return }
                self.performIncrementalSync(dataTypes: [.notes, .tags]) { _ in }
            }
        }
    }
    
    /// Load sync history from persistent storage
    private func loadSyncHistory() {
        // Load from UserDefaults for now, could be moved to Core Data later
        if let data = UserDefaults.standard.data(forKey: "syncHistory"),
           let history = try? JSONDecoder().decode([SyncHistoryEntry].self, from: data) {
            syncHistory = history
        }
    }
    
    /// Save sync history to persistent storage
    private func saveSyncHistory() {
        if let data = try? JSONEncoder().encode(syncHistory) {
            UserDefaults.standard.set(data, forKey: "syncHistory")
        }
    }

    // MARK: - Serial Sync Sequences (avoid main-thread blocking)
    private func runFullSyncSequence(progress: @escaping (Double) -> Void, completion: @escaping (Error?) -> Void) {
        // Temporarily restrict full sync to notes + tags (links handled in Task 10)
        firestoreIntegration.syncNotesFromFirestore { result in
            switch result {
            case .success:
                progress(0.5)
                self.firestoreIntegration.syncTagsFromFirestore { result in
                    switch result {
                    case .success:
                        progress(1.0)
                        completion(nil)
                    case .failure(let error):
                        completion(error)
                    }
                }
            case .failure(let error):
                completion(error)
            }
        }
    }
    
    private func runIncrementalSyncSequence(dataTypes: [DataType], progress: @escaping (Double) -> Void, completion: @escaping (Error?) -> Void) {
        guard !dataTypes.isEmpty else { completion(nil); return }
        var index = 0
        let total = dataTypes.count
        
        func processNext() {
            if index >= total { completion(nil); return }
            let dataType = dataTypes[index]
            let update = {
                index += 1
                progress(Double(index) / Double(total))
                processNext()
            }
            
            switch dataType {
            case .notes:
                firestoreIntegration.syncNotesFromFirestore { result in
                    switch result {
                    case .success: update()
                    case .failure(let error): completion(error)
                    }
                }
            case .tags:
                firestoreIntegration.syncTagsFromFirestore { result in
                    switch result {
                    case .success: update()
                    case .failure(let error): completion(error)
                    }
                }
            case .noteLinks:
                firestoreIntegration.syncNoteLinksFromFirestore { result in
                    switch result {
                    case .success: update()
                    case .failure(let error): completion(error)
                    }
                }
            case .all:
                runFullSyncSequence(progress: progress) { error in
                    if let error = error { completion(error) } else { update() }
                }
            }
        }
        
        progress(0.0)
        processNext()
    }
}

// MARK: - Supporting Types

/// Sync status enumeration
enum SyncStatus: Equatable {
    case idle
    case syncing
    case completed
    case failed(Error)
    
    static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.syncing, .syncing), (.completed, .completed):
            return true
        case (.failed(let lhsError), .failed(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

/// Sync result enumeration
enum SyncResult: Equatable {
    case success
    case failure(Error)
    
    static func == (lhs: SyncResult, rhs: SyncResult) -> Bool {
        switch (lhs, rhs) {
        case (.success, .success):
            return true
        case (.failure(let lhsError), .failure(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

/// Data types for sync operations
enum DataType: String, CaseIterable, Codable {
    case notes = "notes"
    case tags = "tags"
    case noteLinks = "note_links"
    case all = "all"
}

/// Conflict resolution strategies
enum ConflictResolution {
    case useLocal
    case useRemote
    case merge
    case askUser
}

/// Sync history entry
struct SyncHistoryEntry: Codable, Identifiable {
    let id = UUID()
    let timestamp: Date
    let operation: String
    let result: SyncResult
    let dataType: DataType
    
    enum CodingKeys: String, CodingKey {
        case timestamp, operation, result, dataType
    }
    
    init(timestamp: Date, operation: String, result: SyncResult, dataType: DataType) {
        self.timestamp = timestamp
        self.operation = operation
        self.result = result
        self.dataType = dataType
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        operation = try container.decode(String.self, forKey: .operation)
        dataType = try container.decode(DataType.self, forKey: .dataType)
        
        // Custom decoding for SyncResult since Error is not Codable
        let resultString = try container.decode(String.self, forKey: .result)
        if resultString == "success" {
            result = .success
        } else {
            result = .failure(SyncError.unknown)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(operation, forKey: .operation)
        try container.encode(dataType, forKey: .dataType)
        
        // Custom encoding for SyncResult
        let resultString: String
        switch result {
        case .success:
            resultString = "success"
        case .failure:
            resultString = "failure"
        }
        try container.encode(resultString, forKey: .result)
    }
}

/// Sync statistics
struct SyncStatistics {
    let totalOperations: Int
    let successfulOperations: Int
    let failedOperations: Int
    let successRate: Double
    let lastSyncTimestamp: Date?
    let averageSyncDuration: TimeInterval?
}

/// Sync errors
enum SyncError: LocalizedError {
    case noNetworkConnection
    case conflictResolutionFailed
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .noNetworkConnection:
            return "No network connection available for sync"
        case .conflictResolutionFailed:
            return "Failed to resolve data conflicts"
        case .unknown:
            return "Unknown sync error occurred"
        }
    }
}

// MARK: - Sync Operations

/// Base class for sync operations
class SyncOperation: Operation, @unchecked Sendable {
    var error: Error?
    let progressHandler: (Double) -> Void
    
    init(progressHandler: @escaping (Double) -> Void) {
        self.progressHandler = progressHandler
        super.init()
    }
}

/// Full sync operation
class FullSyncOperation: SyncOperation, @unchecked Sendable {
    private let firestoreIntegration: FirestoreIntegration
    
    init(firestoreIntegration: FirestoreIntegration, progressHandler: @escaping (Double) -> Void) {
        self.firestoreIntegration = firestoreIntegration
        super.init(progressHandler: progressHandler)
    }
    
    override func main() {
        let group = DispatchGroup()
        var syncError: Error?
        
        progressHandler(0.0)
        
        // Sync notes from Firestore
        group.enter()
        Task { @MainActor in
            firestoreIntegration.syncNotesFromFirestore { result in
                switch result {
                case .success:
                    self.progressHandler(0.4)
                case .failure(let error):
                    syncError = error
                }
                group.leave()
            }
        }
        
        // Sync tags from Firestore
        group.enter()
        Task { @MainActor in
            firestoreIntegration.syncTagsFromFirestore { result in
                switch result {
                case .success:
                    self.progressHandler(0.7)
                case .failure(let error):
                    syncError = error
                }
                group.leave()
            }
        }
        
        // Sync note links from Firestore
        group.enter()
        Task { @MainActor in
            firestoreIntegration.syncNoteLinksFromFirestore { result in
                switch result {
                case .success:
                    self.progressHandler(1.0)
                case .failure(let error):
                    syncError = error
                }
                group.leave()
            }
        }
        
        group.wait()
        
        if let error = syncError {
            self.error = error
        }
    }
}

/// Incremental sync operation
class IncrementalSyncOperation: SyncOperation, @unchecked Sendable {
    private let dataTypes: [DataType]
    private let firestoreIntegration: FirestoreIntegration
    
    init(dataTypes: [DataType], firestoreIntegration: FirestoreIntegration, progressHandler: @escaping (Double) -> Void) {
        self.dataTypes = dataTypes
        self.firestoreIntegration = firestoreIntegration
        super.init(progressHandler: progressHandler)
    }
    
    override func main() {
        let group = DispatchGroup()
        var syncError: Error?
        var completedOperations = 0
        let totalOperations = dataTypes.count
        
        progressHandler(0.0)
        
        for dataType in dataTypes {
            group.enter()
            
            switch dataType {
            case .notes:
                Task { @MainActor in
                    firestoreIntegration.syncNotesFromFirestore { result in
                        self.handleSyncResult(result, &syncError)
                        completedOperations += 1
                        self.progressHandler(Double(completedOperations) / Double(totalOperations))
                        group.leave()
                    }
                }
            case .tags:
                Task { @MainActor in
                    firestoreIntegration.syncTagsFromFirestore { result in
                        self.handleSyncResult(result, &syncError)
                        completedOperations += 1
                        self.progressHandler(Double(completedOperations) / Double(totalOperations))
                        group.leave()
                    }
                }
            case .noteLinks:
                Task { @MainActor in
                    firestoreIntegration.syncNoteLinksFromFirestore { result in
                        self.handleSyncResult(result, &syncError)
                        completedOperations += 1
                        self.progressHandler(Double(completedOperations) / Double(totalOperations))
                        group.leave()
                    }
                }
            case .all:
                Task { @MainActor in
                    firestoreIntegration.performFullSync { result in
                        self.handleSyncResult(result, &syncError)
                        completedOperations += 1
                        self.progressHandler(Double(completedOperations) / Double(totalOperations))
                        group.leave()
                    }
                }
            }
        }
        
        group.wait()
        
        if let error = syncError {
            self.error = error
        }
    }
    
    private func handleSyncResult(_ result: Result<Void, Error>, _ syncError: inout Error?) {
        if case .failure(let error) = result {
            syncError = error
        }
    }
}

/// Conflict resolution operation
class ConflictResolutionOperation: SyncOperation, @unchecked Sendable {
    private let localData: any PersistentModel
    private let remoteData: [String: Any]
    private let resolution: ConflictResolution
    private let context: ModelContext
    
    var resolvedData: (any PersistentModel)?
    
    init(localData: any PersistentModel, remoteData: [String: Any], resolution: ConflictResolution, context: ModelContext) {
        self.localData = localData
        self.remoteData = remoteData
        self.resolution = resolution
        self.context = context
        super.init(progressHandler: { _ in })
    }
    
    override func main() {
        // Implementation would depend on the specific data type and conflict resolution strategy
        // For now, this is a placeholder that would need to be implemented based on specific requirements
        resolvedData = localData
    }
}

// MARK: - Network Monitor

/// Simple network connectivity monitor
class NetworkMonitor {
    var onStatusChange: ((Bool) -> Void)?
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.kunlun.network.monitor")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let isOnline = path.status == .satisfied
            DispatchQueue.main.async { self?.onStatusChange?(isOnline) }
        }
        monitor.start(queue: queue)
    }
    
    deinit { monitor.cancel() }
}


