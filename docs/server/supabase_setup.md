# Supabase Setup

最終更新: 2026-05-22

## どこにIDやキーを書くか

実値はルートの `.env.local` に書く。

```bash
SUPABASE_URL=
SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=
BOUBIGA_SUPABASE_SERVICE_ROLE_KEY=
SUPABASE_ADMIN_EMAIL=
SUPABASE_PROJECT_REF=
```

`.env.local` はGit管理しない。共有用の雛形は `.env.example` を使う。

## キーの扱い

- `SUPABASE_URL`: iOSアプリ、管理画面、Edge Functionsで使用可
- `SUPABASE_ANON_KEY`: 管理画面や将来のクライアント接続で使用可。現在のiOS公開設定取得では不要
- `SUPABASE_SERVICE_ROLE_KEY`: サーバー/Edge Functions/ローカル管理作業だけで使用する
- `BOUBIGA_SUPABASE_SERVICE_ROLE_KEY`: Edge Functions用。`SUPABASE_SERVICE_ROLE_KEY` と同じ値をSupabase secretsへ設定する
- `SUPABASE_ADMIN_EMAIL`: 初期管理者を作るときの控え
- `SUPABASE_PROJECT_REF`: Supabase CLIのlink/deployで使う

`SUPABASE_SERVICE_ROLE_KEY` はiOSアプリに入れない。

## Supabase Dashboardで見る場所

- Project URL: Project Settings -> API -> Project URL
- anon key: Project Settings -> API -> Project API keys -> anon public
- service role key: Project Settings -> API -> Project API keys -> service_role
- project ref: Project Settings -> General -> Reference ID

## 次にやること

1. `.env.local` に実値を入れる。
2. Supabase Authで管理者ユーザーを作る。
3. そのユーザーのUUIDを `admin_profiles` に `owner` として登録する。
4. `supabase/migrations` のSQLを適用する。
5. Edge Functionsに環境変数を設定してデプロイする。
6. `get-published-config` は認証なし公開APIとして `--no-verify-jwt` 付きでデプロイする。

## Data API設定

Supabase作成時のData API設定は次の方針にする。

- Enable Data API: ON
- Automatically expose new tables: OFF
- Enable automatic RLS: ON

`Automatically expose new tables` をOFFにするため、必要な権限は `202605220003_data_api_grants.sql` で明示的に付与する。

## iOSアプリ側

`boubiga/supabase_public_config.json` には公開設定取得用のURLだけを入れる。

```json
{
  "supabase_url": "https://PROJECT_REF.supabase.co"
}
```

service role key はiOSアプリに入れない。

## 管理画面側

管理画面は `admin/` に置く。ローカル起動時は `admin/.env.local` に公開URLとanon keyだけを入れる。

```bash
NEXT_PUBLIC_SUPABASE_URL=https://PROJECT_REF.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
```

`admin/.env.local` もGit管理しない。service role key は管理画面に入れない。

起動:

```bash
cd admin
npm install
npm run dev -- --port 3000
```

確認URL:

```text
http://localhost:3000
```

ログインには、Supabase Authで作成し、`admin_profiles` に `owner` または `editor` として登録したユーザーを使う。

管理者ユーザーにパスワードを設定していない場合は、管理画面でメールアドレスを入力し、「メールでログインリンクを送る」を使う。届いたリンクから開くとログインできる。
