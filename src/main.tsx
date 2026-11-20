import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App";
import { AuthGate } from "./auth/AuthGate";
import "./styles.css";
ReactDOM.createRoot(document.getElementById("root")!).render(<React.StrictMode><AuthGate>{(user,signOut)=><App displayName={user.displayName} roles={user.roles} onSignOut={signOut}/>}</AuthGate></React.StrictMode>);
