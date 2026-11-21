import { useState } from "react";
import { Settings2, SlidersHorizontal, ShieldAlert } from "lucide-react";
import LifecycleConfiguration from "./LifecycleConfiguration";
import ReportingConfiguration from "./ReportingConfiguration";

export default function ConfigurationCenter({ globalRoles }: { globalRoles: string[] }) {
  const isPlatformAdmin = globalRoles.includes("platform_admin");
  const canManageReporting = isPlatformAdmin || globalRoles.includes("configuration_steward") || globalRoles.includes("configuration_approver");
  const [tab, setTab] = useState<"lifecycle" | "reporting">(isPlatformAdmin ? "lifecycle" : "reporting");

  if (!isPlatformAdmin && !canManageReporting) return <section className="panel configuration-access-denied"><ShieldAlert size={24}/><strong>Configuration access is restricted</strong><span>Contact a Platform Administrator to request the appropriate configuration role.</span></section>;

  return <div className="configuration-center">
    <div className="configuration-center-tabs">
      {isPlatformAdmin && <button className={tab === "lifecycle" ? "active" : ""} onClick={() => setTab("lifecycle")}><Settings2 size={14}/> Lifecycle configuration</button>}
      {canManageReporting && <button className={tab === "reporting" ? "active" : ""} onClick={() => setTab("reporting")}><SlidersHorizontal size={14}/> Reporting rules & KPIs</button>}
    </div>
    {tab === "lifecycle" && isPlatformAdmin ? <LifecycleConfiguration isPlatformAdmin={isPlatformAdmin}/> : tab === "reporting" && canManageReporting ? <ReportingConfiguration globalRoles={globalRoles}/> : <ReportingConfiguration globalRoles={globalRoles}/>}
  </div>;
}
