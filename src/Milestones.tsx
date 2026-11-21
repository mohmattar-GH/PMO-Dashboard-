import { useCallback, useEffect, useMemo, useState } from "react";
import type { FormEvent } from "react";
import { AlertCircle, CheckCircle2, FilePlus2, Flag, LoaderCircle, Search, ShieldCheck, X } from "lucide-react";
import { supabase } from "./lib/supabase";

type Project = { id: string; project_code: string; name: string };
type Member = { project_id: string; user_id: string; project_role: string; display_name: string };
type Milestone = {
  id: string; project_id: string; milestone_code: string; name: string; description: string | null;
  milestone_type: string; sequence_no: number | null; weight: number | null;
  baseline_start_date: string | null; baseline_due_date: string | null;
  approved_revised_start_date: string | null; approved_revised_due_date: string | null;
  forecast_start_date: string | null; forecast_due_date: string | null;
  actual_start_date: string | null; actual_due_date: string | null;
  progress_percent: number; status: string; owner_user_id: string | null;
  is_critical: boolean; completion_evidence: string | null;
};
type Rebaseline = {
  id: string; project_id: string; milestone_id: string; request_reference: string; reason: string;
  proposed_start_date: string | null; proposed_due_date: string | null;
  requested_baseline_start_date: string | null; requested_baseline_due_date: string | null;
  status: string; requested_by: string; requested_at: string; decided_by: string | null;
  decided_at: string | null; decision_reason: string | null; applied_at: string | null;
};
type BaselineHistory = { id: string; previous_start_date: string | null; previous_due_date: string | null; new_start_date: string | null; new_due_date: string | null; applied_by: string; applied_at: string; reason: string };
const label = (value: string) => value.replace(/_/g, " ").replace(/\b\w/g, (s) => s.toUpperCase());
const dateTime = (value: string | null) => value ? new Intl.DateTimeFormat(undefined, { dateStyle: "medium", timeStyle: "short" }).format(new Date(value)) : "Not recorded";

