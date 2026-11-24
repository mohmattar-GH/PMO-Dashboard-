"use client";
import { useState } from "react";
import type { DashboardData } from "./dashboard-shell";

export default function ProjectsRegister({data}: {data: DashboardData}) {
 const [search,setSearch]=useState("");
 const [status,setStatus]=useState("");
 const [selected,setSelected]=useState<string|null>(null);
 const project=data.projects.find(p=>p.id===selected);
 const rows=data.projects.filter(p=>(!status||p.lifecycle_status===status)&&[p.name,p.project_code].some(v=>v.toLowerCase().includes(search.toLowerCase())));
 if(project) return <section className="panel"><button className="secondary-button" onClick={()=>setSelected(null)}>Back to register</button><h1>{project.name}</h1><p>{project.project_code} · {project.lifecycle_status}</p><dl><dt>Start date</dt><dd>{project.start_date??"Not reported"}</dd><dt>Target end date</dt><dd>{project.target_end_date??"Not reported"}</dd><dt>Calculated health</dt><dd>Not available</dd><dt>PM-reported health</dt><dd>Not available</dd></dl><p>Project workspace overview. Detailed delivery, commercial and governance workflows are not yet connected.</p></section>;
 return <section className="panel"><h2>Project register</h2><p>Showing {rows.length} of {data.counts.projects??"unknown"} accessible projects. Up to 500 records loaded.</p><div style={{display:"flex",gap:12,flexWrap:"wrap",margin:"16px 0"}}><label>Search <input value={search} onChange={e=>setSearch(e.target.value)} placeholder="Name or code"/></label><label>Lifecycle <select value={status} onChange={e=>setStatus(e.target.value)}><option value="">All statuses</option>{Array.from(new Set(data.projects.map(p=>p.lifecycle_status))).map(s=><option key={s}>{s}</option>)}</select></label></div>{data.projectsError?<p role="alert">Project records could not be loaded.</p>:<div style={{overflowX:"auto"}}><table style={{width:"100%",textAlign:"left",borderCollapse:"collapse"}}><thead><tr>{["Project","Code","Lifecycle","Start","Target end"].map(h=><th key={h} style={{padding:12}}>{h}</th>)}</tr></thead><tbody>{rows.map(p=><tr key={p.id} style={{borderTop:"1px solid #e7ebf1"}}><td style={{padding:12}}><button className="secondary-button" onClick={()=>setSelected(p.id)}>{p.name}</button></td><td>{p.project_code}</td><td>{p.lifecycle_status}</td><td>{p.start_date??"Not set"}</td><td>{p.target_end_date??"Not set"}</td></tr>)}</tbody></table>{!rows.length&&<p>No matching accessible projects.</p>}</div>}</section>;
}
