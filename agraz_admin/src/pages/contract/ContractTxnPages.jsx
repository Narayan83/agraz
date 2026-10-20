import React, { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { Loader2, Plus, Trash2, Edit, ExternalLink } from 'lucide-react';
import { cmCreate, cmDelete, cmList, cmUpdate } from '../../api/api';
import api from '../../api/api';
import { todayIso } from '../../lib/contractManage';
import '../ServiceRegistrations.css';
import '../transactions/Transactions.css';

const fieldStyle = {
  display: 'block', width: '100%', marginTop: 6, padding: '0.6rem 0.75rem',
  borderRadius: 8, border: '1px solid var(--border)',
};

const STATUSES = ['planned', 'active', 'on_hold', 'completed', 'cancelled'];

export function CmProjectsFullPage() {
  const [rows, setRows] = useState([]);
  const [customers, setCustomers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [open, setOpen] = useState(false);
  const [edit, setEdit] = useState(null);
  const [form, setForm] = useState({});
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');

  const blank = {
    name: '', code: '', location: '', status: 'active', customer_id: '',
    start_date: todayIso(), end_date: '', estimate_amt: '0', contract_amt: '0',
    commission_pct: '0', notes: '',
  };

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const [p, c] = await Promise.all([cmList('projects'), cmList('customers')]);
      setRows(p.data || p || []);
      setCustomers(c.data || c || []);
    } finally {
      setLoading(false);
    }
  }, []);
  useEffect(() => { load(); }, [load]);

  const custName = (id) => customers.find((c) => c.id === id)?.name || '—';

  return (
    <div className="service-reg-page">
      <div className="sr-page-header">
        <div className="title-area">
          <h1>Projects</h1>
          <p>Map each project to a customer. Open ledger for labour, advances, stock and payments.</p>
        </div>
        <button type="button" className="sr-btn sr-btn-primary" onClick={() => { setEdit(null); setForm(blank); setError(''); setOpen(true); }}>
          <Plus size={16} /> New project
        </button>
      </div>
      <div className="sr-list-card">
        {loading ? <div className="sr-empty"><Loader2 className="spin" size={22} /> Loading…</div> : (
          <div className="sr-table-wrap">
            <table className="sr-table">
              <thead>
                <tr><th>Name</th><th>Customer</th><th>Status</th><th>Start</th><th>End</th><th>Contract</th><th /></tr>
              </thead>
              <tbody>
                {rows.map((r) => (
                  <tr key={r.id}>
                    <td>{r.name}</td>
                    <td>{custName(r.customer_id)}</td>
                    <td>{r.status}</td>
                    <td>{String(r.start_date || '').slice(0, 10) || '—'}</td>
                    <td>{String(r.end_date || '').slice(0, 10) || '—'}</td>
                    <td>₹{r.contract_amt}</td>
                    <td style={{ whiteSpace: 'nowrap' }}>
                      <Link className="sr-btn sr-btn-ghost" to={`/contract-manage/projects/${r.id}`}><ExternalLink size={14} /></Link>
                      <button type="button" className="sr-btn sr-btn-ghost" onClick={() => {
                        setEdit(r);
                        setForm({
                          ...blank,
                          ...r,
                          customer_id: r.customer_id || '',
                          start_date: String(r.start_date || '').slice(0, 10),
                          end_date: String(r.end_date || '').slice(0, 10),
                          estimate_amt: String(r.estimate_amt ?? 0),
                          contract_amt: String(r.contract_amt ?? 0),
                          commission_pct: String(r.commission_pct ?? 0),
                        });
                        setOpen(true);
                      }}><Edit size={14} /></button>
                      <button type="button" className="sr-btn sr-btn-ghost" onClick={async () => {
                        if (!window.confirm('Delete project?')) return;
                        await cmDelete('projects', r.id);
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
          <div className="txn-modal txn-modal-sm" onClick={(e) => e.stopPropagation()}>
            <div className="txn-modal-header"><h2>{edit ? 'Edit project' : 'New project'}</h2></div>
            <div className="txn-modal-body">
              <form onSubmit={async (e) => {
                e.preventDefault(); setSaving(true); setError('');
                try {
                  const body = {
                    name: form.name,
                    code: form.code,
                    location: form.location,
                    status: form.status,
                    customer_id: form.customer_id ? Number(form.customer_id) : null,
                    start_date: form.start_date || null,
                    end_date: form.end_date || null,
                    estimate_amt: Number(form.estimate_amt || 0),
                    contract_amt: Number(form.contract_amt || 0),
                    commission_pct: Number(form.commission_pct || 0),
                    notes: form.notes || '',
                  };
                  if (!body.customer_id) throw new Error('Customer is required');
                  if (edit) await cmUpdate('projects', edit.id, body);
                  else await cmCreate('projects', body);
                  setOpen(false); load();
                } catch (err) {
                  setError(err.response?.data?.error || err.message || 'Save failed');
                } finally { setSaving(false); }
              }}>
                <label>Name<input style={fieldStyle} required value={form.name || ''} onChange={(e) => setForm({ ...form, name: e.target.value })} /></label>
                <label>Customer<select style={fieldStyle} required value={form.customer_id || ''} onChange={(e) => setForm({ ...form, customer_id: e.target.value })}>
                  <option value="">Select</option>
                  {customers.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
                </select></label>
                <label>Status<select style={fieldStyle} value={form.status || 'active'} onChange={(e) => setForm({ ...form, status: e.target.value })}>
                  {STATUSES.map((s) => <option key={s} value={s}>{s}</option>)}
                </select></label>
                <label>Start date<input style={fieldStyle} type="date" value={form.start_date || ''} onChange={(e) => setForm({ ...form, start_date: e.target.value })} /></label>
                <label>End date<input style={fieldStyle} type="date" value={form.end_date || ''} onChange={(e) => setForm({ ...form, end_date: e.target.value })} /></label>
                <label>Contract amount<input style={fieldStyle} type="number" value={form.contract_amt || ''} onChange={(e) => setForm({ ...form, contract_amt: e.target.value })} /></label>
                <label>Location<input style={fieldStyle} value={form.location || ''} onChange={(e) => setForm({ ...form, location: e.target.value })} /></label>
                <label>Notes<textarea style={fieldStyle} value={form.notes || ''} onChange={(e) => setForm({ ...form, notes: e.target.value })} /></label>
                {error && <p style={{ color: 'crimson' }}>{error}</p>}
                <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end' }}>
                  <button type="button" className="sr-btn" onClick={() => setOpen(false)}>Cancel</button>
                  <button type="submit" className="sr-btn sr-btn-primary" disabled={saving}>{saving ? 'Saving…' : 'Save'}</button>
                </div>
              </form>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export function CmProjectLedgerPage({ projectId }) {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [form, setForm] = useState({
    supplier_id: '', men_count: '0', women_count: '0', men_rate: '0', women_rate: '0',
    days_worked: '1', paid_amount: '0', extra_paid: '0', work_date: todayIso(), notes: '',
  });
  const [suppliers, setSuppliers] = useState([]);
  const [pay, setPay] = useState({ kind: 'customer_advance', party_name: '', amount: '0', paid_amount: '0', entry_date: todayIso() });

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const [ledger, sup] = await Promise.all([
        (await api.get(`/contract/projects/${projectId}/ledger`)).data,
        cmList('labour-suppliers'),
      ]);
      setData(ledger);
      setSuppliers(sup.data || sup || []);
    } finally { setLoading(false); }
  }, [projectId]);
  useEffect(() => { load(); }, [load]);

  if (loading || !data) return <div className="sr-empty"><Loader2 className="spin" size={22} /> Loading…</div>;
  const t = data.totals || {};
  const p = data.project || {};

  return (
    <div className="service-reg-page">
      <div className="sr-page-header">
        <div className="title-area">
          <h1>{p.name} — Project workspace</h1>
          <p>Status: {p.status} · Customer: {data.customer?.name || '—'} · {String(p.start_date || '').slice(0, 10)} → {String(p.end_date || '').slice(0, 10)}</p>
        </div>
        <Link to="/contract-manage/projects" className="sr-btn">Back</Link>
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill,minmax(160px,1fr))', gap: 10, marginBottom: 16 }}>
        {[
          ['Contract', t.contract_amt], ['Customer advance', t.customer_advance], ['Received', t.customer_received],
          ['Open receivable', t.open_receivable], ['Men days', t.men_labour_days], ['Women days', t.women_labour_days],
          ['Labour amount', t.labour_amount], ['Labour paid', t.labour_paid], ['Labour balance', t.labour_balance],
          ['Extra', t.labour_extra], ['Dealer paid', t.dealer_paid], ['Lead paid', t.labour_lead_paid],
        ].map(([k, v]) => (
          <div key={k} className="sr-list-card" style={{ padding: 12 }}><div style={{ fontSize: 12, color: 'var(--text-muted)' }}>{k}</div><b>₹{v ?? 0}</b></div>
        ))}
      </div>

      <div className="sr-list-card" style={{ marginBottom: 16 }}>
        <h3>Send labour</h3>
        <form style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill,minmax(140px,1fr))', gap: 8 }} onSubmit={async (e) => {
          e.preventDefault();
          await cmCreate('labour-works', {
            project_id: Number(projectId),
            supplier_id: Number(form.supplier_id),
            work_date: form.work_date,
            men_count: Number(form.men_count || 0),
            women_count: Number(form.women_count || 0),
            men_rate: Number(form.men_rate || 0),
            women_rate: Number(form.women_rate || 0),
            days_worked: Number(form.days_worked || 1),
            paid_amount: Number(form.paid_amount || 0),
            extra_paid: Number(form.extra_paid || 0),
            notes: form.notes,
          });
          load();
        }}>
          <label>Lead<select style={fieldStyle} required value={form.supplier_id} onChange={(e) => setForm({ ...form, supplier_id: e.target.value })}>
            <option value="">Select</option>
            {suppliers.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
          </select></label>
          <label>Date<input style={fieldStyle} type="date" value={form.work_date} onChange={(e) => setForm({ ...form, work_date: e.target.value })} /></label>
          <label>Men<input style={fieldStyle} type="number" value={form.men_count} onChange={(e) => setForm({ ...form, men_count: e.target.value })} /></label>
          <label>Men rate<input style={fieldStyle} type="number" value={form.men_rate} onChange={(e) => setForm({ ...form, men_rate: e.target.value })} /></label>
          <label>Women<input style={fieldStyle} type="number" value={form.women_count} onChange={(e) => setForm({ ...form, women_count: e.target.value })} /></label>
          <label>Women rate<input style={fieldStyle} type="number" value={form.women_rate} onChange={(e) => setForm({ ...form, women_rate: e.target.value })} /></label>
          <label>Days<input style={fieldStyle} type="number" step="0.5" value={form.days_worked} onChange={(e) => setForm({ ...form, days_worked: e.target.value })} /></label>
          <label>Paid now<input style={fieldStyle} type="number" value={form.paid_amount} onChange={(e) => setForm({ ...form, paid_amount: e.target.value })} /></label>
          <label>Extra<input style={fieldStyle} type="number" value={form.extra_paid} onChange={(e) => setForm({ ...form, extra_paid: e.target.value })} /></label>
          <button type="submit" className="sr-btn sr-btn-primary">Save labour</button>
        </form>
        <table className="sr-table" style={{ marginTop: 12 }}>
          <thead><tr><th>Date</th><th>Men</th><th>Women</th><th>Days</th><th>Amount</th><th>Paid</th><th>Extra</th><th /></tr></thead>
          <tbody>
            {(data.labour_works || []).map((w) => (
              <tr key={w.id}>
                <td>{String(w.work_date).slice(0, 10)}</td>
                <td>{w.men_count} @₹{w.men_rate}</td>
                <td>{w.women_count} @₹{w.women_rate}</td>
                <td>{w.days_worked}</td>
                <td>₹{w.amount}</td>
                <td>₹{w.paid_amount}</td>
                <td>₹{w.extra_paid}</td>
                <td><button type="button" className="sr-btn sr-btn-ghost" onClick={async () => { await cmDelete('labour-works', w.id); load(); }}><Trash2 size={14} /></button></td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div className="sr-list-card">
        <h3>Money (advance / receipt / pay lead / pay dealer / commission)</h3>
        <form style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill,minmax(150px,1fr))', gap: 8 }} onSubmit={async (e) => {
          e.preventDefault();
          const amount = Number(pay.amount || 0);
          const paid = Number(pay.paid_amount || amount);
          await cmCreate('payments', {
            project_id: Number(projectId),
            kind: pay.kind,
            party_type: pay.kind.includes('labour') ? 'labour_supplier' : pay.kind.includes('dealer') ? 'dealer' : 'customer',
            party_name: pay.party_name || data.customer?.name || '',
            party_id: pay.kind.includes('customer') || pay.kind === 'commission' ? data.customer?.id : null,
            entry_date: pay.entry_date,
            amount,
            paid_amount: paid,
            status: paid >= amount && amount > 0 ? 'closed' : 'open',
          });
          load();
        }}>
          <label>Kind<select style={fieldStyle} value={pay.kind} onChange={(e) => setPay({ ...pay, kind: e.target.value })}>
            <option value="customer_advance">Customer advance</option>
            <option value="customer_receipt">Customer receipt</option>
            <option value="labour_payment">Pay labour lead</option>
            <option value="labour_extra">Extra to lead</option>
            <option value="dealer_payment">Pay dealer</option>
            <option value="commission">Commission</option>
          </select></label>
          <label>Party<input style={fieldStyle} value={pay.party_name} onChange={(e) => setPay({ ...pay, party_name: e.target.value })} /></label>
          <label>Amount<input style={fieldStyle} type="number" value={pay.amount} onChange={(e) => setPay({ ...pay, amount: e.target.value })} /></label>
          <label>Paid now<input style={fieldStyle} type="number" value={pay.paid_amount} onChange={(e) => setPay({ ...pay, paid_amount: e.target.value })} /></label>
          <label>Date<input style={fieldStyle} type="date" value={pay.entry_date} onChange={(e) => setPay({ ...pay, entry_date: e.target.value })} /></label>
          <button type="submit" className="sr-btn sr-btn-primary">Save payment</button>
        </form>
        <table className="sr-table" style={{ marginTop: 12 }}>
          <thead><tr><th>Date</th><th>Kind</th><th>Party</th><th>Amount</th><th>Paid</th><th /></tr></thead>
          <tbody>
            {(data.payments || []).map((r) => (
              <tr key={r.id}>
                <td>{String(r.entry_date).slice(0, 10)}</td>
                <td>{r.kind}</td>
                <td>{r.party_name}</td>
                <td>₹{r.amount}</td>
                <td>₹{r.paid_amount}</td>
                <td><button type="button" className="sr-btn sr-btn-ghost" onClick={async () => { await cmDelete('payments', r.id); load(); }}><Trash2 size={14} /></button></td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

export function CmAuditPage() {
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  useEffect(() => {
    cmList('audit-logs', { limit: 200 }).then((d) => setRows(d.data || d || [])).finally(() => setLoading(false));
  }, []);
  return (
    <div className="service-reg-page">
      <div className="sr-page-header"><div className="title-area"><h1>Audit Log</h1><p>Create / update / delete history for Contract Manage.</p></div></div>
      <div className="sr-list-card">
        {loading ? <div className="sr-empty"><Loader2 className="spin" size={22} /> Loading…</div> : (
          <table className="sr-table">
            <thead><tr><th>When</th><th>Action</th><th>Entity</th><th>Summary</th></tr></thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.id}>
                  <td>{String(r.created_at || '').replace('T', ' ').slice(0, 19)}</td>
                  <td>{r.action}</td>
                  <td>{r.entity_type} #{r.entity_id}</td>
                  <td>{r.summary}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}

/** All labour deployments across projects (sidebar Labour Work). */
export function CmLabourWorksPage() {
  const [rows, setRows] = useState([]);
  const [projects, setProjects] = useState([]);
  const [suppliers, setSuppliers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [open, setOpen] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [form, setForm] = useState({
    project_id: '', supplier_id: '', work_date: todayIso(),
    men_count: '0', women_count: '0', men_rate: '0', women_rate: '0',
    days_worked: '1', paid_amount: '0', extra_paid: '0', notes: '',
  });

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const [w, p, s] = await Promise.all([
        cmList('labour-works'),
        cmList('projects'),
        cmList('labour-suppliers'),
      ]);
      setRows(w.data || w || []);
      setProjects(p.data || p || []);
      setSuppliers(s.data || s || []);
    } catch (e) {
      console.error(e);
      setRows([]);
    } finally {
      setLoading(false);
    }
  }, []);
  useEffect(() => { load(); }, [load]);

  const projName = (id) => projects.find((p) => p.id === id)?.name || `#${id}`;
  const leadName = (id) => suppliers.find((s) => s.id === id)?.name || `#${id}`;

  return (
    <div className="service-reg-page">
      <div className="sr-page-header">
        <div className="title-area">
          <h1>Labour Work</h1>
          <p>Send labour gangs to project sites (men/women, rates, days). Prefer opening a Project for the full workspace.</p>
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          <Link to="/contract-manage/projects" className="sr-btn">Open Projects</Link>
          <button type="button" className="sr-btn sr-btn-primary" onClick={() => { setError(''); setOpen(true); }}>
            <Plus size={16} /> Send labour
          </button>
        </div>
      </div>
      <div className="sr-list-card">
        {loading ? <div className="sr-empty"><Loader2 className="spin" size={22} /> Loading…</div> : rows.length === 0 ? (
          <div className="sr-empty">No labour deployments yet. Create a project first, then send labour.</div>
        ) : (
          <div className="sr-table-wrap">
            <table className="sr-table">
              <thead>
                <tr><th>Date</th><th>Project</th><th>Lead</th><th>Men</th><th>Women</th><th>Days</th><th>Amount</th><th>Paid</th><th>Extra</th><th /></tr>
              </thead>
              <tbody>
                {rows.map((r) => (
                  <tr key={r.id}>
                    <td>{String(r.work_date || '').slice(0, 10)}</td>
                    <td><Link to={`/contract-manage/projects/${r.project_id}`}>{projName(r.project_id)}</Link></td>
                    <td>{leadName(r.supplier_id)}</td>
                    <td>{r.men_count} @₹{r.men_rate}</td>
                    <td>{r.women_count} @₹{r.women_rate}</td>
                    <td>{r.days_worked}</td>
                    <td>₹{r.amount}</td>
                    <td>₹{r.paid_amount}</td>
                    <td>₹{r.extra_paid}</td>
                    <td>
                      <button type="button" className="sr-btn sr-btn-ghost" onClick={async () => {
                        if (!window.confirm('Delete?')) return;
                        await cmDelete('labour-works', r.id);
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
          <div className="txn-modal txn-modal-sm" onClick={(e) => e.stopPropagation()}>
            <div className="txn-modal-header"><h2>Send labour to site</h2></div>
            <div className="txn-modal-body">
              <form onSubmit={async (e) => {
                e.preventDefault(); setSaving(true); setError('');
                try {
                  if (!form.project_id || !form.supplier_id) throw new Error('Project and labour lead are required');
                  await cmCreate('labour-works', {
                    project_id: Number(form.project_id),
                    supplier_id: Number(form.supplier_id),
                    work_date: form.work_date,
                    men_count: Number(form.men_count || 0),
                    women_count: Number(form.women_count || 0),
                    men_rate: Number(form.men_rate || 0),
                    women_rate: Number(form.women_rate || 0),
                    days_worked: Number(form.days_worked || 1),
                    paid_amount: Number(form.paid_amount || 0),
                    extra_paid: Number(form.extra_paid || 0),
                    notes: form.notes || '',
                  });
                  setOpen(false);
                  load();
                } catch (err) {
                  setError(err.response?.data?.error || err.message || 'Save failed');
                } finally { setSaving(false); }
              }}>
                <label>Project<select style={fieldStyle} required value={form.project_id} onChange={(e) => setForm({ ...form, project_id: e.target.value })}>
                  <option value="">Select</option>
                  {projects.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}
                </select></label>
                <label>Labour lead<select style={fieldStyle} required value={form.supplier_id} onChange={(e) => setForm({ ...form, supplier_id: e.target.value })}>
                  <option value="">Select</option>
                  {suppliers.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
                </select></label>
                <label>Date<input style={fieldStyle} type="date" value={form.work_date} onChange={(e) => setForm({ ...form, work_date: e.target.value })} /></label>
                <label>Men count<input style={fieldStyle} type="number" value={form.men_count} onChange={(e) => setForm({ ...form, men_count: e.target.value })} /></label>
                <label>Men rate<input style={fieldStyle} type="number" value={form.men_rate} onChange={(e) => setForm({ ...form, men_rate: e.target.value })} /></label>
                <label>Women count<input style={fieldStyle} type="number" value={form.women_count} onChange={(e) => setForm({ ...form, women_count: e.target.value })} /></label>
                <label>Women rate<input style={fieldStyle} type="number" value={form.women_rate} onChange={(e) => setForm({ ...form, women_rate: e.target.value })} /></label>
                <label>Days<input style={fieldStyle} type="number" step="0.5" value={form.days_worked} onChange={(e) => setForm({ ...form, days_worked: e.target.value })} /></label>
                <label>Paid now<input style={fieldStyle} type="number" value={form.paid_amount} onChange={(e) => setForm({ ...form, paid_amount: e.target.value })} /></label>
                <label>Extra<input style={fieldStyle} type="number" value={form.extra_paid} onChange={(e) => setForm({ ...form, extra_paid: e.target.value })} /></label>
                {error && <p style={{ color: 'crimson' }}>{error}</p>}
                <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end' }}>
                  <button type="button" className="sr-btn" onClick={() => setOpen(false)}>Cancel</button>
                  <button type="submit" className="sr-btn sr-btn-primary" disabled={saving}>{saving ? 'Saving…' : 'Save'}</button>
                </div>
              </form>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

/** Stock issues / usage across projects. */
export function CmStockIssuesPage() {
  const [rows, setRows] = useState([]);
  const [projects, setProjects] = useState([]);
  const [materials, setMaterials] = useState([]);
  const [loading, setLoading] = useState(true);
  const [open, setOpen] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [form, setForm] = useState({
    project_id: '', material_id: '', issue_date: todayIso(),
    quantity: '1', from_location: 'customer', purpose: 'site_use', notes: '',
  });

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const [i, p, m] = await Promise.all([
        cmList('stock-issues'),
        cmList('projects'),
        cmList('materials'),
      ]);
      setRows(i.data || i || []);
      setProjects(p.data || p || []);
      setMaterials(m.data || m || []);
    } catch (e) {
      console.error(e);
      setRows([]);
    } finally {
      setLoading(false);
    }
  }, []);
  useEffect(() => { load(); }, [load]);

  const projName = (id) => projects.find((p) => p.id === id)?.name || `#${id}`;
  const matName = (id) => materials.find((m) => m.id === id)?.name || `#${id}`;

  return (
    <div className="service-reg-page">
      <div className="sr-page-header">
        <div className="title-area">
          <h1>Stock Issues</h1>
          <p>Use / transfer stock for projects (own yard ↔ customer site).</p>
        </div>
        <button type="button" className="sr-btn sr-btn-primary" onClick={() => { setError(''); setOpen(true); }}>
          <Plus size={16} /> Issue stock
        </button>
      </div>
      <div className="sr-list-card">
        {loading ? <div className="sr-empty"><Loader2 className="spin" size={22} /> Loading…</div> : rows.length === 0 ? (
          <div className="sr-empty">No stock issues yet.</div>
        ) : (
          <table className="sr-table">
            <thead><tr><th>Date</th><th>Project</th><th>Material</th><th>Qty</th><th>From</th><th>Purpose</th><th /></tr></thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.id}>
                  <td>{String(r.issue_date || '').slice(0, 10)}</td>
                  <td><Link to={`/contract-manage/projects/${r.project_id}`}>{projName(r.project_id)}</Link></td>
                  <td>{matName(r.material_id)}</td>
                  <td>{r.quantity}</td>
                  <td>{r.from_location}</td>
                  <td>{r.purpose}</td>
                  <td>
                    <button type="button" className="sr-btn sr-btn-ghost" onClick={async () => {
                      if (!window.confirm('Delete?')) return;
                      await cmDelete('stock-issues', r.id);
                      load();
                    }}><Trash2 size={14} /></button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
      {open && (
        <div className="txn-modal-overlay" onClick={() => setOpen(false)}>
          <div className="txn-modal txn-modal-sm" onClick={(e) => e.stopPropagation()}>
            <div className="txn-modal-header"><h2>Issue / use stock</h2></div>
            <div className="txn-modal-body">
              <form onSubmit={async (e) => {
                e.preventDefault(); setSaving(true); setError('');
                try {
                  const proj = projects.find((p) => String(p.id) === String(form.project_id));
                  await cmCreate('stock-issues', {
                    project_id: Number(form.project_id),
                    material_id: Number(form.material_id),
                    customer_id: proj?.customer_id || null,
                    issue_date: form.issue_date,
                    quantity: Number(form.quantity || 0),
                    from_location: form.from_location,
                    purpose: form.purpose,
                    notes: form.notes || '',
                  });
                  setOpen(false);
                  load();
                } catch (err) {
                  setError(err.response?.data?.error || err.message || 'Save failed');
                } finally { setSaving(false); }
              }}>
                <label>Project<select style={fieldStyle} required value={form.project_id} onChange={(e) => setForm({ ...form, project_id: e.target.value })}>
                  <option value="">Select</option>
                  {projects.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}
                </select></label>
                <label>Material<select style={fieldStyle} required value={form.material_id} onChange={(e) => setForm({ ...form, material_id: e.target.value })}>
                  <option value="">Select</option>
                  {materials.map((m) => <option key={m.id} value={m.id}>{m.name}</option>)}
                </select></label>
                <label>From<select style={fieldStyle} value={form.from_location} onChange={(e) => setForm({ ...form, from_location: e.target.value })}>
                  <option value="customer">Customer site</option>
                  <option value="own">Own yard</option>
                </select></label>
                <label>Purpose<select style={fieldStyle} value={form.purpose} onChange={(e) => setForm({ ...form, purpose: e.target.value })}>
                  <option value="site_use">Used on site</option>
                  <option value="transfer_to_customer">Transfer to customer site</option>
                  <option value="return_to_own">Return to own yard</option>
                </select></label>
                <label>Quantity<input style={fieldStyle} type="number" value={form.quantity} onChange={(e) => setForm({ ...form, quantity: e.target.value })} /></label>
                <label>Date<input style={fieldStyle} type="date" value={form.issue_date} onChange={(e) => setForm({ ...form, issue_date: e.target.value })} /></label>
                {error && <p style={{ color: 'crimson' }}>{error}</p>}
                <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end' }}>
                  <button type="button" className="sr-btn" onClick={() => setOpen(false)}>Cancel</button>
                  <button type="submit" className="sr-btn sr-btn-primary" disabled={saving}>{saving ? 'Saving…' : 'Save'}</button>
                </div>
              </form>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
