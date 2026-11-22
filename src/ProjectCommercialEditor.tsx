import { useState } from "react";
import { CircleDollarSign, FileText, Pencil, Plus } from "lucide-react";
import { supabase } from "./lib/supabase";

type Contract = {
  id: string; contract_reference: string; contract_title: string; contract_type: string; status: string;
  signed_date: string | null; commencement_date: string | null; contractual_end_date: string | null;
  duration_months: number | null; scope_summary: string | null; obligations: string | null;
  acceptance_criteria: string | null; penalties_terms: string | null; change_control_terms: string | null;
  payment_terms: string | null; currency_code: string | null; original_contract_value: number | null;
  tax_rate: number | null; retention_rate: number | null;
};
type Finance = {
  currency_code: string; original_contract_value: number; approved_variations: number;
  revised_contract_value: number | null; tax_rate: number | null; retention_rate: number | null;
  payment_terms: string | null; billing_notes: string | null;
};
type ContractForm = {
  contract_reference: string; contract_title: string; contract_type: string; status: string;
  signed_date: string; commencement_date: string; contractual_end_date: string; duration_months: string;
  scope_summary: string; obligations: string; acceptance_criteria: string; penalties_terms: string;
  change_control_terms: string; payment_terms: string; currency_code: string; original_contract_value: string;
  tax_rate: string; retention_rate: string;
};
const emptyContract: ContractForm = {
  contract_reference: "", contract_title: "", contract_type: "services", status: "draft",
  signed_date: "", commencement_date: "", contractual_end_date: "", duration_months: "",
  scope_summary: "", obligations: "", acceptance_criteria: "", penalties_terms: "",
  change_control_terms: "", payment_terms: "", currency_code: "", original_contract_value: "",
  tax_rate: "", retention_rate: ""
};
const amount = (value: number | null | undefined, currency: string | null | undefined) => {
  if (value == null) return "Not Reported";
  if (!currency) return Number(value).toLocaleString() + " · Currency not reported";
  try { return new Intl.NumberFormat(undefined, { style: "currency", currency: currency.trim() }).format(Number(value)); }
  catch { return Number(value).toLocaleString() + " " + currency; }
};
const dateLabel = (value: string | null) => value ? new Intl.DateTimeFormat(undefined, { dateStyle: "medium" }).format(new Date(value + (value.length === 10 ? "T00:00:00" : ""))) : "Not Reported";

