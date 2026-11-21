create index project_custom_timeline_events_project_id_idx
  on public.project_custom_timeline_events(project_id);

create index project_custom_timeline_events_created_by_idx
  on public.project_custom_timeline_events(created_by);

create index project_custom_timeline_events_updated_by_idx
  on public.project_custom_timeline_events(updated_by);
