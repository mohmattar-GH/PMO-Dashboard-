begin;
do $patch$
declare d text;
begin
 d:=pg_get_functiondef('private.calculate_project_snapshot_kpis_v1(uuid)'::regprocedure);
 d:=regexp_replace(d,E',\\n  ''calculated_health_reason'',''Overall health aggregation requires[^'']*''','');
 d:=regexp_replace(d,E',\\n \\)','' || E'\n )');
 if position('Overall health aggregation requires' in d)>0 then
  raise exception 'Stale hard-coded health reason remains';
 end if;
 execute d;
end;
$patch$;
commit;