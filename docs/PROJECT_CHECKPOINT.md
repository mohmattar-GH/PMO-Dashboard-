# Project Checkpoint — 14 November 2026

## Confirmed infrastructure

### GitHub
- Repository: `mohmattar-GH/PMO-Dashboard-` (display name: PMO-Dashboard-)
- Default branch: `main`
- Connected GitHub identity has admin/maintain/push permissions.
- Repository was initially empty; baseline documentation was committed successfully.
- Existing `mohmattar-GH/project-draft` is the separate Staff Time & Performance app and must remain untouched.

### Supabase
- Dedicated project: `Executive PPM Platform`
- Project ref: `oihawkpbtgqxxliaamxs`
- Organization: `My Own` (`mafpwmiooiqmcgblktcq`)
- Region: `eu-central-1`
- Current status from project listing: `ACTIVE_HEALTHY`
- Database: PostgreSQL 17.
- Current public schema: no tables.
- Current migration history: no migrations.
- Existing Staff Time & Performance project `nwxwszwcdnczaurhjqke` is separate and must not be modified.

## Commits completed

1. `README.md` — project charter, boundaries, product outcomes, principles, and delivery sequence.
   - Commit: `3ac26f5926583f304a4e5c57f6c54ef791e6f85b`
2. `docs/requirements/PRD.md` — baseline product requirements, modules, roles, configuration center, governance, security, reporting, and acceptance criteria.
   - Commit: `c7376388e256584a076cb4ad9ba43d6aa40e0d11`
3. `docs/architecture/ARCHITECTURE.md` — logical architecture, source-of-truth rules, reporting engine, schedule integrity, timeline, security, and implementation sequence.
   - Commit: `c7ac020431efd66aa7986c1195ad1b33f581e167`
4. `docs/architecture/DATA_MODEL.md` — initial logical entity blueprint for identity, projects, finance, schedule, risks, configuration, snapshots, and timeline.
   - Commit: `07762f3e94f3f0c46299e34f9418a810095adbdd`

## Requirements that must not be weakened

- Standalone Executive PPM platform; no coupling to or changes in Staff Time & Performance app/database.
- Reporting rules, dimensions, KPI formulas, weights, thresholds, statuses, calendars, date logic, progress methods, risk scoring, and financial rules must be configurable in the application.
- Configuration changes must be permission-controlled, versioned, effective-dated, approved where required, and audited.
- Weekly snapshots retain exact configuration version and values used; historical reports are not silently recalculated.
- Original baseline, approved revised baseline, forecast, and actual dates are separate.
- Missing/insufficient data is never Green.
- Calculated health and PM-reported/approved status remain separate; overrides require reasons and audit.
- CEO dashboard provides portfolio-wide management attention and drill-down.
- Master schedule timeline and payment/risk exposure timeline are standalone modules and draw from source records.
- Supabase RLS on all exposed tables; trusted role authorization; no service-role key in frontend.
- No production publishing/deployment without explicit user approval.

## Additional architecture/security documents committed on 14 November 2026

5. `docs/architecture/SECURITY_MODEL.md` — security boundaries, role model, RLS principles, sensitive data, audit, and authorization tests.
   - Commit: `f7f9862b5bf26c2d05bfcdc5cb8433f42370f477`
6. `docs/architecture/DATABASE_SCHEMA_DESIGN.md` — detailed relational schema design for project, contract, schedule, finance, risk, configuration, snapshots and timelines.
   - Commit: `d0f93a6287fa202a17eb1d176805ff439c7468b6`
7. `docs/security/PERMISSION_MATRIX.md` — role/entity permission matrix, data classification, workflow permissions and RLS test cases.
   - Commit: `f450b3b17b37d18594df355e695800d6a654c0d5`
8. `docs/database/MIGRATION_001_DESIGN.md` — proposed first migration scope, table definitions, security approach and acceptance criteria.
   - Commit: `d2b33c1386d2760df867a971a72549f07ceacd4b`

## Migration 001 executable draft — 14 November 2026

