/* eslint-disable @typescript-eslint/no-explicit-any */
"use client";

import { useMemo, useState } from "react";

export type DashboardData = {
  profileName: string | null;
  profilePending: boolean;
  activeRoles: string[];
  hasPlatformAccess: boolean;
  projects: { id: string; project_code: string; name: string; lifecycle_status: string; start_date: string | null; target_end_date: string | null }[];
  projectsError: boolean;
  counts: { projects: number | null; milestones: number | null; changeRequests: number | null; deliverables: number | null; unreadNotifications: number | null };
  latestSnapshot: { id: string; generated_at: string; snapshot_status: string } | null;
};

const navigation = [
  { group: "WORKSPACE", items: [["Executive Overview", "◫"], ["Portfolio", "▦"], ["Projects Register", "▤"]] },
  { group: "DELIVERY CONTROL", items: [["Master Schedule", "⌁"], ["Payments & Risk Timeline", "⌗"], ["Change Requests", "↗"], ["Deliverables", "▧"], ["Milestones", "◆"]] },
  { group: "GOVERNANCE", items: [["Notification Centre", "♧"], ["Reports & Snapshots", "▥"], ["Configuration", "⚙"], ["Administration", "⌘"]] }
] as const;

const descriptions: Record<string, string> = {
  "Executive Overview": "A decision-ready view of portfolio performance, exceptions and management attention.",
  Portfolio: "Compare project health, delivery confidence and lifecycle distribution across the portfolio.",
  "Projects Register": "The controlled register of projects and their accountable owners.",
  "Master Schedule": "A consolidated timeline of activities, milestones and configured schedule layers.",
  "Payments & Risk Timeline": "A time-based view of financial events and risk exposure.",
  "Change Requests": "Assess, route, approve and track controlled changes to project commitments.",
  Deliverables: "Track submissions, reviews, resubmissions and explicit Project Manager acceptance.",
  Milestones: "Monitor milestone commitments, forecast dates and governed baseline changes.",
  "Notification Centre": "Review assigned notifications, required acknowledgements and escalations.",
  "Reports & Snapshots": "Access reporting cycles, immutable weekly snapshots and management exports.",
  Configuration: "Manage versioned reporting rules, KPI definitions, workflows and thresholds.",
  Administration: "Manage users, roles, access grants and platform-level controls."
};

function MetricCard({ label, value, note }: { label: string; value: number | null; note: string }) {
  return <article className="metric-card">
    <span className="metric-label">{label}</span>
    <strong className={value === null ? "metric-value unavailable" : "metric-value"}>{value === null ? "—" : value}</strong>
    <span className="metric-note">{note}</span>
  </article>;
}

export default function DashboardShell({ email, data }: { email: string; data: DashboardData }) {
  const [active, setActive] = useState("Executive Overview");
  const initials = useMemo(() => email.slice(0, 1).toUpperCase(), [email]);
  const snapshotDate = data.latestSnapshot ? new Date(data.latestSnapshot.generated_at).toLocaleDateString() : null;

  return <div className="app-frame">
    <aside className="sidebar">
      <div className="sidebar-brand"><div className="brand-mark small">P</div><div><strong>PMO<span> / </span>COMMAND</strong><small>EXECUTIVE PORTFOLIO</small></div></div>
      <div className="workspace-switch"><span className="workspace-icon">◎</span><span><small>WORKSPACE</small><strong>Executive Portfolio</strong></span><span className="chevron">⌄</span></div>
      <nav className="primary-nav" aria-label="Primary navigation">
        {navigation.map(section => <div className="nav-section" key={section.group}><p className="nav-group-label">{section.group}</p>
          {section.items.map(([label, icon]) => <button key={label} className={active === label ? "nav-item active" : "nav-item"} onClick={() => setActive(label)} aria-current={active === label ? "page" : undefined}>
            <span className="nav-icon">{icon}</span><span>{label}</span>{label === "Notification Centre" && data.counts.unreadNotifications !== null && data.counts.unreadNotifications > 0 && <i className="nav-dot" />}
          </button>)}
        </div>)}
      </nav>
      <div className="sidebar-bottom"><div className="system-status"><span className="status-indicator" />Supabase connected</div><div className="sidebar-version">PMO PLATFORM <span>v0.1 · FIRST RELEASE</span></div></div>
    </aside>

    <main className="main-area">
      <header className="topbar">
        <div className="breadcrumbs"><span>PMO Workspace</span><b>/</b><strong>{active}</strong></div>
        <div className="topbar-actions"><button className="icon-button" aria-label="Search" title="Search">⌕</button><button className="icon-button notification-button" aria-label="Notifications" title="Notifications">♧</button>
          <div className="profile-chip"><span className="avatar">{initials}</span><span className="profile-email">{data.profileName ?? email}</span></div>
          <form action="/auth/signout" method="post"><button className="signout-button" type="submit">Sign out</button></form>
        </div>
      </header>

      <div className="page-content">
        <div className="page-heading"><div><div className="eyebrow">PORTFOLIO INTELLIGENCE <span className="heading-divider">/</span> WEEKLY CONTROL</div><h1>{active}</h1><p>{descriptions[active]}</p></div>
          <div className="heading-meta"><span className="live-label"><i /> LIVE WORKSPACE</span><span className="as-of">Reporting snapshot <strong>{snapshotDate ?? "Not yet generated"}</strong></span></div>
        </div>
        {!data.hasPlatformAccess && <section className="setup-alert"><strong>Account access setup is incomplete.</strong><span>Your sign-in is valid, but no active PMO role/profile is assigned. A platform administrator must provision your user profile and role before project data becomes available. This is an access-control requirement, not a dashboard data issue.</span></section>}
        {active === "Executive Overview" ? <Overview data={data} /> : <SectionPlaceholder title={active} />}
        <footer className="page-footer"><span>EXECUTIVE PPM PLATFORM</span><span>Data visibility is governed by assigned role and project access.</span></footer>
      </div>
    </main>
  </div>;
}

