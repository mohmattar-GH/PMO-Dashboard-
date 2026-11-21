import { useCallback, useEffect, useMemo, useState } from "react";
import { Archive, CalendarDays, Filter, Pencil, Plus, Search, SlidersHorizontal, X } from "lucide-react";
import { supabase } from "./lib/supabase";

type Project = { id: string; project_code: string; name: string };
type TimelineEvent = {
  event_id: string; project_id: string; source_entity_type: string; source_record_id: string;
  event_category: string; event_name: string; event_start_date: string | null; event_end_date: string | null;
  date_basis: string; record_status: string | null; severity: string | null; amount: number | null;
  currency_code: string | null; owner_user_id: string | null; source_reference: string | null;
  metadata: Record<string, unknown> | null;
};
type CustomEventForm = {
  project_id: string; event_code: string; event_name: string; event_description: string; event_subtype: string;
  start_date: string; end_date: string; date_basis: string; status: string; severity: string;
};
const categories = ["activity", "milestone", "contract", "license", "management_decision", "custom_event"];
const basisOptions = ["baseline", "approved_revised", "forecast", "actual", "contractual"];
const emptyForm: CustomEventForm = { project_id: "", event_code: "", event_name: "", event_description: "", event_subtype: "", start_date: "", end_date: "", date_basis: "forecast", status: "planned", severity: "" };
const label = (value: string | null | undefined) => value ? value.replace(/_/g, " ").replace(/\b\w/g, (letter) => letter.toUpperCase()) : "Not Reported";
const dateLabel = (value: string | null) => value ? new Intl.DateTimeFormat(undefined, { dateStyle: "medium" }).format(new Date(value + (value.length === 10 ? "T00:00:00" : ""))) : "Not Reported";

