# boubiga Supabase Server Design

最終更新: 2026-05-22

## 目的

boubiga のサーバー側は、アプリ本体に重いロジックや最新情報を埋め込みすぎないための「公開設定配信」と「運営用CMS」の土台として作る。

初期スコープでは、ユーザーアカウント同期や購入検証は扱わない。アプリは公開済みJSONだけを読み、管理者だけがドラフトデータ、プレビュー、公開処理を使う。

## 構成

```text
iOS App
  -> get-published-config
  -> published_configs.config_json

Admin Web
  -> Supabase Auth
  -> Postgres draft/admin tables
  -> preview-rules
  -> publish-config
  -> published_configs
```

## DB

マイグレーションは `supabase/migrations` に置く。

- `202605220001_initial_server_schema.sql`
  - 管理者ロール、コンテンツ状態、ルール条件などの enum
  - `admin_profiles`
  - `app_config_versions`
  - `os_versions`
  - `condition_thresholds`
  - `content_guides`
  - `action_items`
  - `rules`
  - `rule_conditions`
  - `published_configs`
  - `audit_logs`
  - RLS と管理者権限ポリシー
- `202605220002_seed_initial_config.sql`
  - アプリ同梱 `bundled_app_config.json` と同等の初期公開設定
  - iOS 26.5、バッテリー/容量しきい値、初期ルール3件
- `202605220003_data_api_grants.sql`
  - Data API の自動公開をOFFにした前提で、必要なテーブル権限だけを明示的に付与
  - RLSは引き続き有効で、行レベルのアクセス制御はRLSで行う

## Edge Functions

### get-published-config

アプリ用。認証なしで現在公開中の `published_configs.config_json` だけを返す。

必要な環境変数:

- `SUPABASE_URL`
- `BOUBIGA_SUPABASE_SERVICE_ROLE_KEY`

### preview-rules

管理画面用。端末スナップショットを受け取り、公開済みまたは編集中ルールで表示結果を返す。

必要な環境変数:

- `SUPABASE_URL`
- `BOUBIGA_SUPABASE_SERVICE_ROLE_KEY`

### publish-config

管理画面用。アーカイブ以外の iOS情報、しきい値、ガイド、ルールをアプリ配信用JSONへ変換し、新しい `published_configs` として公開する。

必要な環境変数:

- `SUPABASE_URL`
- `BOUBIGA_SUPABASE_SERVICE_ROLE_KEY`

## 管理者初期化

RLSの都合で、最初の管理者は Supabase SQL Editor か service role 経由で `admin_profiles` に追加する。

```sql
insert into public.admin_profiles (id, role)
values ('<auth.users.id>', 'owner');
```

`<auth.users.id>` は Supabase Auth で作成した管理者ユーザーの UUID を入れる。

## 公開JSONの互換性

iOSアプリの `RemoteAppConfig` が読めるよう、公開JSONは同梱JSONと同じ snake_case を維持する。

`os_versions.severity` は管理上 `normal` / `security` / `major` を持てるが、アプリ配信時は `normal` / `warning` / `critical` に正規化する。現在は `security` と `major` を `warning` として配信する。

## デプロイ順

1. Supabaseプロジェクトを作成する。
2. `supabase/migrations` のSQLを順番に適用する。
3. Supabase Auth に管理者ユーザーを作る。
4. `admin_profiles` に管理者UUIDを `owner` で追加する。
5. Edge Functions をデプロイする。
6. `SUPABASE_URL`、`SUPABASE_ANON_KEY`、`SUPABASE_SERVICE_ROLE_KEY` を設定する。
7. `get-published-config` で初期JSONが返ることを確認する。

IDやキーの記入場所は `docs/server/supabase_setup.md` を参照する。実値は `.env.local` にだけ置き、共有用には `.env.example` を使う。

## 後続タスク

- iOS側に `AppConfigClient` / `AppConfigStore` を分離して、公開JSON取得とローカルキャッシュを追加する。
- 管理画面を作り、Authログイン、ルール編集、プレビュー、公開ボタンを接続する。
- 将来、StoreKitのサーバー検証やProユーザー同期を追加する場合は、別スキーマとして扱う。