export default function Milestones({ canManage, isPlatformAdmin }: { canManage: boolean; isPlatformAdmin: boolean }) {
  const [projects,setProjects]=useState<Project[]>([]);
  const [members,setMembers]=useState<Member[]>([]);
  const [records,setRecords]=useState<Milestone[]>([]);
  const [requests,setRequests]=useState<Rebaseline[]>([]);
  const [baselineHistory,setBaselineHistory]=useState<BaselineHistory[]>([]);
  const [currentUserId,setCurrentUserId]=useState("");
  const [loading,setLoading]=useState(true);
  const [detailLoading,setDetailLoading]=useState(false);
  const [error,setError]=useState("");
  const [notice,setNotice]=useState("");
  const [query,setQuery]=useState("");
  const [projectFilter,setProjectFilter]=useState("all");
  const [statusFilter,setStatusFilter]=useState("all");
  const [selectedId,setSelectedId]=useState<string|null>(null);
  const [busy,setBusy]=useState(false);
  const [showCreate,setShowCreate]=useState(false);
  const [progress,setProgress]=useState({status:"planned",percent:"0",owner:"",forecastStart:"",forecastDue:"",actualStart:"",actualDue:"",evidence:""});
  const [rebaseline,setRebaseline]=useState({start:"",due:"",reason:""});
  const [decisionReason,setDecisionReason]=useState("");
  const [decisionId,setDecisionId]=useState("");
  const [form,setForm]=useState({project:"",code:"",name:"",description:"",type:"delivery",sequence:"",weight:"",baselineStart:"",baselineDue:"",owner:"",critical:false});

  const loadRegister=useCallback(async()=>{
    if(!supabase){setError("Supabase client is not configured.");setLoading(false);return;}
    setLoading(true);setError("");
    const [{data:userData},pr,mr,rr,mem]=await Promise.all([
      supabase.auth.getUser(),
      supabase.from("projects").select("id,project_code,name").order("project_code"),
      supabase.from("project_milestones").select("id,project_id,milestone_code,name,description,milestone_type,sequence_no,weight,baseline_start_date,baseline_due_date,approved_revised_start_date,approved_revised_due_date,forecast_start_date,forecast_due_date,actual_start_date,actual_due_date,progress_percent,status,owner_user_id,is_critical,completion_evidence").order("sequence_no"),
      supabase.from("project_milestone_rebaseline_requests").select("id,project_id,milestone_id,request_reference,reason,proposed_start_date,proposed_due_date,requested_baseline_start_date,requested_baseline_due_date,status,requested_by,requested_at,decided_by,decided_at,decision_reason,applied_at").order("requested_at",{ascending:false}),
      supabase.from("project_memberships").select("project_id,user_id,project_role").eq("status","active").lte("effective_from",new Date().toISOString()).or("effective_to.is.null,effective_to.gt."+new Date().toISOString())
    ]);
    if(pr.error||mr.error){setError(pr.error?.message||mr.error?.message||"Unable to load milestones.");setLoading(false);return;}
    setCurrentUserId(userData.user?.id??"");setProjects((pr.data??[]) as Project[]);setRecords((mr.data??[]) as Milestone[]);setRequests((rr.data??[]) as Rebaseline[]);
    const raw=(mem.data??[]) as Omit<Member,"display_name">[];const ids=[...new Set(raw.map((m)=>m.user_id))];
    const profiles=ids.length?await supabase.from("user_profiles").select("user_id,display_name").in("user_id",ids):{data:[],error:null};
    const names=new Map((profiles.data??[]).map((p:{user_id:string;display_name:string|null})=>[p.user_id,p.display_name||p.user_id.slice(0,8)]));
    setMembers(raw.map((m)=>({...m,display_name:names.get(m.user_id)??m.user_id.slice(0,8)})));setLoading(false);
  },[]);
  useEffect(()=>{void loadRegister();},[loadRegister]);

  const selected=records.find((m)=>m.id===selectedId)??null;
  const membersFor=(projectId:string)=>members.filter((m)=>m.project_id===projectId);
  const isPM=(projectId:string)=>membersFor(projectId).some((m)=>m.user_id===currentUserId&&m.project_role==="project_manager");
  const canManageProject=(projectId:string)=>isPlatformAdmin||isPM(projectId);
  const projectName=(id:string)=>projects.find((p)=>p.id===id)?.name??"Project";
  const memberName=(id:string|null,projectId:string)=>id?membersFor(projectId).find((m)=>m.user_id===id)?.display_name??id.slice(0,8):"Unassigned";
  const filtered=useMemo(()=>records.filter((m)=>(projectFilter==="all"||m.project_id===projectFilter)&&(statusFilter==="all"||m.status===statusFilter)&&[m.milestone_code,m.name,projectName(m.project_id)].join(" ").toLowerCase().includes(query.trim().toLowerCase())),[records,projects,projectFilter,statusFilter,query]);

  const loadDetail=useCallback(async(record:Milestone)=>{
    if(!supabase)return;setSelectedId(record.id);setDetailLoading(true);
    setProgress({status:record.status,percent:String(record.progress_percent),owner:record.owner_user_id??"",forecastStart:record.forecast_start_date??"",forecastDue:record.forecast_due_date??"",actualStart:record.actual_start_date??"",actualDue:record.actual_due_date??"",evidence:record.completion_evidence??""});
    setRebaseline({start:"",due:"",reason:""});setDecisionReason("");setDecisionId("");
    const h=await supabase.from("project_milestone_baseline_history").select("id,previous_start_date,previous_due_date,new_start_date,new_due_date,applied_by,applied_at,reason").eq("milestone_id",record.id).order("applied_at",{ascending:false});
    if(h.error)setNotice("Baseline history is not available: "+h.error.message);
    setBaselineHistory((h.data??[]) as BaselineHistory[]);setDetailLoading(false);
  },[]);

  const createMilestone=async(event:FormEvent)=>{
    event.preventDefault();if(!supabase)return;
    if(form.baselineStart&&form.baselineDue&&form.baselineStart>form.baselineDue){setNotice("Baseline start cannot be after baseline due date.");return;}
    if(form.weight!==""&&(Number(form.weight)<0||Number(form.weight)>1)){setNotice("Weight must be between 0 and 1.");return;}
    setBusy(true);setNotice("");
    const {data,error:createError}=await supabase.from("project_milestones").insert({
      project_id:form.project,milestone_code:form.code.trim(),name:form.name.trim(),description:form.description.trim()||null,
      milestone_type:form.type.trim()||"delivery",sequence_no:form.sequence===""?null:Number(form.sequence),weight:form.weight===""?null:Number(form.weight),
      baseline_start_date:form.baselineStart||null,baseline_due_date:form.baselineDue||null,owner_user_id:form.owner||null,
      is_critical:form.critical,status:"planned",progress_percent:0
    }).select("id").single();
    if(createError)setNotice("Could not create milestone: "+createError.message);
    else{
      setShowCreate(false);setForm({project:"",code:"",name:"",description:"",type:"delivery",sequence:"",weight:"",baselineStart:"",baselineDue:"",owner:"",critical:false});
      await loadRegister();setNotice("Milestone created.");
      if(data?.id){const row=await supabase.from("project_milestones").select("id,project_id,milestone_code,name,description,milestone_type,sequence_no,weight,baseline_start_date,baseline_due_date,approved_revised_start_date,approved_revised_due_date,forecast_start_date,forecast_due_date,actual_start_date,actual_due_date,progress_percent,status,owner_user_id,is_critical,completion_evidence").eq("id",data.id).single();if(row.data)await loadDetail(row.data as Milestone);}
    }setBusy(false);
  };

  const saveProgress=async()=>{
    if(!supabase||!selected)return;const pct=Number(progress.percent);
    if(!Number.isFinite(pct)||pct<0||pct>100){setNotice("Progress must be between 0 and 100.");return;}
    if(progress.actualStart&&progress.actualDue&&progress.actualStart>progress.actualDue){setNotice("Actual start cannot be after actual completion.");return;}
    if(progress.forecastStart&&progress.forecastDue&&progress.forecastStart>progress.forecastDue){setNotice("Forecast start cannot be after forecast due.");return;}
    if(progress.status==="completed"&&(pct!==100||progress.evidence.trim().length<8)){setNotice("Completed milestones require 100% progress and completion evidence of at least 8 characters.");return;}
    setBusy(true);setNotice("");
    const {error:updateError}=await supabase.from("project_milestones").update({
      status:progress.status,progress_percent:pct,owner_user_id:progress.owner||null,forecast_start_date:progress.forecastStart||null,
      forecast_due_date:progress.forecastDue||null,actual_start_date:progress.actualStart||null,actual_due_date:progress.actualDue||null,
      completion_evidence:progress.evidence.trim()||null
    }).eq("id",selected.id);
    if(updateError)setNotice("Milestone update failed: "+updateError.message);
    else{setNotice("Milestone progress updated.");await loadRegister();await loadDetail({...selected,status:progress.status,progress_percent:pct,owner_user_id:progress.owner||null,forecast_start_date:progress.forecastStart||null,forecast_due_date:progress.forecastDue||null,actual_start_date:progress.actualStart||null,actual_due_date:progress.actualDue||null,completion_evidence:progress.evidence.trim()||null});}
    setBusy(false);
  };

  const requestBaseline=async()=>{
    if(!supabase||!selected)return;if(!rebaseline.start&&!rebaseline.due){setNotice("Enter at least one proposed baseline date.");return;}
    if(rebaseline.reason.trim().length<8){setNotice("A re-baseline reason of at least 8 characters is required.");return;}
    setBusy(true);setNotice("");
    const {error:err}=await supabase.rpc("request_milestone_rebaseline",{p_milestone_id:selected.id,p_proposed_start_date:rebaseline.start||null,p_proposed_due_date:rebaseline.due||null,p_reason:rebaseline.reason.trim()});
    if(err)setNotice("Re-baseline request failed: "+err.message);
    else{setNotice("Re-baseline request submitted. An independent PM/Admin must decide.");setRebaseline({start:"",due:"",reason:""});await loadRegister();}
    setBusy(false);
  };

  const decideBaseline=async(r:Rebaseline,decision:"approve"|"reject")=>{
    if(!supabase)return;if(decisionReason.trim().length<8){setNotice("Decision reason must be at least 8 characters.");return;}
    setBusy(true);setNotice("");
    const {error:err}=await supabase.rpc("decide_milestone_rebaseline",{p_request_id:r.id,p_decision:decision,p_decision_reason:decisionReason.trim()});
    if(err)setNotice("Re-baseline decision failed: "+err.message);
    else{setNotice(decision==="approve"?"Re-baseline approved and applied.":"Re-baseline request rejected.");setDecisionReason("");setDecisionId("");await loadRegister();if(selected)await loadDetail(selected);}
    setBusy(false);
  };

  const selectedRequests=requests.filter((r)=>r.milestone_id===selected?.id);
  const pendingCount=requests.filter((r)=>r.status==="submitted").length;

  return <div className="ms-module">
    <div className="ms-toolbar">
      <div className="ms-search"><Search size={15}/><input value={query} onChange={(e)=>setQuery(e.target.value)} placeholder="Search milestone or project"/></div>
      <select value={projectFilter} onChange={(e)=>setProjectFilter(e.target.value)}><option value="all">All projects</option>{projects.map((p)=><option key={p.id} value={p.id}>{p.project_code} · {p.name}</option>)}</select>
      <select value={statusFilter} onChange={(e)=>setStatusFilter(e.target.value)}><option value="all">All statuses</option>{["planned","in_progress","at_risk","delayed","blocked","completed"].map((s)=><option key={s} value={s}>{label(s)}</option>)}</select>
      <span className="ms-spacer"/>{canManage&&<button className="button-primary" onClick={()=>setShowCreate(true)}><FilePlus2 size={15}/> New Milestone</button>}
    </div>
    <div className="ms-summary">{[["Total milestones",records.length],["Completed",records.filter((m)=>m.status==="completed").length],["Critical open",records.filter((m)=>m.is_critical&&m.status!=="completed").length],["Re-baseline pending",pendingCount]].map(([name,count])=><article key={String(name)}><span>{name}</span><strong>{loading?"—":count}</strong></article>)}</div>
    {error&&<div className="cr-message error"><AlertCircle size={16}/>{error}</div>}
    {notice&&<div className="cr-message"><CheckCircle2 size={16}/><span>{notice}</span><button onClick={()=>setNotice("")} aria-label="Dismiss"><X size={14}/></button></div>}
    <div className="ms-grid">
      <section className="panel ms-register"><div className="panel-heading"><div><h3>Milestone Register</h3><span className="panel-subtitle">Delivery commitments · baseline, forecast and actual tracking</span></div><span className="cr-count">{loading?"Loading…":filtered.length+" records"}</span></div>
        {loading?<div className="cr-empty"><LoaderCircle className="spin" size={20}/> Loading milestones…</div>:filtered.length===0?<div className="cr-empty"><Flag size={22}/><strong>No milestones found</strong><span>No milestones match the filters or are visible to this account.</span></div>:
        <div className="ms-list">{filtered.map((m)=><button key={m.id} className={selectedId===m.id?"ms-row selected":"ms-row"} onClick={()=>void loadDetail(m)}>
          <span><strong>{m.milestone_code} · {m.name}</strong><small>{projectName(m.project_id)} · Owner: {memberName(m.owner_user_id,m.project_id)}</small></span>
          <span className={"cr-status "+(m.status==="completed"?"success":["delayed","blocked","at_risk"].includes(m.status)?"danger":"neutral")}>{label(m.status)}</span>
          <div className="ms-progress"><i><span style={{width:m.progress_percent+"%"}}/></i><small>{m.progress_percent}%</small>{m.is_critical&&<b>Critical</b>}</div>
          <small>{m.approved_revised_due_date||m.baseline_due_date||"No baseline due date"}</small>
        </button>)}</div>}
      </section>
      <section className="panel ms-detail">
        {!selected?<div className="cr-empty cr-detail-empty"><ShieldCheck size={26}/><strong>Milestone workspace</strong><span>Select a milestone to track progress, baseline dates and re-baseline decisions.</span></div>:
        detailLoading?<div className="cr-empty"><LoaderCircle className="spin" size={20}/> Loading milestone…</div>:
        <div className="ms-detail-body">
          <div className="cr-detail-header"><div><span className="cr-reference">{selected.milestone_code}</span><span className="cr-status">{label(selected.status)}</span><h2>{selected.name}</h2><p>{projectName(selected.project_id)} · {label(selected.milestone_type)}{selected.is_critical?" · Critical":""}</p></div><button className="icon-button" onClick={()=>setSelectedId(null)} aria-label="Close detail"><X size={17}/></button></div>
          {selected.description&&<div className="ms-section"><p>{selected.description}</p></div>}
          <div className="ms-date-grid"><div><small>Baseline</small><strong>{selected.baseline_start_date||"—"} → {selected.baseline_due_date||"—"}</strong></div><div><small>Approved revised</small><strong>{selected.approved_revised_start_date||"—"} → {selected.approved_revised_due_date||"—"}</strong></div><div><small>Forecast</small><strong>{selected.forecast_start_date||"—"} → {selected.forecast_due_date||"—"}</strong></div><div><small>Actual</small><strong>{selected.actual_start_date||"—"} → {selected.actual_due_date||"—"}</strong></div></div>
          <div className="ms-section"><div className="cr-section-title"><div><h3>Progress tracking</h3><p>Baseline dates cannot be edited here. Submit a re-baseline request for controlled changes.</p></div><span className="cr-status">{selected.progress_percent}%</span></div>
            <div className="ms-owner-row"><span>Owner</span><strong>{memberName(selected.owner_user_id,selected.project_id)}</strong><span>Weight</span><strong>{selected.weight===null?"Not set":(Number(selected.weight)*100).toFixed(1)+"%"}</strong></div>
            {canManageProject(selected.project_id)?<div className="ms-edit-form">
              <div className="cr-form-two"><label>Status<select value={progress.status} onChange={(e)=>setProgress((v)=>({...v,status:e.target.value}))}>{["planned","in_progress","at_risk","delayed","blocked","completed"].map((s)=><option key={s} value={s}>{label(s)}</option>)}</select></label><label>Progress %<input type="number" min="0" max="100" value={progress.percent} onChange={(e)=>setProgress((v)=>({...v,percent:e.target.value}))}/></label></div>
              <label>Owner<select value={progress.owner} onChange={(e)=>setProgress((v)=>({...v,owner:e.target.value}))}><option value="">Unassigned</option>{membersFor(selected.project_id).map((m)=><option key={m.user_id} value={m.user_id}>{m.display_name} · {label(m.project_role)}</option>)}</select></label>
              <div className="cr-form-two"><label>Forecast start<input type="date" value={progress.forecastStart} onChange={(e)=>setProgress((v)=>({...v,forecastStart:e.target.value}))}/></label><label>Forecast due<input type="date" value={progress.forecastDue} onChange={(e)=>setProgress((v)=>({...v,forecastDue:e.target.value}))}/></label></div>
              <div className="cr-form-two"><label>Actual start<input type="date" value={progress.actualStart} onChange={(e)=>setProgress((v)=>({...v,actualStart:e.target.value}))}/></label><label>Actual completion<input type="date" value={progress.actualDue} onChange={(e)=>setProgress((v)=>({...v,actualDue:e.target.value}))}/></label></div>
              {progress.status==="completed"&&<label>Completion evidence<textarea value={progress.evidence} onChange={(e)=>setProgress((v)=>({...v,evidence:e.target.value}))} placeholder="Evidence reference or acceptance details"/></label>}
              <button className="button-primary" disabled={busy} onClick={()=>void saveProgress()}>{busy?"Saving…":"Save progress update"}</button>
            </div>:<div className="ms-read-progress"><strong>{selected.progress_percent}% complete</strong><span>{selected.completion_evidence||"No completion evidence recorded."}</span></div>}
          </div>
          {canManageProject(selected.project_id)&&selected.status!=="completed"&&<div className="ms-section"><div className="cr-section-title"><div><h3>Request baseline revision</h3><p>An independent PM/Admin decision is required. Baseline remains unchanged until approval.</p></div></div>
            <div className="ms-edit-form"><div className="cr-form-two"><label>Proposed baseline start<input type="date" value={rebaseline.start} onChange={(e)=>setRebaseline((v)=>({...v,start:e.target.value}))}/></label><label>Proposed baseline due<input type="date" value={rebaseline.due} onChange={(e)=>setRebaseline((v)=>({...v,due:e.target.value}))}/></label></div><label>Reason<textarea value={rebaseline.reason} onChange={(e)=>setRebaseline((v)=>({...v,reason:e.target.value}))} placeholder="Reason for baseline change (minimum 8 characters)"/></label><button className="button-secondary" disabled={busy||(!rebaseline.start&&!rebaseline.due)||rebaseline.reason.trim().length<8} onClick={()=>void requestBaseline()}>{busy?"Submitting…":"Submit re-baseline request"}</button></div>
          </div>}
          <div className="ms-section"><div className="cr-section-title"><div><h3>Re-baseline request history</h3><p>Requests, independent decisions and application status.</p></div></div>
            {selectedRequests.length===0?<div className="cr-inline-empty">No re-baseline requests for this milestone.</div>:<div className="ms-request-list">{selectedRequests.map((r)=><article key={r.id}><div className="ms-request-head"><strong>{r.request_reference}</strong><span className={"cr-status "+(r.status==="applied"?"success":r.status==="rejected"?"danger":"warning")}>{label(r.status)}</span></div><p>{r.reason}</p><div className="ms-request-dates"><span>Baseline at request: {r.requested_baseline_start_date||"—"} → {r.requested_baseline_due_date||"—"}</span><span>Proposed: {r.proposed_start_date||"—"} → {r.proposed_due_date||"—"}</span></div><small>{dateTime(r.requested_at)} · Requested by {memberName(r.requested_by,selected.project_id)}</small>{r.decision_reason&&<div className="ms-decision-note">Decision: {r.decision_reason}</div>}
              {canManageProject(selected.project_id)&&r.status==="submitted"&&r.requested_by!==currentUserId&&<div className="ms-decision-form"><textarea value={decisionId===r.id?decisionReason:""} onChange={(e)=>{setDecisionId(r.id);setDecisionReason(e.target.value);}} placeholder="Independent decision reason (minimum 8 characters)"/><div><button className="button-secondary" disabled={busy||decisionId!==r.id||decisionReason.trim().length<8} onClick={()=>void decideBaseline(r,"reject")}>Reject</button><button className="button-primary" disabled={busy||decisionId!==r.id||decisionReason.trim().length<8} onClick={()=>void decideBaseline(r,"approve")}>Approve and apply</button></div></div>}
            </article>)}</div>}
          </div>
          <div className="ms-section"><div className="cr-section-title"><div><h3>Baseline change audit</h3><p>Previous baselines are retained after approved changes.</p></div><button className="text-action" onClick={()=>void loadDetail(selected)}>Refresh</button></div>
            {baselineHistory.length===0?<div className="cr-inline-empty">No approved baseline changes recorded.</div>:<div className="ms-history">{baselineHistory.map((h)=><article key={h.id}><strong>{h.previous_start_date||"—"} → {h.previous_due_date||"—"}</strong><span>Changed to {h.new_start_date||"—"} → {h.new_due_date||"—"}</span><small>{dateTime(h.applied_at)} · {h.reason}</small></article>)}</div>}
          </div>
        </div>}
      </section>
    </div>
    {showCreate&&<div className="cr-modal-backdrop" role="presentation" onMouseDown={(e)=>{if(e.target===e.currentTarget)setShowCreate(false);}}><form className="cr-create-modal ms-create-modal" onSubmit={createMilestone}>
      <div className="cr-modal-heading"><div><span>NEW RECORD</span><h2>Create milestone</h2><p>Set initial baseline dates, accountable owner and criticality.</p></div><button type="button" className="icon-button" onClick={()=>setShowCreate(false)}><X size={18}/></button></div>
      <label>Project<select required value={form.project} onChange={(e)=>setForm((v)=>({...v,project:e.target.value,owner:""}))}><option value="">Select project</option>{projects.map((p)=><option key={p.id} value={p.id}>{p.project_code} · {p.name}</option>)}</select></label>
      <div className="cr-form-two"><label>Milestone code<input required maxLength={80} value={form.code} onChange={(e)=>setForm((v)=>({...v,code:e.target.value}))}/></label><label>Milestone type<input value={form.type} onChange={(e)=>setForm((v)=>({...v,type:e.target.value}))}/></label></div>
      <label>Name<input required maxLength={250} value={form.name} onChange={(e)=>setForm((v)=>({...v,name:e.target.value}))}/></label>
      <label>Description<textarea value={form.description} onChange={(e)=>setForm((v)=>({...v,description:e.target.value}))}/></label>
      <div className="cr-form-two"><label>Baseline start<input type="date" value={form.baselineStart} onChange={(e)=>setForm((v)=>({...v,baselineStart:e.target.value}))}/></label><label>Baseline due<input type="date" value={form.baselineDue} onChange={(e)=>setForm((v)=>({...v,baselineDue:e.target.value}))}/></label></div>
      <div className="cr-form-two"><label>Sequence<input type="number" min="1" value={form.sequence} onChange={(e)=>setForm((v)=>({...v,sequence:e.target.value}))}/></label><label>Weight (0–1)<input type="number" min="0" max="1" step="0.01" value={form.weight} onChange={(e)=>setForm((v)=>({...v,weight:e.target.value}))}/></label></div>
      <label>Owner<select value={form.owner} onChange={(e)=>setForm((v)=>({...v,owner:e.target.value}))}><option value="">Unassigned</option>{membersFor(form.project).map((m)=><option key={m.user_id} value={m.user_id}>{m.display_name} · {label(m.project_role)}</option>)}</select></label>
      <label className="ms-check"><input type="checkbox" checked={form.critical} onChange={(e)=>setForm((v)=>({...v,critical:e.target.checked}))}/> Critical milestone</label>
      <div className="cr-modal-footer"><button type="button" className="button-secondary" onClick={()=>setShowCreate(false)}>Cancel</button><button className="button-primary" disabled={busy||!canManage||!form.project}>{busy?<LoaderCircle className="spin" size={15}/>:<FilePlus2 size={15}/>} Create milestone</button></div>
    </form></div>}
  </div>;
}