export default function MasterSchedule({ isPlatformAdmin }: { isPlatformAdmin: boolean }) {
  const [events, setEvents] = useState<TimelineEvent[]>([]);
  const [projects, setProjects] = useState<Project[]>([]);
  const [pmProjectIds, setPmProjectIds] = useState<string[]>([]);
  const [currentUserId, setCurrentUserId] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [busy, setBusy] = useState(false);
  const [query, setQuery] = useState("");
  const [projectFilter, setProjectFilter] = useState("all");
  const [basisFilter, setBasisFilter] = useState("all");
  const [selectedCategories, setSelectedCategories] = useState<string[]>([]);
  const [fromDate, setFromDate] = useState("");
  const [toDate, setToDate] = useState("");
  const [showCustomForm, setShowCustomForm] = useState(false);
  const [editingEventId, setEditingEventId] = useState<string | null>(null);
  const [customForm, setCustomForm] = useState<CustomEventForm>(emptyForm);

  const loadData = useCallback(async () => {
    if (!supabase) { setError("Supabase client is not configured."); setLoading(false); return; }
    setLoading(true); setError("");
    const [{ data: userData }, eventResult, projectResult] = await Promise.all([
      supabase.auth.getUser(),
      supabase.from("project_master_schedule_timeline").select("event_id,project_id,source_entity_type,source_record_id,event_category,event_name,event_start_date,event_end_date,date_basis,record_status,severity,amount,currency_code,owner_user_id,source_reference,metadata").order("event_start_date", { ascending: true }).limit(2000),
      supabase.from("projects").select("id,project_code,name").order("project_code")
    ]);
    const userId = userData.user?.id ?? "";
    setCurrentUserId(userId);
    const pmResult = userId ? await supabase.from("project_memberships").select("project_id").eq("user_id", userId).eq("project_role", "project_manager").eq("status", "active").lte("effective_from", new Date().toISOString()).or("effective_to.is.null,effective_to.gt." + new Date().toISOString()) : { data: [], error: null };
    setPmProjectIds([...new Set((pmResult.data ?? []).map((row: { project_id: string }) => row.project_id))]);
    if (eventResult.error) setError(eventResult.error.message);
    else setEvents((eventResult.data ?? []) as TimelineEvent[]);
    if (projectResult.error) setError((current) => current ? current + " · " + projectResult.error!.message : projectResult.error!.message);
    setProjects((projectResult.data ?? []) as Project[]);
    setLoading(false);
  }, []);

  useEffect(() => { void loadData(); }, [loadData]);

  const availableCategories = [...new Set([...categories, ...events.map((event) => event.event_category)])].sort();
  const filtered = useMemo(() => events.filter((event) => {
    const eventStart = event.event_start_date ?? event.event_end_date;
    const eventEnd = event.event_end_date ?? event.event_start_date;
    const datePass = (!fromDate || !eventEnd || eventEnd >= fromDate) && (!toDate || !eventStart || eventStart <= toDate);
    const projectPass = projectFilter === "all" || event.project_id === projectFilter;
    const basisPass = basisFilter === "all" || event.date_basis === basisFilter;
    const categoryPass = selectedCategories.length === 0 || selectedCategories.includes(event.event_category);
    const text = [event.event_name, event.source_reference, event.source_entity_type, projects.find((project) => project.id === event.project_id)?.name ?? ""].join(" ").toLowerCase();
    return datePass && projectPass && basisPass && categoryPass && text.includes(query.trim().toLowerCase());
  }), [events, projects, projectFilter, basisFilter, selectedCategories, fromDate, toDate, query]);

  const grouped = useMemo(() => {
    const map = new Map<string, TimelineEvent[]>();
    for (const event of filtered) {
      const date = event.event_start_date ?? event.event_end_date;
      const month = date ? date.slice(0, 7) : "undated";
      map.set(month, [...(map.get(month) ?? []), event]);
    }
    return [...map.entries()];
  }, [filtered]);

  const projectLabel = (id: string) => {
    const project = projects.find((item) => item.id === id);
    return project ? project.project_code + " · " + project.name : "Project not available";
  };
  const canManageProject = (projectId: string) => isPlatformAdmin || pmProjectIds.includes(projectId);
  const canAddCustomEvent = isPlatformAdmin || pmProjectIds.length > 0;
  const allowedProjects = isPlatformAdmin ? projects : projects.filter((project) => pmProjectIds.includes(project.id));
  const toggleCategory = (category: string) => setSelectedCategories((current) => {
    const next = current.length === 0 ? availableCategories.filter((item) => item !== category) : current.includes(category) ? current.filter((item) => item !== category) : [...current, category];
    return next.length === availableCategories.length ? [] : next;
  });

  const startNewCustomEvent = () => {
    setEditingEventId(null);
    setCustomForm({ ...emptyForm, project_id: allowedProjects[0]?.id ?? "" });
    setNotice("");
    setShowCustomForm(true);
  };
  const startEditCustomEvent = (event: TimelineEvent) => {
    setEditingEventId(event.source_record_id);
    setCustomForm({
      project_id: event.project_id, event_code: event.source_reference ?? "", event_name: event.event_name,
      event_description: String(event.metadata?.event_description ?? ""), event_subtype: String(event.metadata?.event_subtype ?? ""),
      start_date: event.event_start_date ?? "", end_date: event.event_end_date ?? "", date_basis: event.date_basis,
      status: event.record_status ?? "planned", severity: event.severity ?? ""
    });
    setNotice("");
    setShowCustomForm(true);
  };
  const saveCustomEvent = async () => {
    if (!supabase || !currentUserId) return;
    if (!customForm.project_id || !customForm.event_code.trim() || !customForm.event_name.trim() || (!customForm.start_date && !customForm.end_date)) {
      setNotice("Project, event code, event name and at least one date are required."); return;
    }
    if (customForm.start_date && customForm.end_date && customForm.start_date > customForm.end_date) {
      setNotice("Event start date cannot be later than the end date."); return;
    }
    setBusy(true); setNotice("");
    const payload = {
      project_id: customForm.project_id, event_code: customForm.event_code.trim(), event_name: customForm.event_name.trim(),
      event_description: customForm.event_description.trim() || null, event_subtype: customForm.event_subtype.trim() || null,
      start_date: customForm.start_date || null, end_date: customForm.end_date || null, date_basis: customForm.date_basis,
      status: customForm.status, severity: customForm.severity || null, updated_by: currentUserId
    };
    const result = editingEventId
      ? await supabase.from("project_custom_timeline_events").update(payload).eq("id", editingEventId).select("id").single()
      : await supabase.from("project_custom_timeline_events").insert({ ...payload, created_by: currentUserId }).select("id").single();
    if (result.error) setNotice("Custom event was not saved: " + result.error.message);
    else { setNotice(editingEventId ? "Custom event updated and versioned." : "Custom event created and added to the master schedule."); setShowCustomForm(false); setEditingEventId(null); await loadData(); }
    setBusy(false);
  };
  const archiveCustomEvent = async (event: TimelineEvent) => {
    if (!supabase || !currentUserId) return;
    setBusy(true); setNotice("");
    const { error: archiveError } = await supabase.from("project_custom_timeline_events").update({ is_active: false, updated_by: currentUserId }).eq("id", event.source_record_id);
    if (archiveError) setNotice("Custom event could not be archived: " + archiveError.message);
    else { setNotice("Custom event archived. Its audit history is retained."); await loadData(); }
    setBusy(false);
  };

  return <section className="timeline-module">
    <div className="timeline-module-heading"><div><span className="module-eyebrow">DELIVERY CONTROL</span><h2>Master Schedule Timeline</h2><p>Cross-project view of activities, milestones, contract dates, licenses, management decisions and custom events.</p></div><div className="timeline-heading-actions">{canAddCustomEvent && <button className="button-primary small" onClick={startNewCustomEvent}><Plus size={13}/> Add custom event</button>}<div className="timeline-live-label"><CalendarDays size={15}/> Live schedule records</div></div></div>
    {notice && <div className="timeline-security-note">{notice}</div>}
    {showCustomForm && <div className="panel custom-event-form"><div className="custom-event-form-heading"><div><strong>{editingEventId ? "Edit custom schedule event" : "Add custom schedule event"}</strong><small>Changes are versioned and visible in the master timeline.</small></div><button className="icon-button" onClick={() => setShowCustomForm(false)}><X size={16}/></button></div><div className="custom-event-form-grid">
      <label>Project<select value={customForm.project_id} onChange={(e) => setCustomForm((f) => ({ ...f, project_id: e.target.value }))}>{allowedProjects.map((project) => <option key={project.id} value={project.id}>{project.project_code} · {project.name}</option>)}</select></label>
      <label>Event code<input value={customForm.event_code} maxLength={50} disabled={Boolean(editingEventId)} onChange={(e) => setCustomForm((f) => ({ ...f, event_code: e.target.value.toUpperCase() }))} placeholder="e.g. UAT-START"/></label>
      <label className="wide">Event name<input value={customForm.event_name} maxLength={180} onChange={(e) => setCustomForm((f) => ({ ...f, event_name: e.target.value }))} placeholder="e.g. UAT commencement"/></label>
      <label>Event type / subtype<input value={customForm.event_subtype} maxLength={80} onChange={(e) => setCustomForm((f) => ({ ...f, event_subtype: e.target.value }))} placeholder="Deployment, review, workshop…"/></label>
      <label>Date basis<select value={customForm.date_basis} onChange={(e) => setCustomForm((f) => ({ ...f, date_basis: e.target.value }))}>{basisOptions.map((basis) => <option key={basis} value={basis}>{label(basis)}</option>)}</select></label>
      <label>Start date<input type="date" value={customForm.start_date} onChange={(e) => setCustomForm((f) => ({ ...f, start_date: e.target.value }))}/></label>
      <label>End date<input type="date" value={customForm.end_date} onChange={(e) => setCustomForm((f) => ({ ...f, end_date: e.target.value }))}/></label>
      <label>Status<select value={customForm.status} onChange={(e) => setCustomForm((f) => ({ ...f, status: e.target.value }))}><option value="planned">Planned</option><option value="in_progress">In Progress</option><option value="completed">Completed</option><option value="cancelled">Cancelled</option></select></label>
      <label>Severity<select value={customForm.severity} onChange={(e) => setCustomForm((f) => ({ ...f, severity: e.target.value }))}><option value="">Not applicable</option><option value="low">Low</option><option value="medium">Medium</option><option value="high">High</option><option value="critical">Critical</option></select></label>
      <label className="wide">Description<textarea value={customForm.event_description} onChange={(e) => setCustomForm((f) => ({ ...f, event_description: e.target.value }))} placeholder="Purpose, dependencies or expected outcome"/></label>
    </div><div className="custom-event-form-actions"><button className="button-secondary small" onClick={() => setShowCustomForm(false)}>Cancel</button><button className="button-primary small" disabled={busy} onClick={() => void saveCustomEvent()}>{busy ? "Saving…" : editingEventId ? "Save changes" : "Create event"}</button></div></div>}
    <div className="timeline-filter-panel panel">
      <div className="timeline-filter-row"><div className="timeline-search"><Search size={14}/><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search event, reference or project"/></div><select value={projectFilter} onChange={(event) => setProjectFilter(event.target.value)}><option value="all">All accessible projects</option>{projects.map((project) => <option key={project.id} value={project.id}>{project.project_code} · {project.name}</option>)}</select><select value={basisFilter} onChange={(event) => setBasisFilter(event.target.value)}><option value="all">All date bases</option>{basisOptions.map((basis) => <option key={basis} value={basis}>{label(basis)}</option>)}</select><label className="timeline-date-filter">From<input type="date" value={fromDate} onChange={(event) => setFromDate(event.target.value)}/></label><label className="timeline-date-filter">To<input type="date" value={toDate} onChange={(event) => setToDate(event.target.value)}/></label></div>
      <div className="timeline-category-filter"><span><Filter size={13}/> Event layers</span>{availableCategories.map((category) => <label key={category}><input type="checkbox" checked={selectedCategories.length === 0 || selectedCategories.includes(category)} onChange={() => toggleCategory(category)}/>{label(category)}</label>)}</div>
    </div>
    <div className="timeline-results-heading"><div><strong>{filtered.length}</strong><span>schedule events</span></div><span><SlidersHorizontal size={13}/> Filters apply to this view only</span></div>
    {loading ? <div className="panel module-loading">Loading schedule events…</div> : error ? <div className="panel module-error">{error}</div> : grouped.length ? <div className="timeline-month-groups">{grouped.map(([month, rows]) => <section className="panel timeline-month-group" key={month}><div className="timeline-month-heading"><strong>{month === "undated" ? "Date not reported" : new Intl.DateTimeFormat(undefined, { month: "long", year: "numeric" }).format(new Date(month + "-01T00:00:00"))}</strong><span>{rows.length} events</span></div><div className="timeline-event-list">{rows.map((event) => <article className="timeline-event-row" key={event.event_id}><div className="timeline-event-date"><strong>{dateLabel(event.event_start_date ?? event.event_end_date)}</strong><small>{event.event_start_date && event.event_end_date && event.event_start_date !== event.event_end_date ? "to " + dateLabel(event.event_end_date) : event.date_basis === "baseline" ? "Baseline date" : label(event.date_basis) + " date"}</small></div><div className="timeline-event-marker"><i className={"timeline-marker " + statusClass(event.event_category)}/></div><div className="timeline-event-content"><div className="timeline-event-title"><strong>{event.event_name}</strong><span className={"timeline-type-pill " + statusClass(event.event_category)}>{label(event.event_category)}</span></div><small>{projectLabel(event.project_id)} · {event.source_reference || "Reference not reported"}</small><div className="timeline-event-meta"><span>{label(event.source_entity_type)}</span><span>{label(event.date_basis)}</span><span>{label(event.record_status)}</span>{event.severity && <span>{label(event.severity)}</span>}</div>{typeof event.metadata?.workstream === "string" && <small>Workstream: {event.metadata.workstream}</small>}{typeof event.metadata?.event_subtype === "string" && <small>Type: {event.metadata.event_subtype}</small>}{typeof event.metadata?.event_description === "string" && <small>{event.metadata.event_description}</small>}{event.metadata?.progress_percent !== undefined && <small>Progress: {String(event.metadata.progress_percent)}%</small>}</div>{event.event_category === "custom_event" && canManageProject(event.project_id) && <div className="custom-event-actions"><button className="icon-button" title="Edit custom event" disabled={busy} onClick={() => startEditCustomEvent(event)}><Pencil size={13}/></button><button className="icon-button" title="Archive custom event" disabled={busy} onClick={() => void archiveCustomEvent(event)}><Archive size={13}/></button></div>}</article>)}</div></section>)}</div> : <div className="panel timeline-empty"><CalendarDays size={25}/><strong>No schedule events match the selected filters.</strong><span>No demo events are displayed. Missing dates and records remain unreported rather than being inferred.</span></div>}
  </section>;
}

function statusClass(value: string) {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, "-");
}
