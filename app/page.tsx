import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import DashboardShell, { type DashboardData } from "@/components/dashboard-shell";

async function loadDashboard(supabase: Awaited<ReturnType<typeof createClient>>, userId: string): Promise<DashboardData> {
  const now = new Date().toISOString();
  const [profileResult, rolesResult, projectsResult, milestonesResult, crResult, deliverablesResult, notificationsResult, snapshotsResult] = await Promise.all([
    supabase.from("user_profiles").select("display_name,is_active").eq("user_id", userId).maybeSingle(),
    supabase.from("user_global_role_assignments").select("role_code,status,effective_from,effective_to").eq("user_id", userId).eq("status", "active").lte("effective_from", now),
    supabase.from("projects").select("id,project_code,name,lifecycle_status,start_date,target_end_date").order("updated_at", { ascending: false }).limit(8),
    supabase.from("project_milestones").select("id", { count: "exact", head: true }),
    supabase.from("project_change_requests").select("id", { count: "exact", head: true }).not("status", "in", '("closed","cancelled","rejected")'),
    supabase.from("contract_deliverables").select("id", { count: "exact", head: true }).neq("acceptance_status", "accepted"),
    supabase.from("ppm_user_notifications").select("id", { count: "exact", head: true }).eq("recipient_user_id", userId).eq("is_read", false),
    supabase.from("portfolio_snapshots").select("id,generated_at,snapshot_status").order("generated_at", { ascending: false }).limit(1).maybeSingle()
  ]);

  const activeRoles = (rolesResult.data ?? []).filter(role => !role.effective_to || role.effective_to > now).map(role => role.role_code);
  const hasPlatformAccess = activeRoles.length > 0 || Boolean(profileResult.data?.is_active);
  return {
    profileName: profileResult.data?.display_name ?? null,
    profilePending: !profileResult.data,
    activeRoles,
    hasPlatformAccess,
    projects: projectsResult.data ?? [],
    projectsError: Boolean(projectsResult.error),
    counts: {
      projects: projectsResult.error ? null : projectsResult.data?.length ?? 0,
      milestones: milestonesResult.error ? null : milestonesResult.count ?? 0,
      changeRequests: crResult.error ? null : crResult.count ?? 0,
      deliverables: deliverablesResult.error ? null : deliverablesResult.count ?? 0,
      unreadNotifications: notificationsResult.error ? null : notificationsResult.count ?? 0
    },
    latestSnapshot: snapshotsResult.data ?? null
  };
}

export default async function HomePage() {
  const supabase = await createClient();
  const { data, error } = await supabase.auth.getClaims();
  if (error || !data?.claims?.sub) redirect("/login");
  const email = typeof data.claims.email === "string" ? data.claims.email : "Authorized user";
  const dashboard = await loadDashboard(supabase, data.claims.sub);
  return <DashboardShell email={email} data={dashboard} />;
}
