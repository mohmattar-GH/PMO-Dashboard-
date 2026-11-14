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
  const keyName = Object.keys(keys).find((key) => key === "default") ?? Object.keys(keys)[0];
  if (!keyName) throw new Error("Server secret key is not configured");
  return keys[keyName];
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply({ error: "Method not allowed" }, 405);

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) return reply({ error: "Authentication required" }, 401);
    const body = await req.json();
    if (!body || typeof body !== "object" || Array.isArray(body)) {
      return reply({ error: "Request body must be a JSON object" }, 400);
    }

    const action = body.action;
    const reason = typeof body.reason === "string" ? body.reason.trim() : "";
    const actions = ["create_cycle", "close_cycle", "build_snapshot", "finalize_snapshot", "record_correction"];
    if (!actions.includes(action)) return reply({ error: "Unsupported weekly reporting action" }, 400);
    if (reason.length < 8 || reason.length > 1000) {
      return reply({ error: "A reason of 8–1000 characters is required" }, 400);
    }

    const url = Deno.env.get("SUPABASE_URL");
    if (!url) throw new Error("Supabase URL is not configured");
    const admin = createClient(url, secretKey(), { auth: { persistSession: false } });
    const token = authHeader.slice(7);
    const { data: authData, error: authError } = await admin.auth.getUser(token);
    if (authError || !authData.user) return reply({ error: "Invalid authentication token" }, 401);
    const actorId = authData.user.id;

    let rpc: string;
    let args: Record<string, unknown>;
    switch (action) {
      case "create_cycle":
        rpc = "create_reporting_cycle";
        args = {
          p_actor_user_id: actorId,
          p_cycle_code: body.cycle_code,
          p_period_start: body.period_start,
          p_period_end: body.period_end,
          p_cutoff_at: body.cutoff_at,
          p_as_of_date: body.as_of_date,
          p_timezone: body.timezone,
          p_reason: reason,
        };
        break;
      case "close_cycle":
        rpc = "close_reporting_cycle";
        args = { p_actor_user_id: actorId, p_reporting_cycle_id: body.reporting_cycle_id, p_reason: reason };
        break;
      case "build_snapshot":
        rpc = "build_weekly_portfolio_snapshot";
        args = { p_reporting_cycle_id: body.reporting_cycle_id, p_actor_user_id: actorId };
        break;
      case "finalize_snapshot":
        rpc = "finalize_weekly_portfolio_snapshot";
        args = { p_portfolio_snapshot_id: body.portfolio_snapshot_id, p_actor_user_id: actorId };
        break;
      default:
        rpc = "record_snapshot_correction";
        args = {
          p_actor_user_id: actorId,
          p_original_snapshot_id: body.original_snapshot_id,
          p_replacement_snapshot_id: body.replacement_snapshot_id,
          p_reason: reason,
        };
    }

    const { data, error } = await admin.rpc(rpc, args);
    if (error) {
      const message = error.message || "Weekly reporting request failed";
      const status = message.startsWith("Forbidden:") ? 403
        : message.includes("not found") ? 404
        : message.includes("already exists") || message.includes("Only ") || message.includes("must remain") ? 409
        : 400;
      return reply({ error: message }, status);
    }
    return reply(data ?? { success: true });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unexpected server error";
    return reply({ error: message }, 400);
  }
});
