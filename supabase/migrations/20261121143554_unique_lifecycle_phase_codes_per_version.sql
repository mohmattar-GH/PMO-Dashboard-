alter table public.project_lifecycle_phases
  add constraint project_lifecycle_phases_version_id_phase_code_key
  unique (version_id, phase_code);
