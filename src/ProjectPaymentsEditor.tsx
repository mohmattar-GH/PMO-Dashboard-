import { useMemo, useState } from "react";
import { CircleDollarSign, FilePlus2, Plus } from "lucide-react";
import { supabase } from "./lib/supabase";

type Contract = { id: string; contract_reference: string; contract_title: string; currency_code: string | null };
type Invoice = { id: string; contract_id?: string | null; invoice_reference: string; invoice_type: string; status: string; issue_date: string | null; submission_date: string | null; due_date: string | null; currency_code: string; total_amount: number; disputed_reason: string | null; contract_id?: string | null };
type Balance = { invoice_id: string; applied_amount: number; outstanding_amount: number; is_settled: boolean };
type Cash = { id: string; transaction_reference: string; transaction_type: string; status: string; transaction_date: string; currency_code: string; amount: number; payer_payee: string | null; bank_reference?: string | null };
const label = (value: string | null | undefined) => value ? value.replace(/_/g, " ").replace(/\b\w/g, (s) => s.toUpperCase()) : "Not Reported";
const money = (value: number | null | undefined, currency: string) => {
  if (value == null) return "Not Reported";
  try { return new Intl.NumberFormat(undefined, { style: "currency", currency: currency.trim() }).format(Number(value)); }
  catch { return Number(value).toLocaleString() + " " + currency; }
};
const today = () => new Date().toISOString().slice(0, 10);

