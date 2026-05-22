//
//  AppModels.swift
//  boubiga
//
//  Created by Codex on 2026/05/18.
//

import Combine
import Foundation
import UIKit

enum IPhoneOwnershipStatus: String, CaseIterable, Identifiable, Codable {
    case current = "あなたのiPhone"
    case past = "過去のiPhone"

    var id: String { rawValue }
}

enum BatteryChargeState: String, Codable {
    case charging = "充電中"
    case unplugged = "未充電"
    case full = "充電完了"
    case unknown = "不明"
}

enum IPhoneTaskType: String, CaseIterable, Identifiable, Codable {
    case inputBatteryHealth = "バッテリー最大容量を入力"
    case recordFirstImpression = "今の使用感を記録"
    case checkTradeInValue = "下取り・売却相場を確認"
    case updateBatteryHealth = "バッテリー最大容量を更新"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .inputBatteryHealth:
            "買い替え判断に使えるよう、最大容量を記録しましょう。"
        case .recordFirstImpression:
            "満足度や気になる点を残しておきましょう。"
        case .checkTradeInValue:
            "買い替え判断のため、今の価値を確認しておきましょう。"
        case .updateBatteryHealth:
            "前回確認から3ヶ月経ちました。今の状態を更新しましょう。"
        }
    }
}

enum IPhoneTaskStatus: String, Codable {
    case open
    case completed
}

enum UsageStatusOption: String, CaseIterable, Identifiable, Codable {
    case main = "今もメインで使っている"
    case sub = "サブとして使っている"
    case retired = "もう使っていない"

    var id: String { rawValue }
}

enum SizeFitOption: String, CaseIterable, Identifiable, Codable {
    case good = "ちょうどいい"
    case smaller = "もう少し小さい方がいい"
    case larger = "もう少し大きい方がいい"
    case heavy = "重い"
    case hardToUseOneHanded = "片手で使いにくい"

    var id: String { rawValue }
}

enum UpgradeIntentOption: String, CaseIterable, Identifiable, Codable {
    case keepUsing = "まだ使いたい"
    case interested = "少し気になっている"
    case withinHalfYear = "半年以内に買い替えたい"
    case immediately = "今すぐ買い替えたい"
    case unsure = "迷っている"

    var id: String { rawValue }
}

enum IPhoneConcernStatus: String, Codable {
    case good = "問題なさそう"
    case waiting = "確認待ち"
    case slightAttention = "少し注意"
    case reviewCandidate = "見直し候補"
    case replacementCandidate = "交換検討"
    case compareUpgrade = "買い替え比較"
}

struct IPhoneProduct: Identifiable, Hashable, Codable {
    var id = UUID()
    let name: String
    let series: String
    let releaseYear: Int
    let imageFilename: String?
}

struct DetectedDeviceSnapshot: Identifiable, Codable {
    var id = UUID()
    let detectedAt: Date
    let hardwareIdentifier: String
    let inferredModelName: String
    let totalStorageGB: Int
    let freeStorageGB: Int
    let osVersion: String
    let batteryLevelPercent: Int?
    let batteryState: BatteryChargeState
}

struct BatteryHealthLog: Identifiable, Codable {
    var id = UUID()
    let healthPercent: Int
    let checkedAt: Date
    let note: String
}

enum BatteryConditionSource: String, Codable {
    case screenshotOCR = "スクショOCR"
    case manual = "手入力"
    case sample = "サンプル"
}

struct BatteryConditionSnapshot: Identifiable, Codable {
    var id = UUID()
    let maximumCapacityPercent: Int
    let cycleCount: Int?
    let batteryStateText: String
    let manufacturedYearMonth: String?
    let firstUsedYearMonth: String?
    let capturedAt: Date
    let source: BatteryConditionSource
    let ocrRawText: String
}

struct ExperienceLog: Identifiable, Codable {
    var id = UUID()
    let recordedAt: Date
    let usageStatus: UsageStatusOption
    let satisfactionScore: Int
    let batteryComplaint: String
    let storageComplaint: String
    var performanceComplaint = "特にない"
    let sizeFit: SizeFitOption
    let cameraSatisfaction: String
    var upgradeIntent: UpgradeIntentOption = .keepUsing
    let note: String
}

struct TradeValueEstimate: Identifiable, Codable {
    var id = UUID()
    let lowPrice: Int
    let highPrice: Int
    let checkedAt: Date
}

struct IPhoneDiagnosisLog: Identifiable, Codable {
    var id = UUID()
    let diagnosedAt: Date
    let title: String
    let summary: String
    let reasons: [String]
    let recommendedAction: String
}

struct IPhoneTask: Identifiable, Codable {
    var id = UUID()
    let type: IPhoneTaskType
    var status: IPhoneTaskStatus
    let createdAt: Date
    let dueAt: Date?
    let ownershipID: UUID
}

struct IPhoneOwnership: Identifiable, Codable {
    let id: UUID
    let product: IPhoneProduct
    let status: IPhoneOwnershipStatus
    let storageCapacityGB: Int
    let colorName: String
    let registeredAt: Date
    let purchasedAt: Date?
    let purchasePrice: Int?
    let soldAt: Date?
    let soldPrice: Int?
    let lastUpdatedAt: Date
    let manuallyConfirmed: Bool
    let detectionConfidence: Double
    let latestSnapshot: DetectedDeviceSnapshot?
    let batteryHealthLogs: [BatteryHealthLog]
    let experienceLogs: [ExperienceLog]
    var tradeValueEstimate: TradeValueEstimate? = nil
    var diagnosisLogs: [IPhoneDiagnosisLog] = []
    var batteryConditionSnapshots: [BatteryConditionSnapshot] = []

    var latestBatteryHealth: BatteryHealthLog? {
        batteryHealthLogs.sorted { $0.checkedAt > $1.checkedAt }.first
    }

    var latestBatteryCondition: BatteryConditionSnapshot? {
        batteryConditionSnapshots.sorted { $0.capturedAt > $1.capturedAt }.first
    }

    var latestExperienceLog: ExperienceLog? {
        experienceLogs.sorted { $0.recordedAt > $1.recordedAt }.first
    }

    var storageUsageRatio: Double? {
        guard let snapshot = latestSnapshot, storageCapacityGB > 0 else { return nil }
        let used = max(storageCapacityGB - snapshot.freeStorageGB, 0)
        return Double(used) / Double(storageCapacityGB)
    }

    var freeStorageRatio: Double? {
        guard let snapshot = latestSnapshot, storageCapacityGB > 0 else { return nil }
        return Double(snapshot.freeStorageGB) / Double(storageCapacityGB)
    }

    var usagePeriodText: String {
        guard let firstUsed = latestBatteryCondition?.firstUsedYearMonth,
              let firstUsedDate = YearMonthParser.date(from: firstUsed) else {
            return "未確認"
        }

        let components = Calendar.current.dateComponents([.year, .month], from: firstUsedDate, to: .now)
        let years = max(components.year ?? 0, 0)
        let months = max(components.month ?? 0, 0)

        if years > 0 {
            return "\(years)年\(months)か月"
        }

        return "\(months)か月"
    }
}

enum YearMonthParser {
    static func date(from text: String) -> Date? {
        let normalized = text
            .replacingOccurrences(of: "年", with: "-")
            .replacingOccurrences(of: "月", with: "")
            .replacingOccurrences(of: "/", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = normalized.split(separator: "-").compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }
        return Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: 1))
    }
}

struct IPhoneConcern: Identifiable {
    let id = UUID()
    let title: String
    let status: IPhoneConcernStatus
}

struct IPhoneDiagnosisSummary {
    let title: String
    let summary: String
    let reasons: [String]
    let recommendedAction: String
    let concerns: [IPhoneConcern]
    let valueCheckNeed: Int
}

struct IPhoneSearchSuggestion: Identifiable, Codable {
    var id = UUID()
    let title: String
    let subtitle: String
}

struct IPhoneDiagnosisPrompt: Identifiable, Codable {
    var id = UUID()
    let title: String
    let summary: String
    let answer: String
}

struct AppNotificationSetting: Identifiable, Codable {
    var id = UUID()
    let title: String
    let subtitle: String
    let enabled: Bool
}

