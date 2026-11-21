import { useCallback, useEffect, useMemo, useState } from "react";
import type { FormEvent } from "react";
import { AlertCircle, CheckCircle2, FileCheck2, FilePlus2, LoaderCircle, Search, ShieldCheck, X } from "lucide-react";
import { supabase } from "./lib/supabase";

type Project = { id: string; project_code: string; name: string };
type Contract = { id: string; project_id: string; contract_reference: string; contract_title: string };
type Member = { project_id: string; user_id: string; project_role: string; display_name: string };
type Deliverable = {
  id: string; project_id: string; contract_id: string; deliverable_code: string; name: string;
  description: string | null; due_date: string | null; acceptance_criteria: string | null;
  status: string; deliverable_type: string | null; is_contractual: boolean;
  contract_reference: string | null; owner_user_id: string | null; reviewer_user_id: string | null;
  accepting_authority: string | null; baseline_submission_date: string | null;
  approved_revised_submission_date: string | null; forecast_submission_date: string | null;
  actual_submission_date: string | null; baseline_acceptance_date: string | null;
  approved_revised_acceptance_date: string | null; forecast_acceptance_date: string | null;
  acceptance_status: string; accepted_by: string | null; accepted_at: string | null;
};
type Submission = { id: string; deliverable_id: string; submission_no: number; submitted_by: string; submitted_at: string; document_id: string | null; document_version_id: string | null; submission_notes: string | null; status: string };
type Review = { id: string; submission_id: string; reviewer_user_id: string; outcome: string; comments: string | null; rejection_reason: string | null; reviewed_at: string };

const label = (value: string) => value.replace(/_/g, " ").replace(/\b\w/g, (s) => s.toUpperCase());
const dateTime = (value: string | null) => value ? new Intl.DateTimeFormat(undefined, { dateStyle: "medium", timeStyle: "short" }).format(new Date(value)) : "Not recorded";

