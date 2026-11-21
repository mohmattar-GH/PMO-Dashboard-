import { useEffect, useMemo, useState } from "react";
import { AlertTriangle, CalendarDays, CircleDollarSign, Filter, Search, ShieldAlert } from "lucide-react";
import { supabase } from "./lib/supabase";

type Project = { id: string; project_code: string; name: string };
type TimelineEvent = {
  event_id: string; project_id: string; source_entity_type: string; source_record_id: string;
  event_category: string; event_name: string; event_start_date: string | null; event_end_date: string | null;
  date_basis: string; record_status: string | null; severity: string | null; amount: number | null;
  currency_code: string | null; owner_user_id: string | null; source_reference: string | null;
  metadata: Record<string, unknown> | null;
};
type Balance = { invoice_id: string; applied_amount: number; outstanding_amount: number; is_settled: boolean };
const label = (value: string | null | undefined) => value ? value.replace(/_/g, " ").replace(/\b\w/g, (letter) => letter.toUpperCase()) : "Not Reported";
const dateLabel = (value: string | null) => value ? new Intl.DateTimeFormat(undefined, { dateStyle: "medium" }).format(new Date(value + (value.length === 10 ? "T00:00:00" : ""))) : "Not Reported";
const amount = (value: number | null, currency: string | null) => {
  if (value === null) return "Not Reported";
  if (!currency) return Number(value).toLocaleString() + " · Currency not reported";
  try { return new Intl.NumberFormat(undefined, { style: "currency", currency: currency.trim() }).format(Number(value)); }
  catch { return Number(value).toLocaleString() + " " + currency; }
};
const statusClass = (value: string) => value.toLowerCase().replace(/[^a-z0-9]+/g, "-");

