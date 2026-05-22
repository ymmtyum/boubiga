# boubiga Admin

Next.js based admin MVP for boubiga server config.

## Setup

Create `admin/.env.local`:

```bash
NEXT_PUBLIC_SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
```

Do not put `service_role` keys in this app.

## Run

```bash
npm install
npm run dev -- --port 3000
```

Open:

```text
http://localhost:3000
```

Use a Supabase Auth user that exists in `admin_profiles` as `owner` or `editor`.
