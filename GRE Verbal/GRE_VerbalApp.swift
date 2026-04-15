//
//  GRE_VerbalApp.swift
//  GRE Verbal
//
//  Created by Martin Olivares on 23-01-26.
//

import SwiftUI
import SwiftData

// MARK: - Schema Versions for Migration

enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [WordProgressV1.self, AppSettingsV1.self]
    }
    
    @Model
    final class WordProgressV1 {
        @Attribute(.unique) var word: String
        var wrongCount: Int
        var hasSeenOnce: Bool
        var knewOnFirstTry: Bool
        var lastReviewedDate: Date?
        var consecutiveCorrectCount: Int
        
        init(word: String) {
            self.word = word
            self.wrongCount = 0
            self.hasSeenOnce = false
            self.knewOnFirstTry = false
            self.lastReviewedDate = nil
            self.consecutiveCorrectCount = 0
        }
    }
    
    @Model
    final class AppSettingsV1 {
        var selectedGroups: [Int]
        var selectedDifficulties: [String]
        var isCumulativeMode: Bool
        var hasCompletedOnboarding: Bool
        
        init() {
            self.selectedGroups = [1]
            self.selectedDifficulties = ["Unlocked", "Easy", "Medium", "Hard"]
            self.isCumulativeMode = false
            self.hasCompletedOnboarding = false
        }
    }
}

enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [WordProgress.self, AppSettings.self]
    }
}

enum SchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)
    static var models: [any PersistentModel.Type] {
        [WordProgress.self, AppSettings.self, DrillSession.self]
    }
}

enum MigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self, SchemaV3.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2, migrateV2toV3]
    }

    // Migration from V1 to V2: Add wasPromotedToEasy field
    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self
    )

    // Migration from V2 to V3: Add DrillSession model
    static let migrateV2toV3 = MigrationStage.lightweight(
        fromVersion: SchemaV2.self,
        toVersion: SchemaV3.self
    )
}

@main
struct GRE_VerbalApp: App {
    let modelContainer: ModelContainer
    
    init() {
        do {
            let schema = Schema([
                WordProgress.self,
                AppSettings.self,
                DrillSession.self
            ])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                cloudKitDatabase: .none
            )
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            print("✅ SwiftData initialized successfully")
        } catch {
            // Migration failed — backup old store and start fresh
            print("⚠️ SwiftData migration failed: \(error). Creating new database (old data preserved in backup)...")

            let fileManager = FileManager.default
            let appSupport = URL.applicationSupportDirectory
            let defaultStore = appSupport.appending(path: "default.store")

            // Create backup of old database if it exists
            if fileManager.fileExists(atPath: defaultStore.path) {
                let backupURL = appSupport.appending(path: "backup_\(Date().timeIntervalSince1970).store")
                try? fileManager.copyItem(at: defaultStore, to: backupURL)
                print("📦 Old database backed up to: \(backupURL.path)")

                // Remove old store files
                try? fileManager.removeItem(at: defaultStore)
                try? fileManager.removeItem(at: defaultStore.appendingPathExtension("wal"))
                try? fileManager.removeItem(at: defaultStore.appendingPathExtension("shm"))
            }

            do {
                let schema = Schema([
                    WordProgress.self,
                    AppSettings.self,
                    DrillSession.self
                ])
                let modelConfiguration = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false
                )
                modelContainer = try ModelContainer(
                    for: schema,
                    configurations: [modelConfiguration]
                )
            } catch {
                fatalError("Could not initialize ModelContainer: \(error)")
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .onAppear {
                    UIApplication.shared.isIdleTimerDisabled = true
                }
        }
        .modelContainer(modelContainer)
    }
}