export default function PaymentsRiskTimeline() {
  const [events, setEvents] = useState<TimelineEvent[]>([]);
  const [projects, setProjects] = useState<Project[]>([]);
  const [balances, setBalances] = useState<Record<string, Balance>>({});
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
      const [eventResult, projectResult, balanceResult] = await Promise.all([
        supabase.from("project_payment_risk_timeline").select("event_id,project_id,source_entity_type,source_record_id,event_category,event_name,event_start_date,event_end_date,date_basis,record_status,severity,amount,currency_code,owner_user_id,source_reference,metadata").order("event_start_date", { ascending: true }).limit(2000),
        supabase.from("projects").select("id,project_code,name").order("project_code"),
        supabase.from("project_invoice_balances").select("invoice_id,applied_amount,outstanding_amount,is_settled")
      ]);
      if (!active) return;
      if (eventResult.error) setError(eventResult.error.message);
      else setEvents((eventResult.data ?? []) as TimelineEvent[]);
      setProjects((projectResult.data ?? []) as Project[]);
      setBalances(Object.fromEntries(((balanceResult.data ?? []) as Balance[]).map((balance) => [balance.invoice_id, balance])));
      setLoading(false);
    }
    void load();
    return () => { active = false; };
  }, []);

  const availableCategories = [...new Set(["payment", "risk", ...events.map((event) => event.event_category)])].sort();
  const filtered = useMemo(() => events.filter((event) => {
    const start = event.event_start_date ?? event.event_end_date;
    const end = event.event_end_date ?? event.event_start_date;
    const datePass = (!fromDate || !end || end >= fromDate) && (!toDate || !start || start <= toDate);
    const projectPass = projectFilter === "all" || event.project_id === projectFilter;
    const basisPass = basisFilter === "all" || event.date_basis === basisFilter;
    const categoryPass = selectedCategories.length === 0 || selectedCategories.includes(event.event_category);
    const project = projects.find((item) => item.id === event.project_id);
    const text = [event.event_name, event.source_reference, event.source_entity_type, project?.name ?? "", event.record_status ?? ""].join(" ").toLowerCase();
    return datePass && projectPass && basisPass && categoryPass && text.includes(query.trim().toLowerCase());
  }), [events, projects, projectFilter, basisFilter, selectedCategories, fromDate, toDate, query]);

  const toggleCategory = (category: string) => setSelectedCategories((current) => {
    const next = current.length === 0 ? availableCategories.filter((item) => item !== category) : current.includes(category) ? current.filter((item) => item !== category) : [...current, category];
    return next.length === availableCategories.length ? [] : next;
  });
  const projectLabel = (id: string) => {
    const project = projects.find((item) => item.id === id);
    return project ? project.project_code + " · " + project.name : "Project not available";
  };

  return <section className="timeline-module">
    <div className="timeline-module-heading"><div><span className="module-eyebrow">FINANCIAL & RISK CONTROL</span><h2>Payments & Risk Timeline</h2><p>Invoice milestones, cash movements, payment status and project risk events in one chronological view.</p></div><div className="timeline-live-label"><CalendarDays size={15}/> Live financial and risk records</div></div>
    <div className="timeline-security-note"><ShieldAlert size={15}/><span>Financial events and amounts are returned only when the signed-in role has the required project or executive financial access. Missing payment records are not treated as zero.</span></div>
    <div className="timeline-filter-panel panel">
      <div className="timeline-filter-row"><div className="timeline-search"><Search size={14}/><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search invoice, risk, reference or project"/></div><select value={projectFilter} onChange={(event) => setProjectFilter(event.target.value)}><option value="all">All accessible projects</option>{projects.map((project) => <option key={project.id} value={project.id}>{project.project_code} · {project.name}</option>)}</select><select value={basisFilter} onChange={(event) => setBasisFilter(event.target.value)}><option value="all">All date bases</option><option value="actual">Actual</option><option value="contractual">Contractual</option><option value="forecast">Forecast</option></select><label className="timeline-date-filter">From<input type="date" value={fromDate} onChange={(event) => setFromDate(event.target.value)}/></label><label className="timeline-date-filter">To<input type="date" value={toDate} onChange={(event) => setToDate(event.target.value)}/></label></div>
      <div className="timeline-category-filter"><span><Filter size={13}/> Event layers</span>{availableCategories.map((category) => <label key={category}><input type="checkbox" checked={selectedCategories.length === 0 || selectedCategories.includes(category)} onChange={() => toggleCategory(category)}/>{label(category)}</label>)}</div>
    </div>
    <div className="timeline-results-heading"><div><strong>{filtered.length}</strong><span>payment and risk events</span></div><span><AlertTriangle size={13}/> Risk and payment records remain separate event types</span></div>
    {loading ? <div className="panel module-loading">Loading payment and risk events…</div> : error ? <div className="panel module-error">{error}</div> : filtered.length ? <div className="panel payment-risk-list">{filtered.map((event) => {
      const isRisk = event.event_category === "risk";
      const balance = event.source_entity_type === "invoice" ? balances[event.source_record_id] : undefined;
      const metadata = event.metadata ?? {};
      return <article className="payment-risk-event-row" key={event.event_id}>
        <div className="payment-risk-date"><strong>{dateLabel(event.event_start_date ?? event.event_end_date)}</strong><small>{event.event_end_date && event.event_start_date !== event.event_end_date ? "Resolution " + dateLabel(event.event_end_date) : label(event.date_basis)}</small></div>
        <div className={"payment-risk-icon " + (isRisk ? "risk" : "payment")}>{isRisk ? <AlertTriangle size={16}/> : <CircleDollarSign size={16}/>}</div>
        <div className="payment-risk-content"><div className="payment-risk-title"><strong>{event.event_name}</strong><span className={"timeline-type-pill " + (isRisk ? "risk" : "payment")}>{label(event.event_category)}</span><span className={"project-status-pill " + statusClass(event.record_status ?? "not-reported")}>{label(event.record_status)}</span></div><small>{projectLabel(event.project_id)} · {event.source_reference || "Reference not reported"}</small>
          {isRisk ? <div className="timeline-event-meta"><span>Risk score {metadata.risk_score == null ? "Not Reported" : String(metadata.risk_score)}</span><span>Probability {metadata.probability_level == null ? "Not Reported" : String(metadata.probability_level)}</span><span>Impact {metadata.impact_level == null ? "Not Reported" : String(metadata.impact_level)}</span><span>Trend {label(String(metadata.trend ?? ""))}</span>{event.severity && <span>{label(event.severity)}</span>}</div> : <div className="timeline-event-meta"><span>{label(String(metadata.invoice_event ?? metadata.transaction_type ?? "payment event"))}</span><span>{label(event.date_basis)}</span>{typeof metadata.payer_payee === "string" && <span>{metadata.payer_payee}</span>}</div>}
          {balance && <small>Applied {amount(balance.applied_amount, event.currency_code)} · Outstanding {amount(balance.outstanding_amount, event.currency_code)} · {balance.is_settled ? "Settled" : "Balance outstanding"}</small>}
        </div>
        <div className="payment-risk-amount">{event.amount == null ? <span>Amount not applicable</span> : <strong>{amount(event.amount, event.currency_code)}</strong>}</div>
      </article>;
    })}</div> : <div className="panel timeline-empty"><CalendarDays size={25}/><strong>No accessible payment or risk events match the selected filters.</strong><span>Payment visibility depends on Finance, Project Manager, Platform Administrator, Finance Administrator or an explicit Executive Viewer grant. Risk visibility follows project membership and executive access.</span></div>}
  </section>;
}
