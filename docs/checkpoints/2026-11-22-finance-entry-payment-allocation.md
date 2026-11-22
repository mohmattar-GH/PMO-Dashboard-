# Finance Entry and Payment Allocation Checkpoint — 22 November 2026

## Repository and environment
- Repository: `mohmattar-GH/PMO-Dashboard-`
- Branch: `feature/ppm-frontend-foundation`
- Pull request: #1 — draft, unmerged
- Supabase: `Executive PPM Platform` (`oihawkpbtgqxxliaamxs`), eu-central-1
- Live migration ledger: 112 applied migrations
- Separate Staff Time & Performance repository and Supabase project remain untouched

## Completed in this slice
- Added `src/ProjectPaymentsEditor.tsx` and connected it to the Project Profile Payments tab.
- Finance users (project Finance, Finance Administrator or Platform Administrator) can register invoices with contract link, type, status, issue/submission/due dates, currency, subtotal, tax, retention and calculated total.
- Finance users can register cash transactions with type, status, date, currency, amount, counterparty, bank reference and notes.
- Finance users can allocate confirmed payment or credit-note transactions to standard invoices, with a mandatory allocation reason.
- Allocation UI filters to standard invoices and confirmed eligible cash transactions; it checks same-currency before submission.
- Database triggers remain the final integrity boundary: they enforce Finance authorization, same-project and same-currency matching, confirmed transaction type, available invoice and cash balances, immutable financial source values while allocations are active, and one-way allocation reversal rules.
- Invoice outstanding amounts continue to be read from the database balance view; the UI does not calculate or override allocations locally.
- Existing RLS remains authoritative. No database schema or policy changes were made in this slice.

## Verification
- The branch head before this slice passed:
  - Frontend build run 656.
  - Clean migration replay run 310.
- New frontend build run 660 and migration replay run 312 were triggered by this slice and were still running at the time this checkpoint was written. Do not treat them as passed until GitHub reports successful conclusions.
- Live database contains 112 applied migrations and no Auth users or project fixtures. Authenticated Finance role and allocation journeys cannot yet be exercised against real test records.
- The database migration replay workflow is configured to rebuild an isolated local Supabase stack and apply all archived migrations from scratch.

## Remaining release gates
1. Confirm frontend build run 660 and clean migration replay run 312 succeed.
2. Provision controlled test identities and isolated project fixtures; then run Finance, PM, Team Lead, Platform Admin and Executive Viewer signed-JWT tests.
3. Browser-test invoice creation, cash transaction creation, same-currency allocation, over-allocation rejection, and allocation reversal.
4. Continue remaining general project-profile editing and any separately approved dashboard/notification enhancements.

## Boundaries
- PR #1 remains draft and unmerged. No deployment.
- No changes to the Staff Time & Performance application.
