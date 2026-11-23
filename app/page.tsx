import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import DashboardShell from "@/components/dashboard-shell";

export default async function HomePage() {
  const supabase = await createClient();
  const { data, error } = await supabase.auth.getClaims();
  if (error || !data?.claims) redirect("/login");
  const email = typeof data.claims.email === "string" ? data.claims.email : "Authorized user";
  return <DashboardShell email={email} />;
}
