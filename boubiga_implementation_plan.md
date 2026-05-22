# boubiga 実装計画書

最終更新: 2026-05-22
目的: iPhone状態確認アプリ「boubiga」の実用MVPを、ローカル永続化 → ルール配信のローカル土台 → Pro課金 → Supabase CMS の順に段階実装する。

---

## 0. この計画書の結論

2026-05-22時点では、まず「実機で使い始められるMVP」を優先する。Supabase、管理画面、StoreKitは重要だが、ユーザー操作やApple Developer / Supabase側の準備が必要なため、アプリ単体で進められる範囲から固める。

### 0.1 現在の実装状況

完了:

- iPhone検出 → 機種確認 → カラー選択 → 登録完了のオンボーディング
- `マイiPhone` 1画面ホーム
- 状態メーター、情報ボタン、やることリスト数字バッジ
- バッテリーOCR導線、手入力フォールバック
- 使用感ログ、相場確認モック、ルールベース簡易診断
- `UserDefaults` + JSON による最小ローカル永続化
- 初回起動時はサンプルデータではなく、保存データまたは現在端末検出から開始
- 設定からの「登録データを消してやり直す」で、現在端末登録・バッテリー記録・使用感ログ・相場確認・確認待ち状態を消して初回登録に戻す
- `DeviceSnapshot` / `RemoteAppConfig` / `RuleDefinition` / `RuleEngine` のローカル土台
- `bundled_app_config.json` からルールとしきい値を読み込む仕組み
- ホーム上のルール由来インサイトカード
- iPhone診断カードから開く簡易診断結果シート
- 非Pro向けの詳細診断プレビューとPaywall
- StoreKit 2による商品読み込み、購入、復元、ローカルPro判定の土台
- Apple Developer Team ID `RSB2T5LYYP` / Bundle ID `com.boubiga` へXcode設定を更新
- App Store Connectに買い切りPro商品 `boubiga_pro_lifetime` を作成済み
- Supabase初期DBスキーマ、RLS、初期公開JSON seed を追加
- Supabase Data APIの自動公開OFF前提で、必要なGRANTを明示するmigrationを追加
- Supabase Edge Functions の `get-published-config` / `preview-rules` / `publish-config` を追加
- サーバー設計メモを `docs/server/supabase_design.md` に整理
- Supabaseキー記入用の `.env.local` 雛形、共有用 `.env.example`、セットアップメモを追加
- iOS側に公開設定取得用の `AppConfigClient` 土台、Supabase公開URL設定、取得結果キャッシュを追加
- やることリスト本体に `RuleEngine` のtodo出力を接続し、固定タスクとの重複を抑制
- `VersionNumber` によるiOSバージョン比較を追加し、配信JSONの最新iOS判定に接続
- `admin/` に Next.js 管理画面MVPを追加
- 管理画面で Supabase Authログイン、公開設定確認、最新iOS下書き編集、しきい値編集、ルールプレビュー、公開処理を実行できる土台を追加
- 管理画面にメールリンクログインを追加し、管理者ユーザーにパスワード未設定でもログインできるようにした
- 管理画面へのログインは確認済み

次に進める:

- 実機で「登録データを消してやり直す」が完全リセットとして動くか確認
- 実機でルール由来インサイト、診断結果、Paywall表示、商品価格表示の導線を確認
- 実機またはTestFlight/Sandboxで購入・復元・Pro解放を確認
- 実機でSupabase公開JSON取得、やることリスト表示、iOS最新判定が期待通りか確認
- やることリスト本体と使いづらさ解消カードを `RuleEngine` の結果へさらに統合
- 管理画面ログイン後に、下書き保存、プレビュー、公開処理が実Supabaseで通るか確認
- 管理画面に action_items / rules / guides の一覧・編集UIを追加

ユーザー側の操作が必要:

- 実機またはSimulatorで、初回登録後にアプリを終了・再起動して保存が残るか確認
- バッテリー状態画面のスクショを用意し、OCR結果が妥当か確認
- App Store Connectの商品反映後、Paywallに価格が出るか実機で確認
- 管理画面 `http://localhost:3000` に、Supabase Authで作成した管理者メール、またはメールリンクでログインできるか確認する: 完了
- ログイン後、公開設定表示、下書き保存、プレビュー、公開ボタンを押した時の結果を確認する
- 管理者ユーザーにパスワードを設定していない場合は、管理画面の「メールでログインリンクを送る」を使う

### 0.2 実装優先順

1. 最小ローカル永続化とリセット導線: 完了
2. バッテリーOCR保存体験の実機確認と修正
3. bundled JSON + RuleEngine: 土台完了、一部UI接続済み
4. 使用感ログと簡易診断結果画面の磨き込み: 診断結果シートの初期版完了
5. Pro詳細診断入口とPaywallモック: 初期版完了
6. StoreKit 2買い切りPro: アプリ側土台完了、App Store Connectの商品作成完了、実機購入確認待ち
7. Supabase配信JSON: サーバー側土台とiOS取得接続は完了
8. Web管理画面: 初期MVP完了、action/rule/guide編集は次フェーズ
9. iOS最新版自動検出