struct AppSettingsData: Codable {
    let notifications: [AppNotificationSetting]
}

struct DeviceSnapshot: Codable, Equatable {
    var deviceIdentifier: String
    var marketingName: String
    var colorName: String?
    var iosVersion: String
    var storageTotalGB: Double?
    var storageFreeGB: Double?
    var batteryCapacityPercent: Int?
    var cycleCount: Int?
    var manufactureDateText: String?
    var firstUseDateText: String?
    var firstUseMonths: Int?
    var tradeInPriceYen: Int?
    var updatedAt: Date

    init(ownership: IPhoneOwnership) {
        let latestCondition = ownership.latestBatteryCondition
        self.deviceIdentifier = ownership.latestSnapshot?.hardwareIdentifier ?? ""
        self.marketingName = ownership.product.name
        self.colorName = ownership.colorName == "未設定" ? nil : ownership.colorName
        self.iosVersion = ownership.latestSnapshot?.osVersion ?? ""
        self.storageTotalGB = Double(ownership.storageCapacityGB)
        self.storageFreeGB = ownership.latestSnapshot.map { Double($0.freeStorageGB) }
        self.batteryCapacityPercent = latestCondition?.maximumCapacityPercent ?? ownership.latestBatteryHealth?.healthPercent
        self.cycleCount = latestCondition?.cycleCount
        self.manufactureDateText = latestCondition?.manufacturedYearMonth
        self.firstUseDateText = latestCondition?.firstUsedYearMonth
        self.firstUseMonths = Self.monthsSinceYearMonth(latestCondition?.firstUsedYearMonth)
        self.tradeInPriceYen = ownership.tradeValueEstimate?.lowPrice
        self.updatedAt = ownership.lastUpdatedAt
    }

    private static func monthsSinceYearMonth(_ text: String?) -> Int? {
        guard let text, let date = YearMonthParser.date(from: text) else { return nil }
        let components = Calendar.current.dateComponents([.month], from: date, to: .now)
        return max(components.month ?? 0, 0)
    }
}

struct RemoteAppConfig: Codable, Equatable {
    let version: Int
    let publishedAt: Date
    let ios: RemoteIOSConfig
    let thresholds: RemoteThresholdConfig
    let rules: [RuleDefinition]

    static let fallback = RemoteAppConfig(
        version: 1,
        publishedAt: Date(timeIntervalSince1970: 1_779_408_000),
        ios: RemoteIOSConfig(
            latestGlobalVersion: "26.5",
            releaseDate: "2026-05-11",
            severity: .normal,
            message: "利用できるアップデートがある可能性があります。設定アプリから確認しましょう。"
        ),
        thresholds: RemoteThresholdConfig(
            batteryWarningPercent: 85,
            batteryCriticalPercent: 80,
            storageWarningGB: 20,
            storageCriticalGB: 10
        ),
        rules: [
            RuleDefinition(
                id: "battery-unchecked",
                title: "バッテリー最大容量を確認する",
                description: "設定アプリのバッテリー画面スクショを追加すると、より正確に状態を見られます。",
                targetSurface: .todo,
                severity: .info,
                ctaLabel: "スクショを追加",
                actionType: "battery_ocr",
                accessLevel: .free,
                priority: 10,
                isActive: true,
                conditions: [RuleCondition(metric: "battery_capacity_percent", operatorName: .isNull, value: nil)]
            ),
            RuleDefinition(
                id: "storage-low",
                title: "空き容量を少し整理する",
                description: "空き容量が少ないため、写真や動画の整理が買い替え判断の材料になります。",
                targetSurface: .caution,
                severity: .warning,
                ctaLabel: "容量を確認",
                actionType: "storage_guide",
                accessLevel: .free,
                priority: 20,
                isActive: true,
                conditions: [RuleCondition(metric: "storage_free_gb", operatorName: .lte, value: 10)]
            ),
            RuleDefinition(
                id: "battery-replacement-candidate",
                title: "バッテリー交換も比較する",
                description: "最大容量が80%未満なら、買い替えだけでなく交換費用も並べて見ましょう。",
                targetSurface: .solve,
                severity: .warning,
                ctaLabel: "交換と買い替えを比較",
                actionType: "battery_compare",
                accessLevel: .free,
                priority: 30,
                isActive: true,
                conditions: [RuleCondition(metric: "battery_capacity_percent", operatorName: .lt, value: 80)]
            )
        ]
    )
}

struct RemoteIOSConfig: Codable, Equatable {
    let latestGlobalVersion: String
    let releaseDate: String?
    let severity: RemoteSeverity
    let message: String
}

struct RemoteThresholdConfig: Codable, Equatable {
    let batteryWarningPercent: Int
    let batteryCriticalPercent: Int
    let storageWarningGB: Int
    let storageCriticalGB: Int
}

enum RemoteSeverity: String, Codable {
    case info
    case normal
    case warning
    case critical
}

enum RemoteAccessLevel: String, Codable {
    case free
    case pro
}

enum RemoteActionSurface: String, Codable {
    case todo
    case caution
    case solve
    case diagnosis
}

struct RuleDefinition: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let description: String
    let targetSurface: RemoteActionSurface
    let severity: RemoteSeverity
    let ctaLabel: String?
    let actionType: String?
    let accessLevel: RemoteAccessLevel
    let priority: Int
    let isActive: Bool
    let conditions: [RuleCondition]
}

struct RuleCondition: Codable, Equatable {
    let metric: String
    let operatorName: RuleConditionOperator
    let value: Double?
}

enum RuleConditionOperator: String, Codable {
    case eq
    case neq
    case lt
    case lte
    case gt
    case gte
    case isNull = "is_null"
    case isNotNull = "is_not_null"
}

struct MatchedRuleResult: Equatable {
    let todoItems: [RuleDefinition]
    let cautionItems: [RuleDefinition]
    let solveItems: [RuleDefinition]
    let diagnosisHints: [RuleDefinition]

    static let empty = MatchedRuleResult(todoItems: [], cautionItems: [], solveItems: [], diagnosisHints: [])
}

struct IPhoneAppData {
    let ownerships: [IPhoneOwnership]
    let tasks: [IPhoneTask]
    let products: [IPhoneProduct]
    let searchSuggestions: [IPhoneSearchSuggestion]
    let diagnosisPrompts: [IPhoneDiagnosisPrompt]
    let settings: AppSettingsData
    let currentDeviceDetection: DetectedDeviceSnapshot

    var currentOwnership: IPhoneOwnership? {
        ownerships.first { $0.status == .current }
    }

    var pastOwnerships: [IPhoneOwnership] {
        ownerships.filter { $0.status == .past }
    }

    var openTasks: [IPhoneTask] {
        tasks.filter { $0.status == .open }
    }

    func openTasks(for ownershipID: UUID) -> [IPhoneTask] {
        openTasks.filter { $0.ownershipID == ownershipID }
    }

    func hasOpenTasks(for ownershipID: UUID) -> Bool {
        !openTasks(for: ownershipID).isEmpty
    }

