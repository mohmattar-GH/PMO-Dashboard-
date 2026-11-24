# Project Checkpoint — 23 November 2026

## Product and boundaries
- Product: Executive PPM Platform / PMO Dashboard.
- GitHub repository: `mohmattar-GH/PMO-Dashboard-`.
- Supabase project: `oihawkpbtgqxxliaamxs` (Executive PPM Platform).
- The Staff Time & Performance application and its Supabase project remain strictly out of scope.
- No production deployment has been performed or authorized.

## Product-owner decisions
- The UI Review Round 1 blueprint was accepted as the baseline for the first software release on 23 November 2026.
- The user may request UI changes after inspecting the first software release; the accepted blueprint is not immutable.
- Approved 12-section primary navigation remains the application structure.
- CEO/Executive financial visibility remains restricted by default and must be enforced by backend authorization.
- Dashboard layout management remains Admin-only.
- Project deliverables remain unaccepted until the Project Manager explicitly accepts them.
- Change Requests, Milestones, Deliverables and in-app Notification Centre are included in the current release.
- All reporting rules, KPI formulas/weights/thresholds, lifecycle mappings, workflows, notification rules, date rules and dashboard layout settings remain configurable, versioned and audited.
- Weekly snapshots must preserve the exact configuration lineage and source cutoff.
- Missing data must never be classified as Green.

## Verified Supabase state
- Project status: ACTIVE_HEALTHY; PostgreSQL 17.11.
- Applied migrations currently reach `20261121211410` (`configurable_project_risk_score_engine`).
- Public tables and read models for project registry, lifecycle, schedules, milestones, CRs, deliverables, finance, risks, licenses, notifications, reporting and dashboard layout are present.
- The database inspection on 23 November confirmed zero records in each of: projects, project memberships, user profiles, global role assignments, milestones, risks, change requests, deliverables, notifications, reporting cycles and portfolio snapshots.
- RLS is enabled on the listed public tables. Example inspected policies restrict project reads to active project memberships or authorized global roles; user profile and global-role assignment reads are self-scoped; notifications are recipient-scoped.
- The current database contains no provisioned platform administrator or project member. A signed-in user therefore still needs a trusted profile plus a global role assignment or active project membership before operational data is visible.
- Do not bypass RLS or create a privileged bootstrap identity without an explicitly authorized, secure provisioning path.

## Frontend work committed
- Next.js App Router + React 19.3.1 + TypeScript scaffold.
- Pinned Next.js 16.4.6, Supabase SSR 0.12.7 and Supabase JS 2.119.2 dependencies.
- Supabase server/browser clients and Next.js `proxy.ts` session refresh/claim validation.
- Email/password login and sign-out.
- Responsive app shell and approved navigation.
- Executive Overview server-side reads for projects, milestones, change requests, unaccepted deliverables, notifications and latest portfolio snapshot, all through the signed-in Supabase client.
- Access-setup warning when the signed-in user lacks an active global role or project membership.
- GitHub Actions workflow for TypeScript checking and production build.

## Important limitations / not yet verified
- GitHub Actions has not yet completed a successful TypeScript check and production build.
- No local build or browser test was run from this session.
- No package lockfile has yet been generated/committed.
- Login credentials/user provisioning and end-to-end role tests remain outstanding.
- The 12 navigation destinations are not yet all fully implemented; non-overview modules currently show an implementation placeholder.
- The dashboard is connected to Supabase read queries but operational tables are empty and there is no provisioned authorized user to validate real business data.
- The project is not a first-release candidate yet.

## Next implementation priorities
1. Establish a secure initial platform-admin provisioning procedure, without weakening RLS.
2. Validate auth, role and project-membership authorization with controlled test users.
3. Implement Projects Register, project creation and project workspace against existing RPCs and tables.
4. Implement detailed schedule, milestone, deliverable and CR screens and their governed actions.
5. Implement notification centre, reporting/snapshots, configuration and administration.
6. Implement finance-aware views only with explicit authorization checks; implement exports.
7. Run CI, browser, RLS positive/negative, workflow and regression tests before calling the first release ready.

## Key repository references
- UI baseline: `docs/UI_REVIEW_ROUND_1_2026-11-22.md`
- Architecture: `docs/architecture/ARCHITECTURE.md`
- Requirements: `docs/requirements/PRD.md`
- Previous checkpoint: `docs/PROJECT_CHECKPOINT_2026-11-22.md`

## Update — 24 November 2026

### GitHub CI verification
- Inspected the actual latest Frontend CI workflow run on `main`: run #6, ID `45157537682`, commit `f998019adb09947e2444d61a49f08440fb0ba54d`.
- The run completed with failure in the single `validate` job at the `Setup Node.js` step.
- The actionable log error was: dependency lock file not found. The workflow had `cache: npm` configured, but the repository has no `package-lock.json`, `npm-shrinkwrap.json`, or `yarn.lock`.
- The install, TypeScript type-check, and production build steps were skipped. Neither TypeScript nor build has been verified as passing.
- Corrected the workflow by removing npm caching until a committed lockfile is available. A new run must verify both actual check steps.
- CI run: https://github.com/mohmattar-GH/PMO-Dashboard-/actions/runs/45157537682

### Documentation reconciliation
- README now reflects the actual initial frontend implementation and explicitly identifies unfinished operational modules.
- README and checkpoint distinguish the database foundation from populated, authorized, end-to-end-tested application workflows.

### Current next steps
1. Verify the next completed Frontend CI run, including actual type-check and production-build results.
2. Generate and commit a reproducible npm lockfile before restoring npm cache.
3. Implement Projects Register and Project Workspace using existing backend contracts and RLS-safe server access.
4. Complete secure platform-admin provisioning and role/membership tests before populating production data.
5. Continue with schedule, milestones, deliverables, Change Requests, notifications, reporting, configuration, and administration.
6. Do not deploy production without explicit approval.