MVPでは、次の構成で進める。

```text
iOSアプリ SwiftUI
  ├─ StoreKit 2
  │   └─ Pro買い切り課金 / ローカルPro判定
  ├─ ローカル永続化
  │   └─ 端末情報・OCR結果・診断結果キャッシュ
  ├─ Supabase配信JSON取得
  │   └─ 最新iOS / しきい値 / やることリスト / 気をつけること / ガイド
  └─ ルールエンジン
      └─ ユーザー端末状態 × 運営ルールで表示内容を決定

Supabase
  ├─ Postgres
  │   └─ 設定・ルール・ガイド・公開バージョン管理
  ├─ Auth + RLS
  │   └─ 管理画面の認証・権限管理
  ├─ Edge Functions
  │   ├─ 公開設定JSONの配信
  │   ├─ CMSプレビュー
  │   ├─ 公開処理
  │   └─ 将来: iOS最新版自動検出
  └─ Cron
      └─ 将来: Apple公式情報の定期チェック

Web管理画面
  └─ Next.js + Supabase
      ├─ iOS最新版管理
      ├─ しきい値管理
      ├─ やることリスト管理
      ├─ 気をつけること管理
      ├─ ガイド管理
      ├─ プレビュー
      └─ 公開 / ロールバック
```

Firebase Remote Configは、初期実装では必須にしない。まずはSupabase一本で「CMS + 公開JSON配信」まで作る。将来的にA/Bテスト、段階公開、緊急Feature Flagを強化したくなった段階で追加検討する。

---

## 1. 実装方針

### 1.1 アプリの基本方針

boubigaは、ユーザーの不安を煽る診断アプリではなく、「自分のiPhoneの状態を軽く把握して、次に何をすればいいか分かるアプリ」として設計する。

そのため、課金導線も次のようにする。

```text
無料で状態確認
↓
無料で簡易診断
↓
もっと詳しく判断したい人だけPro
```

避ける設計:

```text
診断する
↓
即Paywall
↓
払わないと何も分からない
```

### 1.2 Pro機能の切り分け

| 機能 | 無料 | Pro |
|---|---:|---:|
| あなたのiPhoneカード | ○ | ○ |
| 状態メーター | ○ | ○ |
| バッテリーOCR | ○ | ○ |
| 使いづらさを解消する | ○ | ○ |
| やることリスト | ○ | ○ |
| 簡易診断 | ○ | ○ |
| 詳細診断 | × | ○ |
| 修理 vs 買い替え比較 | × | ○ |
| おすすめiPhone候補 | 一部 | ○ |
| 容量対処ガイド | 基本のみ | 詳細 |
| 診断ログ履歴 | 直近のみ | 複数履歴 |
| 価格・相場込みの判断 | 一部 | ○ |

MVPのProは「買い切り」を前提にする。

候補Product ID:

```text
boubiga_pro_lifetime
```

---

## 2. 全体アーキテクチャ

### 2.1 MVP構成

```text
[iOS App]
  ↓ GET
[Supabase Edge Function: get-published-config]
  ↓
[Supabase Postgres: published config]

[Admin Web]
  ↓ CRUD
[Supabase Postgres: draft data]
  ↓ publish
[Supabase Postgres: published config]
```

### 2.2 アプリ側で持つもの

- UI
- StoreKit 2購入処理
- Pro判定
- ローカル永続化
- ルールエンジン
- 配信JSONのキャッシュ
- 通信失敗時の初期デフォルト値

### 2.3 Supabase側で持つもの

- 最新iOS情報
- しきい値
- やることリスト項目
- 気をつけること項目
- ガイド記事
- 表示ルール
- 公開バージョン
- 管理者ユーザー
- 変更履歴
- 将来的なiOS自動検出候補

### 2.4 初期実装でやらないこと

- Proユーザーのサーバー側購入検証
- アカウント同期
- 複数端末同期
- A/Bテスト
- 完全自動iOS最新版公開
- 高度な承認ワークフロー

---

## 3. iOSアプリ実装計画

### 3.1 追加・整理する主要コンポーネント

```text
boubiga/
  AppModels.swift
  ContentView.swift
  Services/
    AppConfigStore.swift
    AppConfigClient.swift
    EntitlementManager.swift
    RuleEngine.swift
    DiagnosisEngine.swift
    LocalPersistenceStore.swift
  Models/
    RemoteAppConfig.swift
    DeviceSnapshot.swift
    RuleDefinition.swift
    TodoItem.swift
    CautionItem.swift
    GuideContent.swift
    ProEntitlement.swift
  Views/
    PaywallView.swift
    DiagnosisView.swift
    DiagnosisResultView.swift
    TodoListView.swift
    GuideDetailView.swift
```