    func diagnosisSummary(for ownership: IPhoneOwnership) -> IPhoneDiagnosisSummary {
        let batteryRisk = batteryRisk(for: ownership)
        let storageRisk = storageRisk(for: ownership)
        let performanceRisk = performanceRisk(for: ownership)
        let sizeMismatch = sizeMismatch(for: ownership)
        let cameraNeed = cameraNeed(for: ownership)
        let upgradeIntent = upgradeIntent(for: ownership)
        let valueCheckNeed = max(upgradeIntent >= 2 || batteryRisk >= 2 || storageRisk >= 2 ? 2 : 0, ownership.tradeValueEstimate == nil ? 1 : 0)

        let concerns = [
            IPhoneConcern(title: "バッテリー", status: batteryStatus(from: batteryRisk, ownership: ownership)),
            IPhoneConcern(title: "容量", status: storageStatus(from: storageRisk, ownership: ownership)),
            IPhoneConcern(title: "使用感", status: ownership.latestExperienceLog == nil ? .waiting : performanceRisk >= 2 ? .reviewCandidate : .good),
            IPhoneConcern(title: "相場", status: valueCheckNeed >= 2 ? .reviewCandidate : ownership.tradeValueEstimate == nil ? .waiting : .good)
        ]

        if batteryRisk >= 2 && (storageRisk >= 2 || performanceRisk >= 2 || cameraNeed >= 2) {
            return IPhoneDiagnosisSummary(
                title: "買い替えも比較した方がよさそう",
                summary: "バッテリー交換だけでなく、買い替えも比較してよさそうです。",
                reasons: diagnosisReasons(ownership: ownership, batteryRisk: batteryRisk, storageRisk: storageRisk, performanceRisk: performanceRisk, cameraNeed: cameraNeed),
                recommendedAction: "相場を確認して、交換費用と買い替え費用を並べて見ましょう。",
                concerns: concerns,
                valueCheckNeed: valueCheckNeed
            )
        }

        if cameraNeed >= 2 {
            return IPhoneDiagnosisSummary(
                title: "Proモデルが向いている可能性あり",
                summary: "カメラを重視するなら、Pro系も候補に入れてよさそうです。",
                reasons: diagnosisReasons(ownership: ownership, batteryRisk: batteryRisk, storageRisk: storageRisk, performanceRisk: performanceRisk, cameraNeed: cameraNeed),
                recommendedAction: "次は同じサイズ帯のPro系と容量アップを比較しましょう。",
                concerns: concerns,
                valueCheckNeed: valueCheckNeed
            )
        }

        if sizeMismatch >= 2 {
            return IPhoneDiagnosisSummary(
                title: "サイズ選びを見直した方がよさそう",
                summary: "次に選ぶときは、性能よりもサイズ感を優先した方が満足度が上がりそうです。",
                reasons: diagnosisReasons(ownership: ownership, batteryRisk: batteryRisk, storageRisk: storageRisk, performanceRisk: performanceRisk, cameraNeed: cameraNeed),
                recommendedAction: "小さめ・軽め・大画面のどれを優先するか、使用感ログをもう少し残しましょう。",
                concerns: concerns,
                valueCheckNeed: valueCheckNeed
            )
        }

        if storageRisk >= 2 && cameraNeed <= 1 && performanceRisk <= 1 {
            return IPhoneDiagnosisSummary(
                title: "次は容量を上げた方がよさそう",
                summary: "次にiPhoneを選ぶときは、今より大きい容量を選ぶと安心です。",
                reasons: diagnosisReasons(ownership: ownership, batteryRisk: batteryRisk, storageRisk: storageRisk, performanceRisk: performanceRisk, cameraNeed: cameraNeed),
                recommendedAction: "次回は256GB以上を候補にして、今のiPhoneの相場も確認しましょう。",
                concerns: concerns,
                valueCheckNeed: valueCheckNeed
            )
        }

        if batteryRisk >= 2 && storageRisk <= 1 && performanceRisk <= 1 && cameraNeed <= 1 {
            return IPhoneDiagnosisSummary(
                title: "バッテリー交換で延命できそう",
                summary: "買い替えよりも、まずはバッテリー交換で延命できる可能性があります。",
                reasons: diagnosisReasons(ownership: ownership, batteryRisk: batteryRisk, storageRisk: storageRisk, performanceRisk: performanceRisk, cameraNeed: cameraNeed),
                recommendedAction: "交換費用と現在の相場を見て、延命するかを決めましょう。",
                concerns: concerns,
                valueCheckNeed: valueCheckNeed
            )
        }

        return IPhoneDiagnosisSummary(
            title: "今すぐ買い替えなくてもよさそう",
            summary: "今のiPhoneはまだ問題なく使えそうです。",
            reasons: diagnosisReasons(ownership: ownership, batteryRisk: batteryRisk, storageRisk: storageRisk, performanceRisk: performanceRisk, cameraNeed: cameraNeed),
            recommendedAction: "まずはバッテリー最大容量を入力して、3ヶ月後にもう一度確認しましょう。",
            concerns: concerns,
            valueCheckNeed: valueCheckNeed
        )
    }

    private func batteryRisk(for ownership: IPhoneOwnership) -> Int {
        let healthPercent = ownership.latestBatteryCondition?.maximumCapacityPercent ?? ownership.latestBatteryHealth?.healthPercent
        guard let healthPercent else { return 0 }
        let base: Int
        switch healthPercent {
        case 90...100:
            base = 0
        case 85...89:
            base = 1
        case 80...84:
            base = 2
        default:
            base = healthPercent < 80 ? 3 : 0
        }

        let complaint = ownership.latestExperienceLog?.batteryComplaint ?? ""
        let adjusted = complaint.contains("何度も") || complaint.contains("モバイルバッテリー") ? base + 1 : base
        return min(adjusted, 3)
    }

    private func storageRisk(for ownership: IPhoneOwnership) -> Int {
        let ratio = ownership.freeStorageRatio ?? 1
        let base: Int
        switch ratio {
        case 0.2...:
            base = 0
        case 0.1..<0.2:
            base = 1
        case 0.05..<0.1:
            base = 2
        default:
            base = 3
        }

        let complaint = ownership.latestExperienceLog?.storageComplaint ?? ""
        let adjusted = complaint.contains("常に") || complaint.contains("消す") ? base + 1 : base
        return min(adjusted, 3)
    }

    private func performanceRisk(for ownership: IPhoneOwnership) -> Int {
        let complaint = ownership.latestExperienceLog?.performanceComplaint ?? "特にない"
        if complaint.contains("熱く") || complaint.contains("固まる") || complaint.contains("遅い") { return 2 }
        if complaint.contains("重い") { return 1 }
        return 0
    }

    private func sizeMismatch(for ownership: IPhoneOwnership) -> Int {
        switch ownership.latestExperienceLog?.sizeFit {
        case .heavy, .hardToUseOneHanded:
            return 2
        case .smaller, .larger:
            return 1
        case .good, .none:
            return 0
        }
    }

    private func cameraNeed(for ownership: IPhoneOwnership) -> Int {
        let camera = ownership.latestExperienceLog?.cameraSatisfaction ?? ""
        if camera.contains("仕事") { return 3 }
        if camera.contains("暗い") || camera.contains("ズーム") || camera.contains("動画") { return 2 }
        return 0
    }

    private func upgradeIntent(for ownership: IPhoneOwnership) -> Int {
        switch ownership.latestExperienceLog?.upgradeIntent {
        case .immediately:
            return 3
        case .withinHalfYear, .unsure:
            return 2
        case .interested:
            return 1
        case .keepUsing, .none:
            return 0
        }
    }

    private func batteryStatus(from risk: Int, ownership: IPhoneOwnership) -> IPhoneConcernStatus {
        guard ownership.latestBatteryCondition != nil || ownership.latestBatteryHealth != nil else { return .waiting }
        if risk >= 3 { return .replacementCandidate }
        if risk == 2 { return .replacementCandidate }
        if risk == 1 { return .slightAttention }
        return .good
    }

    private func storageStatus(from risk: Int, ownership: IPhoneOwnership) -> IPhoneConcernStatus {
        guard ownership.latestSnapshot != nil else { return .waiting }
        if risk >= 3 { return .compareUpgrade }
        if risk == 2 { return .reviewCandidate }
        if risk == 1 { return .slightAttention }
        return .good
    }

    private func diagnosisReasons(ownership: IPhoneOwnership, batteryRisk: Int, storageRisk: Int, performanceRisk: Int, cameraNeed: Int) -> [String] {
        var reasons: [String] = []
        if let battery = ownership.latestBatteryCondition {
            reasons.append("バッテリー最大容量は\(battery.maximumCapacityPercent)%です")
        } else if let battery = ownership.latestBatteryHealth {
            reasons.append("バッテリー最大容量は\(battery.healthPercent)%です")
        } else {
            reasons.append("バッテリー最大容量は確認待ちです")
        }
        if let snapshot = ownership.latestSnapshot {
            reasons.append("\(ownership.storageCapacityGB)GB中、\(snapshot.freeStorageGB)GB空いています")
        }
        if performanceRisk >= 2 {
            reasons.append("動作への不満が記録されています")
        } else if ownership.latestExperienceLog != nil {
            reasons.append("使用感ログは記録済みです")
        } else {
            reasons.append("使用感ログはまだ未記録です")
        }
        if cameraNeed >= 2 {
            reasons.append("カメラへのこだわりが強そうです")
        }
        return reasons
    }