export default function ProjectPaymentsEditor({
  projectId, contracts, invoices, balances, cash, canManageFinance, defaultCurrency, onSaved
}: {
  projectId: string; contracts: Contract[]; invoices: Invoice[]; balances: Record<string, Balance>; cash: Cash[];
  canManageFinance: boolean; defaultCurrency: string | null; onSaved: () => Promise<void>;
}) {
  const [invoiceOpen, setInvoiceOpen] = useState(false);
  const [cashOpen, setCashOpen] = useState(false);
  const [allocationOpen, setAllocationOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [invoiceForm, setInvoiceForm] = useState({
    contract_id: "", invoice_reference: "", invoice_type: "standard", status: "draft", issue_date: "", submission_date: "", due_date: "",
    currency_code: defaultCurrency ?? "", subtotal_amount: "", tax_amount: "0", retention_amount: "0", description: ""
  });
  const [cashForm, setCashForm] = useState({
    transaction_reference: "", transaction_type: "payment", status: "confirmed", transaction_date: today(),
    currency_code: defaultCurrency ?? "", amount: "", payer_payee: "", bank_reference: "", notes: ""
  });
  const [allocationForm, setAllocationForm] = useState({ invoice_id: "", cash_transaction_id: "", allocated_amount: "", allocation_date: today(), allocation_reason: "" });
  const totalAmount = useMemo(() => {
    const subtotal = Number(invoiceForm.subtotal_amount || 0);
    const tax = Number(invoiceForm.tax_amount || 0);
    const retention = Number(invoiceForm.retention_amount || 0);
    return subtotal + tax - retention;
  }, [invoiceForm.subtotal_amount, invoiceForm.tax_amount, invoiceForm.retention_amount]);
  const allocatableInvoices = invoices.filter((invoice) => invoice.invoice_type === "standard" && Number(balances[invoice.id]?.outstanding_amount ?? invoice.total_amount) > 0);
  const allocatableCash = cash.filter((item) => item.status === "confirmed" && ["payment", "credit_note"].includes(item.transaction_type));

  const createInvoice = async () => {
    if (!supabase) return;
    const currency = invoiceForm.currency_code.trim().toUpperCase();
    const subtotal = Number(invoiceForm.subtotal_amount);
    const tax = Number(invoiceForm.tax_amount || 0);
    const retention = Number(invoiceForm.retention_amount || 0);
    if (!invoiceForm.invoice_reference.trim() || !invoiceForm.subtotal_amount || !Number.isFinite(subtotal) || subtotal < 0) { setError("Invoice reference and a valid non-negative subtotal are required."); return; }
    if (!/^[A-Z]{3}$/.test(currency)) { setError("Enter a three-letter invoice currency code."); return; }
    if (![tax, retention, totalAmount].every(Number.isFinite) || tax < 0 || retention < 0 || totalAmount < 0) { setError("Tax and retention must be non-negative and the resulting invoice total cannot be negative."); return; }
    if (invoiceForm.issue_date && invoiceForm.submission_date && invoiceForm.submission_date < invoiceForm.issue_date) { setError("Submission date cannot precede issue date."); return; }
    if (invoiceForm.submission_date && invoiceForm.due_date && invoiceForm.due_date < invoiceForm.submission_date) { setError("Due date cannot precede submission date."); return; }
    setBusy(true); setError(""); setNotice("");
    const { error: saveError } = await supabase.from("project_invoices").insert({
      project_id: projectId, contract_id: invoiceForm.contract_id || null, invoice_reference: invoiceForm.invoice_reference.trim(),
      invoice_type: invoiceForm.invoice_type, status: invoiceForm.status.trim() || "draft",
      issue_date: invoiceForm.issue_date || null, submission_date: invoiceForm.submission_date || null, due_date: invoiceForm.due_date || null,
      currency_code: currency, subtotal_amount: subtotal, tax_amount: tax, retention_amount: retention, total_amount: totalAmount,
      description: invoiceForm.description.trim() || null
    });
    if (saveError) setError("Invoice was not saved: " + saveError.message);
    else {
      setNotice("Invoice created. Its outstanding balance is calculated from active payment allocations.");
      setInvoiceOpen(false);
      setInvoiceForm({ contract_id: "", invoice_reference: "", invoice_type: "standard", status: "draft", issue_date: "", submission_date: "", due_date: "", currency_code: defaultCurrency ?? "", subtotal_amount: "", tax_amount: "0", retention_amount: "0", description: "" });
      await onSaved();
    }
    setBusy(false);
  };

  const createCash = async () => {
    if (!supabase) return;
    const currency = cashForm.currency_code.trim().toUpperCase();
    const amount = Number(cashForm.amount);
    if (!cashForm.transaction_reference.trim() || !cashForm.transaction_date || !Number.isFinite(amount) || amount <= 0) { setError("Transaction reference, date and a positive amount are required."); return; }
    if (!/^[A-Z]{3}$/.test(currency)) { setError("Enter a three-letter transaction currency code."); return; }
    setBusy(true); setError(""); setNotice("");
    const { error: saveError } = await supabase.from("project_cash_transactions").insert({
      project_id: projectId, transaction_reference: cashForm.transaction_reference.trim(), transaction_type: cashForm.transaction_type,
      status: cashForm.status, transaction_date: cashForm.transaction_date, currency_code: currency, amount,
      payer_payee: cashForm.payer_payee.trim() || null, bank_reference: cashForm.bank_reference.trim() || null, notes: cashForm.notes.trim() || null
    });
    if (saveError) setError("Cash transaction was not saved: " + saveError.message);
    else {
      setNotice("Cash transaction recorded. Only confirmed payments and credit notes can be allocated to standard invoices.");
      setCashOpen(false);
      setCashForm({ transaction_reference: "", transaction_type: "payment", status: "confirmed", transaction_date: today(), currency_code: defaultCurrency ?? "", amount: "", payer_payee: "", bank_reference: "", notes: "" });
      await onSaved();
    }
    setBusy(false);
  };

  const createAllocation = async () => {
    if (!supabase) return;
    const invoice = invoices.find((item) => item.id === allocationForm.invoice_id);
    const transaction = cash.find((item) => item.id === allocationForm.cash_transaction_id);
    const amount = Number(allocationForm.allocated_amount);
    if (!invoice || !transaction || !Number.isFinite(amount) || amount <= 0 || allocationForm.allocation_reason.trim().length < 8) {
      setError("Select an invoice and confirmed payment, enter a positive amount and provide an allocation reason of at least 8 characters."); return;
    }
    if (invoice.currency_code.trim().toUpperCase() !== transaction.currency_code.trim().toUpperCase()) { setError("Invoice and cash transaction currencies must match."); return; }
    setBusy(true); setError(""); setNotice("");
    const { error: saveError } = await supabase.from("invoice_payment_allocations").insert({
      project_id: projectId, invoice_id: invoice.id, cash_transaction_id: transaction.id, allocated_amount: amount,
      allocation_date: allocationForm.allocation_date, allocation_reason: allocationForm.allocation_reason.trim()
    });
    if (saveError) setError("Payment allocation was not saved: " + saveError.message);
    else {
      setNotice("Payment allocation recorded. The database validated invoice and transaction balances and currency.");
      setAllocationOpen(false);
      setAllocationForm({ invoice_id: "", cash_transaction_id: "", allocated_amount: "", allocation_date: today(), allocation_reason: "" });
      await onSaved();
    }
    setBusy(false);
  };

  return <div className="project-commercial-editor">
    {error && <div className="project-create-error">{error}</div>}{notice && <div className="project-create-success">{notice}</div>}
    <div className="project-detail-grid">
      <article className="panel project-info-panel">
        <div className="project-panel-heading"><div><h3><FilePlus2 size={13}/> Invoices & Receivables</h3><span>{invoices.length} invoices</span></div>{canManageFinance && <button className="button-secondary small" onClick={() => { setError(""); setInvoiceOpen(!invoiceOpen); }}><Plus size={12}/> Add invoice</button>}</div>
        {invoices.length ? <div className="project-invoice-list">{invoices.map((invoice) => {
          const balance = balances[invoice.id];
          return <div className="project-invoice-row" key={invoice.id}><div><strong>{invoice.invoice_reference} · {label(invoice.invoice_type)}</strong><small>{label(invoice.status)} · Issued {invoice.issue_date ?? "Not reported"} · Submitted {invoice.submission_date ?? "Not reported"} · Due {invoice.due_date ?? "Not reported"}</small>{invoice.contract_id && <small>Contract: {contracts.find((contract) => contract.id === invoice.contract_id)?.contract_reference ?? "Linked contract"}</small>}{invoice.disputed_reason && <small className="project-dispute">Dispute: {invoice.disputed_reason}</small>}</div><div><strong>{money(invoice.total_amount, invoice.currency_code)}</strong><small>Applied {money(balance?.applied_amount ?? 0, invoice.currency_code)}</small><small>Outstanding {money(balance?.outstanding_amount ?? invoice.total_amount, invoice.currency_code)}</small></div></div>;
        })}</div> : <p className="project-empty-inline">No invoice records are accessible or have been reported.</p>}
        {invoiceOpen && canManageFinance && <div className="commercial-form"><div className="commercial-form-heading"><strong>Register invoice</strong></div><div className="commercial-form-grid">
          <label>Invoice reference<input maxLength={100} value={invoiceForm.invoice_reference} onChange={(e) => setInvoiceForm((f) => ({ ...f, invoice_reference: e.target.value }))}/></label>
          <label>Contract<select value={invoiceForm.contract_id} onChange={(e) => setInvoiceForm((f) => ({ ...f, contract_id: e.target.value }))}><option value="">Not linked</option>{contracts.map((contract) => <option key={contract.id} value={contract.id}>{contract.contract_reference} · {contract.contract_title}</option>)}</select></label>
          <label>Invoice type<select value={invoiceForm.invoice_type} onChange={(e) => setInvoiceForm((f) => ({ ...f, invoice_type: e.target.value }))}><option value="standard">Standard</option><option value="credit_note">Credit note</option></select></label>
          <label>Status<input value={invoiceForm.status} onChange={(e) => setInvoiceForm((f) => ({ ...f, status: e.target.value }))} placeholder="Enter configured invoice status"/></label>
          <label>Issue date<input type="date" value={invoiceForm.issue_date} onChange={(e) => setInvoiceForm((f) => ({ ...f, issue_date: e.target.value }))}/></label>
          <label>Submission date<input type="date" value={invoiceForm.submission_date} onChange={(e) => setInvoiceForm((f) => ({ ...f, submission_date: e.target.value }))}/></label>
          <label>Due date<input type="date" value={invoiceForm.due_date} onChange={(e) => setInvoiceForm((f) => ({ ...f, due_date: e.target.value }))}/></label>
          <label>Currency<input maxLength={3} value={invoiceForm.currency_code} onChange={(e) => setInvoiceForm((f) => ({ ...f, currency_code: e.target.value.toUpperCase() }))}/></label>
          <label>Subtotal<input type="number" min="0" step="0.01" value={invoiceForm.subtotal_amount} onChange={(e) => setInvoiceForm((f) => ({ ...f, subtotal_amount: e.target.value }))}/></label>
          <label>Tax amount<input type="number" min="0" step="0.01" value={invoiceForm.tax_amount} onChange={(e) => setInvoiceForm((f) => ({ ...f, tax_amount: e.target.value }))}/></label>
          <label>Retention amount<input type="number" min="0" step="0.01" value={invoiceForm.retention_amount} onChange={(e) => setInvoiceForm((f) => ({ ...f, retention_amount: e.target.value }))}/></label>
          <label>Total amount (calculated)<input disabled value={Number.isFinite(totalAmount) ? totalAmount.toFixed(2) : "—"}/></label>
          <label className="wide">Description<textarea value={invoiceForm.description} onChange={(e) => setInvoiceForm((f) => ({ ...f, description: e.target.value }))}/></label>
        </div><div className="commercial-form-note">Total = subtotal + tax − retention. The database preserves the invoice audit history and prevents financial amount/currency changes while active allocations exist.</div><div className="commercial-form-actions"><button className="button-secondary small" onClick={() => setInvoiceOpen(false)}>Cancel</button><button className="button-primary small" disabled={busy} onClick={() => void createInvoice()}>{busy ? "Saving…" : "Save invoice"}</button></div></div>}
      </article>
      <article className="panel project-info-panel">
        <div className="project-panel-heading"><div><h3><CircleDollarSign size={13}/> Cash Transactions</h3><span>{cash.length} transactions</span></div>{canManageFinance && <button className="button-secondary small" onClick={() => { setError(""); setCashOpen(!cashOpen); }}><Plus size={12}/> Add transaction</button>}</div>
        {cash.length ? cash.map((transaction) => <div className="project-invoice-row" key={transaction.id}><div><strong>{transaction.transaction_reference}</strong><small>{label(transaction.transaction_type)} · {label(transaction.status)} · {transaction.transaction_date}</small><small>{transaction.payer_payee || "Counterparty not reported"}{transaction.bank_reference ? " · " + transaction.bank_reference : ""}</small></div><div><strong>{money(transaction.amount, transaction.currency_code)}</strong></div></div>) : <p className="project-empty-inline">No cash transactions are accessible or have been reported.</p>}
        {cashOpen && canManageFinance && <div className="commercial-form"><div className="commercial-form-heading"><strong>Register cash transaction</strong></div><div className="commercial-form-grid">
          <label>Transaction reference<input maxLength={100} value={cashForm.transaction_reference} onChange={(e) => setCashForm((f) => ({ ...f, transaction_reference: e.target.value }))}/></label>
          <label>Type<select value={cashForm.transaction_type} onChange={(e) => setCashForm((f) => ({ ...f, transaction_type: e.target.value }))}><option value="payment">Payment received</option><option value="credit_note">Credit note</option><option value="refund">Refund</option><option value="adjustment">Adjustment</option></select></label>
          <label>Status<select value={cashForm.status} onChange={(e) => setCashForm((f) => ({ ...f, status: e.target.value }))}><option value="confirmed">Confirmed</option><option value="pending">Pending</option><option value="reversed">Reversed</option><option value="cancelled">Cancelled</option></select></label>
          <label>Transaction date<input type="date" value={cashForm.transaction_date} onChange={(e) => setCashForm((f) => ({ ...f, transaction_date: e.target.value }))}/></label>
          <label>Currency<input maxLength={3} value={cashForm.currency_code} onChange={(e) => setCashForm((f) => ({ ...f, currency_code: e.target.value.toUpperCase() }))}/></label>
          <label>Amount<input type="number" min="0.01" step="0.01" value={cashForm.amount} onChange={(e) => setCashForm((f) => ({ ...f, amount: e.target.value }))}/></label>
          <label>Counterparty<input value={cashForm.payer_payee} onChange={(e) => setCashForm((f) => ({ ...f, payer_payee: e.target.value }))}/></label>
          <label>Bank reference<input value={cashForm.bank_reference} onChange={(e) => setCashForm((f) => ({ ...f, bank_reference: e.target.value }))}/></label>
          <label className="wide">Notes<textarea value={cashForm.notes} onChange={(e) => setCashForm((f) => ({ ...f, notes: e.target.value }))}/></label>
        </div><div className="commercial-form-actions"><button className="button-secondary small" onClick={() => setCashOpen(false)}>Cancel</button><button className="button-primary small" disabled={busy} onClick={() => void createCash()}>{busy ? "Saving…" : "Save transaction"}</button></div></div>}
      </article>
    </div>
    {canManageFinance && <article className="panel project-info-panel"><div className="project-panel-heading"><div><h3>Payment Allocation</h3><span>Apply confirmed receipts against standard invoices</span></div><button className="button-secondary small" onClick={() => setAllocationOpen(!allocationOpen)} disabled={!allocatableInvoices.length || !allocatableCash.length}><Plus size={12}/> Allocate payment</button></div>
      {allocationOpen && <div className="commercial-form"><div className="commercial-form-grid">
        <label>Invoice<select value={allocationForm.invoice_id} onChange={(e) => setAllocationForm((f) => ({ ...f, invoice_id: e.target.value }))}><option value="">Select invoice</option>{allocatableInvoices.map((invoice) => <option key={invoice.id} value={invoice.id}>{invoice.invoice_reference} · {money(balances[invoice.id]?.outstanding_amount ?? invoice.total_amount, invoice.currency_code)} outstanding</option>)}</select></label>
        <label>Cash transaction<select value={allocationForm.cash_transaction_id} onChange={(e) => setAllocationForm((f) => ({ ...f, cash_transaction_id: e.target.value }))}><option value="">Select confirmed receipt</option>{allocatableCash.map((item) => <option key={item.id} value={item.id}>{item.transaction_reference} · {money(item.amount, item.currency_code)}</option>)}</select></label>
        <label>Amount to allocate<input type="number" min="0.01" step="0.01" value={allocationForm.allocated_amount} onChange={(e) => setAllocationForm((f) => ({ ...f, allocated_amount: e.target.value }))}/></label>
        <label>Allocation date<input type="date" value={allocationForm.allocation_date} onChange={(e) => setAllocationForm((f) => ({ ...f, allocation_date: e.target.value }))}/></label>
        <label className="wide">Allocation reason<textarea value={allocationForm.allocation_reason} onChange={(e) => setAllocationForm((f) => ({ ...f, allocation_reason: e.target.value }))} placeholder="Explain the payment-to-invoice matching (minimum 8 characters)"/></label>
      </div><div className="commercial-form-note">The database rejects allocations that exceed either outstanding invoice balance or unallocated cash, and enforces same-project and same-currency matching. Allocations are audited.</div><div className="commercial-form-actions"><button className="button-secondary small" onClick={() => setAllocationOpen(false)}>Cancel</button><button className="button-primary small" disabled={busy} onClick={() => void createAllocation()}>{busy ? "Saving…" : "Save allocation"}</button></div></div>}
      {!allocationOpen && (!allocatableInvoices.length || !allocatableCash.length) && <p className="project-empty-inline">Create a standard invoice and a confirmed payment/credit-note transaction before allocating receipts.</p>}
    </article>}
  </div>;
}
