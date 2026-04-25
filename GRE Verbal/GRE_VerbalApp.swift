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

    private static let storeFileName = "default.store"

    init() {
        let fileManager = FileManager.default
        let appSupport = URL.applicationSupportDirectory
        let defaultStore = appSupport.appending(path: Self.storeFileName)

        try? fileManager.createDirectory(at: appSupport, withIntermediateDirectories: true)

        // If a backup exists but current store is missing, recover automatically.
        Self.restoreMostRecentBackupIfStoreMissing(
            fileManager: fileManager,
            appSupport: appSupport,
            defaultStore: defaultStore
        )

        do {
            modelContainer = try Self.makeContainer(useMigrationPlan: true)
            print("✅ SwiftData initialized successfully")
        } catch {
            print("⚠️ SwiftData migration failed: \(error). Preserving old store and rebuilding...")

            let backupURL = Self.backupStoreFamilyIfNeeded(
                fileManager: fileManager,
                appSupport: appSupport,
                defaultStore: defaultStore
            )

            if let backupURL {
                print("📦 Backed up old database to: \(backupURL.path)")
            }

            do {
                modelContainer = try Self.makeContainer(useMigrationPlan: false)
                print("✅ SwiftData initialized with fresh store")
            } catch {
                fatalError("Could not initialize ModelContainer after recovery: \(error)")
            }
        }
    }

    private static func makeContainer(useMigrationPlan: Bool) throws -> ModelContainer {
        let schema = Schema(
            [WordProgress.self, AppSettings.self, DrillSession.self],
            version: SchemaV3.versionIdentifier
        )

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        if useMigrationPlan {
            return try ModelContainer(
                for: schema,
                migrationPlan: MigrationPlan.self,
                configurations: [modelConfiguration]
            )
        }

        return try ModelContainer(
            for: schema,
            configurations: [modelConfiguration]
        )
    }

    private static func walURL(for store: URL) -> URL {
        URL(fileURLWithPath: store.path + "-wal")
    }

    private static func shmURL(for store: URL) -> URL {
        URL(fileURLWithPath: store.path + "-shm")
    }

    private static func backupStoreFamilyIfNeeded(
        fileManager: FileManager,
        appSupport: URL,
        defaultStore: URL
    ) -> URL? {
        guard fileManager.fileExists(atPath: defaultStore.path) else {
            return nil
        }

        let timestamp = Int(Date().timeIntervalSince1970)
        let backupStore = appSupport.appending(path: "backup_\(timestamp).store")

        if fileManager.fileExists(atPath: backupStore.path) {
            try? fileManager.removeItem(at: backupStore)
        }

        do {
            try fileManager.moveItem(at: defaultStore, to: backupStore)
        } catch {
            do {
                try fileManager.copyItem(at: defaultStore, to: backupStore)
                try? fileManager.removeItem(at: defaultStore)
            } catch {
                return nil
            }
        }

        moveSidecarIfExists(
            fileManager: fileManager,
            from: walURL(for: defaultStore),
            to: walURL(for: backupStore)
        )
        moveSidecarIfExists(
            fileManager: fileManager,
            from: shmURL(for: defaultStore),
            to: shmURL(for: backupStore)
        )

        return backupStore
    }

    private static func moveSidecarIfExists(fileManager: FileManager, from: URL, to: URL) {
        guard fileManager.fileExists(atPath: from.path) else { return }
        try? fileManager.removeItem(at: to)

        do {
            try fileManager.moveItem(at: from, to: to)
        } catch {
            do {
                try fileManager.copyItem(at: from, to: to)
                try? fileManager.removeItem(at: from)
            } catch {
                // Best effort only
            }
        }
    }

    private static func restoreMostRecentBackupIfStoreMissing(
        fileManager: FileManager,
        appSupport: URL,
        defaultStore: URL
    ) {
        guard !fileManager.fileExists(atPath: defaultStore.path) else { return }
        guard let backupStore = latestBackupStore(fileManager: fileManager, appSupport: appSupport) else { return }

        do {
            try fileManager.copyItem(at: backupStore, to: defaultStore)
            copySidecarIfExists(
                fileManager: fileManager,
                from: walURL(for: backupStore),
                to: walURL(for: defaultStore)
            )
            copySidecarIfExists(
                fileManager: fileManager,
                from: shmURL(for: backupStore),
                to: shmURL(for: defaultStore)
            )
            print("🔄 Restored store from backup: \(backupStore.lastPathComponent)")
        } catch {
            print("⚠️ Failed to restore backup store: \(error)")
        }
    }

    private static func copySidecarIfExists(fileManager: FileManager, from: URL, to: URL) {
        guard fileManager.fileExists(atPath: from.path) else { return }
        try? fileManager.removeItem(at: to)
        try? fileManager.copyItem(at: from, to: to)
    }

    private static func latestBackupStore(fileManager: FileManager, appSupport: URL) -> URL? {
        let contents = (try? fileManager.contentsOfDirectory(at: appSupport, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []

        let backups = contents.filter {
            $0.lastPathComponent.hasPrefix("backup_") && $0.pathExtension == "store"
        }

        return backups.sorted { lhs, rhs in
            let l = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let r = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return l > r
        }.first
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
