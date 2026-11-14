-- Migration 005: private audit write RPC for trusted backend calls
begin;
create or replace function public.write_reporting_configuration_audit(
 p_configuration_set_id uuid,
 p_configuration_version_id uuid,
 p_actor_user_id uuid,
 p_action text,
 p_reason text,
 p_before_data jsonb,
 p_after_data jsonb
) returns uuid
language plpgsql security definer set search_path = ''
as $$
declare v_id uuid;
begin
 if auth.role() <> 'service_role' then raise exception 'Service role required'; end if;
 insert into private.reporting_configuration_audit(
  configuration_set_id,configuration_version_id,actor_user_id,action,reason,before_data,after_data
 ) values (
  p_configuration_set_id,p_configuration_version_id,p_actor_user_id,p_action,p_reason,p_before_data,p_after_data
 ) returning id into v_id;
 return v_id;
end;
$$;
revoke all on function public.write_reporting_configuration_audit(uuid,uuid,uuid,text,text,jsonb,jsonb) from public,anon,authenticated;
grant execute on function public.write_reporting_configuration_audit(uuid,uuid,uuid,text,text,jsonb,jsonb) to service_role;
commit;
