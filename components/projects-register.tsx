"use client";
import { useEffect, useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import type { DashboardData } from "./dashboard-shell";

export default function ProjectsRegister({data}: {data: DashboardData}) {
 const [search,setSearch]=useState("");
 const [status,setStatus]=useState("");
 const [selected,setSelected]=useState<string|null>(null);
 const [creating,setCreating]=useState(false);
 const project=data.projects.find(p=>p.id===selected);
 const rows=data.projects.filter(p=>(!status||p.lifecycle_status===status)&&[p.name,p.project_code].some(v=>v.toLowerCase().includes(search.toLowerCase())));
 if(creating) return <ProjectRegistration onBack={()=>setCreating(false)} />;
 if(project) return <ProjectWorkspace key={project.id} project={project} onBack={()=>setSelected(null)}/>;
 return <section className="panel"><div className="panel-heading"><h2>Project register</h2>{data.activeRoles.includes("platform_admin")&&<button type="button" className="secondary-button" onClick={()=>setCreating(true)}>Add project</button>}</div><p>Showing {rows.length} of {data.counts.projects??"unknown"} accessible projects. Up to 500 records loaded.</p><div style={{display:"flex",gap:12,flexWrap:"wrap",margin:"16px 0"}}><label>Search <input value={search} onChange={e=>setSearch(e.target.value)} placeholder="Name or code"/></label><label>Lifecycle <select value={status} onChange={e=>setStatus(e.target.value)}><option value="">All statuses</option>{Array.from(new Set(data.projects.map(p=>p.lifecycle_status))).map(s=><option key={s}>{s}</option>)}</select></label></div>{data.projectsError?<p role="alert">Project records could not be loaded.</p>:<div style={{overflowX:"auto"}}><table style={{width:"100%",textAlign:"left",borderCollapse:"collapse"}}><thead><tr>{["Project","Code","Lifecycle","Start","Target end"].map(h=><th key={h} style={{padding:12}}>{h}</th>)}</tr></thead><tbody>{rows.map(p=><tr key={p.id} style={{borderTop:"1px solid #e7ebf1"}}><td style={{padding:12}}><button className="secondary-button" onClick={()=>setSelected(p.id)}>{p.name}</button></td><td>{p.project_code}</td><td>{p.lifecycle_status}</td><td>{p.start_date??"Not set"}</td><td>{p.target_end_date??"Not set"}</td></tr>)}</tbody></table>{!rows.length&&<p>No matching accessible projects.</p>}</div>}</section>;
}

type Project = DashboardData["projects"][number];

function ProjectWorkspace({project,onBack}: {project: Project; onBack:()=>void}) {
 const router=useRouter();
 const [permission,setPermission]=useState<"checking"|"allowed"|"denied"|"error">("checking");
 const [record,setRecord]=useState(project);
 const [editing,setEditing]=useState(false);
 const [name,setName]=useState(project.name);
 const [start,setStart]=useState(project.start_date??"");
 const [end,setEnd]=useState(project.target_end_date??"");
 const [saving,setSaving]=useState(false);
 const [error,setError]=useState("");
 const [notice,setNotice]=useState("");
 useEffect(()=>{
   let current=true;
   async function check(){
     try {
       const supabase=createClient();
       const {data,error}=await supabase.auth.getClaims();
       const uid=data?.claims?.sub;
       if(error||!uid) {if(current)setPermission("denied");return;}
       const now=new Date().toISOString();
       const [roles,members,owner]=await Promise.all([
         supabase.from("user_global_role_assignments").select("effective_to").eq("user_id",uid).eq("role_code","platform_admin").eq("status","active").lte("effective_from",now),
         supabase.from("project_memberships").select("effective_to").eq("project_id",project.id).eq("user_id",uid).eq("project_role","project_manager").eq("status","active").lte("effective_from",now),
         supabase.from("projects").select("project_manager_id").eq("id",project.id).maybeSingle()
       ]);
       if(!current)return;
       if(roles.error||members.error||owner.error){setPermission("error");return;}
       const admin=(roles.data??[]).some(r=>!r.effective_to||Date.parse(r.effective_to)>Date.parse(now));
       const pm=owner.data?.project_manager_id===uid&&(members.data??[]).some(r=>!r.effective_to||Date.parse(r.effective_to)>Date.parse(now));
       setPermission(admin||pm?"allowed":"denied");
     } catch {if(current)setPermission("error");}
   }
   void check();
   return ()=>{current=false;};
 },[project.id]);
 function beginEdit(){
   setName(record.name);setStart(record.start_date??"");setEnd(record.target_end_date??"");
   setError("");setNotice("");setEditing(true);
 }
 async function save(event:FormEvent<HTMLFormElement>){
   event.preventDefault();
   if(saving||permission!=="allowed")return;
   setError("");setNotice("");
   if(!name.trim()){setError("Project name is required.");return;}
   if(start&&end&&end<start){setError("Target end date cannot be before the start date.");return;}
   setSaving(true);
   try{
     const supabase=createClient();
     let query=supabase.from("projects").update({name:name.trim(),start_date:start||null,target_end_date:end||null}).eq("id",record.id).eq("name",record.name);
     query=record.start_date?query.eq("start_date",record.start_date):query.is("start_date",null);
     query=record.target_end_date?query.eq("target_end_date",record.target_end_date):query.is("target_end_date",null);
     const result=await query.select("id,project_code,name,lifecycle_status,start_date,target_end_date").maybeSingle();
     if(result.error||!result.data){setError("Update was not saved. Your access may have changed, the record may have been updated by another user, or validation failed. Reopen the project and try again.");return;}
     setRecord(result.data);setEditing(false);setNotice("Project information saved.");router.refresh();
   }catch{setError("Unable to save project information. Please retry.");}
   finally{setSaving(false);}
 }
 return <section className="panel">
   <button type="button" className="secondary-button" disabled={saving} onClick={onBack}>Back to register</button>
   <div className="panel-heading"><div><h1>{record.name}</h1><p>{record.project_code} · {record.lifecycle_status}</p></div>
   {permission==="allowed"&&!editing&&<button type="button" className="secondary-button" onClick={beginEdit}>Edit project</button>}</div>
   {permission==="checking"&&<p role="status">Checking edit access…</p>}
   {permission==="error"&&<p role="alert">Edit access could not be verified. Reopen the project to retry.</p>}
   {permission==="denied"&&<p>Read-only project access.</p>}
   {notice&&<p role="status">{notice}</p>}
   {editing?<form onSubmit={save} style={{display:"grid",gap:12,maxWidth:540}}>
     <label>Project name <input required value={name} disabled={saving} onChange={e=>setName(e.target.value)} style={{display:"block",width:"100%"}}/></label>
     <label>Start date <input type="date" value={start} disabled={saving} onChange={e=>setStart(e.target.value)} style={{display:"block"}}/></label>
     <label>Target end date <input type="date" value={end} disabled={saving} onChange={e=>setEnd(e.target.value)} style={{display:"block"}}/></label>
     {error&&<p role="alert">{error}</p>}
     <div style={{display:"flex",gap:12}}><button className="secondary-button" type="submit" disabled={saving}>{saving?"Saving…":"Save changes"}</button><button className="secondary-button" type="button" disabled={saving} onClick={()=>{setEditing(false);setError("");}}>Cancel</button></div>
   </form>:<dl><dt>Start date</dt><dd>{record.start_date??"Not reported"}</dd><dt>Target end date</dt><dd>{record.target_end_date??"Not reported"}</dd><dt>Calculated health</dt><dd>Not available</dd><dt>PM-reported health</dt><dd>Not available</dd></dl>}
   <p>Ownership and lifecycle changes require governed workflows. Detailed delivery, commercial and governance workflows are not yet connected.</p>
 </section>;
}

type Choice={id:string;name:string};
type LifecycleChoice={id:string;name:string;phases:Choice[]};

function ProjectRegistration({onBack}:{onBack:()=>void}) {
 const router=useRouter();
 const [choices,setChoices]=useState<{clients:Choice[];portfolios:Choice[];people:Choice[];lifecycles:LifecycleChoice[]}|null>(null);
 const [error,setError]=useState("");
 const [busy,setBusy]=useState(false);
 const [created,setCreated]=useState<string|null>(null);
 const [assigned,setAssigned]=useState(false);
 const [version,setVersion]=useState("");
 const [phase,setPhase]=useState("");
 const [reason,setReason]=useState("");
 useEffect(()=>{
   let live=true;
   async function load(){
     try {
       const supabase=createClient();
       const now=new Date().toISOString();
       const [clients,portfolios,people,templates,versions,phases,rules]=await Promise.all([
         supabase.from("clients").select("id,name").eq("status","active").order("name"),
         supabase.from("portfolios").select("id,name").eq("status","active").order("name"),
         supabase.from("user_profiles").select("user_id,display_name").eq("is_active",true).order("display_name"),
         supabase.from("project_lifecycle_templates").select("id,template_name").is("project_id",null),
         supabase.from("project_lifecycle_template_versions").select("id,template_id,version_number,effective_to").is("project_id",null).eq("status","published").lte("effective_from",now),
         supabase.from("project_lifecycle_phases").select("id,version_id,phase_name").eq("is_active",true).order("display_order"),
         supabase.from("project_lifecycle_transition_rules").select("version_id,to_phase_id").is("from_phase_id",null)
       ]);
       if(!live)return;
       if([clients,portfolios,people,templates,versions,phases,rules].some(r=>r.error)){setError("Registration options could not be loaded. Check your permissions and reopen the form.");return;}
       const lifecycles=(versions.data??[]).filter(v=>!v.effective_to||Date.parse(v.effective_to)>Date.parse(now)).flatMap(v=>{
         const template=(templates.data??[]).find(t=>t.id===v.template_id);
         if(!template)return [];
         const initial=(phases.data??[]).filter(p=>p.version_id===v.id&&(rules.data??[]).some(r=>r.version_id===v.id&&r.to_phase_id===p.id)).map(p=>({id:p.id,name:p.phase_name}));
         return initial.length?[{id:v.id,name:template.template_name+" · v"+v.version_number,phases:initial}]:[];
       });
       setChoices({clients:clients.data??[],portfolios:portfolios.data??[],people:(people.data??[]).map(p=>({id:p.user_id,name:p.display_name||p.user_id})),lifecycles});
     } catch {if(live)setError("Registration options are unavailable.");}
   }
   void load();return ()=>{live=false;};
 },[]);
 async function register(e:FormEvent<HTMLFormElement>){
   e.preventDefault();if(busy||created||!choices)return;
   const fields=new FormData(e.currentTarget);
   const get=(key:string)=>String(fields.get(key)??"").trim();
   const start=get("start"),end=get("end");
   if(start&&end&&end<start){setError("Target end date cannot precede start date.");return;}
   setBusy(true);setError("");
   try{
     const result=await createClient().rpc("create_project_register_entry",{
       p_project_code:get("code"),p_name:get("name"),p_client_id:get("client")||null,p_portfolio_id:get("portfolio")||null,
       p_project_manager_id:get("pm"),p_team_lead_id:get("lead")||null,p_start_date:start||null,p_target_end_date:end||null,
       p_timezone:get("timezone"),p_currency_code:get("currency").toUpperCase()||null
     });
     if(result.error||typeof result.data!=="string"){setError(result.error?.message??"Project registration was not confirmed. Check the register before retrying.");return;}
     setCreated(result.data);router.refresh();
   }catch{setError("Registration could not be confirmed. Check the register before retrying.");}
   finally{setBusy(false);}
 }
 async function assign(e:FormEvent<HTMLFormElement>){
   e.preventDefault();if(!created||busy||assigned)return;
   setBusy(true);setError("");
   try{
     const result=await createClient().rpc("assign_project_lifecycle",{p_project_id:created,p_version_id:version,p_initial_phase_id:phase,p_assignment_reason:reason.trim()});
     if(result.error||!result.data){setError(result.error?.message??"Lifecycle assignment was not confirmed.");return;}
     setAssigned(true);router.refresh();
   }catch{setError("Assignment could not be confirmed. The project has already been registered.");}
   finally{setBusy(false);}
 }
 const options=(items:Choice[])=>items.map(item=><option value={item.id} key={item.id}>{item.name}</option>);
 return <section className="panel"><button type="button" className="secondary-button" onClick={onBack} disabled={busy}>Back to register</button>
 <h2>{created?"Configure project lifecycle":"Register project"}</h2>
 {error&&<p role="alert">{error}</p>}
 {!choices&&!error&&<p role="status">Loading registration options…</p>}
 {choices&&!created&&<form onSubmit={register} style={{display:"grid",gap:12,maxWidth:640}}>
   <fieldset disabled={busy} style={{display:"grid",gap:12,border:0,padding:0}}>
   <label>Project code <input name="code" required /></label>
   <label>Project name <input name="name" required /></label>
   <label>Client <select name="client"><option value="">Not assigned</option>{options(choices.clients)}</select></label>
   <label>Portfolio <select name="portfolio"><option value="">Not assigned</option>{options(choices.portfolios)}</select></label>
   <label>Project Manager (owner) <select name="pm" required><option value="">Select active user</option>{options(choices.people)}</select></label>
   <label>Team lead <select name="lead"><option value="">Not assigned</option>{options(choices.people)}</select></label>
   <label>Start date <input name="start" type="date"/></label>
   <label>Target end date <input name="end" type="date"/></label>
   <label>Project timezone <input name="timezone" required defaultValue="UTC" placeholder="IANA timezone"/></label>
   <label>Currency code <input name="currency" maxLength={3} pattern="[A-Za-z]{3}" placeholder="e.g. JOD"/></label>
   </fieldset>
   {!choices.people.length&&<p role="alert">No active user profiles are available. An active Project Manager is required.</p>}
   <button className="secondary-button" type="submit" disabled={busy||!choices.people.length}>{busy?"Registering…":"Register draft project"}</button>
 </form>}
 {created&&<p role="status">Draft project registered. The Project Manager membership has been created.{assigned?" Lifecycle assigned successfully.":""}</p>}
 {created&&choices&&!assigned&&<form onSubmit={assign} style={{display:"grid",gap:12,maxWidth:640}}>
   <label>Published lifecycle <select required value={version} disabled={busy} onChange={e=>{setVersion(e.target.value);setPhase("");}}><option value="">Select lifecycle</option>{options(choices.lifecycles)}</select></label>
   <label>Initial phase <select required value={phase} disabled={busy||!version} onChange={e=>setPhase(e.target.value)}><option value="">Select initial phase</option>{options(choices.lifecycles.find(v=>v.id===version)?.phases??[])}</select></label>
   <label>Assignment reason <textarea required minLength={8} maxLength={1000} value={reason} disabled={busy} onChange={e=>setReason(e.target.value)}/></label>
   {!choices.lifecycles.length&&<p>No effective published lifecycle with an allowed initial phase is available. The project remains registered without a lifecycle assignment.</p>}
   <button className="secondary-button" type="submit" disabled={busy||!version||!phase}>{busy?"Assigning…":"Assign lifecycle"}</button>
 </form>}
 </section>;
}