---

### 3.2 AppConfigStore

役割:

- アプリ起動時にローカルデフォルトを読む
- 前回キャッシュ済みの公開設定を読む
- Supabaseから最新版設定を取得する
- 取得成功時にローカルキャッシュを更新する
- 通信失敗時でもアプリを壊さない

仕様:

```swift
final class AppConfigStore: ObservableObject {
    @Published private(set) var config: RemoteAppConfig
    @Published private(set) var isLoading: Bool
    @Published private(set) var lastFetchedAt: Date?

    func loadBundledDefaults()
    func loadCachedConfig()
    func refreshConfig() async
}
```

起動時の流れ:

```text
1. アプリ内デフォルト値を読み込む
2. キャッシュがあれば上書き
3. 画面表示
4. 裏でSupabaseから最新版を取得
5. 取得できたらキャッシュ保存
6. 次回表示または必要なタイミングで反映
```

---

### 3.3 EntitlementManager

役割:

- StoreKit 2で商品情報を取得
- 購入処理
- 購入復元
- `currentEntitlements` によるPro判定
- `isPro` をアプリ全体に提供

仕様:

```swift
@MainActor
final class EntitlementManager: ObservableObject {
    @Published private(set) var isPro: Bool = false
    @Published private(set) var products: [Product] = []

    let proProductID = "boubiga_pro_lifetime"

    func loadProducts() async
    func purchasePro() async throws
    func refreshEntitlements() async
    func restorePurchases() async
}
```

MVPではサーバー購入検証は行わない。将来、Pro専用APIやアカウント同期を実装する段階で、App Store Server API / Notificationsの導入を検討する。

---

### 3.4 RuleEngine

役割:

端末状態と運営側ルールを照合し、以下を生成する。

- やることリスト
- 気をつけること
- 使いづらさを解消するカード
- 診断結果の表示補助
- ガイド導線

入力:

```text
DeviceSnapshot
RemoteAppConfig.rules
EntitlementState
```

出力:

```text
MatchedRuleResult
  ├─ todoItems
  ├─ cautionItems
  ├─ guideRecommendations
  └─ diagnosisHints
```

疑似コード:

```swift
func evaluate(
    snapshot: DeviceSnapshot,
    config: RemoteAppConfig,
    isPro: Bool
) -> MatchedRuleResult {
    let activeRules = config.rules.filter { $0.isActive }
    let matched = activeRules.filter { rule in
        evaluateConditions(rule.conditions, snapshot: snapshot)
    }

    return MatchedRuleResult.from(matched, isPro: isPro)
}
```

---

### 3.5 DeviceSnapshot

端末状態をアプリ内で統一して扱う。

```swift
struct DeviceSnapshot: Codable, Equatable {
    var deviceIdentifier: String
    var marketingName: String
    var colorName: String?
    var iosVersion: String
    var storageTotalGB: Double?
    var storageFreeGB: Double?
    var batteryCapacityPercent: Int?
    var cycleCount: Int?
    var manufactureDate: Date?
    var firstUseDate: Date?
    var firstUseMonths: Int?
    var tradeInPriceYen: Int?
    var updatedAt: Date
}
```

---

## 4. Pro機能実装

### 4.1 Paywall表示位置

Paywallは診断カードを押した直後には出さない。

推奨フロー:

```text
iPhone診断カード
↓
質問に回答
↓
無料の簡易結果
↓
「詳しい診断を見る」
↓
Paywall
↓
購入後に詳細診断
```

### 4.2 Paywallコピー

管理画面から変更できるようにする。

初期値:

```text
詳しい診断を見る

Proでできること
・今のiPhoneを使い続けるべきか確認
・バッテリー交換と買い替えを比較
・あなたに合うiPhone候補を表示
・売却前に確認するポイントを整理
```

### 4.3 Pro判定箇所

- 詳細診断結果
- 修理 vs 買い替え比較
- 詳細なおすすめiPhone候補
- Pro限定ガイド本文
- 複数診断ログ保存

---

## 5. Supabase DB設計

### 5.1 テーブル一覧

```text
admin_profiles
app_config_versions
os_versions
os_release_candidates
condition_thresholds
content_guides
action_items
rules
rule_conditions
published_configs
audit_logs
```

---

### 5.2 admin_profiles

管理者権限管理。

```sql
create table admin_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('owner', 'editor', 'viewer')),
  created_at timestamptz not null default now()
);
```

---

### 5.3 app_config_versions

公開バージョン管理。

```sql
create table app_config_versions (
  id uuid primary key default gen_random_uuid(),
  version_number integer not null unique,
  status text not null check (status in ('draft', 'published', 'archived')),
  notes text,
  created_by uuid references auth.users(id),
  published_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  published_at timestamptz
);
```

---

### 5.4 os_versions

アプリに配信する確定済みOS情報。