- `docs/database/MIGRATION_001_EXECUTABLE_DRAFT.sql` committed (`90ae8f338bf8ce2fb4cc2126838405a598c9a934`).
- `docs/database/MIGRATION_001_VERIFICATION.sql` committed (`82ba1900ea9bc5a2abd56f630a83efacdad1ab32`).
- `docs/database/MIGRATION_001_REVIEW_NOTES.md` committed (`ded68db5b4841e1654883f64599dea11e05c321c`).
- Draft scope: role catalogue, user profiles, trusted global role assignments, clients, portfolios, project registry, project memberships, private audit events, grants, RLS and indexes.
- Supabase documentation was consulted for Data API grants/RLS, policy structure and view security. No anonymous business-data grants are included.
- The migration has NOT been applied. Supabase remains active/healthy with zero tables and zero migration history.
- Supabase CLI was not available in the execution environment. A CLI-generated timestamped file under `supabase/migrations` has not yet been created. Do not represent the SQL draft as a deployed migration.
- Structural verification SQL is committed; actual role-based authorization tests remain outstanding and require test users/projects.
- Deployment gate: create CLI migration in repository, review, apply only to `oihawkpbtgqxxliaamxs`, then verify schema/grants/RLS and run advisors and negative access tests.

## Supabase Migration 001 and 002 applied — 14 November 2026

- Target verified: `Executive PPM Platform`, ref `oihawkpbtgqxxliaamxs`, PostgreSQL 17.11, status `ACTIVE_HEALTHY`.
- Migration 001 applied: version `20261114093442`, name `migration_001_identity_access_project_foundation`.
- Migration 002 applied: version `20261114093557`, name `migration_002_foreign_key_indexes`.
- Created seven public tables: `app_role_definitions`, `user_profiles`, `user_global_role_assignments`, `clients`, `portfolios`, `projects`, `project_memberships`.
- Created private `security_audit_events` table.
- All eight tables verified with RLS enabled.
- Nine application role definitions seeded. No user profiles, role assignments, clients, portfolios, projects or memberships have been provisioned.
- Policies verified: authenticated read policies on the role catalogue, own profile/role assignment, project membership and project rows; self profile update is column-limited to display_name/job_title.
- Grant inspection found no `anon` table privileges on these tables. Authenticated has only the intended table SELECT grants; profile UPDATE is restricted to display_name/job_title at column level. Service-role grants are server-side only.
- Migration 002 adds six foreign-key indexes flagged by the first performance advisor run.
- Security advisor: one INFO finding remains for `private.security_audit_events` having RLS enabled but no policies. This is intentional: the schema is not exposed to the Data API; anon/authenticated have no access; service_role has explicit SELECT/INSERT and bypasses RLS. Keep this documented and reassess if private-schema access model changes.
- Performance advisor after Migration 002: only unused-index INFO findings remain. With no operational workload/data, these are not actionable yet; review after realistic query usage.
- Health advisor: no findings.
- Important limitation: role-based negative tests with actual Auth identities and two projects have NOT been run. Structural/policy/grant checks are not a substitute for end-to-end JWT/RLS tests.
- Supabase migration CLI/local timestamped `supabase/migrations` files are still not created in the repository. The applied migration versions are recorded by Supabase and the corresponding SQL artifacts remain under `docs/database`; reconcile a proper CLI migration workflow before normalizing local development.
- Existing Staff Time & Performance Supabase project and `project-draft` GitHub repository were not modified.

## Not implemented yet

- Application code/UI and framework selection.
- Supabase schema, migrations, RLS policies, Auth roles/membership, Storage buckets.
- Reporting rules engine and configuration UI.
- Project record workflows.
- Timeline modules.
- CEO dashboard and weekly snapshots.
- Excel/PDF exports.
- Automated tests, security review, regression suite, and deployment handover.

## Next execution sequence

1. Inspect and confirm the intended frontend/runtime stack (repository is currently documentation-only and has no app scaffold).
2. Finalize schema relationships, permission matrix, and RLS policy design.
3. Commit the reviewed schema as version-controlled migration(s), then apply to the dedicated Supabase project.
4. Verify tables, constraints, RLS, and allowed/denied access paths.
5. Implement identity/roles/project registry and the Reporting Rules & Configuration Center foundation.
6. Implement core project modules, timelines, CEO dashboard, snapshots, and exports.
7. Run regression/security/acceptance tests and update this checkpoint after each meaningful milestone.

## Current verified state
Documentation is committed to GitHub. Supabase project is active and empty. No functional application or database implementation should be represented as complete yet.
