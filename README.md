# Oddly Admin — TW3184 / Week 6

A separate Next.js repository and Vercel project for administering the existing Oddly Funny Supabase database. The media creation/rating application stays in its original repository and project.

## Features

- Real dashboard: profile/media/rating counts, upvote share, unrated content, incomplete names, 14-day New York activity, net-vote leaders, model distribution.
- Read/search/paginate users and profiles. Identity and roles are read-only.
- Create/register AI media by reusing an existing AI asset or uploading an AI-generated image, with its source prompt/model metadata. No additional paid AI API is required.
- Read/edit media with optimistic concurrency checks. Preserve existing votes on edits.
- Delete into a recoverable recycle bin; restore the original media, votes and bookmarks atomically. Stored image bytes remain protected from owner cleanup while referenced by a live or trashed record.
- Read/search/paginate ratings. No admin score editing or artificial votes.
- Audit log for every media create/update/delete/restore; update logs include the previous content.

## Authentication and authorization

All admin pages use a server-only data access layer. Every page/data read and every Server Action calls `requireAdmin()`. This verifies the actual Supabase user, Google provider and a live database role check. The protected layout is an additional guard, not the sole guard.

Every privileged SQL function rechecks Google + `profiles.is_superadmin` on the authenticated database session. Functions have an empty search path and explicit EXECUTE grants. Anonymous callers cannot execute them. Normal members cannot read other profiles, view admin statistics, mutate admin media, or promote themselves.

Only the existing Supabase URL and anon key are configured in Vercel. No service-role key is used anywhere in this app. Cookies stay server-side; privileged data is never embedded on the public login page. Robots are disabled.

The only public app routes are the Google sign-in page and OAuth callback. A signed-in non-admin sees access denied and a switch-account control, not a partial admin UI.

## Avoid locking yourself out

Apply `supabase/week6_admin.sql` using the Supabase owner's SQL Editor. This adds a default-false `is_superadmin` field and narrows profile write grants so ordinary profile upserts cannot change roles. A trigger adds a second defense against role changes by unprivileged clients.

After confirming the exact account with the owner, use the SQL Editor (not a public signup form) to set the existing profile UUID's flag to true. Verify that exactly the intended account is flagged. Role assignment is deliberately not exposed in this app.

```sql
-- Replace with an existing, verified account UUID. Never auto-promote all users.
update public.profiles set is_superadmin = true where id = 'VERIFIED-ACCOUNT-UUID';
```

Sign in through that account's Google identity. To recover access or revoke it, the database owner can change the flag in the SQL Editor. Do not use user-editable metadata or a hardcoded email allowlist as an authorization mechanism.

## Setup / deployment

1. `npm install`
2. Put `SUPABASE_URL` and `SUPABASE_ANON_KEY` in ignored `.env.local` (see `.env.example`).
3. Apply the migration, bootstrap the explicitly approved account, then run `supabase/security_test.sql`. Tests roll all mutations back.
4. `npm run dev` (localhost:3001), `npm run lint`, `npm run build`.
5. Create a new Vercel project from this new repo. Add the two server-side environment variables. No billing setup is needed.
6. Allowlist the exact deployment origin + `/auth/callback` in Supabase. `VERCEL_URL` supplies the deployment-specific origin; callbacks do not contain custom query parameters.
7. Make the Vercel sign-in page reachable without Vercel Authentication; keep the application's Google + superadmin wall enabled.
8. Verify anonymous, signed-in non-admin, and approved-admin flows. Check all read routes and media CRUD, restore, audit and old-app regression.
9. Provide the latest commit-specific URLs for BOTH apps. Do not substitute a mutable alias or the Vercel dashboard URL.

## Feedback provenance

The user confirmed no PM / Feedback Group feedback was available. This project does not invent meeting comments or claim feedback implementation marks. It builds on the user's actual earlier requests: less forced NYC humor, free credits only, a Crackd-like readable UI, and better usability.

Week 5 already added saved posts, My Posts, real Top-rated discovery, explicit vote state, style choices, quota visibility and inline generation previews. Week 6's self-review adds searchable management views, meaningful real statistics, recovery instead of irreversible deletion, audited changes, and defense against self-promotion. These are self-review decisions, not quotes from a PM.
