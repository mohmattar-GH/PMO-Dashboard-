
with new_template as (
  insert into public.project_lifecycle_templates(
    project_id,template_code,template_name,description,status,created_by
  ) values (
    null,'STANDARD','Standard Project Lifecycle',
    'Editable default lifecycle model. Review and tailor the phases and transition rules before publishing or assigning it to live projects.',
    'active',null
  )
  returning id
),
new_version as (
  insert into public.project_lifecycle_template_versions(
    template_id,project_id,version_number,status,change_reason,created_by
  )
  select id,null,1,'draft',
    'Initial configurable default draft. Review and tailor phases and transition rules before publishing.',
    null
  from new_template
  returning id,template_id,project_id
),
new_phases as (
  insert into public.project_lifecycle_phases(
    version_id,template_id,project_id,phase_code,phase_name,description,display_order,is_active
  )
  select v.id,v.template_id,v.project_id,p.phase_code,p.phase_name,p.description,p.display_order,true
  from new_version v
  cross join (values
    ('DISCOVERY','Discovery','Confirm objectives, business need, scope boundaries, stakeholders and feasibility.',1),
    ('INITIATION','Initiation','Establish the project charter, governance, roles, responsibilities and delivery authorization.',2),
    ('PLANNING','Planning & Design','Complete detailed requirements, solution design, delivery plan, estimates and baselines.',3),
    ('EXECUTION','Execution','Build, configure, integrate and deliver the agreed project scope.',4),
    ('TESTING','Testing & Acceptance','Complete integration, system and user acceptance testing; resolve defects and obtain acceptance evidence.',5),
    ('GO_LIVE','Deployment & Go-Live','Complete release readiness, cutover, deployment and operational stabilization.',6),
    ('CLOSURE','Closure & Handover','Complete operational handover, documentation, final acceptance and project closure.',7)
  ) as p(phase_code,phase_name,description,display_order)
  returning id,version_id,template_id,project_id,display_order
)
insert into public.project_lifecycle_transition_rules(
  version_id,template_id,project_id,from_phase_id,to_phase_id,reason_required
)
select p.version_id,p.template_id,p.project_id,null,p.id,true
from new_phases p
where p.display_order=1
union all
select current_phase.version_id,current_phase.template_id,current_phase.project_id,
  previous_phase.id,current_phase.id,true
from new_phases current_phase
join new_phases previous_phase
  on previous_phase.version_id=current_phase.version_id
 and previous_phase.display_order=current_phase.display_order-1;

comment on table public.project_lifecycle_templates is
  'Configurable global or project-scoped lifecycle templates; the Standard template is seeded as an editable draft version.';
