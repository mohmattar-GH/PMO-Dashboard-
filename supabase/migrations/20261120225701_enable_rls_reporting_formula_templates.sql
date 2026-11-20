-- Defense-in-depth: keep the internal formula template table inaccessible to client roles.
-- No client policies are added: private schema USAGE and table SELECT are not granted
-- to anon/authenticated. Server-side service_role retains its existing SELECT grant.
ALTER TABLE private.reporting_formula_templates ENABLE ROW LEVEL SECURITY;