    static let sample = IPhoneAppData(
        ownerships: SampleData.ownerships,
        tasks: SampleData.tasks,
        products: ProductCatalog.allProducts,
        searchSuggestions: SampleData.searchSuggestions,
        diagnosisPrompts: SampleData.diagnosisPrompts,
        settings: SampleData.settings,
        currentDeviceDetection: SampleData.currentDeviceDetection
    )

    static let freshInstall = IPhoneAppData(
        ownerships: [],
        tasks: [],
        products: ProductCatalog.allProducts,
        searchSuggestions: SampleData.searchSuggestions,
        diagnosisPrompts: SampleData.diagnosisPrompts,
        settings: SampleData.settings,
        currentDeviceDetection: SampleData.currentDeviceDetection
    )
}

struct IPhoneManualDraft {
    var name = ""
    var series = ""
    var storageCapacityGB = 128
    var colorName = ""
    var registeredAt = Date.now
}

struct BatteryHealthDraft {
    var healthPercent = ""
    var note = ""
}

struct OnboardingDraft {
    var selectedModelName: String
    var selectedColorName: String
}

struct ExperienceLogDraft {
    var usageStatus: UsageStatusOption = .main
    var satisfactionScore = 4
    var batteryComplaint = "だいたい持つ"
    var storageComplaint = "困っていない"
    var performanceComplaint = "特にない"
    var sizeFit: SizeFitOption = .good
    var cameraSatisfaction = "特に不満はない"
    var upgradeIntent: UpgradeIntentOption = .keepUsing
    var note = ""
}

enum ProductCatalog {
    static let allProducts: [IPhoneProduct] = [
        IPhoneProduct(name: "iPhone 16 Pro", series: "iPhone 16シリーズ", releaseYear: 2024, imageFilename: "iphone16_pro_natural_titanium.jpg"),
        IPhoneProduct(name: "iPhone 16", series: "iPhone 16シリーズ", releaseYear: 2024, imageFilename: "iphone16_white.jpg"),
        IPhoneProduct(name: "iPhone 16e", series: "iPhone 16シリーズ", releaseYear: 2025, imageFilename: "iphone16e_white.jpg"),
        IPhoneProduct(name: "iPhone 15 Pro", series: "iPhone 15シリーズ", releaseYear: 2023, imageFilename: "iphone15_pro_natural_titanium.jpg"),
        IPhoneProduct(name: "iPhone 15", series: "iPhone 15シリーズ", releaseYear: 2023, imageFilename: "iphone15_blue.jpg"),
        IPhoneProduct(name: "iPhone 14 Pro", series: "iPhone 14シリーズ", releaseYear: 2022, imageFilename: nil),
        IPhoneProduct(name: "iPhone 14", series: "iPhone 14シリーズ", releaseYear: 2022, imageFilename: nil),
        IPhoneProduct(name: "iPhone 13 Pro", series: "iPhone 13シリーズ", releaseYear: 2021, imageFilename: "iphone13_pro_sierra_blue.jpg"),
        IPhoneProduct(name: "iPhone 13", series: "iPhone 13シリーズ", releaseYear: 2021, imageFilename: "iphone13_blue.jpg"),
        IPhoneProduct(name: "iPhone 12 Pro", series: "iPhone 12シリーズ", releaseYear: 2020, imageFilename: nil),
        IPhoneProduct(name: "iPhone 12", series: "iPhone 12シリーズ", releaseYear: 2020, imageFilename: nil),
        IPhoneProduct(name: "iPhone SE 3", series: "iPhone SE", releaseYear: 2022, imageFilename: "iphoneSE_3rd_gen_starlight.jpg"),
        IPhoneProduct(name: "iPhone SE 2", series: "iPhone SE", releaseYear: 2020, imageFilename: "iphoneSE_2nd_gen_white.jpg"),
        IPhoneProduct(name: "iPhone 11", series: "iPhone 11シリーズ", releaseYear: 2019, imageFilename: "iphone11_green.jpg")
    ]

    static var recentModels: [IPhoneProduct] {
        allProducts.filter { $0.releaseYear >= 2023 }
    }

    static var seriesNames: [String] {
        Array(Set(allProducts.map(\.series))).sorted(by: >)
    }

    static func products(in series: String) -> [IPhoneProduct] {
        allProducts.filter { $0.series == series }
    }

    static func colorNames(for productName: String) -> [String] {
        switch productName {
        case "iPhone 16 Pro", "iPhone 16 Pro Max":
            return ["ブラックチタニウム", "ホワイトチタニウム", "ナチュラルチタニウム", "デザートチタニウム"]
        default:
            return ["ブラック", "ホワイト", "ブルー", "ピンク", "グリーン", "パープル"]
        }
    }

    static func imageFilename(for productName: String, colorName: String) -> String? {
        let key = "\(productName)|\(colorName)"
        if let filename = colorImageMap[key] {
            return filename
        }
        return allProducts.first { $0.name == productName }?.imageFilename
    }

    static func product(forHardwareIdentifier hardwareIdentifier: String) -> IPhoneProduct? {
        if let identifiedProduct = IPhoneIdentifierCatalog.product(for: hardwareIdentifier) {
            return identifiedProduct
        }
        let modelName = hardwareModelMap[hardwareIdentifier]
        return allProducts.first { $0.name == modelName }
    }

    private static let hardwareModelMap: [String: String] = [
        "iPhone17,1": "iPhone 16 Pro Max",
        "iPhone17,2": "iPhone 16 Pro",
        "iPhone17,3": "iPhone 16",
        "iPhone17,4": "iPhone 16 Plus",
        "iPhone17,5": "iPhone 16e",
        "iPhone16,1": "iPhone 15 Pro",
        "iPhone16,2": "iPhone 15 Pro Max",
        "iPhone15,2": "iPhone 14 Pro",
        "iPhone15,3": "iPhone 14 Pro Max",
        "iPhone14,2": "iPhone 13 Pro",
        "iPhone14,3": "iPhone 13 Pro Max",
        "iPhone12,1": "iPhone 11",
        "iPhone12,8": "iPhone SE 2",
        "iPhone14,6": "iPhone SE 3"
    ]

    private static let colorImageMap: [String: String] = [
        "iPhone 16 Pro|ブラックチタニウム": "iphone16_pro_black_titanium.jpg",
        "iPhone 16 Pro|ホワイトチタニウム": "iphone16_pro_white_titanium.jpg",
        "iPhone 16 Pro|ナチュラルチタニウム": "iphone16_pro_natural_titanium.jpg",
        "iPhone 16 Pro|デザートチタニウム": "iphone16_pro_desert_titanium.jpg",
        "iPhone 16 Pro Max|ブラックチタニウム": "iphone16_pro_max_black_titanium.jpg",
        "iPhone 16 Pro Max|ホワイトチタニウム": "iphone16_pro_max_white_titanium.jpg",
        "iPhone 16 Pro Max|ナチュラルチタニウム": "iphone16_pro_max_natural_titanium.jpg",
        "iPhone 16 Pro Max|デザートチタニウム": "iphone16_pro_max_desert_titanium.jpg",
        "iPhone 16|ブラック": "iphone16_black.jpg",
        "iPhone 16|ホワイト": "iphone16_white.jpg",
        "iPhone 16|ピンク": "iphone16_pink.jpg",
        "iPhone 16|ブルー": "iphone16_ultramarine.jpg",
        "iPhone 16|グリーン": "iphone16_teal.jpg",
        "iPhone 15 Pro|ブラックチタニウム": "iphone15_pro_black_titanium.jpg",
        "iPhone 15 Pro|ホワイトチタニウム": "iphone15_pro_white_titanium.jpg",
        "iPhone 15 Pro|ナチュラルチタニウム": "iphone15_pro_natural_titanium.jpg",
        "iPhone 15 Pro|ブルーチタニウム": "iphone15_pro_blue_titanium.jpg",
        "iPhone 15|ブラック": "iphone15_black.jpg",
        "iPhone 15|ブルー": "iphone15_blue.jpg",
        "iPhone 15|ピンク": "iphone15_pink.jpg",
        "iPhone 15|グリーン": "iphone15_green.jpg",
        "iPhone 15|イエロー": "iphone15_yellow.jpg"
    ]
}

