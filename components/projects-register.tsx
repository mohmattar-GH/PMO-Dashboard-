"use client";
import { useEffect, useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import type { DashboardData } from "./dashboard-shell";

export default function ProjectsRegister({data}: {data: DashboardData}) {
 const [search,setSearch]=useState("");
 const [status,setStatus]=useState("");
 const [selected,setSelected]=useState<string|null>(null);
 const project=data.projects.find(p=>p.id===selected);
 const rows=data.projects.filter(p=>(!status||p.lifecycle_status===status)&&[p.name,p.project_code].some(v=>v.toLowerCase().includes(search.toLowerCase())));
 if(project) return <ProjectWorkspace key={project.id} project={project} onBack={()=>setSelected(null)}/>;
 return <section className="panel"><h2>Project register</h2><p>Showing {rows.length} of {data.counts.projects??"unknown"} accessible projects. Up to 500 records loaded.</p><div style={{display:"flex",gap:12,flexWrap:"wrap",margin:"16px 0"}}><label>Search <input value={search} onChange={e=>setSearch(e.target.value)} placeholder="Name or code"/></label><label>Lifecycle <select value={status} onChange={e=>setStatus(e.target.value)}><option value="">All statuses</option>{Array.from(new Set(data.projects.map(p=>p.lifecycle_status))).map(s=><option key={s}>{s}</option>)}</select></label></div>{data.projectsError?<p role="alert">Project records could not be loaded.</p>:<div style={{overflowX:"auto"}}><table style={{width:"100%",textAlign:"left",borderCollapse:"collapse"}}><thead><tr>{["Project","Code","Lifecycle","Start","Target end"].map(h=><th key={h} style={{padding:12}}>{h}</th>)}</tr></thead><tbody>{rows.map(p=><tr key={p.id} style={{borderTop:"1px solid #e7ebf1"}}><td style={{padding:12}}><button className="secondary-button" onClick={()=>setSelected(p.id)}>{p.name}</button></td><td>{p.project_code}</td><td>{p.lifecycle_status}</td><td>{p.start_date??"Not set"}</td><td>{p.target_end_date??"Not set"}</td></tr>)}</tbody></table>{!rows.length&&<p>No matching accessible projects.</p>}</div>}</section>;
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
