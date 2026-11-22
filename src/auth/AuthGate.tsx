import { useCallback, useEffect, useState } from "react";
import type { FormEvent, ReactNode } from "react";
import type { Session } from "@supabase/supabase-js";
import { AlertCircle, LoaderCircle, LockKeyhole, LogIn } from "lucide-react";
import { supabase, supabaseConfigured } from "../lib/supabase";
type AuthState = { session: Session | null; displayName: string; roles: string[]; loading: boolean; error: string };
export function AuthGate({ children }: { children: (user: { displayName: string; roles: string[] }, signOut: () => Promise<void>) => ReactNode }) {
 const [state,setState]=useState<AuthState>({session:null,displayName:"",roles:[],loading:true,error:""});
 const [email,setEmail]=useState(""); const [password,setPassword]=useState(""); const [submitting,setSubmitting]=useState(false);
 const loadIdentity=useCallback(async(session:Session|null)=>{
  if(!session||!supabase){setState({session:null,displayName:"",roles:[],loading:false,error:""});return;}
  const [{data:profile,error:profileError},{data:globalRoles,error:roleError},{data:memberships}]=await Promise.all([
   supabase.from("user_profiles").select("display_name,job_title,is_active").eq("user_id",session.user.id).maybeSingle(),
   supabase.from("user_global_role_assignments").select("role_code,status,effective_from,effective_to").eq("user_id",session.user.id).eq("status","active"),
   supabase.from("project_memberships").select("project_role,status,effective_from,effective_to").eq("user_id",session.user.id).eq("status","active")
  ]);
  if(profileError||roleError||!profile||!profile.is_active){await supabase.auth.signOut();setState({session:null,displayName:"",roles:[],loading:false,error:profileError?.message||roleError?.message||"Your account is not active in the PMO platform. Contact the administrator."});return;}
  const now=Date.now();const active=(row:{effective_from:string;effective_to:string|null})=>new Date(row.effective_from).getTime()<=now&&(!row.effective_to||new Date(row.effective_to).getTime()>now);
  const roles=[...(globalRoles||[]).filter(active).map(row=>row.role_code),...(memberships||[]).filter(active).map(row=>row.project_role)];
  setState({session,displayName:profile.display_name||session.user.email||"User",roles:[...new Set(roles)],loading:false,error:""});
 },[]);
 useEffect(()=>{if(!supabase){setState(s=>({...s,loading:false}));return;}let mounted=true;
  supabase.auth.getSession().then(({data})=>{if(mounted)void loadIdentity(data.session);});
  const {data:listener}=supabase.auth.onAuthStateChange((_event,session)=>{if(mounted)window.setTimeout(()=>{if(mounted)void loadIdentity(session);},0);});
  return()=>{mounted=false;listener.subscription.unsubscribe();};
 },[loadIdentity]);
 const signIn=async(event:FormEvent)=>{event.preventDefault();if(!supabase)return;setSubmitting(true);setState(s=>({...s,error:""}));const {error}=await supabase.auth.signInWithPassword({email:email.trim(),password});if(error)setState(s=>({...s,error:error.message}));setSubmitting(false);};
 const signOut=async()=>{if(supabase)await supabase.auth.signOut();};
 if(state.loading)return <div className="auth-screen"><div className="auth-card auth-loading"><LoaderCircle className="spin" size={25}/><strong>Verifying secure session</strong><span>Checking your PMO account and assigned roles.</span></div></div>;
 if(!supabaseConfigured)return <div className="auth-screen"><div className="auth-card"><div className="auth-brand"><LockKeyhole size={22}/></div><h1>Environment setup required</h1><p>Configure the Supabase project URL and publishable key before using the PMO platform.</p><code>VITE_SUPABASE_URL</code><code>VITE_SUPABASE_PUBLISHABLE_KEY</code><small>Use the Executive PPM Platform project. Never place a service-role key in frontend configuration.</small></div></div>;
 if(!state.session)return <div className="auth-screen"><form className="auth-card" onSubmit={signIn}><div className="auth-brand"><LockKeyhole size={22}/></div><div className="auth-eyebrow">PMO COMMAND CENTRE</div><h1>Sign in to your workspace</h1><p>Access is controlled by your active PMO account and database-assigned role.</p><label>Email address<input type="email" value={email} onChange={e=>setEmail(e.target.value)} autoComplete="username" required placeholder="name@company.com"/></label><label>Password<input type="password" value={password} onChange={e=>setPassword(e.target.value)} autoComplete="current-password" required placeholder="Enter your password"/></label>{state.error&&<div className="auth-error"><AlertCircle size={15}/>{state.error}</div>}<button className="button-primary auth-submit" type="submit" disabled={submitting}>{submitting?<LoaderCircle className="spin" size={16}/>:<LogIn size={16}/>} Sign in</button><small>Supabase authentication. User metadata is never used for authorization.</small></form></div>;
 return <>{children({displayName:state.displayName,roles:state.roles},signOut)}</>;
}