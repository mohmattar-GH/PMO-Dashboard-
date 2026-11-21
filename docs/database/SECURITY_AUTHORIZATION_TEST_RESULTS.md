# Backend Security and Authorization Test Results — 21 November 2026

## Executive result

A focused security review and rollback-only authorization test suite was completed against the Executive PPM Platform Supabase project.

One over-broad read policy was identified and corrected:
- Before: any active project member could read the full `project_contracts` record, including contractual obligations, penalties, payment terms and commercial values.
- After: access is limited to active Project Manager and Finance project memberships, Platform Administrator / Finance Administrator global roles, or Executive Viewer with an active explicit financial-access grant.

The new policy was applied to the live PPM database and committed as migration `20261120232936_security_policy_hardening`.

## Contract read policy — verified

All role tests used temporary fixture records inside explicit SQL transactions that were rolled back. The test set `SET LOCAL ROLE authenticated` and a simulated `request.jwt.claim.sub` to exercise the database RLS predicates. These are database-role/RLS tests, **not end-to-end tests using cryptographically signed Auth JWTs**.

Two test projects were created temporarily. One project-specific Executive Viewer grant was scoped to Project A only.

| Test identity | Project A contract rows | Project B contract rows | Expected |
|---|---:|---:|---|
| Project Manager on A | 1 | 0 | Pass |
| Finance on A | 1 | 0 | Pass |
| Team Lead on A | 0 | 0 | Pass |
| Project Viewer on A | 0 | 0 | Pass |
| Executive Viewer with A-only grant | 1 | 0 | Pass |
| Executive Viewer without grant | 0 | 0 | Pass |
| Finance Administrator global role | 1 | 1 | Pass |

The test confirmed both role restriction and project-level grant scoping.

## Invoice allocation reversal — verified

A temporary invoice, confirmed payment transaction and allocation were created inside a rollback-only transaction.

- Finance user: `reverse_invoice_cash_allocation` succeeded.
- Team Lead: reversal was denied; the row was not visible to that role and the function returned `Allocation not found`.
- The Finance test changed the allocation state to `reversed` and recorded the reversal fields.
- The complete transaction was rolled back. No live invoice, cash transaction or allocation was retained.

The current UPDATE policy and SELECT policy both permit the Finance role required by the SECURITY INVOKER reversal function. The earlier concern about the removed duplicate UPDATE policy is therefore not an active defect.

## Lifecycle RPC review

The following functions remain SECURITY DEFINER because they perform multi-table lifecycle writes atomically while direct client write policies remain restricted:

- `public.assign_project_lifecycle(...)`
- `public.transition_project_phase(...)`

Static review confirmed:
- Empty function search path (`search_path = ''`).
- Explicit `auth.uid()` checks.
- Active application-profile checks.
- Platform Administrator or assigned Project Manager authorization checks.
- Effective-from / effective-to checks for the relevant global role or project membership.
- No EXECUTE privilege for `anon`; EXECUTE is granted to `authenticated` for the intended application RPC flow.

Rollback-only negative tests confirmed:
- A future-dated Platform Administrator assignment is rejected.
- An expired Project Manager membership is rejected.

These controls explain why the two Security Advisor SECURITY DEFINER warnings are intentional but still require ongoing review. The warnings are not a substitute for testing the functions through actual authenticated HTTP requests.

## Database-wide security checks

Verified against the live project after migration 062:

- 47 tables across `public` and `private`; all 47 have RLS enabled.
- No table in those schemas was found with RLS disabled.
- The private `private.reporting_formula_templates` table remains inaccessible to `anon` and `authenticated`; `service_role` retains its required SELECT privilege.
- Six key read-model views were checked and all use `security_invoker = true`: project current phase, phase change log, master schedule timeline, payment/risk timeline, project snapshot index and portfolio snapshot index.
- No temporary security-test Auth users, projects, contracts or memberships remained after rollback.

## Security Advisor status

Current findings:

1. **WARN — 2 authenticated SECURITY DEFINER functions.** These are the two lifecycle RPCs above. They are intentionally callable by authenticated users, with authorization enforced in the function bodies. Remediation reference: https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable
2. **INFO — RLS enabled with no policy on `private.reporting_formula_templates`.** This is intentional: the table is server-only and has no client access policy. Remediation reference: https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy

No new Security Advisor finding was introduced by the contract-policy migration.

## CI and migration verification

- Migration: `20261120232936_security_policy_hardening`
- Live Supabase migration ledger: 62 migrations.
- GitHub repository: 62 migration SQL files; filenames exactly match the live ledger.
- Clean local Supabase replay after migration 062: passed.
- GitHub Actions replay run: https://github.com/mohmattar-GH/PMO-Dashboard-/actions/runs/44837247508
- Frontend build run: https://github.com/mohmattar-GH/PMO-Dashboard-/actions/runs/44837247564

## Remaining validation — do not mark complete

The SQL-level role tests use simulated request claims and do not prove the full Auth/API path. Still required before production readiness:

1. Provision approved test Auth accounts and obtain real signed access tokens.
2. Run role-based tests through the Supabase Data API/RPC endpoints, including project-specific and global financial grants, expiry and revocation.
3. Exercise lifecycle assignment and transition through the authenticated RPC HTTP path.
4. Test Storage access with actual uploaded documents across Project, Management, Finance and Restricted classifications.
5. Verify frontend role gating and RLS results together for each role.

No real Auth users were provisioned as part of this pass. No production data was created or changed by the test fixtures. No deployment or PR merge was performed.


## Lifecycle transition authorization correction — 21 November 2026

A deeper source review found that the live `transition_project_phase` function checked membership/role status but omitted effective-date predicates in its authorization branch. This was inconsistent with the intended policy and with the earlier summary of the control.

- Applied migration `20261121082534_lifecycle_transition_effective_date_authorization`.
- The replacement function now requires an active application profile and checks `effective_from <= now()` plus `effective_to IS NULL OR effective_to > now()` for both the Platform Administrator assignment and the Project Manager membership.
- Re-read the live function definition after migration and confirmed both date predicates are present.
- Existing function execution ACLs were preserved; `anon` remains denied and `authenticated` retains the intended RPC access.
- Security Advisor still reports the two intentional lifecycle SECURITY DEFINER warnings and the private formula-template INFO finding.

This is a source-level verification of the correction, **not** a new real-JWT or role-fixture test. The earlier simulated negative-test note must not be treated as proof that the omitted date predicates were enforced before this migration. Fresh rollback-only effective-date tests and signed-JWT HTTP tests remain required.

The migration source is committed at `supabase/migrations/20261121082534_lifecycle_transition_effective_date_authorization.sql`. Migration replay CI for the 63-migration chain is the next verification gate. No user data or Auth accounts were created; no merge or deployment was performed.


### Post-fix effective-date tests

After migration 063, four rollback-only SQL tests were run with temporary Auth/profile/project fixtures and simulated `request.jwt.claim.sub` values:

| Authorization path | Test assignment | Result |
|---|---|---|
| Project Manager membership | Future effective date | Denied as expected |
| Project Manager membership | Expired effective date | Denied as expected |
| Platform Administrator global role | Future effective date | Denied as expected |
| Platform Administrator global role | Expired effective date | Denied as expected |

All four tests returned the expected authorization error. The transaction was rolled back; a follow-up query confirmed zero test Auth users, profiles or projects remained. These are simulated-claim database tests, not signed-JWT HTTP tests.

Privilege verification after migration 063: `anon` cannot execute `transition_project_phase`; `authenticated` retains the intended RPC execution grant. The live function definition contains both effective-date checks for both authorization paths.
