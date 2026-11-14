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
    if (!["create_draft", "save_draft_rules", "submit", "approve", "publish", "supersede"].includes(action)) {
      return reply({ error: "Unsupported configuration action" }, 400);
    }
    if (reason.length < 8 || reason.length > 1000) {
      return reply({ error: "A reason of 8–1000 characters is required" }, 400);
    }

    const url = Deno.env.get("SUPABASE_URL");
    if (!url) throw new Error("Supabase URL is not configured");
    const admin = createClient(url, secretKey(), { auth: { persistSession: false } });
    const token = authHeader.slice(7);
    const { data: authData, error: authError } = await admin.auth.getUser(token);
    if (authError || !authData.user) return reply({ error: "Invalid authentication token" }, 401);

    const { data, error } = await admin.rpc("manage_reporting_configuration", {
      p_actor_user_id: authData.user.id,
      p_action: action,
      p_payload: body,
      p_reason: reason,
    });
    if (error) {
      const message = error.message || "Configuration request failed";
      const status = message.startsWith("Forbidden:") ? 403
        : message.includes("not found") ? 404
        : message.includes("Invalid transition") || message.includes("concurrently") ? 409
        : 400;
      return reply({ error: message }, status);
    }
    return reply(data ?? { success: true });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unexpected server error";
    return reply({ error: message }, 400);
  }
});
