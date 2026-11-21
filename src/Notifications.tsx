import { useCallback, useEffect, useMemo, useState } from "react";
import type { FormEvent } from "react";
import { AlertCircle, Bell, Check, CheckCheck, CheckCircle2, Clock3, LoaderCircle, Plus, Save, ShieldCheck, X } from "lucide-react";
import { supabase } from "./lib/supabase";

type Project={id:string;project_code:string;name:string};
type Notification={id:string;recipient_user_id:string;project_id:string|null;rule_id:string|null;event_code:string;severity:string;title:string;message:string;source_table:string|null;source_record_id:string|null;deep_link:string|null;is_read:boolean;read_at:string|null;requires_acknowledgement:boolean;acknowledged_at:string|null;expires_at:string|null;created_at:string};
type Rule={id:string;rule_code:string;rule_name:string;module_code:string;event_code:string;is_enabled:boolean;severity:string;trigger_conditions:Record<string,unknown>;recipient_rules:Record<string,unknown>;lead_time_minutes:number;repeat_interval_minutes:number|null;escalation_rules:Record<string,unknown>;timezone_mode:string;quiet_hours:Record<string,unknown>;requires_acknowledgement:boolean;effective_from:string|null;effective_to:string|null;version_no:number};
type RuleHistory={id:string;rule_id:string;version_no:number;rule_snapshot:Record<string,unknown>;changed_by:string;changed_at:string};
const label=(value:string)=>value.replace(/_/g," ").replace(/\b\w/g,(s)=>s.toUpperCase());
const dateTime=(value:string)=>new Intl.DateTimeFormat(undefined,{dateStyle:"medium",timeStyle:"short"}).format(new Date(value));

