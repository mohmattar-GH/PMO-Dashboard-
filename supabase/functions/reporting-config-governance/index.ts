import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function reply(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

function secretKey(): string {
  const legacy = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (legacy) return legacy;
  const keys = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") ?? "{}");
  const keyName = Object.keys(keys).find((k) => k === "default") ?? Object.keys(keys)[0];
  if (!keyName) throw new Error("Server secret key is not configured");
  return keys[keyName];
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply({ error: "Method not allowed" }, 405);

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) return reply({ error: "Authentication required" }, 401);
    const token = authHeader.slice(7);
    const url = Deno.env.get("SUPABASE_URL");
    if (!url) throw new Error("Supabase URL is not configured");

    const admin = createClient(url, secretKey(), { auth: { persistSession: false } });
    const { data: authData, error: authError } = await admin.auth.getUser(token);
    if (authError || !authData.user) return reply({ error: "Invalid authentication token" }, 401);
    const actor = authData.user.id;

    const { data: roles, error: roleError } = await admin
      .from("user_global_role_assignments")
      .select("role_code,status,effective_from,effective_to")
      .eq("user_id", actor).eq("status", "active");
    if (roleError) throw roleError;
    const now = Date.now();
    const activeRoles = new Set((roles ?? []).filter((r) =>
      new Date(r.effective_from).getTime() <= now &&
      (!r.effective_to || new Date(r.effective_to).getTime() > now)
    ).map((r) => r.role_code));

    const body = await req.json();
    const action = body?.action;
    const reason = typeof body?.reason === "string" ? body.reason.trim() : "";
    if (!reason || reason.length < 8 || reason.length > 1000) {
      return reply({ error: "A reason of 8–1000 characters is required" }, 400);
    }

    const requireRole = (allowed: string[]) => {
      if (!allowed.some((r) => activeRoles.has(r))) throw new Error("Forbidden: insufficient configuration permissions");
    };
    const adminRoles = ["platform_admin"];
    const stewards = ["platform_admin", "configuration_steward"];
    const approvers = ["platform_admin", "configuration_approver"];

    const audit = async (setId: string, versionId: string | null, event: string, beforeData: unknown, afterData: unknown) => {
      const { error } = await admin.rpc("write_reporting_configuration_audit", {
        p_configuration_set_id: setId,
        p_configuration_version_id: versionId,
        p_actor_user_id: actor,
        p_action: event,
        p_reason: reason,
        p_before_data: beforeData ?? null,
        p_after_data: afterData ?? null,
      });
      if (error) throw error;
    };

    if (action === "create_draft") {
      requireRole(stewards);
      const scope = body.scope_type;
      if (!["global", "project"].includes(scope)) return reply({ error: "Invalid scope_type" }, 400);
      const setPayload: Record<string, unknown> = {
        scope_type: scope,
        project_id: scope === "project" ? body.project_id : null,
        configuration_code: String(body.configuration_code ?? "").trim(),
        name: String(body.name ?? "").trim(),
        description: body.description ?? null,
        created_by: actor,
      };
      if (!setPayload.configuration_code || !setPayload.name) return reply({ error: "configuration_code and name are required" }, 400);
      if (scope === "project") {
        if (!body.project_id) return reply({ error: "project_id is required for project scope" }, 400);
        const { data: membership, error: membershipError } = await admin.from("project_memberships")
          .select("id").eq("project_id", body.project_id).eq("user_id", actor).eq("status", "active").maybeSingle();
        if (membershipError) throw membershipError;
        if (!membership && !activeRoles.has("platform_admin")) return reply({ error: "No active membership for this project" }, 403);
      }
      let setId = body.configuration_set_id;
      if (!setId) {
        const { data, error } = await admin.from("reporting_configuration_sets").insert(setPayload).select("id").single();
        if (error) throw error;
        setId = data.id;
      } else {
        const { data, error } = await admin.from("reporting_configuration_sets").select("id,scope_type,project_id")
          .eq("id", setId).single();
        if (error || data.scope_type !== scope || (scope === "project" && data.project_id !== body.project_id)) {
          return reply({ error: "Configuration set not found or scope mismatch" }, 404);
        }
      }
      const { data: versions, error: versionsError } = await admin.from("reporting_configuration_versions")
        .select("version_number").eq("configuration_set_id", setId).order("version_number", { ascending: false }).limit(1);
      if (versionsError) throw versionsError;
      const nextVersion = (versions?.[0]?.version_number ?? 0) + 1;
      const { data: version, error: versionError } = await admin.from("reporting_configuration_versions").insert({
        configuration_set_id: setId,
        version_number: nextVersion,
        status: "draft",
        effective_from: body.effective_from ?? null,
        effective_to: body.effective_to ?? null,
        change_summary: reason,
        created_by: actor,
      }).select("id,configuration_set_id,version_number,status").single();
      if (versionError) throw versionError;
      await audit(setId, version.id, "draft_created", null, version);
      return reply({ configuration_set_id: setId, version });
    }

    const versionId = body.configuration_version_id;
    if (typeof versionId !== "string") return reply({ error: "configuration_version_id is required" }, 400);
    const { data: version, error: fetchError } = await admin.from("reporting_configuration_versions")
      .select("id,configuration_set_id,version_number,status,effective_from,effective_to")
      .eq("id", versionId).single();
    if (fetchError || !version) return reply({ error: "Configuration version not found" }, 404);
    const setId = version.configuration_set_id;

    if (action === "save_draft_rules") {
      requireRole(stewards);
      if (version.status !== "draft") return reply({ error: "Only draft versions can be edited" }, 409);
      const dimensions = Array.isArray(body.dimensions) ? body.dimensions : [];
      const kpis = Array.isArray(body.kpis) ? body.kpis : [];
      const parameters = Array.isArray(body.parameters) ? body.parameters : [];
      if (dimensions.length > 100 || kpis.length > 500 || parameters.length > 1000) return reply({ error: "Configuration payload exceeds limits" }, 400);
      for (const d of dimensions) {
        if (!d.dimension_code || !d.name || (d.weight != null && (Number(d.weight) < 0 || Number(d.weight) > 1))) return reply({ error: "Invalid dimension definition" }, 400);
      }
      for (const k of kpis) {
        if (!k.kpi_code || !k.name || !k.calculation_method || !k.formula_template) return reply({ error: "Invalid KPI definition" }, 400);
        if (k.weight != null && (Number(k.weight) < 0 || Number(k.weight) > 1)) return reply({ error: "KPI weight must be between 0 and 1" }, 400);
        if (!["weighted_sum", "ratio", "date_variance", "threshold_status", "count", "manual_input"].includes(k.calculation_method)) return reply({ error: "Calculation method is not allowlisted" }, 400);
      }
      const dimensionRows = dimensions.map((d: Record<string, unknown>) => ({
        configuration_version_id: versionId, dimension_code: d.dimension_code, name: d.name,
        description: d.description ?? null, display_order: d.display_order ?? 0, weight: d.weight ?? null,
        is_active: d.is_active ?? true, missing_data_status: d.missing_data_status ?? "not_reported",
      }));
      const { data: savedDimensions, error: dimError } = await admin.from("reporting_dimensions")
        .insert(dimensionRows).select("id,dimension_code");
      if (dimError) throw dimError;
      const dimensionIds = new Map((savedDimensions ?? []).map((d) => [d.dimension_code, d.id]));
      const kpiRows = kpis.map((k: Record<string, unknown>) => ({
        configuration_version_id: versionId,
        dimension_id: k.dimension_code ? dimensionIds.get(k.dimension_code) : null,
        kpi_code: k.kpi_code, name: k.name, description: k.description ?? null,
        calculation_method: k.calculation_method, formula_template: k.formula_template,
        source_mapping: k.source_mapping ?? {}, parameters: k.parameters ?? {}, unit: k.unit ?? null,
        weight: k.weight ?? null, is_active: k.is_active ?? true, display_order: k.display_order ?? 0,
      }));
      if (kpiRows.some((k: Record<string, unknown>) => k.dimension_id === undefined)) return reply({ error: "KPI references an unknown dimension_code" }, 400);
      if (kpiRows.length) {
        const { error } = await admin.from("kpi_definitions").insert(kpiRows);
        if (error) throw error;
      }
      const parameterRows = parameters.map((p: Record<string, unknown>) => ({
        configuration_version_id: versionId, rule_code: p.rule_code, parameter_code: p.parameter_code,
        parameter_value: p.parameter_value, value_type: p.value_type,
        description: p.description ?? null, validation_definition: p.validation_definition ?? {},
      }));
      if (parameterRows.length) {
        const { error } = await admin.from("reporting_rule_parameters").insert(parameterRows);
        if (error) throw error;
      }
      await audit(setId, versionId, "draft_rules_saved", null, {
        dimensions_count: dimensionRows.length, kpis_count: kpiRows.length, parameters_count: parameterRows.length,
      });
      return reply({ saved: true, dimensions: dimensionRows.length, kpis: kpiRows.length, parameters: parameterRows.length });
    }

    const transitions: Record<string, { from: string; to: string; roles: string[] }> = {
      submit: { from: "draft", to: "submitted", roles: stewards },
      approve: { from: "submitted", to: "approved", roles: approvers },
      publish: { from: "approved", to: "published", roles: approvers },
      supersede: { from: "published", to: "superseded", roles: approvers },
    };
    const transition = transitions[action];
    if (!transition) return reply({ error: "Unsupported action" }, 400);
    requireRole(transition.roles);
    if (version.status !== transition.from) return reply({ error: `Invalid transition: ${version.status} to ${transition.to}` }, 409);
    if (action === "publish") {
      if (!version.effective_from) return reply({ error: "effective_from is required before publication" }, 400);
      const { count, error } = await admin.from("reporting_dimensions").select("id", { count: "exact", head: true }).eq("configuration_version_id", versionId).eq("is_active", true);
      if (error) throw error;
      if (!count) return reply({ error: "At least one active reporting dimension is required" }, 400);
      const { count: pending, error: pendingError } = await admin.from("reporting_configuration_versions")
        .select("id", { count: "exact", head: true }).eq("configuration_set_id", setId).eq("status", "published");
      if (pendingError) throw pendingError;
      if ((pending ?? 0) > 0) return reply({ error: "Supersede the currently published version before publishing its replacement" }, 409);
    }
    const patch: Record<string, unknown> = { status: transition.to };
    if (action === "submit") { patch.submitted_by = actor; patch.submitted_at = new Date().toISOString(); }
    if (action === "approve") { patch.approved_by = actor; patch.approved_at = new Date().toISOString(); }
    if (action === "publish") { patch.published_by = actor; patch.published_at = new Date().toISOString(); }
    const { data: changed, error: updateError } = await admin.from("reporting_configuration_versions")
      .update(patch).eq("id", versionId).eq("status", transition.from)
      .select("id,configuration_set_id,version_number,status,effective_from,effective_to").single();
    if (updateError) throw updateError;
    await audit(setId, versionId, action, version, changed);
    return reply({ version: changed });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unexpected server error";
    const status = message.startsWith("Forbidden:") ? 403 : 400;
    return reply({ error: message }, status);
  }
});