export default function Deliverables({ canManage }: { canManage: boolean }) {
  const [projects, setProjects] = useState<Project[]>([]);
  const [contracts, setContracts] = useState<Contract[]>([]);
  const [members, setMembers] = useState<Member[]>([]);
  const [records, setRecords] = useState<Deliverable[]>([]);
  const [submissions, setSubmissions] = useState<Submission[]>([]);
  const [reviews, setReviews] = useState<Review[]>([]);
  const [currentUserId, setCurrentUserId] = useState("");
  const [loading, setLoading] = useState(true);
  const [detailLoading, setDetailLoading] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [query, setQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState("all");
  const [projectFilter, setProjectFilter] = useState("all");
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [showCreate, setShowCreate] = useState(false);
  const [submissionNotes, setSubmissionNotes] = useState("");
  const [reviewOutcome, setReviewOutcome] = useState("accepted");
  const [reviewComments, setReviewComments] = useState("");
  const [rejectionReason, setRejectionReason] = useState("");
  const [form, setForm] = useState({
    project_id: "", contract_id: "", deliverable_code: "", name: "", description: "",
    due_date: "", acceptance_criteria: "", deliverable_type: "document", owner_user_id: "",
    reviewer_user_id: "", accepting_authority: "", baseline_submission_date: "",
    baseline_acceptance_date: "", is_contractual: true
  });

  const loadRegister = useCallback(async () => {
    if (!supabase) { setError("Supabase client is not configured."); setLoading(false); return; }
    setLoading(true); setError("");
    const [{ data: userData }, projectResult, contractResult, memberResult, deliverableResult] = await Promise.all([
      supabase.auth.getUser(),
      supabase.from("projects").select("id,project_code,name").order("project_code"),
      supabase.from("project_contracts").select("id,project_id,contract_reference,contract_title").order("contract_reference"),
      supabase.from("project_memberships").select("project_id,user_id,project_role").eq("status", "active").lte("effective_from", new Date().toISOString()).or(`effective_to.is.null,effective_to.gt.${new Date().toISOString()}`),
      supabase.from("contract_deliverables").select("id,project_id,contract_id,deliverable_code,name,description,due_date,acceptance_criteria,status,deliverable_type,is_contractual,contract_reference,owner_user_id,reviewer_user_id,accepting_authority,baseline_submission_date,approved_revised_submission_date,forecast_submission_date,actual_submission_date,baseline_acceptance_date,approved_revised_acceptance_date,forecast_acceptance_date,acceptance_status,accepted_by,accepted_at").order("due_date", { ascending: true, nullsFirst: false })
    ]);
    if (projectResult.error || deliverableResult.error) {
      setError(projectResult.error?.message || deliverableResult.error?.message || "Unable to load deliverables.");
      setLoading(false); return;
    }
    setCurrentUserId(userData.user?.id ?? "");
    const projectRows = (projectResult.data ?? []) as Project[];
    setProjects(projectRows);
    setContracts((contractResult.data ?? []) as Contract[]);
    const rawMembers = (memberResult.data ?? []) as Omit<Member, "display_name">[];
    const memberIds = [...new Set(rawMembers.map((m) => m.user_id))];
    const profileResult = memberIds.length ? await supabase.from("user_profiles").select("user_id,display_name").in("user_id", memberIds) : { data: [], error: null };
    const names = new Map((profileResult.data ?? []).map((p: { user_id: string; display_name: string | null }) => [p.user_id, p.display_name || p.user_id.slice(0, 8)]));
    setMembers(rawMembers.map((m) => ({ ...m, display_name: names.get(m.user_id) ?? m.user_id.slice(0, 8) })));
    setRecords((deliverableResult.data ?? []) as Deliverable[]);
    setLoading(false);
  }, []);

  useEffect(() => { void loadRegister(); }, [loadRegister]);

  const selected = records.find((r) => r.id === selectedId) ?? null;
  const membersFor = (projectId: string) => members.filter((m) => m.project_id === projectId);
  const isProjectPM = (projectId: string) => membersFor(projectId).some((m) => m.user_id === currentUserId && m.project_role === "project_manager");
  const canManageSelected = Boolean(selected && (isPlatformAdmin || isProjectPM(selected.project_id)));
  const projectName = (projectId: string) => projects.find((p) => p.id === projectId)?.name ?? "Project";
  const ownerName = (id: string | null, projectId: string) => id ? membersFor(projectId).find((m) => m.user_id === id)?.display_name ?? id.slice(0, 8) : "Unassigned";
  const filtered = useMemo(() => records.filter((r) =>
    (statusFilter === "all" || r.status === statusFilter) &&
    (projectFilter === "all" || r.project_id === projectFilter) &&
    [r.deliverable_code, r.name, r.contract_reference ?? "", projectName(r.project_id)].join(" ").toLowerCase().includes(query.trim().toLowerCase())
  ), [records, statusFilter, projectFilter, query, projects]);

  const loadDetail = useCallback(async (record: Deliverable) => {
    if (!supabase) return;
    setSelectedId(record.id); setDetailLoading(true); setSubmissionNotes(""); setReviewComments(""); setRejectionReason(""); setReviewOutcome("accepted");
    const submissionResult = await supabase.from("contract_deliverable_submissions").select("id,deliverable_id,submission_no,submitted_by,submitted_at,document_id,document_version_id,submission_notes,status").eq("deliverable_id", record.id).order("submission_no", { ascending: false });
    if (submissionResult.error) setNotice("Submission history is not available to this account: " + submissionResult.error.message);
    const submissionRows = (submissionResult.data ?? []) as Submission[];
    setSubmissions(submissionRows);
    if (submissionRows.length) {
      const reviewResult = await supabase.from("contract_deliverable_reviews").select("id,submission_id,reviewer_user_id,outcome,comments,rejection_reason,reviewed_at").in("submission_id", submissionRows.map((s) => s.id)).order("reviewed_at", { ascending: false });
      if (reviewResult.error) setNotice("Some review details are not available to this account: " + reviewResult.error.message);
      setReviews((reviewResult.data ?? []) as Review[]);
    } else setReviews([]);
    setDetailLoading(false);
  }, []);

  const createDeliverable = async (event: FormEvent) => {
    event.preventDefault();
    if (!supabase) return;
    setBusy(true); setNotice("");
    const contract = contracts.find((c) => c.id === form.contract_id && c.project_id === form.project_id);
    if (!contract) { setNotice("Select a contract belonging to the chosen project."); setBusy(false); return; }
    const { data, error: createError } = await supabase.from("contract_deliverables").insert({
      project_id: form.project_id, contract_id: form.contract_id,
      deliverable_code: form.deliverable_code.trim(), name: form.name.trim(),
      description: form.description.trim() || null, due_date: form.due_date || null,
      acceptance_criteria: form.acceptance_criteria.trim() || null, status: "planned",
      deliverable_type: form.deliverable_type || null, is_contractual: form.is_contractual,
      contract_reference: contract.contract_reference, owner_user_id: form.owner_user_id || null,
      reviewer_user_id: form.reviewer_user_id || null, accepting_authority: form.accepting_authority.trim() || null,
      baseline_submission_date: form.baseline_submission_date || null,
      baseline_acceptance_date: form.baseline_acceptance_date || null, acceptance_status: "unaccepted"
    }).select("id").single();
    if (createError) setNotice("Could not create deliverable: " + createError.message);
    else {
      setShowCreate(false);
      setForm({ project_id: "", contract_id: "", deliverable_code: "", name: "", description: "", due_date: "", acceptance_criteria: "", deliverable_type: "document", owner_user_id: "", reviewer_user_id: "", accepting_authority: "", baseline_submission_date: "", baseline_acceptance_date: "", is_contractual: true });
      await loadRegister(); setNotice("Deliverable created.");
      if (data?.id) {
        const { data: createdRecord } = await supabase.from("contract_deliverables").select("id,project_id,contract_id,deliverable_code,name,description,due_date,acceptance_criteria,status,deliverable_type,is_contractual,contract_reference,owner_user_id,reviewer_user_id,accepting_authority,baseline_submission_date,approved_revised_submission_date,forecast_submission_date,actual_submission_date,baseline_acceptance_date,approved_revised_acceptance_date,forecast_acceptance_date,acceptance_status,accepted_by,accepted_at").eq("id", data.id).single();
        if (createdRecord) await loadDetail(createdRecord as Deliverable);
      }
    }
    setBusy(false);
  };

  const submitDeliverable = async () => {
    if (!supabase || !selected) return;
    setBusy(true); setNotice("");
    const { error: submitError } = await supabase.rpc("submit_contract_deliverable", {
      p_deliverable_id: selected.id, p_document_id: null, p_document_version_id: null,
      p_submission_notes: submissionNotes.trim() || null
    });
    if (submitError) setNotice("Submission failed: " + submitError.message);
    else { setNotice("Deliverable submitted for review."); await loadRegister(); await loadDetail({ ...selected, status: "submitted" }); }
    setBusy(false);
  };

  const reviewSubmission = async (submission: Submission) => {
    if (!supabase) return;
    if (reviewOutcome === "rejected" && rejectionReason.trim().length < 8) { setNotice("A rejection reason of at least 8 characters is required."); return; }
    setBusy(true); setNotice("");
    const { error: reviewError } = await supabase.rpc("review_contract_deliverable_submission", {
      p_submission_id: submission.id, p_outcome: reviewOutcome,
      p_comments: reviewComments.trim() || null, p_rejection_reason: rejectionReason.trim() || null
    });
    if (reviewError) setNotice("Review failed: " + reviewError.message);
    else { setNotice("Deliverable review recorded. Formal PM acceptance remains a separate step."); await loadRegister(); if (selected) await loadDetail({ ...selected, status: reviewOutcome === "accepted" ? "reviewed" : reviewOutcome }); }
    setBusy(false);
  };

  const acceptDeliverable = async () => {
    if (!supabase || !selected) return;
    setBusy(true); setNotice("");
    const { error: acceptError } = await supabase.rpc("accept_contract_deliverable", { p_deliverable_id: selected.id });
    if (acceptError) setNotice("Formal acceptance failed: " + acceptError.message);
    else { setNotice("Deliverable formally accepted by the Project Manager."); await loadRegister(); await loadDetail({ ...selected, status: "accepted", acceptance_status: "accepted" }); }
    setBusy(false);
  };

  const latestSubmission = submissions[0] ?? null;
  const latestReview = latestSubmission ? reviews.find((r) => r.submission_id === latestSubmission.id) ?? null : null;
  const isOwner = Boolean(selected && selected.owner_user_id === currentUserId && membersFor(selected.project_id).some((m) => m.user_id === currentUserId));
  const isReviewer = Boolean(selected && selected.reviewer_user_id === currentUserId && membersFor(selected.project_id).some((m) => m.user_id === currentUserId));
  const canSubmit = Boolean(selected && (isOwner || isProjectPM(selected.project_id)) && ["planned","in_progress","changes_required"].includes(selected.status));
  const canReview = Boolean(selected && (isProjectPM(selected.project_id) || isReviewer) && latestSubmission?.status === "submitted" && !latestReview);
  const canAccept = Boolean(selected && isProjectPM(selected.project_id) && selected.status === "reviewed" && latestReview?.outcome === "accepted");

  return <div className="dl-module">
    <div className="dl-toolbar">
      <div className="dl-search"><Search size={15}/><input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Search deliverable, contract or project"/></div>
      <select value={projectFilter} onChange={(e) => setProjectFilter(e.target.value)}><option value="all">All projects</option>{projects.map((p) => <option key={p.id} value={p.id}>{p.project_code} · {p.name}</option>)}</select>
      <select value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)}><option value="all">All statuses</option>{["planned","in_progress","submitted","reviewed","changes_required","rejected","accepted","waived"].map((s) => <option key={s} value={s}>{label(s)}</option>)}</select>
      <span className="dl-spacer"/>
      {canManage && <button className="button-primary" onClick={() => setShowCreate(true)}><FilePlus2 size={15}/> New Deliverable</button>}
    </div>

    <div className="dl-summary">
      {[["Total",records.length],["Awaiting review",records.filter((r) => r.status === "submitted").length],["Awaiting PM acceptance",records.filter((r) => r.status === "reviewed" && r.acceptance_status !== "accepted").length],["Accepted",records.filter((r) => r.acceptance_status === "accepted").length]].map(([name,count]) => <article key={String(name)}><span>{name}</span><strong>{loading ? "—" : count}</strong></article>)}
    </div>
    {error && <div className="cr-message error"><AlertCircle size={16}/>{error}</div>}
    {notice && <div className="cr-message"><CheckCircle2 size={16}/><span>{notice}</span><button onClick={() => setNotice("")} aria-label="Dismiss"><X size={14}/></button></div>}

    <div className="dl-grid">
      <section className="panel dl-register">
        <div className="panel-heading"><div><h3>Deliverables Register</h3><span className="panel-subtitle">Contract-linked deliverables · governed submission and acceptance</span></div><span className="cr-count">{loading ? "Loading…" : `${filtered.length} records`}</span></div>
        {loading ? <div className="cr-empty"><LoaderCircle className="spin" size={20}/> Loading deliverables…</div> : filtered.length === 0 ? <div className="cr-empty"><FileCheck2 size={22}/><strong>No deliverables found</strong><span>No records match the filters or are visible to this account.</span></div> :
          <div className="dl-list">{filtered.map((record) => <button key={record.id} className={selectedId === record.id ? "dl-row selected" : "dl-row"} onClick={() => void loadDetail(record)}>
            <span><strong>{record.deliverable_code} · {record.name}</strong><small>{projectName(record.project_id)} · {record.contract_reference ?? "Contract"} · Owner: {ownerName(record.owner_user_id,record.project_id)}</small></span>
            <span className={`cr-status ${["accepted"].includes(record.status) ? "success" : ["rejected","changes_required"].includes(record.status) ? "danger" : ["submitted","reviewed"].includes(record.status) ? "warning" : "neutral"}`}>{label(record.status)}</span>
            <small>{record.due_date ?? "No due date"}</small>
          </button>)}</div>}
      </section>

      <section className="panel dl-detail">
        {!selected ? <div className="cr-empty cr-detail-empty"><ShieldCheck size={26}/><strong>Deliverable workspace</strong><span>Select a deliverable to review its contractual details, submissions and acceptance.</span></div> :
          detailLoading ? <div className="cr-empty"><LoaderCircle className="spin" size={20}/> Loading deliverable…</div> :
          <div className="dl-detail-body">
            <div className="cr-detail-header"><div><span className="cr-reference">{selected.deliverable_code}</span><span className="cr-status">{label(selected.status)}</span><h2>{selected.name}</h2><p>{projectName(selected.project_id)} · {selected.contract_reference ?? "Contract"}</p></div><button className="icon-button" onClick={() => setSelectedId(null)} aria-label="Close detail"><X size={17}/></button></div>
            <div className="dl-info-grid"><div><small>Owner</small><strong>{ownerName(selected.owner_user_id,selected.project_id)}</strong></div><div><small>Reviewer</small><strong>{ownerName(selected.reviewer_user_id,selected.project_id)}</strong></div><div><small>Due date</small><strong>{selected.due_date ?? "Not set"}</strong></div><div><small>Acceptance status</small><strong>{label(selected.acceptance_status)}</strong></div><div><small>Baseline submission</small><strong>{selected.baseline_submission_date ?? "Not set"}</strong></div><div><small>Baseline acceptance</small><strong>{selected.baseline_acceptance_date ?? "Not set"}</strong></div></div>
            {selected.description && <div className="dl-section"><h3>Description</h3><p>{selected.description}</p></div>}
            {selected.acceptance_criteria && <div className="dl-section"><h3>Acceptance criteria</h3><p>{selected.acceptance_criteria}</p></div>}
            {selected.accepting_authority && <div className="dl-section"><h3>Accepting authority</h3><p>{selected.accepting_authority}</p></div>}

            {canSubmit && <div className="dl-action"><strong>Submit deliverable</strong><p>Submit a new version for review. A project document link can be attached in a later integration step; submission notes are captured now.</p><textarea value={submissionNotes} onChange={(e) => setSubmissionNotes(e.target.value)} placeholder="Submission notes, version reference or evidence location"/><button className="button-primary" disabled={busy} onClick={() => void submitDeliverable()}>{busy ? "Submitting…" : "Submit for review"}</button></div>}

            {canReview && latestSubmission && <div className="dl-action"><strong>Review submission #{latestSubmission.submission_no}</strong><p>Review outcome is separate from formal Project Manager acceptance.</p><select value={reviewOutcome} onChange={(e) => setReviewOutcome(e.target.value)}><option value="accepted">Review accepted</option><option value="changes_required">Changes required</option><option value="rejected">Reject submission</option></select><textarea value={reviewComments} onChange={(e) => setReviewComments(e.target.value)} placeholder="Review comments"/>{reviewOutcome === "rejected" && <textarea value={rejectionReason} onChange={(e) => setRejectionReason(e.target.value)} placeholder="Mandatory rejection reason (minimum 8 characters)"/>}<button className="button-primary" disabled={busy || (reviewOutcome === "rejected" && rejectionReason.trim().length < 8)} onClick={() => void reviewSubmission(latestSubmission)}>{busy ? "Saving review…" : "Record review"}</button></div>}

            {canAccept && <div className="dl-action dl-accept"><strong>Formal PM acceptance</strong><p>The latest submission has an accepted review. Only the Project Manager can formally accept this contractual deliverable.</p><button className="button-primary" disabled={busy} onClick={() => void acceptDeliverable()}>{busy ? "Accepting…" : "Accept deliverable"}</button></div>}

            {selected.acceptance_status === "accepted" && <div className="dl-accepted"><CheckCircle2 size={17}/><div><strong>Formally accepted</strong><p>Accepted by {ownerName(selected.accepted_by,selected.project_id)} · {dateTime(selected.accepted_at)}</p></div></div>}

            <div className="dl-section"><div className="cr-section-title"><div><h3>Submission and review history</h3><p>Each submission version and review decision is retained.</p></div><button className="text-action" onClick={() => void loadDetail(selected)}>Refresh</button></div>
              {submissions.length === 0 ? <div className="cr-inline-empty">No submissions recorded yet.</div> : <div className="dl-history">{submissions.map((submission) => { const review = reviews.find((r) => r.submission_id === submission.id); return <article key={submission.id}><div><strong>Submission #{submission.submission_no}</strong><small>{dateTime(submission.submitted_at)} · Submitted by {ownerName(submission.submitted_by,selected.project_id)}</small>{submission.submission_notes && <p>{submission.submission_notes}</p>}</div><span className="cr-status">{label(submission.status)}</span>{review && <div className="dl-review"><strong>{label(review.outcome)} · {dateTime(review.reviewed_at)}</strong>{review.comments && <p>{review.comments}</p>}{review.rejection_reason && <p>Reason: {review.rejection_reason}</p>}</div>}</article>;})}</div>}
            </div>
          </div>}
      </section>
    </div>

    {showCreate && <div className="cr-modal-backdrop" role="presentation" onMouseDown={(e) => { if (e.target === e.currentTarget) setShowCreate(false); }}><form className="cr-create-modal dl-create-modal" onSubmit={createDeliverable}>
      <div className="cr-modal-heading"><div><span>NEW RECORD</span><h2>Create contractual deliverable</h2><p>Define ownership, review responsibility and acceptance criteria.</p></div><button type="button" className="icon-button" onClick={() => setShowCreate(false)}><X size={18}/></button></div>
      <label>Project<select required value={form.project_id} onChange={(e) => setForm((v) => ({ ...v, project_id: e.target.value, contract_id: "", owner_user_id: "", reviewer_user_id: "" }))}><option value="">Select project</option>{projects.map((p) => <option key={p.id} value={p.id}>{p.project_code} · {p.name}</option>)}</select></label>
      <label>Contract<select required value={form.contract_id} onChange={(e) => setForm((v) => ({ ...v, contract_id: e.target.value }))}><option value="">Select contract</option>{contracts.filter((c) => c.project_id === form.project_id).map((c) => <option key={c.id} value={c.id}>{c.contract_reference} · {c.contract_title}</option>)}</select></label>
      <div className="cr-form-two"><label>Deliverable code<input required maxLength={80} value={form.deliverable_code} onChange={(e) => setForm((v) => ({ ...v, deliverable_code: e.target.value }))}/></label><label>Deliverable type<select value={form.deliverable_type} onChange={(e) => setForm((v) => ({ ...v, deliverable_type: e.target.value }))}><option value="document">Document</option><option value="software">Software</option><option value="service">Service</option><option value="report">Report</option><option value="other">Other</option></select></label></div>
      <label>Name<input required maxLength={250} value={form.name} onChange={(e) => setForm((v) => ({ ...v, name: e.target.value }))}/></label>
      <label>Description<textarea value={form.description} onChange={(e) => setForm((v) => ({ ...v, description: e.target.value }))}/></label>
      <label>Acceptance criteria<textarea value={form.acceptance_criteria} onChange={(e) => setForm((v) => ({ ...v, acceptance_criteria: e.target.value }))}/></label>
      <div className="cr-form-two"><label>Owner<select value={form.owner_user_id} onChange={(e) => setForm((v) => ({ ...v, owner_user_id: e.target.value }))}><option value="">Unassigned</option>{membersFor(form.project_id).map((m) => <option key={m.user_id} value={m.user_id}>{m.display_name} · {label(m.project_role)}</option>)}</select></label><label>Reviewer<select value={form.reviewer_user_id} onChange={(e) => setForm((v) => ({ ...v, reviewer_user_id: e.target.value }))}><option value="">Unassigned</option>{membersFor(form.project_id).map((m) => <option key={m.user_id} value={m.user_id}>{m.display_name} · {label(m.project_role)}</option>)}</select></label></div>
      <div className="cr-form-two"><label>Due date<input type="date" value={form.due_date} onChange={(e) => setForm((v) => ({ ...v, due_date: e.target.value }))}/></label><label>Accepting authority<input value={form.accepting_authority} onChange={(e) => setForm((v) => ({ ...v, accepting_authority: e.target.value }))} placeholder="Client / committee / role"/></label></div>
      <div className="cr-form-two"><label>Baseline submission date<input type="date" value={form.baseline_submission_date} onChange={(e) => setForm((v) => ({ ...v, baseline_submission_date: e.target.value }))}/></label><label>Baseline acceptance date<input type="date" value={form.baseline_acceptance_date} onChange={(e) => setForm((v) => ({ ...v, baseline_acceptance_date: e.target.value }))}/></label></div>
      <label className="dl-check"><input type="checkbox" checked={form.is_contractual} onChange={(e) => setForm((v) => ({ ...v, is_contractual: e.target.checked }))}/> Contractual deliverable</label>
      <div className="cr-modal-footer"><button type="button" className="button-secondary" onClick={() => setShowCreate(false)}>Cancel</button><button className="button-primary" disabled={busy || !canManage || !contracts.some((c) => c.id === form.contract_id && c.project_id === form.project_id)}>{busy ? <LoaderCircle className="spin" size={15}/> : <FilePlus2 size={15}/>} Create deliverable</button></div>
    </form></div>}
  </div>;
}
