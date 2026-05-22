//
//  boubigaTests.swift
//  boubigaTests
//
//  Created by 山本勇磨 on 2026/05/17.
//

import Foundation
import Testing
@testable import boubiga

struct boubigaTests {

    @Test func sampleDataMatchesIPhoneMvp() async throws {
        let data = IPhoneAppData.sample

        #expect(data.currentOwnership?.product.name == "iPhone 16 Pro")
        #expect(data.pastOwnerships.count == 2)
        #expect(data.openTasks.count == 2)
        #expect(data.currentDeviceDetection.freeStorageGB == 78)
    }

    @MainActor
    @Test func addDetectedCurrentIPhoneCreatesTasks() async throws {
        let emptyData = IPhoneAppData(
            ownerships: [],
            tasks: [],
            products: ProductCatalog.allProducts,
            searchSuggestions: SampleData.searchSuggestions,
            diagnosisPrompts: SampleData.diagnosisPrompts,
            settings: SampleData.settings,
            currentDeviceDetection: SampleData.currentDeviceDetection
        )
        let store = AppStore(data: emptyData)

        store.addDetectedCurrentIPhone()

        #expect(store.snapshot.currentOwnership?.product.name == "iPhone 16 Pro")
        #expect(store.snapshot.openTasks.count == 2)
    }

    @MainActor
    @Test func completeBatteryHealthTaskAddsLog() async throws {
        let store = AppStore(data: .sample)
        let ownershipID = try #require(store.snapshot.currentOwnership?.id)

        store.completeBatteryHealthTask(
            for: ownershipID,
            draft: BatteryHealthDraft(healthPercent: "86", note: "設定アプリで確認")
        )

        let updated = try #require(store.snapshot.currentOwnership)
        #expect(updated.latestBatteryHealth?.healthPercent == 86)
        #expect(!store.snapshot.openTasks.contains { $0.ownershipID == ownershipID && $0.type == .inputBatteryHealth && $0.status == .open })
    }

    @MainActor
    @Test func localPersistenceRestoresOnboardingAndLogs() async throws {
        let suiteName = "boubiga.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let persistence = LocalPersistenceStore(defaults: defaults)
        persistence.reset()

        let store = AppStore(data: .freshInstall, persistence: persistence)
        store.ensureCurrentOwnershipForOnboarding()
        store.completeOnboarding(draft: OnboardingDraft(selectedModelName: "iPhone 16 Pro", selectedColorName: "ナチュラルチタニウム"))
        let ownershipID = try #require(store.snapshot.currentOwnership?.id)
        store.completeBatteryHealthTask(for: ownershipID, draft: BatteryHealthDraft(healthPercent: "88", note: "テスト"))

        let restoredStore = AppStore(data: .freshInstall, persistence: persistence)
        let restored = try #require(restoredStore.snapshot.currentOwnership)
        #expect(restored.manuallyConfirmed)
        #expect(restored.colorName == "ナチュラルチタニウム")
        #expect(restored.latestBatteryHealth?.healthPercent == 88)

        persistence.reset()
        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    @Test func resetOnboardingClearsPersistedCurrentData() async throws {
        let suiteName = "boubiga.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let persistence = LocalPersistenceStore(defaults: defaults)
        persistence.reset()

        let store = AppStore(data: .freshInstall, persistence: persistence)
        store.ensureCurrentOwnershipForOnboarding()
        store.completeOnboarding(draft: OnboardingDraft(selectedModelName: "iPhone 16 Pro", selectedColorName: "デザートチタニウム"))
        let ownershipID = try #require(store.snapshot.currentOwnership?.id)
        store.completeBatteryHealthTask(for: ownershipID, draft: BatteryHealthDraft(healthPercent: "77", note: "リセット前"))
        store.markTradeValueChecked(for: ownershipID)

        store.resetCurrentIPhoneOnboarding()

        let resetCurrent = try #require(store.snapshot.currentOwnership)
        #expect(!resetCurrent.manuallyConfirmed)
        #expect(resetCurrent.colorName == "未設定")
        #expect(resetCurrent.latestBatteryHealth == nil)
        #expect(resetCurrent.tradeValueEstimate == nil)
        #expect(store.snapshot.openTasks(for: resetCurrent.id).count == 2)

        let restoredStore = AppStore(data: .freshInstall, persistence: persistence)
        let restoredCurrent = try #require(restoredStore.snapshot.currentOwnership)
        #expect(!restoredCurrent.manuallyConfirmed)
        #expect(restoredCurrent.latestBatteryHealth == nil)
        #expect(restoredCurrent.tradeValueEstimate == nil)

        persistence.reset()
        defaults.removePersistentDomain(forName: suiteName)
    }

    @MainActor
    @Test func ruleEngineMatchesDeviceSnapshot() async throws {
        let store = AppStore(data: .sample)
        let ownership = try #require(store.snapshot.currentOwnership)
        let result = store.ruleResult(for: ownership)

        #expect(result.todoItems.contains { $0.id == "battery-unchecked" })
        #expect(result.cautionItems.isEmpty)
        #expect(result.solveItems.isEmpty)
    }

    @MainActor
    @Test func pendingActionCountDeduplicatesRuleCoveredTasks() async throws {
        let store = AppStore(data: .sample)
        let ownership = try #require(store.snapshot.currentOwnership)

        #expect(store.pendingActionCount(for: ownership) == 2)
    }

    @Test func versionNumberComparesMultiDigitComponents() async throws {
        let version26_10 = try #require(VersionNumber("iOS 26.10"))
        let version26_5 = try #require(VersionNumber("26.5"))
        let version26_5_0 = try #require(VersionNumber("26.5.0"))

        #expect(version26_10 > version26_5)
        #expect(version26_5 == version26_5_0)
    }

    @MainActor
    @Test func appConfigStoreUsesCachedRemoteConfig() async throws {
        let suiteName = "boubiga.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        let cachedConfig = RemoteAppConfig(
            version: 99,
            publishedAt: Date(timeIntervalSince1970: 1_779_408_000),
            ios: RemoteIOSConfig(
                latestGlobalVersion: "99.9",
                releaseDate: nil,
                severity: .warning,
                message: "テスト設定"
            ),
            thresholds: RemoteThresholdConfig(
                batteryWarningPercent: 90,
                batteryCriticalPercent: 75,
                storageWarningGB: 30,
                storageCriticalGB: 8
            ),
            rules: []
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(cachedConfig)
        defaults.set(data, forKey: "boubiga.remoteAppConfigCache.v1")
        defaults.set(Date(timeIntervalSince1970: 1_779_408_000), forKey: "boubiga.remoteAppConfigLastFetchedAt.v1")

        let store = AppConfigStore(defaults: defaults, client: nil)

        #expect(store.config.version == 99)
        #expect(store.config.ios.latestGlobalVersion == "99.9")

        defaults.removePersistentDomain(forName: suiteName)
    }
}
