# Checkpoint — Frontend Foundation

Date: 20 November 2026

## Approved direction
- User approved the complete UI wireframe baseline and selected direct implementation in GitHub.
- Repository: `mohmattar-GH/PMO-Dashboard-`
- Implementation branch: `feature/ppm-frontend-foundation`
- Stack selected for the initial frontend: React 18, TypeScript, Vite, lucide-react. Exact package versions are pinned in `package.json`.

## Implemented in this slice
- React/Vite/TypeScript application scaffold.
- Responsive navigation shell and executive dashboard layout.
- Portfolio KPI cards, project health distribution, project phase distribution, management attention, decisions, portfolio risk summary, restricted financial panel, project register, recent phase changes.
- Local UI preview controls for administrator layout editing.
- Presentation Mode shell and navigation entry points for the approved modules.
- GitHub Actions workflow for frontend type-check/build.

## Current limitations — do not misrepresent
- Dashboard/project data are illustrative demo data, visibly labelled as demo data.
- No frontend connection to Supabase has been added yet.
- No authentication/session handling, permission-aware routes, persistent layout storage, live data, CRUD, export, or notification delivery has been implemented in this slice.
- Financial preview toggle is demonstrative only and is not authorization.
- Most module navigation destinations are placeholders pending implementation against the approved screen specifications.
- No production deployment or publishing has been performed.

## Next tasks
1. Run CI and resolve any TypeScript/build errors; commit the package lockfile.
2. Implement secure Supabase authentication and database-role-based authorization.
3. Connect Executive Dashboard and Projects Register to verified RLS-protected data sources; remove demo data.
4. Implement Project Workspace, schedule and finance/risk modules.
5. Implement CR, Deliverables, Milestones and Notification Centre.
6. Implement Configuration Center, versioned dashboard layouts, snapshot reports and full Presentation Mode.
7. Complete JWT-based role/RLS, integration, accessibility and regression testing.

## Protected boundary
The Staff Time & Performance application and its Supabase project remain untouched. Production deployment remains reserved for explicit user approval.
