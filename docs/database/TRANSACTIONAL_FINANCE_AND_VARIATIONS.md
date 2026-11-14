# Transactional Finance and Contract Variation Workflows

## Deployment
- Supabase project: `oihawkpbtgqxxliaamxs`.
- Applied migrations: `20261114102719` (018), `20261114102819` (019), and `20261114102910` (020).
- Source migrations are in `supabase/migrations/` with matching version prefixes.

## Contract variation workflow
Table: `public.project_contract_variations`.

1. Project manager/platform administrator creates a draft variation.
2. Project manager submits the draft. Submission timestamp is set by the database clock.
3. Finance member, finance administrator or platform administrator approves/rejects with a reason of at least 8 characters.
4. Approval records actor and decision time; the decision is immutable.
5. Approved positive or negative amount deltas are summed and atomically reflected in `project_financial_terms.approved_variations`.
6. `revised_contract_value` remains the generated sum of original contract value plus approved variations.

Controls:
- Project and contract must match by composite foreign key.
- Variation currency must match project financial terms currency.
- Original contract value is immutable; approved variations are the only supported adjustment path.
- Aggregate cannot be manually changed; it must equal the sum of approved variation records.
- Currency cannot be changed after variation, invoice or cash records exist.
- Submitted/approved/rejected records cannot be edited outside the allowed one-way transition.
- Variation changes are audited in the private operational audit table.

## Invoice cash allocation workflow
RPCs:
- `public.allocate_invoice_cash(project_id, invoice_id, cash_transaction_id, amount, allocation_date, reason)`
- `public.reverse_invoice_cash_allocation(allocation_id, reason)`

Allocation rules:
- Authenticated project finance member, finance administrator or platform administrator only.
- Allocation amount must be positive; reason must contain at least 8 characters.
- Cash transaction must belong to the same project, be confirmed, and be a payment or credit note.
- Invoice must belong to the same project and be a standard invoice.
- Currency must match.
- Row locks serialize concurrent allocations against the invoice and cash transaction.
- Total active allocations cannot exceed invoice total or cash transaction amount.
- Only one active allocation per invoice/cash pair is permitted; a reversed allocation can be re-entered as a new allocation.
- Allocations cannot be edited. They can only be reversed with a reason and actor; the reversal remains audited.
- A trigger enforces the same rules for direct table writes, so the RPC is not the only integrity boundary.
- Invoice/cash financial identity fields cannot be changed while active allocations exist.

## Invoice balances
`public.project_invoice_balances` is a `security_invoker=true` view. It returns total, active applied amount, outstanding amount and settlement boolean. It respects underlying table RLS. It does not impose hard-coded workflow status labels; invoice status mapping remains configuration-governed.

## Security verification
- Both RPCs use SECURITY INVOKER and fixed empty search_path.
- EXECUTE is granted to authenticated only; anon execution is false.
- Allocation table has one UPDATE policy after duplicate policy cleanup.
- Contract variations have RLS enabled and three role-scoped policies.
- Invoice balance view uses security invoker.
- Operational audit triggers are present on variation and allocation records.
- Security Advisor: no findings.
- Health Advisor: no findings.
- Performance Advisor: no unindexed foreign keys or multiple-permissive-policy findings after migration 019. Remaining findings are INFO-level unused indexes because the project has no representative workload.

## Known limits / not yet tested
- The project has zero Auth users and zero project records, so positive/negative JWT authorization tests and real invoice/variation lifecycle tests cannot yet be performed.
- No UI or Edge Function wrapper has been implemented for these finance RPCs; frontend must call the RPCs with authenticated user sessions.
- Cash transactions can be recorded, but no bank reconciliation/import workflow exists.
- Tax, retention and invoice status calculations remain configurable business rules and are not inferred here.
- Approved variation is reflected in project financial terms; no full change-request, deliverable impact, schedule impact or re-baseline workflow exists yet.
- Cross-currency conversions are intentionally not supported; currencies must match.
