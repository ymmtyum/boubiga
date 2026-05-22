# Supabase Setup

最終更新: 2026-05-22

## どこにIDやキーを書くか

実値はルートの `.env.local` に書く。

```bash
SUPABASE_URL=
SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=
SUPABASE_ADMIN_EMAIL=
SUPABASE_PROJECT_REF=
```

`.env.local` はGit管理しない。共有用の雛形は `.env.example` を使う。

## キーの扱い

- `SUPABASE_URL`: iOSアプリ、管理画面、Edge Functionsで使用可
- `SUPABASE_ANON_KEY`: iOSアプリ、管理画面、Edge Functionsで使用可
- `SUPABASE_SERVICE_ROLE_KEY`: サーバー/Edge Functions/ローカル管理作業だけで使用する
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
