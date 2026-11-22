begin;

create policy reporting_cycles_read_platform_admin
on public.reporting_cycles
for select
to authenticated
using (
  exists (
    select 1
    from public.user_global_role_assignments ura
    where ura.user_id = (select auth.uid())
      and ura.role_code = 'platform_admin'
      and ura.status = 'active'
      and ura.effective_from <= now()
      and (ura.effective_to is null or ura.effective_to > now())
  )
);

commit;
