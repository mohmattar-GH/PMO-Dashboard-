do $$
declare d text;
begin
 d:=pg_get_functiondef('private.kpi_source_has_post_cutoff_changes_v1(uuid,text,timestamptz)'::regprocedure);
 d:=replace(d,
 $a$when 'payment_allocations' then
   select exists(select 1 from public.invoice_payment_allocations t where t.project_id=p_project_id and t.created_at<=p_cutoff and t.reversed_at<=p_cutoff) into v_changed;$a$,
 $b$when 'payment_allocations' then v_changed:=false;$b$);
 if position('when ''payment_allocations'' then v_changed:=false' in d)=0 then raise exception 'Payment allocation cutoff correction failed'; end if;
 execute d;
end $$;