export default function ProjectCommercialEditor({
  projectId, contracts, finance, canManageContract, canManageFinance, onSaved
}: {
  projectId: string; contracts: Contract[]; finance: Finance | null;
  canManageContract: boolean; canManageFinance: boolean; onSaved: () => Promise<void>;
}) {
  const [showContractForm, setShowContractForm] = useState(false);
  const [editingContractId, setEditingContractId] = useState<string | null>(null);
  const [contractForm, setContractForm] = useState<ContractForm>(emptyContract);
  const [showFinanceForm, setShowFinanceForm] = useState(false);
  const [financeForm, setFinanceForm] = useState({
    currency_code: finance?.currency_code ?? "", original_contract_value: finance ? String(finance.original_contract_value) : "",
    tax_rate: finance?.tax_rate == null ? "" : String(finance.tax_rate),
    retention_rate: finance?.retention_rate == null ? "" : String(finance.retention_rate),
    payment_terms: finance?.payment_terms ?? "", billing_notes: finance?.billing_notes ?? ""
  });
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [message, setMessage] = useState("");

  const startNewContract = () => {
    setEditingContractId(null); setContractForm(emptyContract); setError(""); setMessage(""); setShowContractForm(true);
  };
  const startEditContract = (contract: Contract) => {
    setEditingContractId(contract.id);
    setContractForm({
      contract_reference: contract.contract_reference, contract_title: contract.contract_title,
      contract_type: contract.contract_type, status: contract.status, signed_date: contract.signed_date ?? "",
      commencement_date: contract.commencement_date ?? "", contractual_end_date: contract.contractual_end_date ?? "",
      duration_months: contract.duration_months == null ? "" : String(contract.duration_months),
      scope_summary: contract.scope_summary ?? "", obligations: contract.obligations ?? "",
      acceptance_criteria: contract.acceptance_criteria ?? "", penalties_terms: contract.penalties_terms ?? "",
      change_control_terms: contract.change_control_terms ?? "", payment_terms: contract.payment_terms ?? "",
      currency_code: contract.currency_code ?? "", original_contract_value: contract.original_contract_value == null ? "" : String(contract.original_contract_value),
      tax_rate: contract.tax_rate == null ? "" : String(contract.tax_rate), retention_rate: contract.retention_rate == null ? "" : String(contract.retention_rate)
    });
    setError(""); setMessage(""); setShowContractForm(true);
  };

  const saveContract = async () => {
    if (!supabase) return;
    if (!contractForm.contract_reference.trim() || !contractForm.contract_title.trim()) { setError("Contract reference and title are required."); return; }
    if (contractForm.commencement_date && contractForm.contractual_end_date && contractForm.contractual_end_date < contractForm.commencement_date) { setError("Contractual end date cannot precede commencement."); return; }
    if (contractForm.duration_months && Number(contractForm.duration_months) <= 0) { setError("Duration must be a positive number of months."); return; }
    if (contractForm.original_contract_value && Number(contractForm.original_contract_value) < 0) { setError("Contract value cannot be negative."); return; }
    if (contractForm.original_contract_value && !/^[A-Z]{3}$/.test(contractForm.currency_code.trim().toUpperCase())) { setError("Enter a three-letter currency code when recording a contract value."); return; }
    for (const [name, value] of [["Tax", contractForm.tax_rate], ["Retention", contractForm.retention_rate]]) {
      if (value && (Number(value) < 0 || Number(value) > 100)) { setError(name + " rate must be between 0 and 100."); return; }
    }
    setBusy(true); setError(""); setMessage("");
    const payload = {
      project_id: projectId, contract_reference: contractForm.contract_reference.trim(),
      contract_title: contractForm.contract_title.trim(), contract_type: contractForm.contract_type,
      status: contractForm.status, signed_date: contractForm.signed_date || null,
      commencement_date: contractForm.commencement_date || null, contractual_end_date: contractForm.contractual_end_date || null,
      duration_months: contractForm.duration_months ? Number(contractForm.duration_months) : null,
      scope_summary: contractForm.scope_summary.trim() || null, obligations: contractForm.obligations.trim() || null,
      acceptance_criteria: contractForm.acceptance_criteria.trim() || null, penalties_terms: contractForm.penalties_terms.trim() || null,
      change_control_terms: contractForm.change_control_terms.trim() || null, payment_terms: contractForm.payment_terms.trim() || null,
      currency_code: contractForm.currency_code.trim().toUpperCase() || null,
      original_contract_value: contractForm.original_contract_value ? Number(contractForm.original_contract_value) : null,
      tax_rate: contractForm.tax_rate ? Number(contractForm.tax_rate) : null,
      retention_rate: contractForm.retention_rate ? Number(contractForm.retention_rate) : null
    };
    const result = editingContractId
      ? await supabase.from("project_contracts").update(payload).eq("id", editingContractId).select("id").single()
      : await supabase.from("project_contracts").insert(payload).select("id").single();
    if (result.error) setError(result.error.message);
    else { setShowContractForm(false); setMessage(editingContractId ? "Contract record updated and audited." : "Contract record created and audited."); setBusy(false); await onSaved(); return; }
    setBusy(false);
  };

  const startFinanceEdit = () => {
    setFinanceForm({
      currency_code: finance?.currency_code ?? contracts[0]?.currency_code ?? "", original_contract_value: finance ? String(finance.original_contract_value) : contracts[0]?.original_contract_value == null ? "" : String(contracts[0].original_contract_value),
      tax_rate: finance?.tax_rate == null ? "" : String(finance.tax_rate),
      retention_rate: finance?.retention_rate == null ? "" : String(finance.retention_rate),
      payment_terms: finance?.payment_terms ?? "", billing_notes: finance?.billing_notes ?? ""
    });
    setError(""); setMessage(""); setShowFinanceForm(true);
  };
  const saveFinance = async () => {
    if (!supabase) return;
    const currency = financeForm.currency_code.trim().toUpperCase();
    const originalValue = Number(financeForm.original_contract_value);
    if (!/^[A-Z]{3}$/.test(currency)) { setError("A three-letter currency code is required."); return; }
    if (!finance && (!financeForm.original_contract_value || !Number.isFinite(originalValue) || originalValue < 0)) { setError("Enter a valid non-negative original contract value."); return; }
    for (const [name, value] of [["Tax", financeForm.tax_rate], ["Retention", financeForm.retention_rate]]) {
      if (value && (Number(value) < 0 || Number(value) > 100)) { setError(name + " rate must be between 0 and 100."); return; }
    }
    setBusy(true); setError(""); setMessage("");
    const editable = {
      tax_rate: financeForm.tax_rate ? Number(financeForm.tax_rate) : null,
      retention_rate: financeForm.retention_rate ? Number(financeForm.retention_rate) : null,
      payment_terms: financeForm.payment_terms.trim() || null, billing_notes: financeForm.billing_notes.trim() || null
    };
    let result;
    if (finance) {
      result = await supabase.from("project_financial_terms").update(editable).eq("project_id", projectId).select("id").single();
    } else {
      const { data: approvedVariationRows, error: variationError } = await supabase.from("project_contract_variations").select("amount_delta,currency_code").eq("project_id", projectId).eq("status", "approved");
      if (variationError) { setError("Approved variation totals could not be verified: " + variationError.message); setBusy(false); return; }
      const currencyMismatch = (approvedVariationRows ?? []).some((row: { amount_delta: number; currency_code: string }) => row.currency_code.trim().toUpperCase() !== currency);
      if (currencyMismatch) { setError("Approved variation currency does not match the financial terms currency."); setBusy(false); return; }
      const approvedTotal = (approvedVariationRows ?? []).reduce((sum: number, row: { amount_delta: number }) => sum + Number(row.amount_delta), 0);
      result = await supabase.from("project_financial_terms").insert({
        project_id: projectId, currency_code: currency, original_contract_value: originalValue,
        approved_variations: approvedTotal, revised_contract_value: originalValue + approvedTotal, ...editable
      }).select("id").single();
    }
    if (result.error) setError(result.error.message);
    else { setShowFinanceForm(false); setMessage(finance ? "Financial terms updated and audited." : "Financial terms created. Approved variations remain system-calculated."); setBusy(false); await onSaved(); return; }
    setBusy(false);
  };

  return <div className="project-commercial-editor">
    {error && <div className="project-create-error">{error}</div>}{message && <div className="project-create-success">{message}</div>}
    <div className="project-detail-grid">
      <article className="panel project-info-panel"><div className="project-panel-heading"><div><h3><FileText size={13}/> Contractual Terms</h3><span>{contracts.length} records</span></div>{canManageContract && <button className="button-secondary small" onClick={startNewContract}><Plus size={12}/> Add contract</button>}</div>
        {contracts.length ? contracts.map((contract) => <div className="project-contract-record" key={contract.id}><div className="project-contract-top"><strong>{contract.contract_reference} · {contract.contract_title}</strong><div><span className={"project-status-pill " + contract.status.replace(/[^a-z0-9]+/gi, "-").toLowerCase()}>{contract.status.replace(/_/g, " ")}</span>{canManageContract && <button className="icon-button" title="Edit contract" onClick={() => startEditContract(contract)}><Pencil size={12}/></button>}</div></div><div className="project-kpi-grid"><div><small>Contract type</small><strong>{contract.contract_type}</strong></div><div><small>Original value</small><strong>{amount(contract.original_contract_value, contract.currency_code)}</strong></div><div><small>Signed</small><strong>{dateLabel(contract.signed_date)}</strong></div><div><small>Contractual end</small><strong>{dateLabel(contract.contractual_end_date)}</strong></div></div><p><b>Scope:</b> {contract.scope_summary || "Not Reported"}</p><p><b>Obligations:</b> {contract.obligations || "Not Reported"}</p><p><b>Acceptance:</b> {contract.acceptance_criteria || "Not Reported"}</p><p><b>Payment terms:</b> {contract.payment_terms || "Not Reported"}</p><p><b>Change control:</b> {contract.change_control_terms || "Not Reported"}</p><p><b>Penalties:</b> {contract.penalties_terms || "Not Reported"}</p></div>) : <p className="project-empty-inline">No accessible contract record. It may not have been reported or the current role may not have contract access.</p>}
        {showContractForm && <div className="commercial-form"><div className="commercial-form-heading"><strong>{editingContractId ? "Edit Contract" : "Add Contract"}</strong><button className="icon-button" onClick={() => setShowContractForm(false)}>×</button></div><div className="commercial-form-grid">
          <label>Contract reference<input disabled={Boolean(editingContractId)} value={contractForm.contract_reference} onChange={(e) => setContractForm((f) => ({ ...f, contract_reference: e.target.value }))}/></label><label>Contract title<input value={contractForm.contract_title} onChange={(e) => setContractForm((f) => ({ ...f, contract_title: e.target.value }))}/></label>
          <label>Type<select value={contractForm.contract_type} onChange={(e) => setContractForm((f) => ({ ...f, contract_type: e.target.value }))}>{["services","subscription","license","support","maintenance","other"].map((value) => <option key={value} value={value}>{value}</option>)}</select></label><label>Status<select value={contractForm.status} onChange={(e) => setContractForm((f) => ({ ...f, status: e.target.value }))}>{["draft","active","expired","terminated"].map((value) => <option key={value} value={value}>{value}</option>)}</select></label>
          <label>Signed date<input type="date" value={contractForm.signed_date} onChange={(e) => setContractForm((f) => ({ ...f, signed_date: e.target.value }))}/></label><label>Commencement<input type="date" value={contractForm.commencement_date} onChange={(e) => setContractForm((f) => ({ ...f, commencement_date: e.target.value }))}/></label><label>Contractual end<input type="date" value={contractForm.contractual_end_date} onChange={(e) => setContractForm((f) => ({ ...f, contractual_end_date: e.target.value }))}/></label><label>Duration (months)<input type="number" min="1" value={contractForm.duration_months} onChange={(e) => setContractForm((f) => ({ ...f, duration_months: e.target.value }))}/></label>
          <label>Currency<input maxLength={3} disabled={Boolean(editingContractId && contracts.find((contract) => contract.id === editingContractId)?.status !== "draft")} value={contractForm.currency_code} onChange={(e) => setContractForm((f) => ({ ...f, currency_code: e.target.value.toUpperCase() }))}/></label><label>Original contract value<input type="number" min="0" disabled={Boolean(editingContractId && contracts.find((contract) => contract.id === editingContractId)?.status !== "draft")} value={contractForm.original_contract_value} onChange={(e) => setContractForm((f) => ({ ...f, original_contract_value: e.target.value }))}/></label><label>Tax rate %<input type="number" min="0" max="100" value={contractForm.tax_rate} onChange={(e) => setContractForm((f) => ({ ...f, tax_rate: e.target.value }))}/></label><label>Retention %<input type="number" min="0" max="100" value={contractForm.retention_rate} onChange={(e) => setContractForm((f) => ({ ...f, retention_rate: e.target.value }))}/></label>
          <label className="wide">Scope summary<textarea value={contractForm.scope_summary} onChange={(e) => setContractForm((f) => ({ ...f, scope_summary: e.target.value }))}/></label><label className="wide">Obligations<textarea value={contractForm.obligations} onChange={(e) => setContractForm((f) => ({ ...f, obligations: e.target.value }))}/></label><label className="wide">Acceptance criteria<textarea value={contractForm.acceptance_criteria} onChange={(e) => setContractForm((f) => ({ ...f, acceptance_criteria: e.target.value }))}/></label><label className="wide">Payment terms<textarea value={contractForm.payment_terms} onChange={(e) => setContractForm((f) => ({ ...f, payment_terms: e.target.value }))}/></label><label className="wide">Change control terms<textarea value={contractForm.change_control_terms} onChange={(e) => setContractForm((f) => ({ ...f, change_control_terms: e.target.value }))}/></label><label className="wide">Penalties / service credits<textarea value={contractForm.penalties_terms} onChange={(e) => setContractForm((f) => ({ ...f, penalties_terms: e.target.value }))}/></label>
        </div><div className="commercial-form-actions"><button className="button-secondary small" onClick={() => setShowContractForm(false)}>Cancel</button><button className="button-primary small" disabled={busy} onClick={() => void saveContract()}>{busy ? "Saving…" : "Save contract"}</button></div></div>}
      </article>
      <article className="panel project-info-panel"><div className="project-panel-heading"><div><h3><CircleDollarSign size={13}/> Financial Terms</h3><span>Finance-controlled record</span></div>{canManageFinance && <button className="button-secondary small" onClick={startFinanceEdit}><Pencil size={12}/>{finance ? "Edit terms" : "Add terms"}</button>}</div>
        {finance ? <><div className="project-kpi-grid"><div><small>Original contract value</small><strong>{amount(finance.original_contract_value, finance.currency_code)}</strong></div><div><small>Approved variations</small><strong>{amount(finance.approved_variations, finance.currency_code)}</strong></div><div><small>Revised contract value</small><strong>{amount(finance.revised_contract_value, finance.currency_code)}</strong></div><div><small>Retention rate</small><strong>{finance.retention_rate == null ? "Not Reported" : finance.retention_rate + "%"}</strong></div></div><p><b>Tax rate:</b> {finance.tax_rate == null ? "Not Reported" : finance.tax_rate + "%"}</p><p><b>Payment terms:</b> {finance.payment_terms || "Not Reported"}</p><p><b>Billing notes:</b> {finance.billing_notes || "Not Reported"}</p></> : <p className="project-empty-inline">No accessible financial terms. They may be unreported or restricted to Finance, Project Manager, Platform Administrator, Finance Administrator or an explicitly granted Executive Viewer.</p>}
        {showFinanceForm && <div className="commercial-form"><div className="commercial-form-heading"><strong>{finance ? "Edit Financial Terms" : "Add Financial Terms"}</strong><button className="icon-button" onClick={() => setShowFinanceForm(false)}>×</button></div><div className="commercial-form-grid">
          <label>Currency code<input maxLength={3} disabled={Boolean(finance)} value={financeForm.currency_code} onChange={(e) => setFinanceForm((f) => ({ ...f, currency_code: e.target.value.toUpperCase() }))}/></label><label>Original contract value<input type="number" min="0" disabled={Boolean(finance)} value={financeForm.original_contract_value} onChange={(e) => setFinanceForm((f) => ({ ...f, original_contract_value: e.target.value }))}/></label>
          <label>Tax rate %<input type="number" min="0" max="100" value={financeForm.tax_rate} onChange={(e) => setFinanceForm((f) => ({ ...f, tax_rate: e.target.value }))}/></label><label>Retention rate %<input type="number" min="0" max="100" value={financeForm.retention_rate} onChange={(e) => setFinanceForm((f) => ({ ...f, retention_rate: e.target.value }))}/></label>
          <label className="wide">Payment terms<textarea value={financeForm.payment_terms} onChange={(e) => setFinanceForm((f) => ({ ...f, payment_terms: e.target.value }))}/></label><label className="wide">Billing notes<textarea value={financeForm.billing_notes} onChange={(e) => setFinanceForm((f) => ({ ...f, billing_notes: e.target.value }))}/></label>
        </div><p className="commercial-form-note">Original value and currency are locked after initial entry. Approved variations are calculated from approved variation records and cannot be manually edited.</p><div className="commercial-form-actions"><button className="button-secondary small" onClick={() => setShowFinanceForm(false)}>Cancel</button><button className="button-primary small" disabled={busy} onClick={() => void saveFinance()}>{busy ? "Saving…" : "Save financial terms"}</button></div></div>}
      </article>
    </div>
  </div>;
}