```sql
create table os_versions (
  id uuid primary key default gen_random_uuid(),
  platform text not null check (platform in ('ios', 'ipados')),
  latest_version text not null,
  release_date date,
  severity text not null default 'normal' check (severity in ('normal', 'security', 'major')),
  message text,
  source_url text,
  status text not null default 'draft' check (status in ('draft', 'published', 'archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

---

### 5.5 os_release_candidates

将来の自動取得で検出した候補。

```sql
create table os_release_candidates (
  id uuid primary key default gen_random_uuid(),
  platform text not null,
  detected_version text not null,
  detected_release_date date,
  source_url text,
  source_text text,
  confidence numeric,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  detected_at timestamptz not null default now(),
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz
);
```

---

### 5.6 condition_thresholds

バッテリー、ストレージ、使用期間などのしきい値。

```sql
create table condition_thresholds (
  id uuid primary key default gen_random_uuid(),
  metric text not null,
  label text not null,
  good_min numeric,
  warning_min numeric,
  critical_below numeric,
  unit text,
  status text not null default 'draft' check (status in ('draft', 'published', 'archived')),
  updated_at timestamptz not null default now()
);
```

例:

```json
{
  "metric": "storage_free_gb",
  "label": "空き容量",
  "good_min": 20,
  "warning_min": 10,
  "critical_below": 10,
  "unit": "GB"
}
```

---

### 5.7 content_guides

容量不足、バッテリー、買い替えなどのガイド。

```sql
create table content_guides (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  category text not null,
  title text not null,
  summary text,
  body text,
  access_level text not null default 'free' check (access_level in ('free', 'pro')),
  priority integer not null default 100,
  min_ios_version text,
  max_ios_version text,
  status text not null default 'draft' check (status in ('draft', 'published', 'archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

---

### 5.8 action_items

やることリスト、気をつけること、使いづらさ解消カードに出す表示項目。

```sql
create table action_items (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  category text not null,
  target_surface text not null check (target_surface in ('todo', 'caution', 'solve', 'diagnosis')),
  severity text not null default 'info' check (severity in ('info', 'warning', 'critical')),
  cta_label text,
  action_type text,
  guide_slug text references content_guides(slug),
  access_level text not null default 'free' check (access_level in ('free', 'pro')),
  priority integer not null default 100,
  status text not null default 'draft' check (status in ('draft', 'published', 'archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

---

### 5.9 rules

表示条件ルールの親。

```sql
create table rules (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  action_item_id uuid references action_items(id) on delete cascade,
  match_type text not null default 'all' check (match_type in ('all', 'any')),
  is_active boolean not null default true,
  status text not null default 'draft' check (status in ('draft', 'published', 'archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

---

### 5.10 rule_conditions

ルール条件。

```sql
create table rule_conditions (
  id uuid primary key default gen_random_uuid(),
  rule_id uuid not null references rules(id) on delete cascade,
  metric text not null,
  operator text not null check (operator in (
    'eq', 'neq', 'lt', 'lte', 'gt', 'gte',
    'between', 'is_null', 'is_not_null', 'in'
  )),
  value_json jsonb,
  created_at timestamptz not null default now()
);
```

例:

```json
{
  "metric": "battery_capacity_percent",
  "operator": "lt",
  "value_json": { "value": 80 }
}
```

```json
{
  "metric": "battery_capacity_percent",
  "operator": "is_null",
  "value_json": null
}
```

---

### 5.11 published_configs

アプリ配信用に固めたJSONを保存する。

```sql
create table published_configs (
  id uuid primary key default gen_random_uuid(),
  version_number integer not null unique,
  config_json jsonb not null,
  published_by uuid references auth.users(id),
  published_at timestamptz not null default now(),
  is_current boolean not null default false
);
```

`is_current = true` は1件だけにする。

---

### 5.12 audit_logs

管理画面の変更履歴。

```sql
create table audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references auth.users(id),
  action text not null,
  target_table text,
  target_id uuid,
  before_json jsonb,
  after_json jsonb,
  created_at timestamptz not null default now()
);
```

---

## 6. RLS / セキュリティ方針

### 6.1 基本方針

- 管理画面はSupabase Authでログイン必須
- 管理系テーブルはadmin_profiles.roleで制御
- アプリはDBを直接読まず、Edge Function経由で公開済みJSONだけ取得
- Service Role Keyはクライアントに置かない
- draftデータはアプリへ返さない

### 6.2 権限

| role | 権限 |
|---|---|
| owner | 全操作 |
| editor | 作成・編集・プレビュー・公開 |
| viewer | 閲覧・プレビューのみ |

MVPでは管理者1人でもよいが、最初からrole列は用意しておく。

---

## 7. Edge Functions設計

### 7.1 get-published-config

アプリが読むAPI。

```text
GET /functions/v1/get-published-config
```

レスポンス:

```json
{
  "version": 12,
  "published_at": "2026-05-21T00:00:00Z",
  "ios": {
    "latest_global_version": "26.5",
    "release_date": "2026-05-11",
    "severity": "normal",
    "message": "iOS 26.5 が利用可能です。設定アプリからアップデートを確認できます。"
  },
  "thresholds": {
    "battery_warning_percent": 85,
    "battery_critical_percent": 80,
    "storage_warning_gb": 20,
    "storage_critical_gb": 10
  },
  "rules": [],
  "guides": []
}
```

要件:

- 認証なしで取得可能にしてもよい
- ただしdraftや管理情報は返さない
- キャッシュしやすい形にする
- アプリ側はレスポンスをローカル保存する

---

### 7.2 preview-rules

管理画面でテスト端末を入力し、表示結果を確認するAPI。

```text
POST /functions/v1/preview-rules
```

入力:

```json
{
  "snapshot": {
    "deviceIdentifier": "iPhone15,2",
    "marketingName": "iPhone 14 Pro",
    "iosVersion": "26.4",
    "storageFreeGB": 8,
    "storageTotalGB": 128,
    "batteryCapacityPercent": 78,
    "firstUseMonths": 42
  },
  "useDraft": true
}
```

出力:

```json
{
  "todoItems": [],
  "cautionItems": [],
  "solveItems": [],
  "diagnosisHints": []
}
```

---

### 7.3 publish-config

管理画面から公開するAPI。

```text
POST /functions/v1/publish-config
```

処理:

```text
1. 管理者認証確認
2. draft状態のos_versions / thresholds / rules / guidesを取得
3. アプリ配信用JSONに変換
4. published_configsへ保存
5. is_currentを切り替え
6. app_config_versionsをpublishedへ変更
7. audit_logsへ記録
```

---

### 7.4 check-ios-release 将来実装

Apple公式情報からiOS最新版候補を検出する。

```text
POST /functions/v1/check-ios-release
```

処理:

```text
1. Apple公式ページを取得
2. iOS最新版らしき表記を抽出
3. 現在のpublished versionと比較
4. 違いがあればos_release_candidatesへ保存
5. status = pending
6. 管理画面に候補として表示
```

重要:

- 自動検出しただけではアプリに公開しない
- 管理画面で承認後、os_versionsへ反映する
- 将来的にパッチアップデートだけ自動公開を検討する

---

## 8. Web管理画面設計

### 8.1 技術構成

```text
Next.js
Supabase Auth
Supabase JS Client
Plain CSS
```

### 8.2 画面一覧

```text
/admin/login
/admin/dashboard
/admin/ios
/admin/thresholds
/admin/action-items
/admin/rules
/admin/guides
/admin/preview
/admin/publish
/admin/audit-logs
```

---

### 8.3 ダッシュボード

表示:

- 現在公開中の設定バージョン
- 最新iOS
- 公開中ルール数
- 下書きルール数
- 公開中ガイド数
- 自動検出されたiOS候補
- 最終公開日時

---

### 8.4 iOS管理

機能:

- 最新iOSバージョン編集
- リリース日編集
- 重要度設定
- 表示メッセージ編集
- 自動検出候補の承認 / 却下

項目:

```text
platform
latest_version
release_date
severity
message
source_url
status
```

---

### 8.5 しきい値管理

対象:

- バッテリー最大容量
- ストレージ空き容量
- ストレージ使用率
- 使用期間
- iOS古さ
- 買取価格

UI例:

```text
ストレージ空き容量
良好: 20GB以上
注意: 10〜20GB
要確認: 10GB未満
```

できればスライダーまたは数値入力で視覚的に調整できるようにする。

---

### 8.6 やることリスト管理

作成できる項目例:

```text
タイトル:
バッテリー最大容量を確認する

説明:
設定アプリのバッテリー画面スクショを追加すると、より正確に状態を見られます。

表示先:
やることリスト

条件:
battery_capacity_percent is null

CTA:
スクショを追加する

無料 / Pro:
無料

優先度:
10
```

---

### 8.7 気をつけること管理

作成できる項目例:

```text
タイトル:
容量が少なくなっています

説明:
空き容量が少ないため、写真やアプリデータの整理を検討しましょう。

表示先:
気をつけること / 使いづらさを解消する

条件:
storage_free_gb < 10

重要度:
warning

CTA:
容量の減らし方を見る
```

---

### 8.8 ルールビルダー

運営者がJSONを直接触らずに条件を作れるUIを作る。

UI例:

```text
条件を追加

[バッテリー最大容量] [が] [80] [%未満]
かつ
[使用期間] [が] [36] [ヶ月以上]

表示:
バッテリー交換か買い替えを検討しましょう
```

対応operator:

```text
eq
neq
lt
lte
gt
gte
between
is_null
is_not_null
in
```

対応metric:

```text
battery_capacity_percent
cycle_count
first_use_months
storage_free_gb
storage_used_percent
ios_version
latest_supported_ios
trade_in_price_yen
device_identifier
marketing_name
```

---

### 8.9 ガイド管理

管理するコンテンツ:

- 容量不足ガイド
- バッテリー確認ガイド
- バッテリー交換ガイド
- 買い替えガイド
- 売却前チェックリスト
- Pro限定詳細ガイド

項目:

```text
slug
category
title
summary
body
access_level
priority
status
```

---

### 8.10 プレビュー画面

最重要画面。

入力例:

```text
機種: iPhone 13
iOS: 26.4
バッテリー: 78%
空き容量: 8GB
総容量: 128GB
使用期間: 42ヶ月
Pro: false / true
```

出力例:

```text
やることリスト
・容量を整理する
・iOSアップデートを確認する

気をつけること
・バッテリーの劣化が進んでいる可能性があります
・容量が少なくなっています

使いづらさを解消する
・容量の減らし方を見る
・バッテリー交換か買い替えを検討する
```

---

### 8.11 公開管理

機能:

- 現在公開中のバージョン確認
- 下書き差分確認
- 公開
- ロールバック
- 公開メモ

運用:

```text
下書き編集
↓
プレビュー
↓
公開
↓
アプリ配信JSON更新
```

---

## 9. アプリ配信JSON仕様

### 9.1 形式

```json
{
  "schema_version": 1,
  "config_version": 12,
  "published_at": "2026-05-21T00:00:00Z",
  "ios": {
    "latest_global_version": "26.5",
    "release_date": "2026-05-11",
    "severity": "normal",
    "message": "iOS 26.5 が利用可能です。設定アプリからアップデートを確認できます。"
  },
  "thresholds": {
    "battery_warning_percent": 85,
    "battery_critical_percent": 80,
    "storage_warning_gb": 20,
    "storage_critical_gb": 10
  },
  "action_items": [
    {
      "id": "storage_low_warning",
      "title": "容量を整理する",
      "description": "空き容量が少なくなっています。写真やアプリデータを確認しましょう。",
      "target_surface": "todo",
      "severity": "warning",
      "cta_label": "対処法を見る",
      "action_type": "open_guide",
      "guide_slug": "storage_cleanup_basic",
      "access_level": "free",
      "priority": 10
    }
  ],
  "rules": [
    {
      "id": "rule_storage_low",
      "action_item_id": "storage_low_warning",
      "match_type": "all",
      "conditions": [
        {
          "metric": "storage_free_gb",
          "operator": "lt",
          "value": 10
        }
      ]
    }
  ],
  "guides": [
    {
      "slug": "storage_cleanup_basic",
      "category": "storage",
      "title": "容量を減らす基本チェック",
      "summary": "写真・動画・アプリデータから確認します。",
      "body": "...",
      "access_level": "free",
      "priority": 10
    }
  ],
  "paywall": {
    "title": "詳しい診断を見る",
    "description": "Proでは、今のiPhoneを使い続けるべきか、買い替えるべきかを詳しく確認できます。",
    "features": [
      "修理と買い替えを比較",
      "おすすめiPhone候補を表示",
      "売却前チェックを整理"
    ]
  }
}
```

---

## 10. 最新iOS自動取得設計

### 10.1 初期運用

最初は手動更新。

```text
管理画面で latest_version を入力
↓
プレビュー
↓
公開
↓
アプリに反映
```

### 10.2 将来運用

```text
Cron
↓
Edge Function: check-ios-release
↓
Apple公式情報を取得
↓
新バージョン候補を検出
↓
os_release_candidates に保存
↓
管理画面で承認
↓
os_versions に反映
↓
公開
```

重要:

- 自動検出と公開を分ける
- 誤検知や表記変更に備える
- ベータ版を拾わない
- 古い機種向けの別系統アップデートに注意する

---

## 11. iOSバージョン判定の注意点

単純に「現在iOS < 最新iOS」で判定しない。

将来的には機種ごとに対応可能な最新iOSを持つ。

```text
現在のiOS
端末識別子
その機種のlatest_supported_ios
↓
比較
```

将来テーブル候補:

```text
device_os_support
- device_identifier
- marketing_name
- latest_supported_ios
- support_status
```

MVPでは、全体最新バージョンで判定してもよいが、古い端末に対して「最新ではありません」と断定しすぎない文言にする。

---

## 12. 実装フェーズ

### Phase 1: ローカルPro + ローカルルール

目的: 課金とルールエンジンの土台を作る。

作業:

- StoreKit 2 EntitlementManager実装: アプリ側土台完了
- Pro買い切り商品IDを定義: `boubiga_pro_lifetime`
- PaywallView作成: `ContentView.swift` 内に初期版を実装
- RemoteAppConfigモデル作成: 完了
- Bundled default config追加: 完了
- RuleEngine実装: 完了
- TodoList / Caution表示をRuleEngine化: ホームのルール由来インサイトへ一部接続済み
- Unit Test追加

完了条件:

- Pro購入状態で詳細診断が開く。購入状態の実動作確認にはStoreKit商品設定が必要
- 無料状態では簡易結果まで表示される
- ローカルJSONのルールでホーム上のインサイト表示が変わる

---

### Phase 2: Supabase DB + 公開JSON配信

目的: アプリ外から設定を更新できるようにする。

作業:

- Supabaseプロジェクト作成: 完了
- DB schema作成: 完了
- RLS設定: 完了
- get-published-config Edge Function作成: 完了
- preview-rules Edge Function作成: 完了
- publish-config Edge Function作成: 完了
- published_configsに初期JSON登録: seed SQL追加済み
- iOSアプリにAppConfigClient追加: 完了（現時点では `AppModels.swift` 内）
- 取得結果のローカルキャッシュ実装: 完了

完了条件:

- Supabaseの公開JSONをアプリが取得できる
- 通信失敗時はキャッシュまたはバンドル値で動く
- iOS最新版やしきい値をSupabase側で変えるとアプリ表示が変わる

---

### Phase 3: Web管理画面 MVP

目的: 運営者が視覚的にルールを管理できるようにする。

作業:

- Next.js管理画面作成: 完了
- Supabase Authログイン実装: 完了
- メールリンクログイン実装: 完了
- Dashboard作成: 公開設定サマリーの初期版は完了
- iOS管理画面: 最新iOS下書き編集の初期版は完了
- しきい値管理画面: バッテリー/容量しきい値編集の初期版は完了
- action_items管理画面
- rule_conditions管理画面
- guides管理画面
- preview-rules Edge Function作成: 完了
- publish-config Edge Function作成: 完了
- preview画面: 完了
- publish画面: 完了

完了条件:

- Web上でやることリスト項目を作成できる: 未完了
- 条件をUIから設定できる: 未完了
- プレビューで表示結果を確認できる: 実装済み、ログイン後の実操作確認待ち
- 公開ボタンでアプリ配信JSONが更新される: 実装済み、ログイン後の実操作確認待ち

---

### Phase 4: 診断Pro強化

目的: Proの価値を明確にする。

作業:

- 詳細診断画面作成
- 修理 vs 買い替え比較ロジック
- おすすめiPhone候補表示
- Pro限定ガイド表示
- PaywallコピーをCMS配信化
- 診断ログ保存

完了条件:

- 無料/Proの体験差が明確になる
- 課金後に詳細診断へ自然に遷移する
- Pro限定コンテンツが非Proではロック表示になる

---

### Phase 5: 最新iOS自動検出

目的: 運営の手動更新負荷を下げる。

作業:

- check-ios-release Edge Function作成
- Supabase Cron設定
- os_release_candidates保存
- 管理画面に候補表示
- 承認/却下フロー
- 承認後にos_versionsへ反映

完了条件:

- 新しいiOS候補を自動検出できる
- 自動検出だけでは公開されない
- 管理者承認後にアプリ配信へ反映される

---

## 13. Codex向け実装タスク一覧

### 13.1 iOS側

```text
[x] EntitlementManager.swift を作成
[x] StoreKit 2の商品読み込み・購入・復元を実装
[x] PaywallView を作成（現時点では `ContentView.swift` 内）
[x] RemoteAppConfig の土台を作成（現時点では `AppModels.swift` 内）
[x] bundled_app_config.json を追加
[x] AppConfigStore の土台を作成（現時点では `AppModels.swift` 内）
[x] AppConfigClient の土台を作成（現時点では `AppModels.swift` 内）
[x] DeviceSnapshot の土台を作成（現時点では `AppModels.swift` 内）
[x] RuleDefinition の土台を作成（現時点では `AppModels.swift` 内）
[x] RuleEngine の土台を作成（現時点では `AppModels.swift` 内）
[x] TodoListViewをRuleEngine出力に接続（現時点では `TaskFlowView` 内）
[x] Caution/使いづらさ解消表示をRuleEngine出力に一部接続（ホームのルール由来インサイト）
[x] DiagnosisResultViewを作成
[x] Pro限定表示のロックUIを作成
[x] ローカルキャッシュ保存を実装
[x] Supabase公開JSON取得とキャッシュ保存を実装
[x] バージョン比較ユーティリティを実装
[x] RuleEngineのUnit Testを追加
[x] VersionCompareのUnit Testを追加
```

### 13.2 Supabase側

```text
[x] Supabase schema SQLを作成
[x] admin_profilesを作成
[x] app_config_versionsを作成
[x] os_versionsを作成
[x] os_release_candidatesを作成
[x] condition_thresholdsを作成
[x] content_guidesを作成
[x] action_itemsを作成
[x] rulesを作成
[x] rule_conditionsを作成
[x] published_configsを作成
[x] audit_logsを作成
[x] RLS policyを設定
[x] Data API用の明示GRANTを設定
[x] get-published-config Edge Functionを作成
[x] preview-rules Edge Functionを作成
[x] publish-config Edge Functionを作成
[x] 初期published_configを投入するseed SQLを作成
[x] Supabaseプロジェクトへmigrationを適用
[x] Supabase Authの管理者ユーザーを作成
[x] admin_profilesへ初期ownerを追加
[x] Edge Functionsをデプロイ
[x] Edge Functionの環境変数を設定
[x] Supabaseキー記入用の.env雛形を作成
```

### 13.3 管理画面側

```text
[x] Next.jsプロジェクト作成
[x] Supabase Authログイン実装
[x] メールリンクログイン実装
[x] Admin layout作成
[x] Dashboard作成（公開設定サマリー）
[x] iOS管理画面作成（最新iOS下書き編集）
[x] しきい値管理画面作成（バッテリー/容量）
[ ] action_items一覧/編集画面作成
[ ] rules編集画面作成
[ ] rule condition builder作成
[ ] guides一覧/編集画面作成
[x] preview画面作成
[x] publish画面作成
[ ] rollback UI作成
```

---

## 14. 最低限の受け入れ基準

### アプリ

- アプリ起動時に公開設定を取得できる
- 取得失敗時もアプリが正常に動く
- 最新iOS判定が外部設定で変わる
- ストレージ・バッテリーのしきい値が外部設定で変わる
- やることリストがルールに応じて変わる
- 気をつけることがルールに応じて変わる
- Pro購入で詳細診断が解放される
- 購入復元ができる

### 管理画面

- 管理者だけログインできる
- 最新iOSを編集できる
- しきい値を編集できる
- やることリスト項目を作成できる
- 表示条件を編集できる
- テスト端末でプレビューできる
- 公開できる
- 公開済みJSONをアプリが取得できる

### バックエンド

- draftとpublishedが分かれている
- アプリにdraftデータが返らない
- 公開JSONにversionが入る
- ロールバックできる
- 変更履歴が残る

---

## 15. 注意点

### 15.1 ルールを複雑にしすぎない

MVPでは、条件はAND/ORの1階層までにする。

許可:

```text
A かつ B
A または B
```

後回し:

```text
(A かつ B) または (C かつ D)
```

### 15.2 Proコンテンツの秘匿性

MVPでは、Pro限定本文が配信JSONに含まれる可能性がある。完全に隠したい場合は、将来的に認証付きAPI + サーバー側購入検証に移行する。

MVPでは「表示制御」と割り切る。

### 15.3 iOS最新版の表現

古い機種では最新iOSに対応していない場合があるため、断定しすぎない。

避ける:

```text
最新ではありません。今すぐ更新してください。
```

推奨:

```text
利用できるアップデートがある可能性があります。設定アプリから確認しましょう。
```

### 15.4 診断トーン

boubigaのトーンは「不安を煽らず、判断を助ける」。

避ける:

```text
危険です
すぐ買い替えてください
寿命です
```

推奨:

```text
注意が必要です
買い替え判断の材料になります
使いづらさの原因になっている可能性があります
```

---

## 16. 次にCodexへ渡す実装プロンプト例

```text
このリポジトリはSwiftUI製のiOSアプリ「boubiga」です。
以下の実装計画書に従って、ローカル永続化済みのMVPを前提に次のPhaseを進めてください。

次のゴール:
1. App Store ConnectまたはStoreKit Configurationに `boubiga_pro_lifetime` を用意する
2. 実機でPaywallの商品読み込み、購入、復元、Pro判定を確認する
3. やることリスト本体をRuleEngineの結果に接続する
4. 詳細診断のPro向け本文と修理 vs 買い替え比較を作る
5. Supabase配信JSONへ差し替える準備を始める

まだSupabase接続は実装しなくてよいです。
Phase 1では、ローカルJSONで動く状態を作ってください。
```

---

## 17. 推奨する次の一手

まずはSupabaseや管理画面に入る前に、iOSアプリ内で次を完成させる。

```text
StoreKit商品設定
実機Paywall確認
購入/復元/Pro判定確認
TodoList本体のRuleEngine接続
詳細診断本文
修理 vs 買い替え比較
```

ここができると、あとからSupabase配信に差し替えるだけで、CMS化がスムーズになる。

ユーザー側では実機で次を確認する。

- 初回登録後、アプリ再起動で登録済みホームに戻る
- OCRで保存した最大容量、充放電回数、製造日、最初の使用が再起動後も残る
- 使用感ログ、相場確認状態、確認待ちタスクの完了状態が再起動後も残る
- 設定から「登録データを消してやり直す」を実行すると、関連ログも消えて再登録フローに戻る
- iPhone診断カードから簡易診断結果が開き、非ProではPaywallへ進む
- StoreKit商品設定後、Paywallに価格が表示され、購入または復元でPro状態になる
