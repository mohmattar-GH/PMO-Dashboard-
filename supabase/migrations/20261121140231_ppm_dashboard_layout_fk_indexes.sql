create index ppm_dashboard_layout_history_changed_by_idx
  on public.ppm_dashboard_layout_history(changed_by)
  where changed_by is not null;

create index ppm_dashboard_layouts_created_by_idx
  on public.ppm_dashboard_layouts(created_by)
  where created_by is not null;

create index ppm_dashboard_layouts_updated_by_idx
  on public.ppm_dashboard_layouts(updated_by)
  where updated_by is not null;