private struct IPhoneIdentifierInfo: Decodable {
    let name: String
    let generation: String
    let releaseDate: String
    let chip: String
}

enum IPhoneIdentifierCatalog {
    static func product(for hardwareIdentifier: String) -> IPhoneProduct? {
        guard let info = identifiers[hardwareIdentifier] else { return nil }
        return ProductCatalog.allProducts.first { $0.name == info.name } ??
            IPhoneProduct(
                name: info.name,
                series: "\(info.generation)シリーズ",
                releaseYear: releaseYear(from: info.releaseDate),
                imageFilename: ProductCatalog.imageFilename(for: info.name, colorName: ProductCatalog.colorNames(for: info.name).first ?? "")
            )
    }

    private static let identifiers: [String: IPhoneIdentifierInfo] = {
        guard let url = Bundle.main.url(forResource: "iphone_identifiers", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: IPhoneIdentifierInfo].self, from: data) else {
            return [:]
        }
        return decoded
    }()

    private static func releaseYear(from releaseDate: String) -> Int {
        Int(releaseDate.prefix(4)) ?? Calendar.current.component(.year, from: .now)
    }
}

enum DeviceDetectionService {
    static func makeSnapshot(products: [IPhoneProduct]) -> DetectedDeviceSnapshot {
        let device = UIDevice.current
        let previousMonitoring = device.isBatteryMonitoringEnabled
        device.isBatteryMonitoringEnabled = true

        let hardwareIdentifier = currentHardwareIdentifier()
        let matchedProduct = ProductCatalog.product(forHardwareIdentifier: hardwareIdentifier)
        let batteryLevel = currentBatteryLevel(from: device)
        let snapshot = DetectedDeviceSnapshot(
            detectedAt: .now,
            hardwareIdentifier: hardwareIdentifier,
            inferredModelName: matchedProduct?.name ?? fallbackModelName(for: hardwareIdentifier, products: products),
            totalStorageGB: currentTotalStorageGB(),
            freeStorageGB: currentFreeStorageGB(),
            osVersion: "\(device.systemName) \(device.systemVersion)",
            batteryLevelPercent: batteryLevel,
            batteryState: BatteryChargeState(deviceState: device.batteryState)
        )

        device.isBatteryMonitoringEnabled = previousMonitoring
        return snapshot
    }

    private static func currentHardwareIdentifier() -> String {
        #if targetEnvironment(simulator)
        if let simulatedIdentifier = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulatedIdentifier
        }
        #endif

        var systemInfo = utsname()
        uname(&systemInfo)
        let identifier = Mirror(reflecting: systemInfo.machine).children.reduce(into: "") { partialResult, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            partialResult.append(Character(UnicodeScalar(UInt8(value))))
        }
        return identifier.isEmpty ? "iPhone" : identifier
    }

    private static func currentBatteryLevel(from device: UIDevice) -> Int? {
        let level = device.batteryLevel
        guard level >= 0 else { return nil }
        return Int((level * 100).rounded())
    }

    private static func currentTotalStorageGB() -> Int {
        let bytes = volumeCapacityValues().volumeTotalCapacity.map(Int64.init) ?? 0
        return normalizedStorageGB(from: bytes)
    }

    private static func currentFreeStorageGB() -> Int {
        let bytes = volumeCapacityValues().volumeAvailableCapacityForImportantUsage ?? 0
        return max(Int((Double(bytes) / 1_000_000_000).rounded()), 0)
    }

    private static func volumeCapacityValues() -> URLResourceValues {
        let homeURL = URL(fileURLWithPath: NSHomeDirectory())
        return (try? homeURL.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey
        ])) ?? URLResourceValues()
    }

    private static func normalizedStorageGB(from bytes: Int64) -> Int {
        let decimalGB = Double(bytes) / 1_000_000_000
        let knownCapacities = [64, 128, 256, 512, 1000, 1024]
        return knownCapacities.min(by: { abs(Double($0) - decimalGB) < abs(Double($1) - decimalGB) }) ?? max(Int(decimalGB.rounded()), 0)
    }

    private static func fallbackModelName(for hardwareIdentifier: String, products: [IPhoneProduct]) -> String {
        if let matchedProduct = products.first(where: { hardwareIdentifier.contains($0.name.replacingOccurrences(of: " ", with: "")) }) {
            return matchedProduct.name
        }

        if hardwareIdentifier.starts(with: "iPhone") {
            return hardwareIdentifier
        }

        return "このiPhone"
    }
}

extension BatteryChargeState {
    init(deviceState: UIDevice.BatteryState) {
        switch deviceState {
        case .charging:
            self = .charging
        case .full:
            self = .full
        case .unplugged:
            self = .unplugged
        default:
            self = .unknown
        }
    }
}

@MainActor
final class LocalPersistenceStore {
    static let shared = LocalPersistenceStore()

    private let defaults: UserDefaults
    private let dataKey = "boubiga.localAppState.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> PersistedAppState? {
        guard let data = defaults.data(forKey: dataKey) else { return nil }
        return try? JSONDecoder.boubiga.decode(PersistedAppState.self, from: data)
    }

    func save(ownerships: [IPhoneOwnership], tasks: [IPhoneTask]) {
        let state = PersistedAppState(ownerships: ownerships, tasks: tasks, savedAt: .now)
        guard let data = try? JSONEncoder.boubiga.encode(state) else { return }
        defaults.set(data, forKey: dataKey)
    }

    func reset() {
        defaults.removeObject(forKey: dataKey)
    }
}

@MainActor
final class AppConfigStore: ObservableObject {
    @Published private(set) var config: RemoteAppConfig
    @Published private(set) var isLoading = false
    @Published private(set) var lastFetchedAt: Date?

    init(config: RemoteAppConfig? = nil) {
        self.config = config ?? RemoteAppConfig.fallback
        loadBundledDefaults()
    }

    func loadBundledDefaults() {
        guard let url = Bundle.main.url(forResource: "bundled_app_config", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder.remoteConfig.decode(RemoteAppConfig.self, from: data) else {
            config = .fallback
            return
        }
        config = decoded
    }

    func refreshConfig() async {
        isLoading = true
        defer { isLoading = false }
        // Supabase接続まではbundled JSONを最新値として扱う。
        loadBundledDefaults()
        lastFetchedAt = .now
    }
}

enum RuleEngine {
    static func evaluate(snapshot: DeviceSnapshot, config: RemoteAppConfig, isPro: Bool) -> MatchedRuleResult {
        let matchedRules = config.rules
            .filter { $0.isActive }
            .filter { isPro || $0.accessLevel == .free }
            .filter { rule in
                rule.conditions.allSatisfy { evaluate($0, snapshot: snapshot) }
            }
            .sorted { $0.priority < $1.priority }

        return MatchedRuleResult(
            todoItems: matchedRules.filter { $0.targetSurface == .todo },
            cautionItems: matchedRules.filter { $0.targetSurface == .caution },
            solveItems: matchedRules.filter { $0.targetSurface == .solve },
            diagnosisHints: matchedRules.filter { $0.targetSurface == .diagnosis }
        )
    }

    private static func evaluate(_ condition: RuleCondition, snapshot: DeviceSnapshot) -> Bool {
        let metricValue = value(for: condition.metric, snapshot: snapshot)

        switch condition.operatorName {
        case .isNull:
            return metricValue == nil
        case .isNotNull:
            return metricValue != nil
        case .eq:
            guard let metricValue, let expected = condition.value else { return false }
            return metricValue == expected
        case .neq:
            guard let metricValue, let expected = condition.value else { return false }
            return metricValue != expected
        case .lt:
            guard let metricValue, let expected = condition.value else { return false }
            return metricValue < expected
        case .lte:
            guard let metricValue, let expected = condition.value else { return false }
            return metricValue <= expected
        case .gt:
            guard let metricValue, let expected = condition.value else { return false }
            return metricValue > expected
        case .gte:
            guard let metricValue, let expected = condition.value else { return false }
            return metricValue >= expected
        }
    }

