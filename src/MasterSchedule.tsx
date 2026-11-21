import { useEffect, useMemo, useState } from "react";
import { CalendarDays, Filter, Search, SlidersHorizontal } from "lucide-react";
import { supabase } from "./lib/supabase";

type Project = { id: string; project_code: string; name: string };
type TimelineEvent = {
  event_id: string; project_id: string; source_entity_type: string; source_record_id: string;
  event_category: string; event_name: string; event_start_date: string | null; event_end_date: string | null;
  date_basis: string; record_status: string | null; severity: string | null; amount: number | null;
  currency_code: string | null; owner_user_id: string | null; source_reference: string | null;
  metadata: Record<string, unknown> | null;
};
const categories = ["activity", "milestone", "contract", "license", "management_decision"];
const basisOptions = ["baseline", "approved_revised", "forecast", "actual", "contractual"];
const label = (value: string | null | undefined) => value ? value.replace(/_/g, " ").replace(/\b\w/g, (letter) => letter.toUpperCase()) : "Not Reported";
const dateLabel = (value: string | null) => value ? new Intl.DateTimeFormat(undefined, { dateStyle: "medium" }).format(new Date(value + (value.length === 10 ? "T00:00:00" : ""))) : "Not Reported";

export default function MasterSchedule() {
  const [events, setEvents] = useState<TimelineEvent[]>([]);
  const [projects, setProjects] = useState<Project[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [query, setQuery] = useState("");
  const [projectFilter, setProjectFilter] = useState("all");
  const [basisFilter, setBasisFilter] = useState("all");
  const [selectedCategories, setSelectedCategories] = useState<string[]>([]);
  const [fromDate, setFromDate] = useState("");
  const [toDate, setToDate] = useState("");

  useEffect(() => {
    let active = true;
    async function load() {
      if (!supabase) { setError("Supabase client is not configured."); setLoading(false); return; }
      setLoading(true); setError("");
      const [eventResult, projectResult] = await Promise.all([
        supabase.from("project_master_schedule_timeline").select("event_id,project_id,source_entity_type,source_record_id,event_category,event_name,event_start_date,event_end_date,date_basis,record_status,severity,amount,currency_code,owner_user_id,source_reference,metadata").order("event_start_date", { ascending: true }).limit(2000),
        supabase.from("projects").select("id,project_code,name").order("project_code")
      ]);
      if (!active) return;
      if (eventResult.error) setError(eventResult.error.message);
      else setEvents((eventResult.data ?? []) as TimelineEvent[]);
      setProjects((projectResult.data ?? []) as Project[]);
      setLoading(false);
    }
    void load();
    return () => { active = false; };
  }, []);

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
  const toggleCategory = (category: string) => setSelectedCategories((current) => {
    const next = current.length === 0 ? availableCategories.filter((item) => item !== category) : current.includes(category) ? current.filter((item) => item !== category) : [...current, category];
    return next.length === availableCategories.length ? [] : next;
  });

  return <section className="timeline-module">
    <div className="timeline-module-heading"><div><span className="module-eyebrow">DELIVERY CONTROL</span><h2>Master Schedule Timeline</h2><p>Cross-project view of activities, milestones, contract dates, licenses and management decisions.</p></div><div className="timeline-live-label"><CalendarDays size={15}/> Live schedule records</div></div>
    <div className="timeline-filter-panel panel">
      <div className="timeline-filter-row"><div className="timeline-search"><Search size={14}/><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search event, reference or project"/></div><select value={projectFilter} onChange={(event) => setProjectFilter(event.target.value)}><option value="all">All accessible projects</option>{projects.map((project) => <option key={project.id} value={project.id}>{project.project_code} · {project.name}</option>)}</select><select value={basisFilter} onChange={(event) => setBasisFilter(event.target.value)}><option value="all">All date bases</option>{basisOptions.map((basis) => <option key={basis} value={basis}>{label(basis)}</option>)}</select><label className="timeline-date-filter">From<input type="date" value={fromDate} onChange={(event) => setFromDate(event.target.value)}/></label><label className="timeline-date-filter">To<input type="date" value={toDate} onChange={(event) => setToDate(event.target.value)}/></label></div>
      <div className="timeline-category-filter"><span><Filter size={13}/> Event layers</span>{availableCategories.map((category) => <label key={category}><input type="checkbox" checked={selectedCategories.length === 0 || selectedCategories.includes(category)} onChange={() => toggleCategory(category)}/>{label(category)}</label>)}</div>
    </div>
    <div className="timeline-results-heading"><div><strong>{filtered.length}</strong><span>schedule events</span></div><span><SlidersHorizontal size={13}/> Filters apply to this view only</span></div>
    {loading ? <div className="panel module-loading">Loading schedule events…</div> : error ? <div className="panel module-error">{error}</div> : grouped.length ? <div className="timeline-month-groups">{grouped.map(([month, rows]) => <section className="panel timeline-month-group" key={month}><div className="timeline-month-heading"><strong>{month === "undated" ? "Date not reported" : new Intl.DateTimeFormat(undefined, { month: "long", year: "numeric" }).format(new Date(month + "-01T00:00:00"))}</strong><span>{rows.length} events</span></div><div className="timeline-event-list">{rows.map((event) => <article className="timeline-event-row" key={event.event_id}><div className="timeline-event-date"><strong>{dateLabel(event.event_start_date ?? event.event_end_date)}</strong><small>{event.event_start_date && event.event_end_date && event.event_start_date !== event.event_end_date ? "to " + dateLabel(event.event_end_date) : event.date_basis === "baseline" ? "Baseline date" : label(event.date_basis) + " date"}</small></div><div className="timeline-event-marker"><i className={"timeline-marker " + statusClass(event.event_category)}/></div><div className="timeline-event-content"><div className="timeline-event-title"><strong>{event.event_name}</strong><span className={"timeline-type-pill " + statusClass(event.event_category)}>{label(event.event_category)}</span></div><small>{projectLabel(event.project_id)} · {event.source_reference || "Reference not reported"}</small><div className="timeline-event-meta"><span>{label(event.source_entity_type)}</span><span>{label(event.date_basis)}</span><span>{label(event.record_status)}</span>{event.severity && <span>{label(event.severity)}</span>}</div>{typeof event.metadata?.workstream === "string" && <small>Workstream: {event.metadata.workstream}</small>}{event.metadata?.progress_percent !== undefined && <small>Progress: {String(event.metadata.progress_percent)}%</small>}</div></article>)}</div></section>)}</div> : <div className="panel timeline-empty"><CalendarDays size={25}/><strong>No schedule events match the selected filters.</strong><span>No demo events are displayed. Missing dates and records remain unreported rather than being inferred.</span></div>}
  </section>;
}

function statusClass(value: string) {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, "-");
}