function Overview({ data }: { data: DashboardData }) {
  return <>
    <section className="reporting-strip">
      <div><span className="strip-label">REPORTING PERIOD</span><strong>Current portfolio</strong><small>Weekly executive review</small></div>
      <div><span className="strip-label">SNAPSHOT STATUS</span><strong className="status-muted">{data.latestSnapshot?.snapshot_status ?? "Not generated"}</strong><small>{data.latestSnapshot ? "Latest finalized portfolio snapshot" : "No historical reporting cycle is available yet"}</small></div>
      <div><span className="strip-label">PORTFOLIO COVERAGE</span><strong>{data.counts.projects === null ? "Unavailable" : data.counts.projects + " projects loaded"}</strong><small>{data.projectsError ? "Project register query needs attention" : "Based on records visible to your account"}</small></div>
      <div className="strip-action"><button className="secondary-button" disabled title="Available after reporting cycles are configured">View snapshots <span>↗</span></button></div>
    </section>

    <div className="section-heading"><div><span className="section-kicker">01 / PERFORMANCE AT A GLANCE</span><h2>Portfolio indicators</h2></div><span className="section-context">Live data · Role-filtered</span></div>
    <section className="metric-grid">
      <MetricCard label="Projects in register" value={data.counts.projects} note="Visible project records" />
      <MetricCard label="Milestones" value={data.counts.milestones} note="Visible milestone records" />
      <MetricCard label="Open change requests" value={data.counts.changeRequests} note="Not closed, cancelled or rejected" />
      <MetricCard label="Deliverables not accepted" value={data.counts.deliverables} note="PM acceptance is explicit" />
      <MetricCard label="Unread notifications" value={data.counts.unreadNotifications} note="Assigned to your account" />
    </section>

    <div className="overview-grid">
      <section className="panel phase-panel"><div className="panel-heading"><div><span className="section-kicker">02 / LIFECYCLE</span><h2>Project phase distribution</h2></div><span className="panel-menu">···</span></div>
        <div className="empty-chart"><div className="empty-ring"><div><strong>{data.counts.projects ?? "—"}</strong><span>PROJECTS</span></div></div><div className="empty-copy"><strong>{data.counts.projects ? "Phase breakdown is next" : "No visible project data"}</strong><p>Project phase distribution will populate from the configured lifecycle and project register. Phase names and lifecycle rules remain administrator-configurable.</p></div></div>
        <div className="panel-footnote">Source: Project Register · Lifecycle configuration</div>
      </section>

      <section className="panel attention-panel"><div className="panel-heading"><div><span className="section-kicker">03 / MANAGEMENT ATTENTION</span><h2>Items requiring attention</h2></div><span className="attention-count">{data.counts.unreadNotifications ?? "—"}</span></div>
        <div className="attention-empty"><div className="attention-icon">i</div><div><strong>Attention feed is being connected</strong><p>Notifications and escalations will appear here after their event and recipient rules are fully wired.</p></div></div>
        <div className="panel-footnote">No items does not imply that project health is Green.</div>
      </section>

      <section className="panel wide-panel"><div className="panel-heading"><div><span className="section-kicker">04 / DELIVERY CONFIDENCE</span><h2>Projects register</h2></div><span className="panel-menu">···</span></div>
        <div className="empty-table">
          <div className="empty-table-head"><span>PROJECT</span><span>CODE</span><span>STATUS</span><span>TARGET END</span></div>
          {data.projects.length ? data.projects.map(project => <div className="project-table-row" key={project.id}><strong>{project.name}</strong><span>{project.project_code}</span><span>{project.lifecycle_status}</span><span>{project.target_end_date ?? "Not set"}</span></div>) : <div className="empty-table-body"><strong>{data.projectsError ? "Project data is unavailable" : "No project records are visible"}</strong><span>Once a project is registered and your account is authorized, it will appear here. Missing data is not classified as Green.</span></div>}
        </div>
        <div className="panel-footnote">Project visibility is restricted by project membership and global role.</div>
      </section>

      <section className="panel phase-changes-panel"><div className="panel-heading"><div><span className="section-kicker">05 / LIFECYCLE MOVEMENT</span><h2>Recent phase changes</h2></div><span className="panel-menu">···</span></div>
        <div className="timeline-empty"><span className="timeline-line" /><div><strong>Phase history feed pending</strong><p>Approved lifecycle transitions will be listed with actor, date and audit context.</p></div></div>
        <div className="panel-footnote">Source: Project phase history</div>
      </section>
    </div>
    <section className="governance-note"><span className="governance-icon">i</span><p><strong>Reporting integrity is active.</strong> KPI values, status thresholds and health classifications will be calculated from approved configuration versions. Empty or incomplete source data will never be silently treated as a positive status.</p></section>
  </>;
}

function SectionPlaceholder({ title }: { title: string }) {
  return <section className="module-placeholder"><div className="module-icon">⌘</div><span className="section-kicker">FIRST RELEASE · MODULE FOUNDATION</span><h2>{title}</h2>
    <p>This module is included in the approved first-release scope. Its data views and governed actions are being connected to the existing Supabase workflows.</p>
    <div className="module-status"><span className="status-indicator" />Navigation and workspace shell available <span className="module-separator">·</span> Operational module pending</div>
  </section>;
}
