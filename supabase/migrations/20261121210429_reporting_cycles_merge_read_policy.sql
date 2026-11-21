begin;
drop policy if exists reporting_cycles_read_authorized on public.reporting_cycles;
drop policy if exists reporting_cycles_read_platform_admin on public.reporting_cycles;

create policy reporting_cycles_read_authorized
on public.reporting_cycles
for select
to authenticated
using (
  exists (
    select 1
    from public.user_global_role_assignments ura
    where ura.user_id = (select auth.uid())
      and ura.role_code in ('platform_admin', 'executive_viewer')
      and ura.status = 'active'
      and ura.effective_from <= now()
      and (ura.effective_to is null or ura.effective_to > now())
      and (
        ura.role_code = 'platform_admin'
        or exists (
          select 1
          from public.portfolio_snapshots ps
          where ps.reporting_cycle_id = reporting_cycles.id
        )
      )
  )
);
commit;
