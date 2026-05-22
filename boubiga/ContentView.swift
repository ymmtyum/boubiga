//
//  ContentView.swift
//  boubiga
//
//  Created by Codex on 2026/05/18.
//

import SwiftUI
import UIKit
import PhotosUI
import Vision
import StoreKit

struct ContentView: View {
    @StateObject private var store = AppStore(data: .freshInstall, persistence: .shared)
    @StateObject private var entitlementManager = EntitlementManager()
    @State private var isShowingSettings = false
    @State private var isShowingOnboarding = false

    var body: some View {
        MyIPhoneHomeView(store: store, entitlementManager: entitlementManager, isShowingSettings: $isShowingSettings)
        .sheet(isPresented: $isShowingSettings) {
            SettingsSheetView(store: store, isPresented: $isShowingSettings)
        }
        .fullScreenCover(isPresented: $isShowingOnboarding) {
            OnboardingFlowView(store: store, isPresented: $isShowingOnboarding)
        }
        .onAppear {
            store.ensureCurrentOwnershipForOnboarding()
            isShowingOnboarding = store.needsOnboarding
        }
        .onChange(of: store.needsOnboarding) { _, needsOnboarding in
            isShowingOnboarding = needsOnboarding
        }
        .task {
            await store.refreshRemoteConfig()
            await entitlementManager.loadProducts()
        }
    }
}

private struct MyIPhoneHomeView: View {
    @ObservedObject var store: AppStore
    @ObservedObject var entitlementManager: EntitlementManager
    @Binding var isShowingSettings: Bool
    @State private var isShowingTaskFlow = false
    @State private var isShowingBatteryOCR = false
    @State private var isShowingDiagnosisResult = false
    @State private var isShowingPaywall = false
    @State private var selectedConcernSolution: IPhoneConcern?
    @State private var preferredTask: IPhoneTaskType?

    private var data: IPhoneAppData { store.snapshot }
    private var openTaskCount: Int {
        guard let current = data.currentOwnership else { return 0 }
        return store.pendingActionCount(for: current, isPro: entitlementManager.isPro)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let current = data.currentOwnership {
                        let ruleResult = store.ruleResult(for: current)

                        NavigationLink {
                            IPhoneDetailView(ownership: current, tasks: data.openTasks(for: current.id))
                        } label: {
                            CurrentIPhoneCard(ownership: current)
                        }
                        .buttonStyle(.plain)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            BatteryMeterCard(ownership: current)
                            StorageMeterCard(ownership: current)
                            UsagePeriodMeterCard(ownership: current)
                            TradeValueMeterCard(ownership: current)
                            DeviceInfoMeterCard(ownership: current, latestIOSVersion: store.remoteConfig.ios.latestGlobalVersion)
                        }

                        if current.latestBatteryCondition == nil && current.latestBatteryHealth == nil {
                            BatteryPromptCard {
                                isShowingBatteryOCR = true
                            }
                        }

                        RuleDrivenInsightCard(result: ruleResult) { actionType in
                            handleRuleAction(actionType)
                        }

                        ConcernSummaryCard(summary: data.diagnosisSummary(for: current)) { concern in
                            selectedConcernSolution = concern
                        }

                        IPhoneDiagnosisEntryCard(current: current) {
                            isShowingDiagnosisResult = true
                        }

                    } else {
                        ContentUnavailableView("iPhoneを設定中です", systemImage: "iphone")
                            .frame(maxWidth: .infinity)
                            .padding(.top, 80)
                    }
                }
                .padding()
            }
            .background(
                LinearGradient(
                    colors: [Color(.systemGroupedBackground), Color(red: 0.93, green: 0.97, blue: 0.95)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        ToolbarCircleIcon(systemName: "gearshape.fill", accessibilityLabel: "設定")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("設定")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        preferredTask = nil
                        isShowingTaskFlow = true
                    } label: {
                        ToolbarCircleIcon(systemName: "checkmark", badgeText: openTaskCount > 0 ? taskBadgeText : nil, accessibilityLabel: "やることリスト")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("やることリスト")
                }
            }
            .sheet(isPresented: $isShowingTaskFlow) {
                TaskFlowView(store: store, ownership: data.currentOwnership, preferredTask: preferredTask) {
                    isShowingTaskFlow = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        isShowingBatteryOCR = true
                    }
                }
            }
            .sheet(isPresented: $isShowingBatteryOCR) {
                BatteryOCRFlowView(store: store, ownership: data.currentOwnership)
            }
            .sheet(isPresented: $isShowingDiagnosisResult) {
                DiagnosisResultView(
                    ownership: data.currentOwnership,
                    summary: data.currentOwnership.map { data.diagnosisSummary(for: $0) },
                    ruleResult: data.currentOwnership.map { store.ruleResult(for: $0, isPro: entitlementManager.isPro) } ?? .empty,
                    isPro: entitlementManager.isPro
                ) {
                    isShowingPaywall = true
                }
            }
            .sheet(isPresented: $isShowingPaywall) {
                PaywallView(entitlementManager: entitlementManager)
            }
            .sheet(item: $selectedConcernSolution) { concern in
                ConcernSolutionSheet(concern: concern) {
                    selectedConcernSolution = nil
                    if concern.title == "バッテリー" {
                        isShowingBatteryOCR = true
                    } else if concern.title == "相場" {
                        openTask(.checkTradeInValue)
                    } else if concern.title == "使用感" {
                        openTask(.recordFirstImpression)
                    }
                }
            }
        }
    }

    private func openTask(_ task: IPhoneTaskType) {
        preferredTask = task
        isShowingTaskFlow = true
    }

    private func handleRuleAction(_ actionType: String?) {
        switch actionType {
        case "battery_ocr", "battery_compare":
            isShowingBatteryOCR = true
        case "storage_guide":
            selectedConcernSolution = IPhoneConcern(title: "容量", status: .reviewCandidate)
        default:
            preferredTask = nil
            isShowingTaskFlow = true
        }
    }

    private var taskBadgeText: String {
        openTaskCount > 9 ? "9+" : "\(openTaskCount)"
    }
}

private struct ToolbarCircleIcon: View {
    let systemName: String
    var badgeText: String?
    let accessibilityLabel: String

    private let buttonSize: CGFloat = 44
    private let iconSize: CGFloat = 23
    private let badgeSize: CGFloat = 15

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: buttonSize, height: buttonSize)
                .background(
                    Circle()
                        .fill(.white.opacity(0.94))
                )

            if let badgeText {
                ZStack {
                    Circle()
                        .fill(.red)
                    Text(badgeText)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.7)
                }
                .frame(width: badgeSize, height: badgeSize)
                .offset(x: -1, y: 1)
            }
        }
        .frame(width: buttonSize, height: buttonSize)
        .fixedSize()
        .contentShape(Circle())
        .accessibilityHidden(true)
    }
}

private struct CurrentIPhoneCard: View {
    let ownership: IPhoneOwnership

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            IPhoneArtworkView(imageFilename: ProductCatalog.imageFilename(for: ownership.product.name, colorName: ownership.colorName))
                .frame(height: 220)
                .frame(maxWidth: .infinity)

            VStack(alignment: .center, spacing: 6) {
                Text("あなたのiPhone")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(ownership.product.name)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                Text(ownership.colorName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(20)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 14, y: 6)
    }
}

private struct BatteryMeterCard: View {
    let ownership: IPhoneOwnership

