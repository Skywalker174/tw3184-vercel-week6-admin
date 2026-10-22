# Week 6 verification — 2026-10-21

## Completed before production deployment

- `npm run lint` and `npm run build` passed.
- Supabase admin migration and OAuth-session hardening applied.
- Transactional SQL security tests passed and rolled back their mutations.
- Anonymous callers, ordinary members, non-Google sessions and password-only sessions cannot use admin RPCs.
- Ordinary members cannot change `is_superadmin`; existing profile upserts still work and preserve the role flag.
- Approved Google administrator can read the dashboard, profiles, media, ratings, recycle bin and audit log.
- Anonymous HTTP requests to all eight tested admin routes redirect to `/login`.
- Real browser test: create an explicitly labeled QA copy of an existing AI asset, edit it, move it to trash, restore it, then move it back to trash.
- The five QA operations appear in the audit log. The QA copy is not in the public/live feed; it remains recoverable in trash. Original media and stored images were not deleted.
- SQL tests cover stale-update rejection and atomic restoration of associated votes and bookmarks.
- Successful create/edit/delete operations now redirect to the relevant destination with a confirmation message.
- At a 390-pixel mobile viewport, dashboard content fits without horizontal overflow.

## Still required for production sign-off

- Complete the user's manual GitHub email verification and add only this repository to the existing Vercel installation's selected repositories.
- Import this repository into a new Vercel project and configure its two server-side Supabase variables.
- Register the exact deployment callback in Supabase before testing Google OAuth.
- Check Vercel deployment protection, public login access, anonymous redirects, non-admin denial and approved-admin access on the production URL.
- Recheck the existing rating app and provide both latest commit-specific deployment URLs.

No PM or Feedback Group feedback was available. These checks are self-review evidence, not invented external feedback. A successful local build is not a claim that production deployment has completed.