    private static func value(for metric: String, snapshot: DeviceSnapshot) -> Double? {
        switch metric {
        case "storage_total_gb":
            return snapshot.storageTotalGB
        case "storage_free_gb":
            return snapshot.storageFreeGB
        case "battery_capacity_percent":
            return snapshot.batteryCapacityPercent.map(Double.init)
        case "cycle_count":
            return snapshot.cycleCount.map(Double.init)
        case "first_use_months":
            return snapshot.firstUseMonths.map(Double.init)
        case "trade_in_price_yen":
            return snapshot.tradeInPriceYen.map(Double.init)
        case "ios_major_version":
            return snapshot.iosVersion.split { !$0.isNumber }.first.flatMap { Double($0) }
        default:
            return nil
        }
    }
}

struct PersistedAppState: Codable {
    let ownerships: [IPhoneOwnership]
    let tasks: [IPhoneTask]
    let savedAt: Date
}

private extension JSONEncoder {
    static var boubiga: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var boubiga: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static var remoteConfig: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var ownerships: [IPhoneOwnership]
    @Published private(set) var tasks: [IPhoneTask]
    @Published var currentDeviceDetection: DetectedDeviceSnapshot

    private let persistence: LocalPersistenceStore?
    private let configStore: AppConfigStore

    let products: [IPhoneProduct]
    let searchSuggestions: [IPhoneSearchSuggestion]
    let diagnosisPrompts: [IPhoneDiagnosisPrompt]
    let settings: AppSettingsData

    init(data: IPhoneAppData, persistence: LocalPersistenceStore? = nil, configStore: AppConfigStore? = nil) {
        let liveDetection = DeviceDetectionService.makeSnapshot(products: data.products)
        let persistedState = persistence?.load()
        let initialOwnerships = persistedState?.ownerships ?? data.ownerships
        let initialTasks = persistedState?.tasks ?? data.tasks
        let reconciledOwnerships = AppStore.reconciledOwnerships(from: initialOwnerships, with: liveDetection, products: data.products)
        self.ownerships = reconciledOwnerships
        self.tasks = AppStore.validTasks(from: initialTasks, ownerships: reconciledOwnerships)
        self.products = data.products
        self.searchSuggestions = data.searchSuggestions
        self.diagnosisPrompts = data.diagnosisPrompts
        self.settings = data.settings
        self.currentDeviceDetection = liveDetection
        self.persistence = persistence
        self.configStore = configStore ?? AppConfigStore()
    }

    var snapshot: IPhoneAppData {
        IPhoneAppData(
            ownerships: ownerships,
            tasks: tasks,
            products: products,
            searchSuggestions: searchSuggestions,
            diagnosisPrompts: diagnosisPrompts,
            settings: settings,
            currentDeviceDetection: currentDeviceDetection
        )
    }

    var needsOnboarding: Bool {
        currentOwnership == nil || currentOwnership?.manuallyConfirmed == false
    }

    var currentOwnership: IPhoneOwnership? {
        ownerships.first { $0.status == .current }
    }

    var remoteConfig: RemoteAppConfig {
        configStore.config
    }

    var onboardingDraft: OnboardingDraft {
        let current = currentOwnership
        return OnboardingDraft(
            selectedModelName: current?.product.name ?? currentDeviceDetection.inferredModelName,
            selectedColorName: current?.colorName == "未設定" ? "" : (current?.colorName ?? "")
        )
    }

    func ensureCurrentOwnershipForOnboarding() {
        guard currentOwnership == nil else { return }
        addDetectedCurrentIPhone()
    }

    func resetCurrentIPhoneOnboarding() {
        persistence?.reset()
        ownerships = []
        tasks = []
        currentDeviceDetection = DeviceDetectionService.makeSnapshot(products: products)
        addDetectedCurrentIPhone()
        persist()
    }

    func ruleResult(for ownership: IPhoneOwnership, isPro: Bool = false) -> MatchedRuleResult {
        RuleEngine.evaluate(snapshot: DeviceSnapshot(ownership: ownership), config: remoteConfig, isPro: isPro)
    }

    func completeOnboarding(draft: OnboardingDraft) {
        let selectedProduct = products.first(where: { $0.name == draft.selectedModelName }) ??
            IPhoneProduct(
                name: draft.selectedModelName,
                series: "不明なシリーズ",
                releaseYear: Calendar.current.component(.year, from: .now),
                imageFilename: nil
            )

        if let index = ownerships.firstIndex(where: { $0.status == .current }) {
            let current = ownerships[index]
            ownerships[index] = IPhoneOwnership(
                id: current.id,
                product: selectedProduct,
                status: current.status,
                storageCapacityGB: currentDeviceDetection.totalStorageGB,
                colorName: draft.selectedColorName.isEmpty ? "未設定" : draft.selectedColorName,
                registeredAt: current.registeredAt,
                purchasedAt: current.purchasedAt,
                purchasePrice: current.purchasePrice,
                soldAt: current.soldAt,
                soldPrice: current.soldPrice,
                lastUpdatedAt: .now,
                manuallyConfirmed: true,
                detectionConfidence: current.detectionConfidence,
                latestSnapshot: currentDeviceDetection,
                batteryHealthLogs: current.batteryHealthLogs,
                experienceLogs: current.experienceLogs,
                tradeValueEstimate: current.tradeValueEstimate,
                diagnosisLogs: current.diagnosisLogs,
                batteryConditionSnapshots: current.batteryConditionSnapshots
            )
            persist()
            return
        }

        let ownership = IPhoneOwnership(
            id: UUID(),
            product: selectedProduct,
            status: .current,
            storageCapacityGB: currentDeviceDetection.totalStorageGB,
            colorName: draft.selectedColorName.isEmpty ? "未設定" : draft.selectedColorName,
            registeredAt: .now,
            purchasedAt: nil,
            purchasePrice: nil,
            soldAt: nil,
            soldPrice: nil,
            lastUpdatedAt: .now,
            manuallyConfirmed: true,
            detectionConfidence: 0.95,
            latestSnapshot: currentDeviceDetection,
            batteryHealthLogs: [],
            experienceLogs: [],
            tradeValueEstimate: nil,
            diagnosisLogs: []
        )
        ownerships.insert(ownership, at: 0)
        tasks.insert(IPhoneTask(type: .recordFirstImpression, status: .open, createdAt: .now, dueAt: nil, ownershipID: ownership.id), at: 0)
        tasks.insert(IPhoneTask(type: .inputBatteryHealth, status: .open, createdAt: .now, dueAt: nil, ownershipID: ownership.id), at: 0)
        persist()
    }

    func addDetectedCurrentIPhone() {
        guard !ownerships.contains(where: { $0.status == .current }) else { return }
        let product = products.first(where: { $0.name == currentDeviceDetection.inferredModelName }) ??
            IPhoneProduct(
                name: currentDeviceDetection.inferredModelName,
                series: "不明なシリーズ",
                releaseYear: Calendar.current.component(.year, from: .now),
                imageFilename: nil
            )

        let ownership = IPhoneOwnership(
            id: UUID(),
            product: product,
            status: .current,
            storageCapacityGB: currentDeviceDetection.totalStorageGB,
            colorName: "未設定",
            registeredAt: .now,
            purchasedAt: nil,
            purchasePrice: nil,
            soldAt: nil,
            soldPrice: nil,
            lastUpdatedAt: .now,
            manuallyConfirmed: false,
            detectionConfidence: 0.78,
            latestSnapshot: currentDeviceDetection,
            batteryHealthLogs: [],
            experienceLogs: [],
            tradeValueEstimate: nil,
            diagnosisLogs: []
        )

        ownerships.insert(ownership, at: 0)
        tasks.insert(IPhoneTask(type: .recordFirstImpression, status: .open, createdAt: .now, dueAt: nil, ownershipID: ownership.id), at: 0)
        tasks.insert(IPhoneTask(type: .inputBatteryHealth, status: .open, createdAt: .now, dueAt: nil, ownershipID: ownership.id), at: 0)
        persist()
    }

