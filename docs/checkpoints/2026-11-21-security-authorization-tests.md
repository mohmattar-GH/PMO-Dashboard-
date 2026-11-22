# Security and Authorization Checkpoint — 21 November 2026

## Completed
- Identified that the former `project_contracts` SELECT policy exposed full contract records to any active project member, including Team Leads and Project Viewers.
- Applied migration `20261120232936_security_policy_hardening` to the live Executive PPM Supabase project and committed the matching SQL file.
- New contract read access: active Project Manager / Finance memberships; global Platform Administrator / Finance Administrator; Executive Viewer only with an active explicit financial-access grant.
- Verified role and project scope using rollback-only SQL tests with simulated Auth claims.
- Verified Finance allocation reversal succeeds and Team Lead cannot read/reverse the allocation.
- Reviewed lifecycle SECURITY DEFINER functions, function ACLs and role effective-date checks.
- Verified all 47 public/private tables have RLS enabled, private formula-template table is not client-accessible, and six key read-model views use security_invoker.
- Confirmed temporary test fixtures were fully rolled back and no test Auth users remain.
- Clean replay of all 62 migrations passed in GitHub Actions; frontend build passed.

## Evidence
- Security/authorization report: `docs/database/SECURITY_AUTHORIZATION_TEST_RESULTS.md`
- Migration source/replay record: `docs/database/MIGRATION_SOURCE_RECOVERY.md`
- Migration replay: https://github.com/mohmattar-GH/PMO-Dashboard-/actions/runs/44837247508
- Frontend build: https://github.com/mohmattar-GH/PMO-Dashboard-/actions/runs/44837247564

## Current Security Advisor findings
- Two WARN findings for the intended authenticated SECURITY DEFINER lifecycle RPCs. Their function bodies contain explicit identity, profile, role and effective-date checks; keep under review.
- One INFO finding for `private.reporting_formula_templates` with RLS enabled and no policies. This is intentional because it remains server-only and inaccessible to client roles.

## Still outstanding
- Real signed JWT tests through Auth and the Data API/RPC endpoints. Current SQL tests use simulated request claims, not real signed tokens.
- End-to-end role tests for Storage documents and the frontend.
- Further lifecycle RPC positive-path tests using real Auth accounts and configured lifecycle fixtures.

## Safety
No real users, projects, contracts or memberships were retained from test runs. No Staff Time & Performance assets were touched. No merge or deployment occurred. PR #1 remains draft.
