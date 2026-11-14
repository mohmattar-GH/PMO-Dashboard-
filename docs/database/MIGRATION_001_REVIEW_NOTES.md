# Migration 001 — Review Notes and Deployment Gate

Status: SQL draft committed; NOT applied to Supabase as of 14 November 2026.

## Committed artifacts

- `docs/database/MIGRATION_001_EXECUTABLE_DRAFT.sql`
  - Commit: `90ae8f338bf8ce2fb4cc2126838405a598c9a934`
- `docs/database/MIGRATION_001_VERIFICATION.sql`
  - Commit: `82ba1900ea9bc5a2abd56f630a83efacdad1ab32`

## Review findings and implementation constraints

1. The draft intentionally restricts user provisioning, role assignment, project membership changes and project master-data writes to trusted server-side workflows using the service role. The service role must never be present in a browser.
2. A trusted provisioning workflow must explicitly supply `projects.created_by` when inserting a project through the service role, because `auth.uid()` is not guaranteed to be populated in a service-role context.
3. Profile rows must be provisioned by a trusted workflow after Auth user creation. The migration does not create an Auth trigger or automatically provision users.
4. When reassigning a global role or project membership, the trusted workflow must revoke any prior active assignment before creating a replacement. The partial unique indexes prevent multiple rows marked active even if an earlier row's effective end date has passed. The RLS checks also validate the effective period.
5. Role catalogue reads are available to authenticated users; user role assignments are self-readable only. Sensitive administrative listing and mutation remains a trusted backend operation.
6. Project and client/portfolio visibility is constrained by active project memberships and the platform-admin role. The migration does not yet implement executive-wide portfolio access or export capabilities; those require dedicated reporting views/permissions in later migrations.
7. This first migration does not create the reporting configuration engine, finance/schedule/risk tables, document storage, timeline read models, snapshots or application UI.
8. No RLS role-negative tests can be considered passed until test identities and at least two test projects exist. The verification SQL checks structural configuration only; it is not a substitute for authorization tests.
9. The Supabase CLI was not available in the execution environment. Therefore, a CLI-generated timestamped migration under `supabase/migrations` has not been created. The SQL remains committed as a reviewable draft under `docs/database`. Before production migration workflow is finalized, create the migration using the Supabase CLI's `supabase migration new` command and verify local migration history.
10. Current Supabase project verification before deployment: project `oihawkpbtgqxxliaamxs` active/healthy; PostgreSQL 17.11; zero tables and zero migration history.

## Deployment gate

Do not apply until:
- The SQL has been reviewed for the intended role and data-access policy.
- The timestamped migration is created using the Supabase CLI in the repository.
- The migration is applied only to `oihawkpbtgqxxliaamxs`.
- Post-apply structural checks and Supabase security/performance advisors are run.
- Real authorization tests verify cross-project isolation, revoked memberships, profile self-edit restrictions and denial of all anonymous access.