    func addManualIPhone(from draft: IPhoneManualDraft) {
        let product = products.first(where: { $0.name == draft.name }) ??
            IPhoneProduct(
                name: draft.name,
                series: draft.series.isEmpty ? "手動入力" : draft.series,
                releaseYear: Calendar.current.component(.year, from: .now),
                imageFilename: nil
            )

        let ownership = IPhoneOwnership(
            id: UUID(),
            product: product,
            status: .past,
            storageCapacityGB: draft.storageCapacityGB,
            colorName: draft.colorName.isEmpty ? "未設定" : draft.colorName,
            registeredAt: draft.registeredAt,
            purchasedAt: nil,
            purchasePrice: nil,
            soldAt: nil,
            soldPrice: nil,
            lastUpdatedAt: draft.registeredAt,
            manuallyConfirmed: true,
            detectionConfidence: 1.0,
            latestSnapshot: nil,
            batteryHealthLogs: [],
            experienceLogs: [],
            tradeValueEstimate: nil,
            diagnosisLogs: []
        )

        ownerships.append(ownership)
        persist()
    }

    func completeBatteryHealthTask(for ownershipID: UUID, draft: BatteryHealthDraft) {
        guard let healthPercent = Int(draft.healthPercent) else { return }
        guard let index = ownerships.firstIndex(where: { $0.id == ownershipID }) else { return }

        var ownership = ownerships[index]
        let newLog = BatteryHealthLog(
            healthPercent: healthPercent,
            checkedAt: .now,
            note: draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        var updatedOwnership = IPhoneOwnership(
            id: ownership.id,
            product: ownership.product,
            status: ownership.status,
            storageCapacityGB: ownership.storageCapacityGB,
            colorName: ownership.colorName,
            registeredAt: ownership.registeredAt,
            purchasedAt: ownership.purchasedAt,
            purchasePrice: ownership.purchasePrice,
            soldAt: ownership.soldAt,
            soldPrice: ownership.soldPrice,
            lastUpdatedAt: .now,
            manuallyConfirmed: ownership.manuallyConfirmed,
            detectionConfidence: ownership.detectionConfidence,
            latestSnapshot: ownership.latestSnapshot,
            batteryHealthLogs: [newLog] + ownership.batteryHealthLogs,
            experienceLogs: ownership.experienceLogs,
            tradeValueEstimate: ownership.tradeValueEstimate,
            diagnosisLogs: ownership.diagnosisLogs,
            batteryConditionSnapshots: ownership.batteryConditionSnapshots
        )
        updatedOwnership.diagnosisLogs = refreshedDiagnosisLogs(for: updatedOwnership)
        ownership = updatedOwnership
        ownerships[index] = ownership
        completeTasks([.inputBatteryHealth, .updateBatteryHealth], for: ownershipID)
        persist()
    }

    func completeBatteryCondition(for ownershipID: UUID, snapshot: BatteryConditionSnapshot) {
        guard let index = ownerships.firstIndex(where: { $0.id == ownershipID }) else { return }

        var ownership = ownerships[index]
        let healthLog = BatteryHealthLog(
            healthPercent: snapshot.maximumCapacityPercent,
            checkedAt: snapshot.capturedAt,
            note: "\(snapshot.source.rawValue)で保存"
        )
        var updatedOwnership = IPhoneOwnership(
            id: ownership.id,
            product: ownership.product,
            status: ownership.status,
            storageCapacityGB: ownership.storageCapacityGB,
            colorName: ownership.colorName,
            registeredAt: ownership.registeredAt,
            purchasedAt: ownership.purchasedAt,
            purchasePrice: ownership.purchasePrice,
            soldAt: ownership.soldAt,
            soldPrice: ownership.soldPrice,
            lastUpdatedAt: .now,
            manuallyConfirmed: ownership.manuallyConfirmed,
            detectionConfidence: ownership.detectionConfidence,
            latestSnapshot: ownership.latestSnapshot,
            batteryHealthLogs: [healthLog] + ownership.batteryHealthLogs,
            experienceLogs: ownership.experienceLogs,
            tradeValueEstimate: ownership.tradeValueEstimate,
            diagnosisLogs: ownership.diagnosisLogs,
            batteryConditionSnapshots: [snapshot] + ownership.batteryConditionSnapshots
        )
        updatedOwnership.diagnosisLogs = refreshedDiagnosisLogs(for: updatedOwnership)
        ownership = updatedOwnership
        ownerships[index] = ownership
        completeTasks([.inputBatteryHealth, .updateBatteryHealth], for: ownershipID)
        persist()
    }

    func completeExperienceTask(for ownershipID: UUID, draft: ExperienceLogDraft) {
        guard let index = ownerships.firstIndex(where: { $0.id == ownershipID }) else { return }

        var ownership = ownerships[index]
        let log = ExperienceLog(
            recordedAt: .now,
            usageStatus: draft.usageStatus,
            satisfactionScore: draft.satisfactionScore,
            batteryComplaint: draft.batteryComplaint.trimmingCharacters(in: .whitespacesAndNewlines),
            storageComplaint: draft.storageComplaint.trimmingCharacters(in: .whitespacesAndNewlines),
            performanceComplaint: draft.performanceComplaint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "特にない" : draft.performanceComplaint.trimmingCharacters(in: .whitespacesAndNewlines),
            sizeFit: draft.sizeFit,
            cameraSatisfaction: draft.cameraSatisfaction.trimmingCharacters(in: .whitespacesAndNewlines),
            upgradeIntent: draft.upgradeIntent,
            note: draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        var updatedOwnership = IPhoneOwnership(
            id: ownership.id,
            product: ownership.product,
            status: ownership.status,
            storageCapacityGB: ownership.storageCapacityGB,
            colorName: ownership.colorName,
            registeredAt: ownership.registeredAt,
            purchasedAt: ownership.purchasedAt,
            purchasePrice: ownership.purchasePrice,
            soldAt: ownership.soldAt,
            soldPrice: ownership.soldPrice,
            lastUpdatedAt: .now,
            manuallyConfirmed: ownership.manuallyConfirmed,
            detectionConfidence: ownership.detectionConfidence,
            latestSnapshot: ownership.latestSnapshot,
            batteryHealthLogs: ownership.batteryHealthLogs,
            experienceLogs: [log] + ownership.experienceLogs,
            tradeValueEstimate: ownership.tradeValueEstimate,
            diagnosisLogs: ownership.diagnosisLogs,
            batteryConditionSnapshots: ownership.batteryConditionSnapshots
        )
        updatedOwnership.diagnosisLogs = refreshedDiagnosisLogs(for: updatedOwnership)
        ownership = updatedOwnership
        ownerships[index] = ownership
        completeTasks([.recordFirstImpression], for: ownershipID)
        persist()
    }

    func markTradeValueChecked(for ownershipID: UUID) {
        guard let index = ownerships.firstIndex(where: { $0.id == ownershipID }) else { return }
        var ownership = ownerships[index]
        let estimate = TradeValueEstimate(lowPrice: 92_000, highPrice: 108_000, checkedAt: .now)
        var updatedOwnership = IPhoneOwnership(
            id: ownership.id,
            product: ownership.product,
            status: ownership.status,
            storageCapacityGB: ownership.storageCapacityGB,
            colorName: ownership.colorName,
            registeredAt: ownership.registeredAt,
            purchasedAt: ownership.purchasedAt,
            purchasePrice: ownership.purchasePrice,
            soldAt: ownership.soldAt,
            soldPrice: ownership.soldPrice,
            lastUpdatedAt: .now,
            manuallyConfirmed: ownership.manuallyConfirmed,
            detectionConfidence: ownership.detectionConfidence,
            latestSnapshot: ownership.latestSnapshot,
            batteryHealthLogs: ownership.batteryHealthLogs,
            experienceLogs: ownership.experienceLogs,
            tradeValueEstimate: estimate,
            diagnosisLogs: ownership.diagnosisLogs,
            batteryConditionSnapshots: ownership.batteryConditionSnapshots
        )
        updatedOwnership.diagnosisLogs = refreshedDiagnosisLogs(for: updatedOwnership)
        ownership = updatedOwnership
        ownerships[index] = ownership
        completeTasks([.checkTradeInValue], for: ownershipID)
        persist()
    }

    private func completeTasks(_ types: [IPhoneTaskType], for ownershipID: UUID) {
        tasks = tasks.map { task in
            guard task.ownershipID == ownershipID, types.contains(task.type), task.status == .open else {
                return task
            }
            return IPhoneTask(type: task.type, status: .completed, createdAt: task.createdAt, dueAt: task.dueAt, ownershipID: task.ownershipID)
        }
    }

    private func persist() {
        persistence?.save(ownerships: ownerships, tasks: tasks)
    }

    private static func validTasks(from tasks: [IPhoneTask], ownerships: [IPhoneOwnership]) -> [IPhoneTask] {
        tasks.filter { task in
            ownerships.contains { $0.id == task.ownershipID }
        }
    }

    private static func reconciledOwnerships(from ownerships: [IPhoneOwnership], with detection: DetectedDeviceSnapshot, products: [IPhoneProduct]) -> [IPhoneOwnership] {
        ownerships.map { ownership in
            guard ownership.status == .current else { return ownership }

            let detectedProduct = ProductCatalog.product(forHardwareIdentifier: detection.hardwareIdentifier)
                ?? products.first(where: { $0.name == detection.inferredModelName })
            let product = ownership.manuallyConfirmed ? ownership.product : (detectedProduct ?? ownership.product)

            return IPhoneOwnership(
                id: ownership.id,
                product: product,
                status: ownership.status,
                storageCapacityGB: detection.totalStorageGB,
                colorName: ownership.colorName,
                registeredAt: ownership.registeredAt,
                purchasedAt: ownership.purchasedAt,
                purchasePrice: ownership.purchasePrice,
                soldAt: ownership.soldAt,
                soldPrice: ownership.soldPrice,
                lastUpdatedAt: detection.detectedAt,
                manuallyConfirmed: ownership.manuallyConfirmed,
                detectionConfidence: product.name == detection.inferredModelName ? 0.95 : ownership.detectionConfidence,
                latestSnapshot: detection,
                batteryHealthLogs: ownership.batteryHealthLogs,
                experienceLogs: ownership.experienceLogs,
                tradeValueEstimate: ownership.tradeValueEstimate,
                diagnosisLogs: ownership.diagnosisLogs,
                batteryConditionSnapshots: ownership.batteryConditionSnapshots
            )
        }
    }

    private func refreshedDiagnosisLogs(for ownership: IPhoneOwnership) -> [IPhoneDiagnosisLog] {
        let summary = snapshot.diagnosisSummary(for: ownership)
        let log = IPhoneDiagnosisLog(
            diagnosedAt: .now,
            title: summary.title,
            summary: summary.summary,
            reasons: summary.reasons,
            recommendedAction: summary.recommendedAction
        )
        return [log] + ownership.diagnosisLogs
    }
}

enum SampleData {
    static let calendar = Calendar(identifier: .gregorian)

    static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .now
    }

    static let currentOwnershipID = UUID()
    static let pastOwnership13ID = UUID()
    static let pastOwnership11ID = UUID()

    static let currentDeviceDetection = DetectedDeviceSnapshot(
        detectedAt: date(2026, 5, 18),
        hardwareIdentifier: "iPhone17,2",
        inferredModelName: "iPhone 16 Pro",
        totalStorageGB: 256,
        freeStorageGB: 78,
        osVersion: "iOS 18.5",
        batteryLevelPercent: 73,
        batteryState: .charging
    )

    static let ownerships: [IPhoneOwnership] = [
        IPhoneOwnership(
            id: currentOwnershipID,
            product: ProductCatalog.allProducts.first { $0.name == "iPhone 16 Pro" }!,
            status: .current,
            storageCapacityGB: 256,
            colorName: "ブラックチタニウム",
            registeredAt: date(2026, 5, 18),
            purchasedAt: nil,
            purchasePrice: nil,
            soldAt: nil,
            soldPrice: nil,
            lastUpdatedAt: date(2026, 5, 18),
            manuallyConfirmed: true,
            detectionConfidence: 0.78,
            latestSnapshot: currentDeviceDetection,
            batteryHealthLogs: [],
            experienceLogs: [],
            tradeValueEstimate: TradeValueEstimate(lowPrice: 92_000, highPrice: 108_000, checkedAt: date(2026, 5, 18)),
            diagnosisLogs: [],
            batteryConditionSnapshots: []
        ),
        IPhoneOwnership(
            id: pastOwnership13ID,
            product: ProductCatalog.allProducts.first { $0.name == "iPhone 13 Pro" }!,
            status: .past,
            storageCapacityGB: 128,
            colorName: "シエラブルー",
            registeredAt: date(2026, 5, 18),
            purchasedAt: date(2022, 2, 12),
            purchasePrice: 122800,
            soldAt: date(2024, 9, 20),
            soldPrice: 69000,
            lastUpdatedAt: date(2026, 5, 18),
            manuallyConfirmed: true,
            detectionConfidence: 1.0,
            latestSnapshot: nil,
            batteryHealthLogs: [
                BatteryHealthLog(healthPercent: 85, checkedAt: date(2024, 6, 10), note: "")
            ],
            experienceLogs: [
                ExperienceLog(
                    recordedAt: date(2024, 6, 10),
                    usageStatus: .main,
                    satisfactionScore: 4,
                    batteryComplaint: "夕方には少し減りが気になる",
                    storageComplaint: "",
                    sizeFit: .good,
                    cameraSatisfaction: "十分満足",
                    note: "次も同じサイズ感が良さそう。"
                )
            ]
        ),
        IPhoneOwnership(
            id: pastOwnership11ID,
            product: ProductCatalog.allProducts.first { $0.name == "iPhone 11" }!,
            status: .past,
            storageCapacityGB: 128,
            colorName: "グリーン",
            registeredAt: date(2026, 5, 18),
            purchasedAt: date(2020, 3, 15),
            purchasePrice: 84800,
            soldAt: date(2022, 2, 12),
            soldPrice: nil,
            lastUpdatedAt: date(2026, 5, 18),
            manuallyConfirmed: true,
            detectionConfidence: 1.0,
            latestSnapshot: nil,
            batteryHealthLogs: [],
            experienceLogs: [
                ExperienceLog(
                    recordedAt: date(2021, 10, 1),
                    usageStatus: .main,
                    satisfactionScore: 4,
                    batteryComplaint: "",
                    storageComplaint: "写真で容量が埋まりやすかった",
                    sizeFit: .good,
                    cameraSatisfaction: "十分満足",
                    note: "容量だけ少し不安があった。"
                )
            ]
        )
    ]

    static let tasks: [IPhoneTask] = [
        IPhoneTask(type: .inputBatteryHealth, status: .open, createdAt: date(2026, 5, 20), dueAt: nil, ownershipID: currentOwnershipID)
    ]

    static let searchSuggestions: [IPhoneSearchSuggestion] = [
        IPhoneSearchSuggestion(title: "容量不足が気になる人", subtitle: "次は 256GB 以上を優先して探す"),
        IPhoneSearchSuggestion(title: "バッテリーの持ちを改善したい", subtitle: "最新世代かバッテリー交換を比較する"),
        IPhoneSearchSuggestion(title: "同じサイズ感で探す", subtitle: "Pro 系の標準サイズを中心に見る")
    ]

    static let diagnosisPrompts: [IPhoneDiagnosisPrompt] = [
        IPhoneDiagnosisPrompt(
            title: "容量が足りない",
            summary: "写真やアプリで埋まりやすいとき",
            answer: "256GB 以上を優先して、新しい標準サイズか Plus を見比べる"
        ),
        IPhoneDiagnosisPrompt(
            title: "電池の減りが気になる",
            summary: "まず交換か買い替えかを見極めたいとき",
            answer: "バッテリー最大容量の入力を先に済ませてから、最新世代との比較に進む"
        ),
        IPhoneDiagnosisPrompt(
            title: "サイズ感は変えたくない",
            summary: "持ちやすさを保って次を探したいとき",
            answer: "今と近い標準サイズを軸にして、Pro と無印の差だけを見る"
        )
    ]

    static let settings = AppSettingsData(
        notifications: [
            AppNotificationSetting(title: "バッテリー更新リマインド", subtitle: "90日以上経ったらお知らせ", enabled: true),
            AppNotificationSetting(title: "使用感ログの記録リマインド", subtitle: "一定期間ごとに今の感想を聞く", enabled: false),
            AppNotificationSetting(title: "データエクスポート準備通知", subtitle: "将来機能の先行案内", enabled: false)
        ]
    )
}