export default function Notifications({isAdmin,onUnreadChange}:{isAdmin:boolean;onUnreadChange:(count:number)=>void}){
  const [tab,setTab]=useState<"inbox"|"rules">("inbox");
  const [userId,setUserId]=useState("");
  const [projects,setProjects]=useState<Project[]>([]);
  const [notifications,setNotifications]=useState<Notification[]>([]);
  const [rules,setRules]=useState<Rule[]>([]);
  const [history,setHistory]=useState<RuleHistory[]>([]);
  const [loading,setLoading]=useState(true);
  const [busy,setBusy]=useState(false);
  const [error,setError]=useState("");
  const [notice,setNotice]=useState("");
  const [readFilter,setReadFilter]=useState("unread");
  const [severityFilter,setSeverityFilter]=useState("all");
  const [editingId,setEditingId]=useState<string|null>(null);
  const [ruleForm,setRuleForm]=useState({rule_code:"",rule_name:"",module_code:"change_request",event_code:"cr_submitted",is_enabled:true,severity:"normal",project_roles:"project_manager",global_roles:"platform_admin",include_target_users:true,exclude_actor:true,requires_acknowledgement:false});

  const load=useCallback(async()=>{
    if(!supabase){setError("Supabase client is not configured.");setLoading(false);return;}
    setLoading(true);setError("");
    const [{data:userData},inboxResult,projectResult]=await Promise.all([
      supabase.auth.getUser(),
      supabase.from("ppm_user_notifications").select("id,recipient_user_id,project_id,rule_id,event_code,severity,title,message,source_table,source_record_id,deep_link,is_read,read_at,requires_acknowledgement,acknowledged_at,expires_at,created_at").order("created_at",{ascending:false}).limit(250),
      supabase.from("projects").select("id,project_code,name")
    ]);
    const uid=userData.user?.id??"";setUserId(uid);
    if(inboxResult.error)setError("Notification inbox could not be loaded: "+inboxResult.error.message);
    else setNotifications((inboxResult.data??[]) as Notification[]);
    setProjects((projectResult.data??[]) as Project[]);
    if(isAdmin){
      const ruleResult=await supabase.from("ppm_notification_rules").select("id,rule_code,rule_name,module_code,event_code,is_enabled,severity,trigger_conditions,recipient_rules,lead_time_minutes,repeat_interval_minutes,escalation_rules,timezone_mode,quiet_hours,requires_acknowledgement,effective_from,effective_to,version_no").order("module_code").order("event_code");
      if(ruleResult.error)setError("Notification rules could not be loaded: "+ruleResult.error.message);
      else setRules((ruleResult.data??[]) as Rule[]);
    }else setRules([]);
    setLoading(false);
  },[isAdmin]);
  useEffect(()=>{void load();},[load]);
  useEffect(()=>{onUnreadChange(notifications.filter((n)=>!n.is_read).length);},[notifications,onUnreadChange]);

  const unreadCount=notifications.filter((n)=>!n.is_read).length;
  const pendingAck=notifications.filter((n)=>n.requires_acknowledgement&&!n.acknowledged_at).length;
  const filtered=useMemo(()=>notifications.filter((n)=>(readFilter==="all"||(readFilter==="unread"&&!n.is_read)||(readFilter==="read"&&n.is_read))&&(severityFilter==="all"||n.severity===severityFilter)),[notifications,readFilter,severityFilter]);
  const projectName=(id:string|null)=>id?projects.find((p)=>p.id===id)?.name??"Project":"Portfolio";

  const markRead=async(item:Notification)=>{
    if(!supabase||item.is_read)return;setBusy(true);setNotice("");
    const {error:err}=await supabase.from("ppm_user_notifications").update({is_read:true}).eq("id",item.id).eq("recipient_user_id",userId);
    if(err)setNotice("Could not mark notification as read: "+err.message);
    else{setNotifications((list)=>list.map((n)=>n.id===item.id?{...n,is_read:true,read_at:new Date().toISOString()}:n));}
    setBusy(false);
  };
  const acknowledge=async(item:Notification)=>{
    if(!supabase||item.acknowledged_at)return;setBusy(true);setNotice("");
    const {error:err}=await supabase.from("ppm_user_notifications").update({is_read:true,acknowledged_at:new Date().toISOString()}).eq("id",item.id).eq("recipient_user_id",userId);
    if(err)setNotice("Could not acknowledge notification: "+err.message);
    else{setNotifications((list)=>list.map((n)=>n.id===item.id?{...n,is_read:true,read_at:n.read_at??new Date().toISOString(),acknowledged_at:new Date().toISOString()}:n));}
    setBusy(false);
  };
  const markAllRead=async()=>{
    if(!supabase||!userId||unreadCount===0)return;setBusy(true);setNotice("");
    const {error:err}=await supabase.from("ppm_user_notifications").update({is_read:true}).eq("recipient_user_id",userId).eq("is_read",false);
    if(err)setNotice("Could not mark inbox as read: "+err.message);
    else{setNotifications((list)=>list.map((n)=>({...n,is_read:true,read_at:n.read_at??new Date().toISOString()})));setNotice("All notifications marked as read.");}
    setBusy(false);
  };

  const chooseRule=(rule:Rule)=>{
    const recipients=rule.recipient_rules??{};
    setEditingId(rule.id);
    setRuleForm({
      rule_code:rule.rule_code,rule_name:rule.rule_name,module_code:rule.module_code,event_code:rule.event_code,
      is_enabled:rule.is_enabled,severity:rule.severity,
      project_roles:Array.isArray(recipients.project_roles)?(recipients.project_roles as string[]).join(", "):"",
      global_roles:Array.isArray(recipients.global_roles)?(recipients.global_roles as string[]).join(", "):"",
      include_target_users:recipients.include_target_users===true,exclude_actor:recipients.exclude_actor!==false,
      requires_acknowledgement:rule.requires_acknowledgement
    });
    void loadRuleHistory(rule.id);
  };
  const loadRuleHistory=async(id:string)=>{
    if(!supabase||!isAdmin)return;
    const {data,error:err}=await supabase.from("ppm_notification_rule_history").select("id,rule_id,version_no,rule_snapshot,changed_by,changed_at").eq("rule_id",id).order("version_no",{ascending:false});
    if(err)setNotice("Rule history unavailable: "+err.message);else setHistory((data??[]) as RuleHistory[]);
  };
  const resetRule=()=>{
    setEditingId(null);setHistory([]);
    setRuleForm({rule_code:"",rule_name:"",module_code:"change_request",event_code:"cr_submitted",is_enabled:true,severity:"normal",project_roles:"project_manager",global_roles:"platform_admin",include_target_users:true,exclude_actor:true,requires_acknowledgement:false});
  };
  const saveRule=async(event:FormEvent)=>{
    event.preventDefault();if(!supabase||!isAdmin)return;
    if(!ruleForm.rule_code.trim()||!ruleForm.rule_name.trim()||!ruleForm.module_code.trim()||!ruleForm.event_code.trim()){setNotice("Complete the rule code, name, module and event.");return;}
    const recipientRules={
      project_roles:ruleForm.project_roles.split(",").map((v)=>v.trim()).filter(Boolean),
      global_roles:ruleForm.global_roles.split(",").map((v)=>v.trim()).filter(Boolean),
      include_target_users:ruleForm.include_target_users,exclude_actor:ruleForm.exclude_actor
    };
    setBusy(true);setNotice("");
    const payload={rule_code:ruleForm.rule_code.trim(),rule_name:ruleForm.rule_name.trim(),module_code:ruleForm.module_code.trim(),event_code:ruleForm.event_code.trim(),is_enabled:ruleForm.is_enabled,severity:ruleForm.severity,trigger_conditions:{},recipient_rules:recipientRules,lead_time_minutes:0,repeat_interval_minutes:null,escalation_rules:{},timezone_mode:"project",quiet_hours:{},requires_acknowledgement:ruleForm.requires_acknowledgement};
    const result=editingId
      ? await supabase.from("ppm_notification_rules").update(payload).eq("id",editingId).select("id,version_no").single()
      : await supabase.from("ppm_notification_rules").insert({...payload,created_by:userId}).select("id,version_no").single();
    if(result.error)setNotice("Notification rule could not be saved: "+result.error.message);
    else{setNotice(editingId?"Notification rule updated as a new version.":"Notification rule created.");await load();if(result.data?.id){setEditingId(result.data.id);setHistoryRuleId(result.data.id);await loadRuleHistory(result.data.id);}}
    setBusy(false);
  };

  return <div className="nt-module">
    <div className="nt-header"><div><div className="nt-eyebrow">PERSONAL INBOX · GOVERNED EVENTS</div><h2>Notifications</h2><p>Recipient-scoped alerts and administrator-managed event rules.</p></div><div className="nt-tabs"><button className={tab==="inbox"?"active":""} onClick={()=>setTab("inbox")}><Bell size={14}/> Inbox <b>{unreadCount}</b></button>{isAdmin&&<button className={tab==="rules"?"active":""} onClick={()=>setTab("rules")}><ShieldCheck size={14}/> Rules</button>}</div></div>
    <div className="nt-summary"><article><span>Unread</span><strong>{loading?"—":unreadCount}</strong></article><article><span>Needs acknowledgement</span><strong>{loading?"—":pendingAck}</strong></article><article><span>Visible notifications</span><strong>{loading?"—":notifications.length}</strong></article></div>
    {error&&<div className="cr-message error"><AlertCircle size={16}/>{error}</div>}
    {notice&&<div className="cr-message"><CheckCircle2 size={16}/><span>{notice}</span><button onClick={()=>setNotice("")} aria-label="Dismiss"><X size={14}/></button></div>}

    {tab==="inbox"?<section className="panel nt-inbox">
      <div className="panel-heading"><div><h3>Your notification inbox</h3><span className="panel-subtitle">Only notifications addressed to your authenticated account are shown.</span></div><div className="nt-inbox-tools"><select value={readFilter} onChange={(e)=>setReadFilter(e.target.value)}><option value="unread">Unread</option><option value="read">Read</option><option value="all">All</option></select><select value={severityFilter} onChange={(e)=>setSeverityFilter(e.target.value)}><option value="all">All severity</option>{["info","normal","warning","critical"].map((s)=><option key={s} value={s}>{label(s)}</option>)}</select><button className="text-action" disabled={busy||unreadCount===0} onClick={()=>void markAllRead()}><CheckCheck size={13}/> Mark all read</button></div></div>
      {loading?<div className="cr-empty"><LoaderCircle className="spin" size={20}/> Loading inbox…</div>:filtered.length===0?<div className="cr-empty"><Bell size={22}/><strong>No notifications</strong><span>No notifications match the selected filters.</span></div>:
      <div className="nt-list">{filtered.map((item)=><article key={item.id} className={item.is_read?"nt-item read":"nt-item unread"}>
        <div className={"nt-severity "+item.severity}/><div className="nt-item-body"><div className="nt-item-head"><strong>{item.title}</strong><span className={"nt-badge "+item.severity}>{label(item.severity)}</span></div><p>{item.message}</p><div className="nt-meta"><span>{projectName(item.project_id)}</span><span>{label(item.event_code)}</span><span>{dateTime(item.created_at)}</span>{item.expires_at&&<span>Expires {dateTime(item.expires_at)}</span>}</div>
          {item.requires_acknowledgement&&!item.acknowledged_at&&<div className="nt-ack-note"><Clock3 size={13}/> Acknowledgement required</div>}
          {item.acknowledged_at&&<div className="nt-ack-note done"><Check size={13}/> Acknowledged {dateTime(item.acknowledged_at)}</div>}
        </div><div className="nt-item-actions">{!item.is_read&&<button className="button-secondary small" disabled={busy} onClick={()=>void markRead(item)}>Mark read</button>}{item.requires_acknowledgement&&!item.acknowledged_at&&<button className="button-primary small" disabled={busy} onClick={()=>void acknowledge(item)}>Acknowledge</button>}</div>
      </article>)}</div>}
    </section>:<div className="nt-rules-layout">
      <section className="panel nt-rule-list"><div className="panel-heading"><div><h3>Notification rules</h3><span className="panel-subtitle">Administrator-only · versioned configuration</span></div><button className="button-primary small" onClick={resetRule}><Plus size={14}/> New rule</button></div>
        {rules.length===0?<div className="cr-empty"><ShieldCheck size={22}/><strong>No rules configured</strong><span>Create an event rule to route notifications to project or global roles.</span></div>:rules.map((rule)=><button key={rule.id} className={editingId===rule.id?"nt-rule-row selected":"nt-rule-row"} onClick={()=>chooseRule(rule)}><span><strong>{rule.rule_name}</strong><small>{rule.module_code} · {rule.event_code}</small></span><span className={"cr-status "+(rule.is_enabled?"success":"neutral")}>{rule.is_enabled?"Enabled":"Disabled"}</span><small>v{rule.version_no}</small></button>)}
      </section>
      <section className="panel nt-rule-editor"><div className="panel-heading"><div><h3>{editingId?"Edit notification rule":"Create notification rule"}</h3><span className="panel-subtitle">Changes are versioned; existing history is retained.</span></div>{editingId&&<button className="text-action" onClick={resetRule}>New rule</button>}</div>
        <form className="nt-rule-form" onSubmit={saveRule}>
          <div className="cr-form-two"><label>Rule code<input required value={ruleForm.rule_code} onChange={(e)=>setRuleForm((v)=>({...v,rule_code:e.target.value}))}/></label><label>Rule name<input required value={ruleForm.rule_name} onChange={(e)=>setRuleForm((v)=>({...v,rule_name:e.target.value}))}/></label></div>
          <div className="cr-form-two"><label>Module code<input required value={ruleForm.module_code} onChange={(e)=>setRuleForm((v)=>({...v,module_code:e.target.value}))} placeholder="change_request"/></label><label>Event code<input required value={ruleForm.event_code} onChange={(e)=>setRuleForm((v)=>({...v,event_code:e.target.value}))} placeholder="cr_submitted"/></label></div>
          <div className="cr-form-two"><label>Severity<select value={ruleForm.severity} onChange={(e)=>setRuleForm((v)=>({...v,severity:e.target.value}))}>{["info","normal","warning","critical"].map((s)=><option key={s} value={s}>{label(s)}</option>)}</select></label><label className="nt-check"><input type="checkbox" checked={ruleForm.is_enabled} onChange={(e)=>setRuleForm((v)=>({...v,is_enabled:e.target.checked}))}/> Enabled</label></div>
          <label>Project roles (comma-separated)<input value={ruleForm.project_roles} onChange={(e)=>setRuleForm((v)=>({...v,project_roles:e.target.value}))} placeholder="project_manager, team_lead"/></label>
          <label>Global roles (comma-separated)<input value={ruleForm.global_roles} onChange={(e)=>setRuleForm((v)=>({...v,global_roles:e.target.value}))} placeholder="platform_admin, executive_viewer"/></label>
          <label className="nt-check"><input type="checkbox" checked={ruleForm.include_target_users} onChange={(e)=>setRuleForm((v)=>({...v,include_target_users:e.target.checked}))}/> Include explicit event recipients</label>
          <label className="nt-check"><input type="checkbox" checked={ruleForm.exclude_actor} onChange={(e)=>setRuleForm((v)=>({...v,exclude_actor:e.target.checked}))}/> Exclude the user who triggered the event</label>
          <label className="nt-check"><input type="checkbox" checked={ruleForm.requires_acknowledgement} onChange={(e)=>setRuleForm((v)=>({...v,requires_acknowledgement:e.target.checked}))}/> Require recipient acknowledgement</label>
          <div className="nt-rule-limit"><strong>Current backend scope</strong><p>Immediate event-based rules only. Scheduled reminders, repeat intervals, quiet hours and escalations are not enabled in this release; these fields remain at their safe defaults.</p></div>
          <div className="nt-rule-footer"><button type="button" className="button-secondary" onClick={resetRule}>Clear</button><button className="button-primary" disabled={busy}>{busy?<LoaderCircle className="spin" size={14}/>:<Save size={14}/>} {editingId?"Save new version":"Create rule"}</button></div>
        </form>
        {editingId&&<div className="nt-history"><div className="cr-section-title"><div><h3>Version history</h3><p>Previous configurations are preserved when a rule is changed.</p></div></div>{history.length===0?<div className="cr-inline-empty">No previous versions recorded yet.</div>:history.map((h)=><article key={h.id}><strong>Version {h.version_no}</strong><small>{dateTime(h.changed_at)} · Changed by {h.changed_by.slice(0,8)}</small><p>{String(h.rule_snapshot.rule_name??"Rule configuration")} · {String(h.rule_snapshot.module_code??"")} / {String(h.rule_snapshot.event_code??"")}</p></article>)}</div>}
      </section>
    </div>}
  </div>;
}