    var body: some View {
        MeterCard(
            title: "バッテリー",
            symbol: "battery.75percent",
            tint: tint,
            infoTitle: "バッテリー最大容量とは？",
            infoMessage: "新品時のバッテリー容量を100%としたとき、今どれくらい充電をためられるかの目安です。設定アプリのバッテリー画面スクショから読み取ります。"
        ) {
            MetricValueView(value: capacityText, label: statusLabel)
            ProgressView(value: Double(capacityPercent ?? 0), total: 100)
                .tint(tint)
            Text(footerText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var capacityPercent: Int? {
        ownership.latestBatteryCondition?.maximumCapacityPercent ?? ownership.latestBatteryHealth?.healthPercent
    }

    private var capacityText: String {
        guard let capacityPercent else { return "未確認" }
        return "\(capacityPercent)%"
    }

    private var footerText: String {
        if let condition = ownership.latestBatteryCondition {
            let dateText = condition.capturedAt.formatted(date: .numeric, time: .omitted)
            if let cycleCount = condition.cycleCount {
                return "\(dateText)確認 ・ \(cycleCount)回"
            }
            return "\(dateText)確認"
        }
        if let battery = ownership.latestBatteryHealth {
            let dateText = battery.checkedAt.formatted(date: .numeric, time: .omitted)
            return "\(dateText)確認 ・ 手入力"
        }
        return "設定アプリのスクショで確認"
    }

    private var statusLabel: String {
        guard let percent = capacityPercent else { return "未記録" }
        return statusText(for: percent)
    }

    private var tint: Color {
        guard let percent = capacityPercent else { return .secondary }
        if percent < 80 { return Color(red: 0.75, green: 0.22, blue: 0.12) }
        if percent < 85 { return Color(red: 0.78, green: 0.45, blue: 0.08) }
        return Color(red: 0.11, green: 0.45, blue: 0.33)
    }

    private func statusText(for percent: Int) -> String {
        if percent < 80 { return "劣化に注意" }
        if percent < 85 { return "少し注意" }
        return "良好"
    }
}

private struct StorageMeterCard: View {
    let ownership: IPhoneOwnership

    var body: some View {
        MeterCard(
            title: "ストレージ",
            symbol: "internaldrive",
            tint: tint,
            infoTitle: "ストレージとは？",
            infoMessage: "写真、動画、アプリなどを保存する容量です。空きが少ないと、撮影やiOSアップデートで困りやすくなります。"
        ) {
            MetricValueView(value: freeStorageValue, label: "空き")
            ProgressView(value: usedStorageRatio)
                .tint(tint)
            Text(storageFooterText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var freeStorageText: String {
        guard let free = ownership.latestSnapshot?.freeStorageGB else { return "未取得" }
        return "\(free)GB 空き"
    }

    private var freeStorageValue: String {
        guard let free = ownership.latestSnapshot?.freeStorageGB else { return "未取得" }
        return "\(free)GB"
    }

    private var usedStorageRatio: Double {
        ownership.storageUsageRatio ?? 0
    }

    private var storageFooterText: String {
        guard let snapshot = ownership.latestSnapshot else {
            return "端末情報が未取得"
        }
        let used = max(ownership.storageCapacityGB - snapshot.freeStorageGB, 0)
        return "\(used)GB使用 / \(ownership.storageCapacityGB)GB"
    }

    private var tint: Color {
        let ratio = ownership.freeStorageRatio ?? 1
        if ratio < 0.1 { return Color(red: 0.75, green: 0.22, blue: 0.12) }
        if ratio < 0.2 { return Color(red: 0.78, green: 0.45, blue: 0.08) }
        return Color(red: 0.11, green: 0.45, blue: 0.33)
    }
}

private struct UsagePeriodMeterCard: View {
    let ownership: IPhoneOwnership

    var body: some View {
        MeterCard(
            title: "使用期間",
            symbol: "calendar",
            tint: tint,
            infoTitle: "使用期間とは？",
            infoMessage: "iPhoneを最初に使い始めた時期から、どれくらい経っているかの目安です。バッテリー状態スクショの「最初の使用」から算出します。"
        ) {
            MetricValueView(value: ownership.usagePeriodText, label: usageStatusText)
            Text(firstUsedText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var firstUsedText: String {
        if let firstUsed = ownership.latestBatteryCondition?.firstUsedYearMonth {
            return "最初の使用 \(firstUsed)"
        }
        return "バッテリー状態スクショから算出"
    }

    private var usageStatusText: String {
        ownership.latestBatteryCondition == nil ? "未算出" : "使用開始から"
    }

    private var tint: Color {
        ownership.latestBatteryCondition == nil ? .secondary : Color(red: 0.11, green: 0.45, blue: 0.33)
    }
}

private struct TradeValueMeterCard: View {
    let ownership: IPhoneOwnership

    var body: some View {
        MeterCard(
            title: "参考買取価格",
            symbol: "yensign.circle",
            tint: tint,
            infoTitle: "参考買取価格とは？",
            infoMessage: "買い替えを考えるときの目安として見る金額です。MVPではゲオ参考のテスト値として表示しています。"
        ) {
            MetricValueView(value: priceText, label: "ゲオ参考（テスト）")
            Text(tradeValueFooterText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var priceText: String {
        let estimate = ownership.tradeValueEstimate ?? TradeValueEstimate(lowPrice: 92_000, highPrice: 108_000, checkedAt: .now)
        return estimate.lowPrice.formatted(.currency(code: "JPY"))
    }

    private var tradeValueFooterText: String {
        if let checkedAt = ownership.tradeValueEstimate?.checkedAt {
            return "\(checkedAt.formatted(date: .numeric, time: .omitted))確認"
        }
        return "売却前に最新相場を確認"
    }

    private var tint: Color {
        Color(red: 0.11, green: 0.38, blue: 0.34)
    }
}

private struct DeviceInfoMeterCard: View {
    let ownership: IPhoneOwnership
    let latestIOSVersion: String

    var body: some View {
        MeterCard(
            title: "iOS",
            symbol: "iphone.gen3",
            tint: tint,
            infoTitle: "iOSとは？",
            infoMessage: "iPhoneを動かしている基本ソフトです。古いままだと、新機能やセキュリティ更新を受け取れていない場合があります。"
        ) {
            MetricValueView(value: osValue, label: osStatusText)
            Text(osFooterText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var osValue: String {
        ownership.latestSnapshot?.osVersion.replacingOccurrences(of: "iOS ", with: "") ?? "未取得"
    }

    private var osStatusText: String {
        guard let current = currentVersion, let latest = VersionNumber(latestIOSVersion) else { return "未取得" }
        return current >= latest ? "最新です" : "最新ではありません"
    }

    private var osFooterText: String {
        guard let detectedAt = ownership.latestSnapshot?.detectedAt else {
            return "端末情報が未取得"
        }
        return "\(detectedAt.formatted(date: .numeric, time: .omitted))確認"
    }

    private var currentVersion: VersionNumber? {
        guard let version = ownership.latestSnapshot?.osVersion else { return nil }
        return VersionNumber(version)
    }

    private var tint: Color {
        guard let current = currentVersion, let latest = VersionNumber(latestIOSVersion) else { return .secondary }
        if current < latest {
            return Color(red: 0.78, green: 0.45, blue: 0.08)
        }
        return Color(red: 0.11, green: 0.45, blue: 0.33)
    }
}

private struct BatteryPromptCard: View {
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "battery.50percent")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Color(red: 0.11, green: 0.38, blue: 0.34))

                VStack(alignment: .leading, spacing: 6) {
                    Text("さらに調べるためバッテリーについて教えてください")
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("設定アプリのスクショから、最大容量と使い始めの時期を読み取ります。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Button(action: action) {
                Label("スクショでバッテリーを更新", systemImage: "photo.badge.plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.11, green: 0.38, blue: 0.34))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color(red: 0.11, green: 0.38, blue: 0.34).opacity(0.16), lineWidth: 1)
        }
    }
}

private struct MeterCard<Content: View>: View {
    let title: String
    let symbol: String
    let tint: Color
    let infoTitle: String
    let infoMessage: String
    @ViewBuilder let content: Content
    @State private var isShowingInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                Button {
                    isShowingInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel(infoTitle)
            }

            content
        }
        .alert(infoTitle, isPresented: $isShowingInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(infoMessage)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 164, alignment: .topLeading)
        .background(Color.white.opacity(0.86))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(tint.opacity(0.12), lineWidth: 1)
        }
    }
}

private struct MetricValueView: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

private struct BatteryStateCard: View {
    let ownership: IPhoneOwnership
    let tasks: [IPhoneTask]
    let action: () -> Void

    private var needsInput: Bool {
        tasks.contains { $0.type == .inputBatteryHealth || $0.type == .updateBatteryHealth }
    }

    var body: some View {
        StateCard(title: "バッテリー", symbol: "battery.75percent", tint: tint) {
            if let battery = ownership.latestBatteryHealth {
                Text("\(battery.healthPercent)%")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                Text(statusText(for: battery.healthPercent))
                    .font(.headline)
                Text("確認日 \(battery.checkedAt.formatted(date: .numeric, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if battery.healthPercent < 80 {
                    Text("夕方の電池持ちが気になるなら、交換や買い替え比較の候補です。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("最大容量がまだ未入力です")
                    .font(.headline)
                Text("買い替え判断に使えるので、わかる時に記録しておきましょう。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if needsInput {
                Button(action: action) {
                    Text(ownership.latestBatteryHealth == nil ? "最大容量を記録" : "最大容量を更新")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(tint)
            }
        }
    }

    private var tint: Color {
        guard let percent = ownership.latestBatteryHealth?.healthPercent else { return .secondary }
        if percent < 80 { return Color(red: 0.75, green: 0.22, blue: 0.12) }
        if percent < 85 { return Color(red: 0.78, green: 0.45, blue: 0.08) }
        return Color(red: 0.11, green: 0.45, blue: 0.33)
    }

    private func statusText(for percent: Int) -> String {
        if percent < 80 { return "劣化に注意" }
        if percent < 85 { return "少し弱ってきています" }
        return "まだ問題なさそう"
    }
}

private struct StorageStateCard: View {
    let ownership: IPhoneOwnership

    var body: some View {
        StateCard(title: "ストレージ", symbol: "internaldrive", tint: tint) {
            Text(freeStorageText)
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text(statusText)
                .font(.headline)
            if isLow {
                Text("写真や動画が増えると、アップデート時に困る可能性があります。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("空き容量を増やすコツを見る") {}
                    .buttonStyle(.bordered)
                    .tint(tint)
            }
        }
    }

    private var freeStorageText: String {
        guard let free = ownership.latestSnapshot?.freeStorageGB else { return "未取得" }
        return "\(free)GB 空き"
    }

    private var isLow: Bool {
        (ownership.freeStorageRatio ?? 1) < 0.1
    }

    private var statusText: String {
        let ratio = ownership.freeStorageRatio ?? 1
        if ratio < 0.1 { return "そろそろ整理したい状態です" }
        if ratio < 0.2 { return "少し少なめです" }
        return "まだ余裕があります"
    }

    private var tint: Color {
        let ratio = ownership.freeStorageRatio ?? 1
        if ratio < 0.1 { return Color(red: 0.75, green: 0.22, blue: 0.12) }
        if ratio < 0.2 { return Color(red: 0.78, green: 0.45, blue: 0.08) }
        return Color(red: 0.11, green: 0.45, blue: 0.33)
    }
}

private struct UsageFeelingCard: View {
    let ownership: IPhoneOwnership
    let tasks: [IPhoneTask]
    let action: () -> Void

    var body: some View {
        StateCard(title: "使用感", symbol: "hand.tap", tint: tint) {
            if let log = ownership.latestExperienceLog {
                Text("満足度 \(log.satisfactionScore)/5")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text("サイズ感は\(log.sizeFit.rawValue)")
                    .font(.headline)
                Text("最終記録 \(log.recordedAt.formatted(date: .numeric, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("まだ記録がありません")
                    .font(.headline)
                Text("今の使い心地を残すと、次に選ぶ iPhone の判断材料になります。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if tasks.contains(where: { $0.type == .recordFirstImpression }) {
                Button(action: action) {
                    Text("今の使用感を残す")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(tint)
            }
        }
    }

    private var tint: Color {
        guard let log = ownership.latestExperienceLog else { return .secondary }
        return log.satisfactionScore <= 2 ? Color(red: 0.78, green: 0.45, blue: 0.08) : Color(red: 0.11, green: 0.45, blue: 0.33)
    }
}

private struct TradeValueStateCard: View {
    let ownership: IPhoneOwnership
    let summary: IPhoneDiagnosisSummary
    let tasks: [IPhoneTask]
    let action: () -> Void

    var body: some View {
        StateCard(title: "相場", symbol: "yensign.circle", tint: tint) {
            if let estimate = ownership.tradeValueEstimate {
                Text("\(estimate.lowPrice.formatted(.currency(code: "JPY")))〜")
                    .font(.title2.bold())
                Text("\(estimate.highPrice.formatted(.currency(code: "JPY")))")
                    .font(.title2.bold())
                Text("確認日 \(estimate.checkedAt.formatted(date: .numeric, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("まだ確認していません")
                    .font(.headline)
                Text("買い替えを考え始めたら、今の価値を見ておくと判断しやすくなります。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if shouldShowCTA {
                Button(action: action) {
                    Text("今の目安価値を確認")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(tint)
            }
        }
    }

    private var shouldShowCTA: Bool {
        tasks.contains(where: { $0.type == .checkTradeInValue }) || summary.valueCheckNeed >= 2
    }

    private var tint: Color {
        shouldShowCTA ? Color(red: 0.78, green: 0.45, blue: 0.08) : .secondary
    }
}

private struct StateCard<Content: View>: View {
    let title: String
    let symbol: String
    let tint: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(tint)

            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(tint.opacity(0.12), lineWidth: 1)
        }
    }
}

private struct ConcernSummaryCard: View {
    let summary: IPhoneDiagnosisSummary
    let onSolve: (IPhoneConcern) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("使いづらさを解消する")
                .font(.title2.bold())
            if importantConcerns.isEmpty {
                Text("今のところ大きな気がかりはありません。気になる変化が出たら、状態カードから軽く記録しておきましょう。")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                ForEach(importantConcerns) { concern in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: concernSymbol(for: concern))
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(concernColor(for: concern))
                            Text(concernTitle(for: concern))
                                .font(.title2.bold())
                            Spacer()
                            Text(concern.status.rawValue)
                                .font(.body.weight(.semibold))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(concernColor(for: concern).opacity(0.14))
                                .foregroundStyle(concernColor(for: concern))
                                .clipShape(Capsule())
                        }
                        Text(concernMessage(for: concern))
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Button {
                            onSolve(concern)
                        } label: {
                            Text("解決する")
                                .font(.title3.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                        }
                        .buttonStyle(.bordered)
                        .tint(concernColor(for: concern))
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(concernColor(for: concern).opacity(0.12), lineWidth: 1)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var importantConcerns: [IPhoneConcern] {
        summary.concerns.filter {
            switch $0.status {
            case .slightAttention, .reviewCandidate, .replacementCandidate, .compareUpgrade:
                return true
            case .good, .waiting:
                return false
            }
        }
    }

    private func concernTitle(for concern: IPhoneConcern) -> String {
        switch concern.title {
        case "バッテリー":
            return "バッテリーが少し弱ってきています"
        case "容量":
            return "ストレージの空きが少なめです"
        case "使用感":
            return "使い心地に少し不満がありそうです"
        case "相場":
            return "価値を見ておくと判断しやすそうです"
        default:
            return "\(concern.title)を見直してもよさそうです"
        }
    }

    private func concernSymbol(for concern: IPhoneConcern) -> String {
        switch concern.title {
        case "バッテリー":
            return "battery.25percent"
        case "容量":
            return "internaldrive"
        case "使用感":
            return "hand.tap"
        case "相場":
            return "yensign.circle"
        default:
            return "exclamationmark.circle"
        }
    }

    private func concernColor(for concern: IPhoneConcern) -> Color {
        switch concern.status {
        case .slightAttention:
            return Color(red: 0.78, green: 0.45, blue: 0.08)
        case .reviewCandidate, .replacementCandidate, .compareUpgrade:
            return Color(red: 0.75, green: 0.22, blue: 0.12)
        case .good, .waiting:
            return .secondary
        }
    }

    private func concernMessage(for concern: IPhoneConcern) -> String {
        switch concern.title {
        case "バッテリー":
            return "最大容量が80%前後になると、電池持ちの不満が出やすくなります。"
        case "容量":
            return "写真や動画が増えると、アップデート時に困る可能性があります。"
        case "使用感":
            return "不満が重なると、次に選ぶiPhoneの条件が見えやすくなります。"
        case "相場":
            return "買い替えを考え始めたら、今の価値を見ておくと安心です。"
        default:
            return "状態カードで少しだけ確認しておきましょう。"
        }
    }
}

private struct RuleDrivenInsightCard: View {
    let result: MatchedRuleResult
    let onAction: (String?) -> Void

    private var visibleRules: [RuleDefinition] {
        (result.todoItems + result.cautionItems + result.solveItems).prefix(3).map { $0 }
    }

    var body: some View {
        if !visibleRules.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("次に見ること")
                    .font(.title2.bold())

                ForEach(visibleRules) { rule in
                    Button {
                        onAction(rule.actionType)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: symbol(for: rule))
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(color(for: rule))
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    Text(rule.title)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if rule.accessLevel == .pro {
                                        Text("Pro")
                                            .font(.caption.weight(.bold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color(red: 0.11, green: 0.38, blue: 0.34).opacity(0.12))
                                            .foregroundStyle(Color(red: 0.11, green: 0.38, blue: 0.34))
                                            .clipShape(Capsule())
                                    }
                                }

                                Text(rule.description)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)

                                if let ctaLabel = rule.ctaLabel {
                                    Text(ctaLabel)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(color(for: rule))
                                }
                            }

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.tertiary)
                                .padding(.top, 4)
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(color(for: rule).opacity(0.12), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func symbol(for rule: RuleDefinition) -> String {
        switch rule.actionType {
        case "battery_ocr", "battery_compare":
            return "battery.50percent"
        case "storage_guide":
            return "internaldrive"
        default:
            return "checkmark.circle"
        }
    }

    private func color(for rule: RuleDefinition) -> Color {
        switch rule.severity {
        case .critical:
            return Color(red: 0.75, green: 0.22, blue: 0.12)
        case .warning:
            return Color(red: 0.78, green: 0.45, blue: 0.08)
        case .info, .normal:
            return Color(red: 0.11, green: 0.38, blue: 0.34)
        }
    }
}

private struct NextIPhoneCard: View {
    let summary: IPhoneDiagnosisSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("次の判断")
                .font(.title3.bold())
            Text(displayTitle)
                .font(.headline)
            Text(displaySummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if shouldShowReasons {
                VStack(alignment: .leading, spacing: 8) {
                    Text("理由")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(summary.reasons, id: \.self) { reason in
                        Label(reason, systemImage: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.primary, Color(red: 0.11, green: 0.38, blue: 0.34))
                    }
                }
            }

            Text(displayAction)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(red: 0.11, green: 0.38, blue: 0.34))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var hasWaitingInfo: Bool {
        summary.concerns.contains { $0.status == .waiting }
    }

    private var shouldShowReasons: Bool {
        !hasWaitingInfo || summary.valueCheckNeed >= 2
    }

    private var displayTitle: String {
        if hasWaitingInfo {
            return "もう少し記録があると判断しやすくなります"
        }
        return summary.title
    }

    private var displaySummary: String {
        if hasWaitingInfo {
            return "今は買い替え候補を急いで決めるより、バッテリーや使用感を少しずつ残す段階です。"
        }
        return summary.summary
    }

    private var displayAction: String {
        if hasWaitingInfo {
            return "状態カードから、わかる項目だけ軽く記録していきましょう。"
        }
        return summary.recommendedAction
    }
}

private struct ConcernSolutionSheet: View {
    let concern: IPhoneConcern
    let primaryAction: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Label(concern.title, systemImage: symbol)
                    .font(.title2.bold())
                    .foregroundStyle(color)

                Text("まず試せること")
                    .font(.headline)

                ForEach(actions, id: \.self) { action in
                    Label(action, systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.primary, color)
                }

                Spacer()

                Button {
                    dismiss()
                    primaryAction()
                } label: {
                    Text(primaryButtonTitle)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(color)
            }
            .padding(24)
            .navigationTitle("解決策")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var symbol: String {
        switch concern.title {
        case "バッテリー":
            return "battery.25percent"
        case "容量":
            return "internaldrive"
        case "使用感":
            return "hand.tap"
        case "相場":
            return "yensign.circle"
        default:
            return "lightbulb"
        }
    }

    private var color: Color {
        switch concern.status {
        case .slightAttention:
            return Color(red: 0.78, green: 0.45, blue: 0.08)
        case .reviewCandidate, .replacementCandidate, .compareUpgrade:
            return Color(red: 0.75, green: 0.22, blue: 0.12)
        case .good, .waiting:
            return Color(red: 0.11, green: 0.38, blue: 0.34)
        }
    }

    private var primaryButtonTitle: String {
        switch concern.title {
        case "バッテリー":
            return "スクショで読み取る"
        case "容量":
            return "整理の観点を見る"
        case "使用感":
            return "使用感を残す"
        case "相場":
            return "相場を見る"
        default:
            return "確認する"
        }
    }

    private var actions: [String] {
        switch concern.title {
        case "バッテリー":
            return ["バッテリー状態スクショで最新化", "Appleの交換目安を確認", "交換費用と買い替えを比較"]
        case "容量":
            return ["写真と動画を大きい順に確認", "使っていないアプリを整理", "次回は容量アップを候補にする"]
        case "使用感":
            return ["4問だけ記録して傾向を見る", "不満が重なる項目を残す", "次に選ぶ条件に変換する"]
        case "相場":
            return ["参考価格を更新", "外部の買取価格も見る", "交換費用と差額で比較する"]
        default:
            return ["状態を軽く確認", "必要なら詳細で見る"]
        }
    }
}

private struct DiagnosisLogCard: View {
    let logs: [IPhoneDiagnosisLog]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("記録ログ")
                .font(.title3.bold())

            if logs.isEmpty {
                Text("まだ記録ログはありません。バッテリーや使用感を残すと、ここに状態の変化がたまっていきます。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(logs.sorted { $0.diagnosedAt > $1.diagnosedAt }.prefix(3)) { log in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(log.diagnosedAt.formatted(date: .numeric, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(log.title)
                            .font(.headline)
                        Text(log.summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(log.recommendedAction)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(red: 0.11, green: 0.38, blue: 0.34))
                    }
                    if log.id != logs.sorted(by: { $0.diagnosedAt > $1.diagnosedAt }).prefix(3).last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct PastIPhoneRow: View {
    let ownership: IPhoneOwnership
    let hasPendingTask: Bool

    var body: some View {
        HStack(spacing: 14) {
            IPhoneArtworkView(imageFilename: ownership.product.imageFilename, contentMode: .fill)
                .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(ownership.product.name)
                        .font(.headline)
                    if hasPendingTask {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                    }
                }
                Text("登録日 \(ownership.registeredAt.formatted(date: .numeric, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let log = ownership.latestExperienceLog {
                    Text(log.note.isEmpty ? "使用感ログあり" : log.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct IPhoneDetailView: View {
    let ownership: IPhoneOwnership
    let tasks: [IPhoneTask]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                IPhoneArtworkView(imageFilename: ProductCatalog.imageFilename(for: ownership.product.name, colorName: ownership.colorName))
                    .frame(height: 220)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(ownership.product.name)
                            .font(.largeTitle.bold())
                        if !tasks.isEmpty {
                            Circle()
                                .fill(.red)
                                .frame(width: 10, height: 10)
                        }
                    }
                    Text("\(ownership.status.rawValue) ・ \(ownership.storageCapacityGB)GB ・ \(ownership.colorName)")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                detailCard("端末情報", rows: [
                    ("登録日", ownership.registeredAt.formatted(date: .long, time: .omitted)),
                    ("最終更新", ownership.lastUpdatedAt.formatted(date: .long, time: .omitted)),
                    ("端末情報取得", ownership.latestSnapshot?.detectedAt.formatted(date: .long, time: .omitted) ?? "未取得"),
                    ("iOS", ownership.latestSnapshot?.osVersion ?? "未取得"),
                    ("空き容量", ownership.latestSnapshot.map { "\($0.freeStorageGB)GB" } ?? "未取得")
                ])

                detailCard("バッテリー", rows: [
                    ("充電状態", ownership.latestSnapshot?.batteryState.rawValue ?? "未取得"),
                    ("最大容量", batteryCapacityText)
                ])

                if !tasks.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("確認待ち")
                            .font(.headline)
                        ForEach(tasks) { task in
                            Label(task.type.rawValue, systemImage: "circle.fill")
                                .font(.subheadline)
                                .foregroundStyle(.primary, .red)
                        }
                    }
                    .padding(18)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }

                if !ownership.experienceLogs.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("使用感ログ")
                            .font(.headline)
                        ForEach(ownership.experienceLogs.sorted { $0.recordedAt > $1.recordedAt }) { log in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(log.recordedAt.formatted(date: .long, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("満足度 \(log.satisfactionScore)/5")
                                    .font(.subheadline.weight(.semibold))
                                Text(log.note.isEmpty ? "使用感を記録済み" : log.note)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            if log.id != ownership.experienceLogs.last?.id {
                                Divider()
                            }
                        }
                    }
                    .padding(18)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("詳細")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var batteryCapacityText: String {
        if let condition = ownership.latestBatteryCondition {
            return "\(condition.maximumCapacityPercent)%（\(condition.capturedAt.formatted(date: .numeric, time: .omitted))確認）"
        }
        if let battery = ownership.latestBatteryHealth {
            return "\(battery.healthPercent)%（\(battery.checkedAt.formatted(date: .numeric, time: .omitted))確認）"
        }
        return "未入力"
    }

    private func detailCard(_ title: String, rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            ForEach(rows, id: \.0) { row in
                HStack(alignment: .top) {
                    Text(row.0)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(row.1)
                        .multilineTextAlignment(.trailing)
                }
                .font(.subheadline)
            }
        }
        .padding(18)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct ManualAddIPhoneView: View {
    @ObservedObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var selectedSeries: String?
    @State private var draft = IPhoneManualDraft()

    private var filteredProducts: [IPhoneProduct] {
        let products = selectedSeries.map { series in
            ProductCatalog.products(in: series)
        } ?? store.products
        guard !query.isEmpty else { return products }
        return products.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("例：iPhone 16 Pro、iPhone SE", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("使っていたiPhoneを探す")
                }

                Section("最近のモデル") {
                    ForEach(ProductCatalog.recentModels) { product in
                        productRow(product)
                    }
                }

                Section("シリーズから探す") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            chip("すべて", isSelected: selectedSeries == nil) {
                                selectedSeries = nil
                            }
                            ForEach(ProductCatalog.seriesNames, id: \.self) { series in
                                chip(series, isSelected: selectedSeries == series) {
                                    selectedSeries = series
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    ForEach(filteredProducts) { product in
                        productRow(product)
                    }
                }

                Section("見つからない場合") {
                    TextField("モデル名", text: $draft.name)
                    TextField("シリーズ名", text: $draft.series)
                    Stepper("容量 \(draft.storageCapacityGB)GB", value: $draft.storageCapacityGB, in: 64...1024, step: 64)
                    TextField("カラー", text: $draft.colorName)

                    Button("手動で入力する") {
                        guard !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        store.addManualIPhone(from: draft)
                        dismiss()
                    }
                }
            }
            .navigationTitle("iPhoneを追加")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func productRow(_ product: IPhoneProduct) -> some View {
        Button {
            store.addManualIPhone(
                from: IPhoneManualDraft(
                    name: product.name,
                    series: product.series,
                    storageCapacityGB: 128,
                    colorName: ""
                )
            )
            dismiss()
        } label: {
            HStack {
                Text(product.name)
                    .foregroundStyle(.primary)
                Spacer()
                Text(product.series)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func chip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color(red: 0.11, green: 0.38, blue: 0.34) : Color(.secondarySystemBackground))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct TaskFlowView: View {
    @ObservedObject var store: AppStore
    let ownership: IPhoneOwnership?
    let preferredTask: IPhoneTaskType?
    let onStartBatteryOCR: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var batteryDraft = BatteryHealthDraft()
    @State private var experienceDraft = ExperienceLogDraft()
    @State private var selectedConcern = "特にない"
    @State private var selectedTask: IPhoneTaskType?
    @State private var selectedRule: RuleDefinition?

    private var taskTypes: [IPhoneTaskType] {
        guard let ownership else { return [] }
        let ruleCoveredTypes = Set(ruleTodoItems.compactMap { IPhoneTaskType(ruleActionType: $0.actionType) })
        let types = store.snapshot.openTasks(for: ownership.id)
            .map(\.type)
            .filter { !ruleCoveredTypes.contains($0) }
        guard let preferredTask, types.contains(preferredTask) else { return types }
        return [preferredTask] + types.filter { $0 != preferredTask }
    }

    private var ruleTodoItems: [RuleDefinition] {
        guard let ownership else { return [] }
        return store.ruleResult(for: ownership).todoItems
    }

    var body: some View {
        NavigationStack {
            if let ownership, !taskTypes.isEmpty || !ruleTodoItems.isEmpty {
                if let selectedTask {
                    actionForm(for: selectedTask, ownershipID: ownership.id)
                        .navigationTitle(selectedTask.navigationTitle)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("一覧") {
                                    self.selectedTask = nil
                                }
                            }

                            ToolbarItem(placement: .topBarTrailing) {
                                if selectedTask.isManualCompletionTask {
                                    Button("完了") {
                                        save(task: selectedTask, for: ownership.id)
                                    }
                                    .disabled(isTaskInvalid(selectedTask))
                                }
                            }
                        }
                } else if let selectedRule {
                    ruleDetail(rule: selectedRule)
                        .navigationTitle("確認")
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("一覧") {
                                    self.selectedRule = nil
                                }
                            }
                        }
                } else {
                    taskList
                        .navigationTitle("やることリスト")
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("閉じる") {
                                    dismiss()
                                }
                            }
                        }
                }
            } else {
                ContentUnavailableView("確認待ちの項目はありません", systemImage: "checkmark.circle")
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("閉じる") {
                                dismiss()
                            }
                        }
                    }
            }
        }
    }

    private var taskList: some View {
        List {
            if !ruleTodoItems.isEmpty {
                Section {
                    ForEach(ruleTodoItems) { rule in
                        Button {
                            handleRuleTap(rule)
                        } label: {
                            RuleTaskRow(rule: rule)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("今の状態から出ていること")
                }
            }

            Section {
                ForEach(taskTypes, id: \.self) { task in
                    Button {
                        selectedTask = task
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: task.symbol)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(task.tint)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.rawValue)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(task.description)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text(ruleTodoItems.isEmpty ? "今やると判断しやすくなること" : "記録しておくこと")
            } footer: {
                Text("まず内容を確認してから、必要な項目だけ進められます。")
            }
        }
    }

    private func ruleDetail(rule: RuleDefinition) -> some View {
        Form {
            Section {
                Label(rule.title, systemImage: rule.symbolName)
                    .font(.title3.bold())
                    .foregroundStyle(.primary, rule.tint)
                Text(rule.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    performRuleAction(rule)
                } label: {
                    Text(rule.ctaLabel ?? "進める")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(rule.tint)
            }
        }
    }

    @ViewBuilder
    private func actionForm(for task: IPhoneTaskType, ownershipID: UUID) -> some View {
        Form {
            Section {
                Label(task.rawValue, systemImage: task.symbol)
                    .font(.title3.bold())
                    .foregroundStyle(.primary, task.tint)
                Text(task.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            switch task {
            case .inputBatteryHealth, .updateBatteryHealth:
                Section {
                    Button {
                        dismiss()
                        onStartBatteryOCR()
                    } label: {
                        Label("スクショで読み取る", systemImage: "photo.badge.plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(task.tint)

                    Text("設定アプリの「バッテリーの状態」画面を読み取って、最大容量や充放電回数を保存します。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("おすすめ")
                }

                Section("手入力する場合") {
                    TextField("86", text: $batteryDraft.healthPercent)
                        .keyboardType(.numberPad)
                    Text("確認日：\(Date.now.formatted(date: .long, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("メモ（任意）", text: $batteryDraft.note)
                }

            case .recordFirstImpression:
                Section("今もメインで使っている？") {
                    Picker("使用状況", selection: $experienceDraft.usageStatus) {
                        ForEach(UsageStatusOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                }

                Section("いまの満足度は？") {
                    Stepper("満足度 \(experienceDraft.satisfactionScore) / 5", value: $experienceDraft.satisfactionScore, in: 1...5)
                }

                Section("気になるところは？") {
                    Picker("気になるところ", selection: $selectedConcern) {
                        ForEach(["特にない", "バッテリー", "容量", "動作", "サイズ感", "カメラ", "買い替え"], id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                }

                Section("ひとこと残す") {
                    TextField("ひとこと残す", text: $experienceDraft.note, axis: .vertical)
                        .lineLimit(3...5)
                }

            case .checkTradeInValue:
                Section("外部で確認") {
                    Text("MVPでは自動取得せず、外部確認導線のモックとして扱います。完了すると、サンプル相場を現在の目安価値として保存します。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Link("Apple Trade Inで確認", destination: URL(string: "https://www.apple.com/jp/shop/trade-in")!)
                    Link("メルカリで相場を見る", destination: URL(string: "https://jp.mercari.com/search")!)
                    Link("中古買取相場を見る", destination: URL(string: "https://www.google.com/search?q=iPhone+買取+相場")!)
                }
            }
        }
    }

    private func isTaskInvalid(_ task: IPhoneTaskType) -> Bool {
        switch task {
        case .inputBatteryHealth, .updateBatteryHealth:
            return Int(batteryDraft.healthPercent) == nil
        case .recordFirstImpression:
            return false
        case .checkTradeInValue:
            return false
        }
    }

    private func save(task: IPhoneTaskType, for ownershipID: UUID) {
        switch task {
        case .inputBatteryHealth, .updateBatteryHealth:
            store.completeBatteryHealthTask(for: ownershipID, draft: batteryDraft)
        case .recordFirstImpression:
            applySelectedConcern()
            store.completeExperienceTask(for: ownershipID, draft: experienceDraft)
        case .checkTradeInValue:
            store.markTradeValueChecked(for: ownershipID)
        }
        if store.snapshot.openTasks(for: ownershipID).isEmpty {
            dismiss()
        } else {
            selectedTask = nil
        }
    }

    private func handleRuleTap(_ rule: RuleDefinition) {
        if rule.actionType == "battery_ocr" || rule.actionType == "battery_compare" {
            performRuleAction(rule)
        } else {
            selectedRule = rule
        }
    }

    private func performRuleAction(_ rule: RuleDefinition) {
        switch rule.actionType {
        case "battery_ocr", "battery_compare":
            dismiss()
            onStartBatteryOCR()
        default:
            selectedRule = rule
        }
    }

    private func applySelectedConcern() {
        switch selectedConcern {
        case "バッテリー":
            experienceDraft.batteryComplaint = "夕方には不安"
        case "容量":
            experienceDraft.storageComplaint = "写真・動画を消すことがある"
        case "動作":
            experienceDraft.performanceComplaint = "たまに重い"
        case "サイズ感":
            experienceDraft.sizeFit = .hardToUseOneHanded
        case "カメラ":
            experienceDraft.cameraSatisfaction = "暗い場所に弱い"
        case "買い替え":
            experienceDraft.upgradeIntent = .interested
        default:
            experienceDraft.batteryComplaint = "だいたい持つ"
            experienceDraft.storageComplaint = "困っていない"
            experienceDraft.performanceComplaint = "特にない"
            experienceDraft.sizeFit = .good
            experienceDraft.cameraSatisfaction = "特に不満はない"
            experienceDraft.upgradeIntent = .keepUsing
        }
    }
}

private struct RuleTaskRow: View {
    let rule: RuleDefinition

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: rule.symbolName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(rule.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(rule.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(rule.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
    }
}

private extension RuleDefinition {
    var symbolName: String {
        switch actionType {
        case "battery_ocr", "battery_compare":
            return "battery.75percent"
        case "storage_guide":
            return "internaldrive"
        default:
            return "checkmark.circle"
        }
    }

    var tint: Color {
        switch severity {
        case .critical:
            return Color(red: 0.75, green: 0.22, blue: 0.12)
        case .warning:
            return Color(red: 0.78, green: 0.45, blue: 0.08)
        default:
            return Color(red: 0.11, green: 0.45, blue: 0.33)
        }
    }
}

private extension IPhoneTaskType {
    var navigationTitle: String {
        switch self {
        case .inputBatteryHealth, .updateBatteryHealth:
            return "バッテリー"
        case .recordFirstImpression:
            return "使用感"
        case .checkTradeInValue:
            return "相場"
        }
    }

    var symbol: String {
        switch self {
        case .inputBatteryHealth, .updateBatteryHealth:
            return "battery.75percent"
        case .recordFirstImpression:
            return "hand.tap"
        case .checkTradeInValue:
            return "yensign.circle"
        }
    }

    var tint: Color {
        switch self {
        case .inputBatteryHealth, .updateBatteryHealth:
            return Color(red: 0.11, green: 0.45, blue: 0.33)
        case .recordFirstImpression:
            return Color(red: 0.11, green: 0.38, blue: 0.48)
        case .checkTradeInValue:
            return Color(red: 0.11, green: 0.38, blue: 0.34)
        }
    }

    var isManualCompletionTask: Bool { true }
}

private struct BatteryOCRFlowView: View {
    @ObservedObject var store: AppStore
    let ownership: IPhoneOwnership?
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isReading = false
    @State private var errorMessage: String?
    @State private var rawText = ""
    @State private var maximumCapacity = ""
    @State private var cycleCount = ""
    @State private var batteryStateText = ""
    @State private var manufacturedYearMonth = ""
    @State private var firstUsedYearMonth = ""
    @State private var isEditingResult = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if page == 0 {
                    uploadStep
                } else {
                    resultStep
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(page == 0 ? "バッテリー情報" : "読み取り結果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(page == 0 ? "閉じる" : "戻る") {
                        if page == 0 {
                            dismiss()
                        } else {
                            page = 0
                        }
                    }
                }
            }
            .task(id: selectedItem) {
                await loadSelectedImage()
            }
        }
    }

    private var uploadStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            PhotosPicker(selection: $selectedItem, matching: .images) {
                VStack(spacing: 12) {
                    if let selectedImage {
                        Image(uiImage: selectedImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    } else {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundStyle(Color(red: 0.11, green: 0.38, blue: 0.34))
                        Text("スクショを選ぶ")
                            .font(.headline)
                        Text("設定アプリのバッテリー画面")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: selectedImage == nil ? 240 : nil)
                .padding(18)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: selectedImage == nil ? [7] : []))
                        .foregroundStyle(Color(red: 0.11, green: 0.38, blue: 0.34).opacity(0.25))
                }
            }
            .buttonStyle(.plain)

            if isReading {
                ProgressView("読み取り中")
                    .frame(maxWidth: .infinity)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button {
                Task {
                    await recognizeSelectedImage()
                }
            } label: {
                Text("スクショを読み取る")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.11, green: 0.38, blue: 0.34))
            .disabled(selectedImage == nil || isReading)

            Button("手入力で進む") {
                rawText = "manual"
                isEditingResult = true
                page = 1
            }
            .font(.caption.weight(.semibold))
            .frame(maxWidth: .infinity)
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(20)
    }

    private var resultStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("確認すること")
                        .font(.title3.bold())
                    Spacer()
                    Button(isEditingResult ? "完了" : "修正する") {
                        isEditingResult.toggle()
                    }
                    .font(.caption.weight(.semibold))
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    OCRResultCard(title: "最大容量", value: maximumCapacity, suffix: "%", placeholder: "90", isEditing: isEditingResult, text: $maximumCapacity, keyboard: .numberPad)
                    OCRResultCard(title: "充放電回数", value: cycleCount, suffix: "回", placeholder: "682", isEditing: isEditingResult, text: $cycleCount, keyboard: .numberPad)
                    OCRResultCard(title: "製造日", value: manufacturedYearMonth, suffix: "", placeholder: "2024年8月", isEditing: isEditingResult, text: $manufacturedYearMonth, keyboard: .default)
                    OCRResultCard(title: "最初の使用", value: firstUsedYearMonth, suffix: "", placeholder: "2024年9月", isEditing: isEditingResult, text: $firstUsedYearMonth, keyboard: .default)
                    OCRResultCard(title: "バッテリー状態", value: batteryStateText, suffix: "", placeholder: "正常", isEditing: isEditingResult, text: $batteryStateText, keyboard: .default)
                    OCRResultCard(title: "使い始めてから", value: usageDurationText, suffix: "", placeholder: "未確認", isEditing: false, text: .constant(usageDurationText), keyboard: .default)
                }
            }
            .padding(18)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            Button {
                if canSave {
                    save(source: rawText == "manual" ? .manual : .screenshotOCR)
                } else {
                    isEditingResult = true
                }
            } label: {
                Text(canSave ? "この内容で保存" : "最大容量を修正して保存")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.11, green: 0.38, blue: 0.34))
            .disabled(ownership == nil)
        }
        .padding(20)
    }

    private var canSave: Bool {
        Int(maximumCapacity.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
    }

    private var usageDurationText: String {
        guard let firstUsedDate = YearMonthParser.date(from: firstUsedYearMonth) else {
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

    private func loadSelectedImage() async {
        guard let selectedItem else { return }
        errorMessage = nil

        do {
            guard let data = try await selectedItem.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                errorMessage = "画像を読み込めませんでした。"
                return
            }
            selectedImage = image
        } catch {
            errorMessage = "画像を読み込めませんでした。"
        }
    }

    private func recognizeSelectedImage() async {
        guard let selectedImage else { return }
        isReading = true
        errorMessage = nil

        do {
            let recognizedText = try await BatteryTextRecognizer.recognizeText(from: selectedImage)
            rawText = recognizedText
            applyParsedResult(BatteryOCRParser.parse(recognizedText))
            isEditingResult = false
            page = 1
        } catch {
            errorMessage = "うまく読めませんでした。数字だけ直せます。"
        }

        isReading = false
    }

    private func applyParsedResult(_ result: BatteryOCRParser.Result) {
        if let value = result.maximumCapacityPercent {
            maximumCapacity = "\(value)"
        }
        if let value = result.cycleCount {
            cycleCount = "\(value)"
        }
        if let value = result.batteryStateText {
            batteryStateText = value
        }
        if let value = result.manufacturedYearMonth {
            manufacturedYearMonth = value
        }
        if let value = result.firstUsedYearMonth {
            firstUsedYearMonth = value
        }
    }

    private func save(source: BatteryConditionSource = .screenshotOCR) {
        guard let ownership, let maximumCapacity = Int(maximumCapacity.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
        let snapshot = BatteryConditionSnapshot(
            maximumCapacityPercent: maximumCapacity,
            cycleCount: Int(cycleCount.trimmingCharacters(in: .whitespacesAndNewlines)),
            batteryStateText: batteryStateText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "未確認" : batteryStateText.trimmingCharacters(in: .whitespacesAndNewlines),
            manufacturedYearMonth: manufacturedYearMonth.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : manufacturedYearMonth.trimmingCharacters(in: .whitespacesAndNewlines),
            firstUsedYearMonth: firstUsedYearMonth.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : firstUsedYearMonth.trimmingCharacters(in: .whitespacesAndNewlines),
            capturedAt: .now,
            source: source,
            ocrRawText: rawText
        )
        store.completeBatteryCondition(for: ownership.id, snapshot: snapshot)
        dismiss()
    }
}

private struct OCRResultCard: View {
    let title: String
    let value: String
    let suffix: String
    let placeholder: String
    let isEditing: Bool
    @Binding var text: String
    let keyboard: UIKeyboardType

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if isEditing {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboard)
                    .textFieldStyle(.roundedBorder)
            } else {
                Text(displayValue)
                    .font(.headline)
                    .foregroundStyle(isMissing ? .secondary : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var displayValue: String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "未確認" else { return "あとでOK" }
        return suffix.isEmpty ? trimmed : "\(trimmed)\(suffix)"
    }

    private var isMissing: Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == "未確認"
    }
}

enum BatteryTextRecognizer {
    static func recognizeText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else { return "" }
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let text = (request.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n") ?? ""
                continuation.resume(returning: text)
            }
            request.recognitionLanguages = ["ja-JP", "en-US"]
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage)
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

enum BatteryOCRParser {
    struct Result {
        let maximumCapacityPercent: Int?
        let cycleCount: Int?
        let batteryStateText: String?
        let manufacturedYearMonth: String?
        let firstUsedYearMonth: String?
    }

    static func parse(_ text: String) -> Result {
        Result(
            maximumCapacityPercent: firstInt(afterAnyOf: ["最大容量", "Maximum Capacity"], in: text),
            cycleCount: firstInt(afterAnyOf: ["充放電回数", "Cycle Count"], in: text),
            batteryStateText: firstLine(containingAnyOf: ["正常", "修理", "Service", "Normal"], in: text),
            manufacturedYearMonth: yearMonth(afterAnyOf: ["製造日", "Manufacture"], in: text),
            firstUsedYearMonth: yearMonth(afterAnyOf: ["最初の使用", "First Used"], in: text)
        )
    }

    private static func firstInt(afterAnyOf keys: [String], in text: String) -> Int? {
        let lines = text.components(separatedBy: .newlines)
        for index in lines.indices where keys.contains(where: { lines[index].localizedCaseInsensitiveContains($0) }) {
            let candidates = lines[index...min(index + 2, lines.index(before: lines.endIndex))]
            for line in candidates {
                if let value = line.firstMatch(of: /\d+/)?.output {
                    return Int(value)
                }
            }
        }
        return nil
    }

    private static func firstLine(containingAnyOf keys: [String], in text: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
        for index in lines.indices where keys.contains(where: { lines[index].localizedCaseInsensitiveContains($0) }) {
            let candidates = lines[index...min(index + 1, lines.index(before: lines.endIndex))]
            if let line = candidates.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                return line.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    private static func yearMonth(afterAnyOf keys: [String], in text: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
        for index in lines.indices where keys.contains(where: { lines[index].localizedCaseInsensitiveContains($0) }) {
            let candidates = lines[index...min(index + 2, lines.index(before: lines.endIndex))]
            for line in candidates {
                if let match = line.firstMatch(of: /\d{4}\s*[年\/\-]\s*\d{1,2}\s*月?/) {
                    return String(match.output).replacingOccurrences(of: " ", with: "")
                }
            }
        }
        return nil
    }
}

private struct OnboardingFlowView: View {
    @ObservedObject var store: AppStore
    @Binding var isPresented: Bool
    @State private var page = 0
    @State private var draft = OnboardingDraft(selectedModelName: "", selectedColorName: "")
    @State private var isCorrectingModel = false

    private var detection: DetectedDeviceSnapshot { store.snapshot.currentDeviceDetection }
    private var detectedProduct: IPhoneProduct? {
        ProductCatalog.product(forHardwareIdentifier: detection.hardwareIdentifier)
    }
    private var selectedProduct: IPhoneProduct? {
        store.products.first { $0.name == draft.selectedModelName } ??
        detectedProduct ??
        store.products.first { $0.name == detection.inferredModelName }
    }
    private var colorOptions: [String] {
        ProductCatalog.colorNames(for: draft.selectedModelName)
    }
    private var recentProducts: [IPhoneProduct] {
        let preferredName = draft.selectedModelName.isEmpty ? detection.inferredModelName : draft.selectedModelName
        let preferredProduct = store.products.first { $0.name == preferredName } ??
            (detectedProduct?.name == preferredName ? detectedProduct : nil)
        let others = ProductCatalog.recentModels.filter { $0.name != preferredName }
        return [preferredProduct].compactMap { $0 } + others
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                Text(pageTitle)
                    .font(.title.bold())
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(pageDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Group {
                    if page == 0 {
                        detectionStep
                    } else if page == 1 {
                        colorStep
                    } else {
                        completionStep
                    }
                }

                Spacer()

                Button {
                    switch page {
                    case 0:
                        page = 1
                    case 1:
                        store.completeOnboarding(draft: draft)
                        page = 2
                    default:
                        isPresented = false
                    }
                } label: {
                    Text(primaryButtonTitle)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.11, green: 0.38, blue: 0.34))
                .disabled(isPrimaryDisabled)
            }
            .padding(24)
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Text("\(page + 1) / 3")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .onAppear {
                let initialDraft = store.onboardingDraft
                draft = initialDraft
                if draft.selectedModelName.isEmpty {
                    draft.selectedModelName = detection.inferredModelName
                }
                if draft.selectedColorName.isEmpty {
                    draft.selectedColorName = ProductCatalog.colorNames(for: draft.selectedModelName).first ?? ""
                }
            }
        }
    }

    private var pageTitle: String {
        switch page {
        case 0:
            "ご使用のiPhoneはこちらで正しいですか？"
        case 1:
            "どのカラーを使っていますか？"
        default:
            "あなたの使っているiPhoneを登録しました！"
        }
    }

    private var pageDescription: String {
        switch page {
        case 0:
            "検出した端末情報を確認して、違っていたらここで選び直します。"
        case 1:
            "ホームに入る前に、見分けやすいようカラーだけ設定します。"
        default:
            "\(draft.selectedModelName)をマイiPhoneに追加しました。"
        }
    }

    private var primaryButtonTitle: String {
        switch page {
        case 0:
            "これであっている"
        case 1:
            "登録する"
        default:
            "完了"
        }
    }

    private var isPrimaryDisabled: Bool {
        switch page {
        case 0:
            return draft.selectedModelName.isEmpty
        case 1:
            return draft.selectedColorName.isEmpty
        default:
            return false
        }
    }

    private var detectionStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("検出したiPhone")
                    .font(.headline)
                IPhoneArtworkView(imageFilename: selectedProduct?.imageFilename)
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)

                Text(detection.inferredModelName)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 6)

                onboardingInfoRow("容量", "\(detection.totalStorageGB)GB")
                onboardingInfoRow("空き容量", "\(detection.freeStorageGB)GB")
                onboardingInfoRow("iOS", detection.osVersion)
            }
            .padding(18)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            Button {
                isCorrectingModel.toggle()
            } label: {
                Label(isCorrectingModel ? "選び直しを閉じる" : "違うiPhoneを選ぶ", systemImage: "pencil")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color(red: 0.11, green: 0.38, blue: 0.34))

            if isCorrectingModel {
                VStack(alignment: .leading, spacing: 12) {
                    Text("機種を選び直す")
                        .font(.headline)

                    ForEach(recentProducts.prefix(4)) { product in
                        Button {
                            draft.selectedModelName = product.name
                            draft.selectedColorName = ProductCatalog.colorNames(for: product.name).first ?? ""
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(product.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(product.series)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if draft.selectedModelName == product.name {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color(red: 0.11, green: 0.38, blue: 0.34))
                                }
                            }
                            .padding(16)
                            .background(draft.selectedModelName == product.name ? Color(red: 0.9, green: 0.96, blue: 0.93) : .white)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var colorStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(draft.selectedModelName)
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(colorOptions, id: \.self) { color in
                    Button {
                        draft.selectedColorName = color
                    } label: {
                        ColorChoiceCard(
                            modelName: draft.selectedModelName,
                            colorName: color,
                            isSelected: draft.selectedColorName == color
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private struct ColorChoiceCard: View {
        let modelName: String
        let colorName: String
        let isSelected: Bool

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .topTrailing) {
                    IPhoneArtworkView(imageFilename: ProductCatalog.imageFilename(for: modelName, colorName: colorName))
                        .frame(height: 118)
                        .frame(maxWidth: .infinity)
                        .background(colorSwatch.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color(red: 0.11, green: 0.38, blue: 0.34))
                            .padding(8)
                    }
                }

                HStack(spacing: 8) {
                    Circle()
                        .fill(colorSwatch)
                        .frame(width: 14, height: 14)
                    Text(colorName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color(red: 0.9, green: 0.96, blue: 0.93) : .white)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(isSelected ? Color(red: 0.11, green: 0.38, blue: 0.34) : Color.black.opacity(0.06), lineWidth: isSelected ? 2 : 1)
            }
        }

        private var colorSwatch: Color {
            if colorName.contains("ブラック") { return Color.black.opacity(0.82) }
            if colorName.contains("ホワイト") { return Color.white }
            if colorName.contains("ナチュラル") { return Color(red: 0.72, green: 0.68, blue: 0.62) }
            if colorName.contains("デザート") { return Color(red: 0.76, green: 0.58, blue: 0.42) }
            if colorName.contains("ブルー") { return Color.blue.opacity(0.65) }
            if colorName.contains("ピンク") { return Color.pink.opacity(0.55) }
            if colorName.contains("グリーン") { return Color.green.opacity(0.55) }
            if colorName.contains("パープル") { return Color.purple.opacity(0.55) }
            return Color(.tertiarySystemFill)
        }
    }

    private var completionStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(Color(red: 0.11, green: 0.38, blue: 0.34))

            VStack(alignment: .leading, spacing: 8) {
                Text(draft.selectedModelName)
                    .font(.title2.bold())
                Text(draft.selectedColorName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("次は、バッテリー最大容量と今の使用感だけあとから追加できます。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func onboardingInfoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
        .font(.subheadline)
    }
}

private struct IPhoneDiagnosisEntryCard: View {
    let current: IPhoneOwnership?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(tint.opacity(0.12))
                    Image(systemName: "iphone")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(tint)
                }
                .frame(width: 62, height: 62)

                VStack(alignment: .leading, spacing: 6) {
                    Text("iPhone診断")
                        .font(.title2.bold())
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(tint.opacity(0.12), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var subtitle: String {
        if let current {
            return "\(current.product.name)のバッテリー、容量、使用感、買い替え意向を整理します。"
        }
        return "今使っているiPhoneの状態と買い替え判断を整理します。"
    }

    private var tint: Color {
        Color(red: 0.11, green: 0.38, blue: 0.34)
    }
}

private struct DiagnosisResultView: View {
    let ownership: IPhoneOwnership?
    let summary: IPhoneDiagnosisSummary?
    let ruleResult: MatchedRuleResult
    let isPro: Bool
    let onShowPaywall: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let ownership, let summary {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(ownership.product.name)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(summary.title)
                                .font(.title.bold())
                                .fixedSize(horizontal: false, vertical: true)
                            Text(summary.summary)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                        VStack(alignment: .leading, spacing: 12) {
                            Text("理由")
                                .font(.headline)
                            ForEach(summary.reasons, id: \.self) { reason in
                                Label(reason, systemImage: "checkmark.circle.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.primary, Color(red: 0.11, green: 0.38, blue: 0.34))
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                        if !freeRules.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("次のアクション")
                                    .font(.headline)
                                ForEach(freeRules) { rule in
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(rule.title)
                                            .font(.subheadline.weight(.semibold))
                                        Text(rule.description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    if rule.id != freeRules.last?.id {
                                        Divider()
                                    }
                                }
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        }

                        if isPro {
                            ProUnlockedDiagnosisCard(summary: summary)
                        } else {
                            ProDiagnosisPreviewCard(onShowPaywall: onShowPaywall)
                        }
                    } else {
                        ContentUnavailableView("診断できるiPhoneがありません", systemImage: "iphone.slash")
                            .padding(.top, 80)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("iPhone診断")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var freeRules: [RuleDefinition] {
        (ruleResult.todoItems + ruleResult.cautionItems + ruleResult.solveItems)
            .filter { $0.accessLevel == .free }
            .prefix(4)
            .map { $0 }
    }
}

private struct ProUnlockedDiagnosisCard: View {
    let summary: IPhoneDiagnosisSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color(red: 0.11, green: 0.38, blue: 0.34))
                Text("詳しい診断")
                    .font(.headline)
                Spacer()
                Text("Pro")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.11, green: 0.38, blue: 0.34).opacity(0.12))
                    .foregroundStyle(Color(red: 0.11, green: 0.38, blue: 0.34))
                    .clipShape(Capsule())
            }

            Text(summary.recommendedAction)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color(red: 0.11, green: 0.38, blue: 0.34))

            VStack(alignment: .leading, spacing: 8) {
                Label("交換費用と買い替え差額を比較できます", systemImage: "checkmark.circle.fill")
                Label("次に見る候補を絞り込めます", systemImage: "checkmark.circle.fill")
                Label("売却前の確認ポイントを整理できます", systemImage: "checkmark.circle.fill")
            }
            .font(.subheadline)
            .foregroundStyle(.primary, Color(red: 0.11, green: 0.38, blue: 0.34))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct ProDiagnosisPreviewCard: View {
    let onShowPaywall: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color(red: 0.11, green: 0.38, blue: 0.34))
                Text("詳しい診断")
                    .font(.headline)
                Spacer()
                Text("Pro")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.11, green: 0.38, blue: 0.34).opacity(0.12))
                    .foregroundStyle(Color(red: 0.11, green: 0.38, blue: 0.34))
                    .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("バッテリー交換と買い替えを比較", systemImage: "checkmark.circle.fill")
                Label("あなたに合うiPhone候補を整理", systemImage: "checkmark.circle.fill")
                Label("売却前に確認するポイントを表示", systemImage: "checkmark.circle.fill")
            }
            .font(.subheadline)
            .foregroundStyle(.primary, Color(red: 0.11, green: 0.38, blue: 0.34))

            Button(action: onShowPaywall) {
                Text("詳しい診断を見る")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.11, green: 0.38, blue: 0.34))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct PaywallView: View {
    @ObservedObject var entitlementManager: EntitlementManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: "sparkles")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(Color(red: 0.11, green: 0.38, blue: 0.34))

                Text("詳しい診断を見る")
                    .font(.largeTitle.bold())
                    .fixedSize(horizontal: false, vertical: true)

                Text("Proで、交換・買い替え・売却前チェックをまとめて判断できるようにします。")
                    .font(.body)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 12) {
                    Label("今のiPhoneを使い続けるべきか確認", systemImage: "checkmark.circle.fill")
                    Label("バッテリー交換と買い替えを比較", systemImage: "checkmark.circle.fill")
                    Label("あなたに合うiPhone候補を表示", systemImage: "checkmark.circle.fill")
                    Label("売却前に確認するポイントを整理", systemImage: "checkmark.circle.fill")
                }
                .font(.headline)
                .foregroundStyle(.primary, Color(red: 0.11, green: 0.38, blue: 0.34))

                Spacer()

                Button {
                    Task {
                        await entitlementManager.purchasePro()
                        if entitlementManager.isPro {
                            dismiss()
                        }
                    }
                } label: {
                    Text(purchaseButtonTitle)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .disabled(entitlementManager.products.isEmpty || entitlementManager.isLoading)
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.11, green: 0.38, blue: 0.34))

                if entitlementManager.products.isEmpty {
                    Button {
                        Task {
                            await entitlementManager.loadProducts()
                        }
                    } label: {
                        Label("商品情報を再読み込み", systemImage: "arrow.clockwise")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(entitlementManager.isLoading)
                    .buttonStyle(.bordered)
                }

                Button {
                    Task {
                        await entitlementManager.restorePurchases()
                        if entitlementManager.isPro {
                            dismiss()
                        }
                    }
                } label: {
                    Text("購入を復元")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color(red: 0.11, green: 0.38, blue: 0.34))

                if let message = entitlementManager.latestErrorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                if entitlementManager.products.isEmpty {
                    Text("確認中のProduct ID: \(entitlementManager.proProductID)。App Store Connectの反映直後は、Sandboxに商品情報が届くまで時間がかかることがあります。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(24)
            .navigationTitle("Pro")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                if entitlementManager.products.isEmpty {
                    await entitlementManager.loadProducts()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var purchaseButtonTitle: String {
        if entitlementManager.isLoading {
            return "読み込み中"
        }
        guard let product = entitlementManager.products.first(where: { $0.id == entitlementManager.proProductID }) else {
            return "Pro商品を設定してください"
        }
        return "Proを購入 \(product.displayPrice)"
    }
}

private struct SettingsSheetView: View {
    @ObservedObject var store: AppStore
    @Binding var isPresented: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingResetConfirmation = false

    private var data: AppSettingsData { store.snapshot.settings }

    var body: some View {
        NavigationStack {
            List {
                Section("通知設定") {
                    ForEach(data.notifications) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                Text(item.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: item.enabled ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(item.enabled ? .green : .secondary)
                        }
                    }
                }

                Section("データ管理") {
                    Button(role: .destructive) {
                        isShowingResetConfirmation = true
                    } label: {
                        Label("登録データを消してやり直す", systemImage: "arrow.counterclockwise")
                    }
                    Label("エクスポート", systemImage: "square.and.arrow.up")
                    Label("プライバシー", systemImage: "hand.raised")
                    Label("Pro機能", systemImage: "sparkles")
                }
            }
            .navigationTitle("設定")
            .confirmationDialog("登録データを消してやり直しますか？", isPresented: $isShowingResetConfirmation, titleVisibility: .visible) {
                Button("やり直す", role: .destructive) {
                    store.resetCurrentIPhoneOnboarding()
                    isPresented = false
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("あなたのiPhone登録、バッテリー記録、使用感ログ、相場確認、確認待ち状態を消して、初回登録からやり直します。")
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct IPhoneArtworkView: View {
    let imageFilename: String?
    var contentMode: ContentMode = .fit

    var body: some View {
        Group {
            if let image = loadImage() {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .blendMode(.multiply)
            } else {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.18, green: 0.33, blue: 0.32), Color(red: 0.34, green: 0.68, blue: 0.61)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        Image(systemName: "iphone")
                            .font(.system(size: 38, weight: .medium))
                            .foregroundStyle(.white.opacity(0.95))
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(contentMode == .fit ? 8 : 0)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func loadImage() -> UIImage? {
        guard let imageFilename else { return nil }
        guard let path = Bundle.main.path(forResource: imageFilename, ofType: nil) else { return nil }
        return UIImage(contentsOfFile: path)
    }
}

#Preview {
    ContentView()
}
