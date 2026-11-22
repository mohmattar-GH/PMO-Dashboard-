# Checkpoint — Frontend Foundation

Date: 20 November 2026

## Approved direction
- User approved the complete UI wireframe baseline and selected direct implementation in GitHub.
- Repository: `mohmattar-GH/PMO-Dashboard-`
- Implementation branch: `feature/ppm-frontend-foundation`
- Stack selected for the initial frontend: React 18, TypeScript, Vite, lucide-react. Exact package versions are pinned in `package.json`.

## Implemented in this slice
- React/Vite/TypeScript application scaffold.
- Responsive navigation shell and executive dashboard layout.
- Portfolio KPI cards, project health distribution, project phase distribution, management attention, decisions, portfolio risk summary, restricted financial panel, project register, recent phase changes.
- Local UI preview controls for administrator layout editing.
- Presentation Mode shell and navigation entry points for the approved modules.
- GitHub Actions workflow for frontend type-check/build.

## Current limitations — do not misrepresent
- Dashboard/project data are illustrative demo data, visibly labelled as demo data.
- No frontend connection to Supabase has been added yet.
- No authentication/session handling, permission-aware routes, persistent layout storage, live data, CRUD, export, or notification delivery has been implemented in this slice.
- Financial preview toggle is demonstrative only and is not authorization.
- Most module navigation destinations are placeholders pending implementation against the approved screen specifications.
- No production deployment or publishing has been performed.

## Next tasks
1. Run CI and resolve any TypeScript/build errors; commit the package lockfile.
2. Implement secure Supabase authentication and database-role-based authorization.
3. Connect Executive Dashboard and Projects Register to verified RLS-protected data sources; remove demo data.
4. Implement Project Workspace, schedule and finance/risk modules.
5. Implement CR, Deliverables, Milestones and Notification Centre.
6. Implement Configuration Center, versioned dashboard layouts, snapshot reports and full Presentation Mode.
7. Complete JWT-based role/RLS, integration, accessibility and regression testing.

## Protected boundary
The Staff Time & Performance application and its Supabase project remain untouched. Production deployment remains reserved for explicit user approval.

## Follow-on implementation — authentication foundation

- Added `@supabase/supabase-js@2.119.2` and `src/lib/supabase.ts`.
- Added `src/auth/AuthGate.tsx`: email/password sign-in, persisted session, token refresh, auth-state listener, active profile validation, global-role and project-membership lookup.
- Authorization identity is derived from protected database tables; `user_metadata` is not trusted.
- Added `.env.example` and Vite environment typings. Browser config uses only the publishable key; no service-role key is included.
- App shell now shows authenticated identity and sign-out control.
- Missing environment configuration blocks the app and displays setup requirements instead of showing a false authenticated workspace.

## Validation and corrections

- The original scaffold's CI build passed.
- First auth integration attempt failed at npm install due to an invalid literal newline in `package.json`; corrected.
- Next attempt passed TypeScript but failed Vite CSS parsing due to literal escaped newlines; corrected.
- Supabase JS 2.119.2 declares Node >=22; CI workflow updated from Node 20 to Node 22.
- The corrected CSS/Node workflow changes are committed. A fresh CI result for the latest branch head has not yet been reported; do not claim the current head build passes.
- No lockfile is committed yet.

## Security follow-up identified during backend review

- Existing SELECT policies include `executive_viewer` for several finance-bearing tables: project financial terms, invoices, cash transactions, payment allocations, contract variations and contracts.
- This conflicts with the approved requirement that executive financial visibility is denied by default and requires an explicit administrator grant.
- Do not connect financial data to the frontend until a dedicated, audited, revocable visibility-grant model is implemented and JWT/RLS tests prove default denial and authorized access.
- Existing demo financial preview remains a local visual-only mock; it is not a permission grant.

