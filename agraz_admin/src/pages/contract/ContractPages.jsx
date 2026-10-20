import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { Loader2, Plus, Trash2, Wrench } from 'lucide-react';
import { cmCreate, cmDelete, cmList, cmCustomerSummary, cmStockReport } from '../../api/api';
import { todayIso } from '../../lib/contractManage';
import '../ServiceRegistrations.css';
import '../transactions/Transactions.css';

const fieldStyle = {
  display: 'block',
  width: '100%',
  marginTop: 6,
  padding: '0.6rem 0.75rem',
  borderRadius: 8,
  border: '1px solid var(--border)',
};

function SimpleEntity({ title, path, fields, subtitle }) {
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState({});
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const blank = useMemo(() => Object.fromEntries(fields.map((f) => [f.key, f.default ?? ''])), [fields]);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const data = await cmList(path);
      setRows(data.data || data || []);
    } catch (e) {
      console.error(e);
      setRows([]);
    } finally {
      setLoading(false);
    }
  }, [path]);

  useEffect(() => { load(); }, [load]);

  return (
    <div className="service-reg-page">
      <div className="sr-page-header">
        <div className="title-area">
          <h1><Wrench size={22} style={{ marginRight: 8, verticalAlign: -4 }} />{title}</h1>
          <p>{subtitle}</p>
        </div>
        <button type="button" className="sr-btn sr-btn-primary" onClick={() => { setForm(blank); setError(''); setOpen(true); }}>
          <Plus size={16} /> Add
        </button>
      </div>
      <div className="sr-list-card">
        {loading ? (
          <div className="sr-empty"><Loader2 className="spin" size={22} /> Loading…</div>
        ) : rows.length === 0 ? (
          <div className="sr-empty">No records yet.</div>
        ) : (
          <div className="sr-table-wrap">
            <table className="sr-table">
              <thead>
                <tr>
                  {fields.slice(0, 4).map((f) => <th key={f.key}>{f.label}</th>)}
                  <th />
                </tr>
              </thead>
              <tbody>
                {rows.map((r) => (
                  <tr key={r.id}>
                    {fields.slice(0, 4).map((f) => <td key={f.key}>{String(r[f.key] ?? '—')}</td>)}
                    <td>
                      <button type="button" className="sr-btn sr-btn-ghost" onClick={async () => {
                        if (!window.confirm('Delete?')) return;
                        await cmDelete(path, r.id);
                        load();
                      }}><Trash2 size={14} /></button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
      {open && (
        <div className="txn-modal-overlay" onClick={() => setOpen(false)}>
          <div className="txn-modal" onClick={(e) => e.stopPropagation()}>
            <h3>Add {title}</h3>
            <form onSubmit={async (e) => {
              e.preventDefault();
              setSaving(true); setError('');
              try {
                const body = {};
                for (const f of fields) {
                  const v = form[f.key];
                  body[f.key] = f.type === 'number' ? Number(v || 0) : (v ?? '');
                }
                await cmCreate(path, body);
                setOpen(false);
                load();
              } catch (err) {
                setError(err.response?.data?.error || 'Save failed');
              } finally {
                setSaving(false);
              }
            }}>
              {fields.map((f) => (
                <label key={f.key} style={{ display: 'block', marginBottom: 10 }}>
                  {f.label}
                  <input
                    style={fieldStyle}
                    type={f.type || 'text'}
                    value={form[f.key] ?? ''}
                    onChange={(ev) => setForm({ ...form, [f.key]: ev.target.value })}
                    required={!!f.required}
                  />
                </label>
              ))}
              {error && <p style={{ color: 'crimson' }}>{error}</p>}
              <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end' }}>
                <button type="button" className="sr-btn" onClick={() => setOpen(false)}>Cancel</button>
                <button type="submit" className="sr-btn sr-btn-primary" disabled={saving}>{saving ? 'Saving…' : 'Save'}</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}

export const CmProjectsPage = () => (
  <SimpleEntity
    title="Projects"
    path="projects"
    subtitle="Create and maintain civil contract projects."
    fields={[
      { key: 'name', label: 'Name', required: true },
      { key: 'code', label: 'Code' },
      { key: 'location', label: 'Location' },
      { key: 'status', label: 'Status', default: 'active' },
      { key: 'estimate_amt', label: 'Estimate', type: 'number', default: '0' },
      { key: 'contract_amt', label: 'Contract amount', type: 'number', default: '0' },
      { key: 'commission_pct', label: 'Commission %', type: 'number', default: '0' },
      { key: 'notes', label: 'Notes' },
    ]}
  />
);

export const CmCustomersPage = () => (
  <SimpleEntity
    title="Customers"
    path="customers"
    subtitle="Customer / site owner details."
    fields={[
      { key: 'name', label: 'Name', required: true },
      { key: 'mobile', label: 'Mobile' },
      { key: 'village', label: 'Village' },
      { key: 'address', label: 'Address' },
      { key: 'notes', label: 'Notes' },
    ]}
  />
);

export const CmDealersPage = () => (
  <SimpleEntity
    title="Dealers"
    path="dealers"
    subtitle="Material suppliers (sand, cement, etc.)."
    fields={[
      { key: 'name', label: 'Name', required: true },
      { key: 'mobile', label: 'Mobile' },
      { key: 'material', label: 'Material focus' },
      { key: 'address', label: 'Address' },
      { key: 'notes', label: 'Notes' },
    ]}
  />
);

export const CmLabourSuppliersPage = () => (
  <SimpleEntity
    title="Labour Suppliers"
    path="labour-suppliers"
    subtitle="Labour leads who supply gangs."
    fields={[
      { key: 'name', label: 'Name', required: true },
      { key: 'mobile', label: 'Mobile' },
      { key: 'address', label: 'Address' },
      { key: 'notes', label: 'Notes' },
    ]}
  />
);

export const CmLaboursPage = () => (
  <SimpleEntity
    title="Labours"
    path="labours"
    subtitle="Workers under each labour lead. Set supplier_id from Labour Suppliers."
    fields={[
      { key: 'name', label: 'Name', required: true },
      { key: 'supplier_id', label: 'Supplier ID', type: 'number', required: true },
      { key: 'mobile', label: 'Mobile' },
      { key: 'skill', label: 'Skill' },
      { key: 'daily_wage', label: 'Daily wage', type: 'number', default: '0' },
      { key: 'notes', label: 'Notes' },
    ]}
  />
);

export const CmMaterialsPage = () => (
  <SimpleEntity
    title="Materials"
    path="materials"
    subtitle="Material master for stock."
    fields={[
      { key: 'name', label: 'Name', required: true },
      { key: 'unit', label: 'Unit', default: 'bag' },
      { key: 'category', label: 'Category' },
      { key: 'notes', label: 'Notes' },
    ]}
  />
);

export const CmAssetsPage = () => (
  <SimpleEntity
    title="Assets"
    path="assets"
    subtitle="JCB and other equipment with purchase details."
    fields={[
      { key: 'name', label: 'Name', required: true },
      { key: 'asset_type', label: 'Type' },
      { key: 'purchase_amt', label: 'Purchase amount', type: 'number', default: '0' },
      { key: 'purchase_date', label: 'Purchase date', default: todayIso() },
      { key: 'vendor_name', label: 'Vendor' },
      { key: 'serial_no', label: 'Serial no' },
      { key: 'status', label: 'Status', default: 'active' },
      { key: 'notes', label: 'Notes' },
    ]}
  />
);

export function CmPurchasesPage() {
  const [rows, setRows] = useState([]);
  const [materials, setMaterials] = useState([]);
  const [dealers, setDealers] = useState([]);
  const [customers, setCustomers] = useState([]);
  const [projects, setProjects] = useState([]);
  const [loading, setLoading] = useState(true);
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState({
    material_id: '', dealer_id: '', project_id: '', customer_id: '',
    stock_location: 'own', quantity: '1', rate: '0', paid_amount: '0',
    invoice_no: '', purchase_date: todayIso(), notes: '',
  });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const [p, m, d, c, pr] = await Promise.all([
        cmList('purchases'), cmList('materials'), cmList('dealers'), cmList('customers'), cmList('projects'),
      ]);
      setRows(p.data || p || []);
      setMaterials(m.data || m || []);
      setDealers(d.data || d || []);
      setCustomers(c.data || c || []);
      setProjects(pr.data || pr || []);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  return (
    <div className="service-reg-page">
      <div className="sr-page-header">
        <div className="title-area">
          <h1>Purchases / Stock</h1>
          <p>Buy materials into own yard or customer site. Unpaid dealer amount creates a payable.</p>
        </div>
        <button type="button" className="sr-btn sr-btn-primary" onClick={() => { setError(''); setOpen(true); }}>
          <Plus size={16} /> Add purchase
        </button>
      </div>
      <div className="sr-list-card">
        {loading ? <div className="sr-empty"><Loader2 className="spin" size={22} /> Loading…</div> : rows.length === 0 ? (
          <div className="sr-empty">No purchases yet.</div>
        ) : (
          <div className="sr-table-wrap">
            <table className="sr-table">
              <thead><tr><th>Date</th><th>Location</th><th>Total</th><th>Paid</th><th>Invoice</th><th /></tr></thead>
              <tbody>
                {rows.map((r) => (
                  <tr key={r.id}>
                    <td>{String(r.purchase_date || '').slice(0, 10)}</td>
                    <td>{r.stock_location}</td>
                    <td>₹{r.total_amount}</td>
                    <td>₹{r.paid_amount}</td>
                    <td>{r.invoice_no || '—'}</td>
                    <td>
                      <button type="button" className="sr-btn sr-btn-ghost" onClick={async () => {
                        if (!window.confirm('Delete?')) return;
                        await cmDelete('purchases', r.id);
                        load();
                      }}><Trash2 size={14} /></button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
      {open && (
        <div className="txn-modal-overlay" onClick={() => setOpen(false)}>
          <div className="txn-modal" onClick={(e) => e.stopPropagation()}>
            <h3>Add purchase</h3>
            <form onSubmit={async (e) => {
              e.preventDefault();
              setSaving(true); setError('');
              try {
                const qty = Number(form.quantity || 0);
                const rate = Number(form.rate || 0);
                await cmCreate('purchases', {
                  dealer_id: form.dealer_id ? Number(form.dealer_id) : null,
                  project_id: form.project_id ? Number(form.project_id) : null,
                  customer_id: form.stock_location === 'customer' && form.customer_id ? Number(form.customer_id) : null,
                  purchase_date: form.purchase_date,
                  invoice_no: form.invoice_no,
                  stock_location: form.stock_location,
                  paid_amount: Number(form.paid_amount || 0),
                  notes: form.notes,
                  items: [{ material_id: Number(form.material_id), quantity: qty, rate, amount: qty * rate }],
                });
                setOpen(false);
                load();
              } catch (err) {
                setError(err.response?.data?.error || 'Save failed');
              } finally {
                setSaving(false);
              }
            }}>
              <label>Material<select style={fieldStyle} required value={form.material_id} onChange={(e) => setForm({ ...form, material_id: e.target.value })}>
                <option value="">Select</option>
                {materials.map((m) => <option key={m.id} value={m.id}>{m.name}</option>)}
              </select></label>
              <label>Dealer<select style={fieldStyle} value={form.dealer_id} onChange={(e) => setForm({ ...form, dealer_id: e.target.value })}>
                <option value="">None</option>
                {dealers.map((m) => <option key={m.id} value={m.id}>{m.name}</option>)}
              </select></label>
              <label>Project<select style={fieldStyle} value={form.project_id} onChange={(e) => setForm({ ...form, project_id: e.target.value })}>
                <option value="">None</option>
                {projects.map((m) => <option key={m.id} value={m.id}>{m.name}</option>)}
              </select></label>
              <label>Stock location<select style={fieldStyle} value={form.stock_location} onChange={(e) => setForm({ ...form, stock_location: e.target.value })}>
                <option value="own">Own stock</option>
                <option value="customer">Customer site</option>
              </select></label>
              {form.stock_location === 'customer' && (
                <label>Customer<select style={fieldStyle} required value={form.customer_id} onChange={(e) => setForm({ ...form, customer_id: e.target.value })}>
                  <option value="">Select</option>
                  {customers.map((m) => <option key={m.id} value={m.id}>{m.name}</option>)}
                </select></label>
              )}
              <label>Quantity<input style={fieldStyle} type="number" value={form.quantity} onChange={(e) => setForm({ ...form, quantity: e.target.value })} /></label>
              <label>Rate<input style={fieldStyle} type="number" value={form.rate} onChange={(e) => setForm({ ...form, rate: e.target.value })} /></label>
              <label>Paid<input style={fieldStyle} type="number" value={form.paid_amount} onChange={(e) => setForm({ ...form, paid_amount: e.target.value })} /></label>
              <label>Invoice<input style={fieldStyle} value={form.invoice_no} onChange={(e) => setForm({ ...form, invoice_no: e.target.value })} /></label>
              <label>Date<input style={fieldStyle} type="date" value={form.purchase_date} onChange={(e) => setForm({ ...form, purchase_date: e.target.value })} /></label>
              {error && <p style={{ color: 'crimson' }}>{error}</p>}
              <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end' }}>
                <button type="button" className="sr-btn" onClick={() => setOpen(false)}>Cancel</button>
                <button type="submit" className="sr-btn sr-btn-primary" disabled={saving}>{saving ? 'Saving…' : 'Save'}</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}

export function CmPaymentsPage() {
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState({
    kind: 'receivable', party_type: 'customer', party_name: '', amount: '0', paid_amount: '0',
    entry_date: todayIso(), due_date: '', notes: '',
  });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const data = await cmList('payments');
      setRows(data.data || data || []);
    } finally {
      setLoading(false);
    }
  }, []);
  useEffect(() => { load(); }, [load]);

  return (
    <div className="service-reg-page">
      <div className="sr-page-header">
        <div className="title-area">
          <h1>Payments</h1>
          <p>Receivables from customers, payables to dealers/leads, and commission.</p>
        </div>
        <button type="button" className="sr-btn sr-btn-primary" onClick={() => { setError(''); setOpen(true); }}>
          <Plus size={16} /> Add
        </button>
      </div>
      <div className="sr-list-card">
        {loading ? <div className="sr-empty"><Loader2 className="spin" size={22} /> Loading…</div> : (
          <div className="sr-table-wrap">
            <table className="sr-table">
              <thead><tr><th>Date</th><th>Kind</th><th>Party</th><th>Amount</th><th>Paid</th><th>Status</th><th /></tr></thead>
              <tbody>
                {rows.map((r) => (
                  <tr key={r.id}>
                    <td>{String(r.entry_date || '').slice(0, 10)}</td>
                    <td>{r.kind}</td>
                    <td>{r.party_type} {r.party_name}</td>
                    <td>₹{r.amount}</td>
                    <td>₹{r.paid_amount}</td>
                    <td>{r.status}</td>
                    <td>
                      <button type="button" className="sr-btn sr-btn-ghost" onClick={async () => {
                        if (!window.confirm('Delete?')) return;
                        await cmDelete('payments', r.id);
                        load();
                      }}><Trash2 size={14} /></button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
      {open && (
        <div className="txn-modal-overlay" onClick={() => setOpen(false)}>
          <div className="txn-modal" onClick={(e) => e.stopPropagation()}>
            <h3>Add payment</h3>
            <form onSubmit={async (e) => {
              e.preventDefault();
              setSaving(true); setError('');
              try {
                const amount = Number(form.amount || 0);
                const paid = Number(form.paid_amount || 0);
                await cmCreate('payments', {
                  ...form,
                  amount,
                  paid_amount: paid,
                  status: paid >= amount && amount > 0 ? 'closed' : 'open',
                  due_date: form.due_date || null,
                });
                setOpen(false);
                load();
              } catch (err) {
                setError(err.response?.data?.error || 'Save failed');
              } finally {
                setSaving(false);
              }
            }}>
              <label>Kind<select style={fieldStyle} value={form.kind} onChange={(e) => setForm({ ...form, kind: e.target.value })}>
                <option value="receivable">Receivable</option>
                <option value="payable">Payable</option>
                <option value="commission">Commission</option>
              </select></label>
              <label>Party type<select style={fieldStyle} value={form.party_type} onChange={(e) => setForm({ ...form, party_type: e.target.value })}>
                <option value="customer">customer</option>
                <option value="dealer">dealer</option>
                <option value="labour_supplier">labour_supplier</option>
              </select></label>
              <label>Party name<input style={fieldStyle} value={form.party_name} onChange={(e) => setForm({ ...form, party_name: e.target.value })} /></label>
              <label>Amount<input style={fieldStyle} type="number" value={form.amount} onChange={(e) => setForm({ ...form, amount: e.target.value })} /></label>
              <label>Paid<input style={fieldStyle} type="number" value={form.paid_amount} onChange={(e) => setForm({ ...form, paid_amount: e.target.value })} /></label>
              <label>Entry date<input style={fieldStyle} type="date" value={form.entry_date} onChange={(e) => setForm({ ...form, entry_date: e.target.value })} /></label>
              <label>Due date<input style={fieldStyle} type="date" value={form.due_date} onChange={(e) => setForm({ ...form, due_date: e.target.value })} /></label>
              {error && <p style={{ color: 'crimson' }}>{error}</p>}
              <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end' }}>
                <button type="button" className="sr-btn" onClick={() => setOpen(false)}>Cancel</button>
                <button type="submit" className="sr-btn sr-btn-primary" disabled={saving}>{saving ? 'Saving…' : 'Save'}</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}

export function CmStockReportPage() {
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [loc, setLoc] = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const data = await cmStockReport(loc ? { location_type: loc } : {});
      setRows(data.data || data || []);
    } finally {
      setLoading(false);
    }
  }, [loc]);
  useEffect(() => { load(); }, [load]);

  return (
    <div className="service-reg-page">
      <div className="sr-page-header">
        <div className="title-area">
          <h1>Stock Report</h1>
          <p>Own yard stock vs material kept at customer sites.</p>
        </div>
        <select value={loc} onChange={(e) => setLoc(e.target.value)} style={{ ...fieldStyle, width: 200, marginTop: 0 }}>
          <option value="">All</option>
          <option value="own">Own</option>
          <option value="customer">Customer site</option>
        </select>
      </div>
      <div className="sr-list-card">
        {loading ? <div className="sr-empty"><Loader2 className="spin" size={22} /> Loading…</div> : (
          <div className="sr-table-wrap">
            <table className="sr-table">
              <thead><tr><th>Material</th><th>Qty</th><th>Location</th><th>Customer</th><th>Project</th></tr></thead>
              <tbody>
                {rows.map((r) => (
                  <tr key={r.id}>
                    <td>{r.material_name}</td>
                    <td>{r.quantity} {r.unit}</td>
                    <td>{r.location_type}</td>
                    <td>{r.customer_name || '—'}</td>
                    <td>{r.project_name || '—'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}

export function CmCustomerSummaryPage() {
  const [customers, setCustomers] = useState([]);
  const [id, setId] = useState('');
  const [summary, setSummary] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    cmList('customers').then((d) => {
      const list = d.data || d || [];
      setCustomers(list);
      if (list[0]) setId(String(list[0].id));
    }).finally(() => setLoading(false));
  }, []);

  useEffect(() => {
    if (!id) return;
    cmCustomerSummary(id).then(setSummary).catch(() => setSummary(null));
  }, [id]);

  const totals = summary?.totals || {};

  return (
    <div className="service-reg-page">
      <div className="sr-page-header">
        <div className="title-area">
          <h1>Customer Summary</h1>
          <p>Projects, dues, commission and stock at customer place.</p>
        </div>
        <select value={id} onChange={(e) => setId(e.target.value)} style={{ ...fieldStyle, width: 260, marginTop: 0 }}>
          {customers.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
        </select>
      </div>
      {loading ? <div className="sr-empty"><Loader2 className="spin" size={22} /> Loading…</div> : !summary ? (
        <div className="sr-empty">No customer selected.</div>
      ) : (
        <>
          <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap', marginBottom: 16 }}>
            <div className="sr-list-card" style={{ padding: 12 }}>Projects: <b>{totals.project_count ?? 0}</b></div>
            <div className="sr-list-card" style={{ padding: 12 }}>Open receivable: <b>₹{totals.receivable_open ?? 0}</b></div>
            <div className="sr-list-card" style={{ padding: 12 }}>Received: <b>₹{totals.receivable_paid ?? 0}</b></div>
            <div className="sr-list-card" style={{ padding: 12 }}>Commission: <b>₹{totals.commission ?? 0}</b></div>
          </div>
          <div className="sr-list-card">
            <h3>Projects</h3>
            <ul>{(summary.projects || []).map((p) => <li key={p.id}>{p.name} — {p.status} — ₹{p.contract_amt}</li>)}</ul>
            <h3>Payments</h3>
            <ul>{(summary.payments || []).map((p) => <li key={p.id}>{p.kind} ₹{p.amount} ({p.status})</li>)}</ul>
            <h3>Stock at site</h3>
            <ul>{(summary.stock_at_site || []).map((s, i) => <li key={i}>{s.material_name}: {s.quantity} {s.unit}</li>)}</ul>
          </div>
        </>
      )}
    </div>
  );
}
