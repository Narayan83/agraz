import React, { useCallback, useEffect, useState } from 'react';
import { Milk, Loader2, Plus, Trash2 } from 'lucide-react';
import {
  getMyDairyCustomers, createMyDairyCustomer,
  getMyOwnerDairyEntries, createMyOwnerDairyEntry, deleteMyOwnerDairyEntry,
} from '../../api/api';
import { todayIso, money } from '../../lib/transactions';
import { useTxnList, TxnToolbar, TxnPager, TxnModal } from './txnList.jsx';
import '../ServiceRegistrations.css';
import './Transactions.css';

const KINDS = [
  { id: 'collected', label: 'Milk collected' },
  { id: 'sold', label: 'Milk sold' },
  { id: 'paid', label: 'Paid to customer' },
  { id: 'received', label: 'Received from customer' },
];

const DairyOwnerEntry = () => {
  const [tab, setTab] = useState('entries');
  const [customers, setCustomers] = useState([]);
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [custModal, setCustModal] = useState(false);
  const [entryModal, setEntryModal] = useState(false);
  const [custForm, setCustForm] = useState({ name: '', mobile: '', village: '', default_rate: '' });
  const [form, setForm] = useState({
    owner_kind: 'collected', customer_id: '', party_name: '', party_mobile: '',
    date: todayIso(), shift: 'morning', quantity_liters: '', rate_per_liter: '', amount: '', narration: '',
  });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');

  const list = useTxnList(rows, {
    searchKeys: tab === 'entries'
      ? ['owner_kind', 'kind', 'party_name', 'party_mobile', 'narration']
      : ['name', 'mobile', 'village'],
    defaultSort: tab === 'entries' ? 'date_desc' : 'name_asc',
  });

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const c = await getMyDairyCustomers({ page: 1, limit: 200 });
      setCustomers(c.data || c || []);
      if (tab === 'entries') {
        const e = await getMyOwnerDairyEntries({ page: 1, limit: 200 });
        setRows(e.data || e || []);
      } else {
        setRows(c.data || c || []);
      }
    } catch (err) {
      console.error(err);
      setRows([]);
    } finally {
      setLoading(false);
    }
  }, [tab]);

  useEffect(() => { load(); }, [load]);

  return (
    <div className="service-reg-page">
      <div className="sr-page-header">
        <div className="title-area">
          <h1><Milk size={22} style={{ marginRight: 8, verticalAlign: -4 }} />Dairy Owner</h1>
          <p>Customers and milk collection / sales ledger.</p>
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          <button type="button" className="sr-btn sr-btn-ghost" onClick={() => { setError(''); setCustForm({ name: '', mobile: '', village: '', default_rate: '' }); setCustModal(true); }}>
            <Plus size={16} /> Customer
          </button>
          <button type="button" className="sr-btn sr-btn-primary" onClick={() => {
            setError('');
            setForm({
              owner_kind: 'collected',
              customer_id: customers[0]?.id ? String(customers[0].id) : '',
              party_name: '', party_mobile: '', date: todayIso(), shift: 'morning',
              quantity_liters: '', rate_per_liter: '', amount: '', narration: '',
            });
            setEntryModal(true);
          }}>
            <Plus size={16} /> Entry
          </button>
        </div>
      </div>

      <div className="sr-toolbar">
        <div className="sr-filter-tabs">
          <button type="button" className={`sr-filter-tab${tab === 'entries' ? ' active' : ''}`} onClick={() => setTab('entries')}>Entries</button>
          <button type="button" className={`sr-filter-tab${tab === 'customers' ? ' active' : ''}`} onClick={() => setTab('customers')}>Customers</button>
        </div>
      </div>

      <TxnToolbar
        list={list}
        placeholder={tab === 'entries' ? 'Search party…' : 'Search customer…'}
        filterOptions={tab === 'entries' ? KINDS : null}
        filterLabel="Kind"
        sortOptions={tab === 'entries' ? undefined : [
          { id: 'name_asc', label: 'Name A–Z' },
          { id: 'name_desc', label: 'Name Z–A' },
        ]}
      />

      <div className="sr-list-card">
        {loading ? (
          <div className="sr-empty"><Loader2 className="spin" size={22} /> Loading…</div>
        ) : list.total === 0 ? (
          <div className="sr-empty">Nothing matches.</div>
        ) : tab === 'entries' ? (
          <>
            <div className="sr-table-wrap">
              <table className="sr-table">
                <thead><tr><th>Date</th><th>Kind</th><th>Party</th><th>Liters</th><th>Amount</th><th /></tr></thead>
                <tbody>
                  {list.paged.map((r) => (
                    <tr key={r.id}>
                      <td>{String(r.date || '').slice(0, 10)}</td>
                      <td>{r.owner_kind || r.kind}</td>
                      <td>{r.party_name}</td>
                      <td>{r.quantity_liters ?? '—'}</td>
                      <td>{money(r.amount)}</td>
                      <td>
                        <button type="button" className="sr-btn sr-btn-ghost" onClick={async () => {
                          if (!window.confirm('Delete?')) return;
                          await deleteMyOwnerDairyEntry(r.id);
                          load();
                        }}><Trash2 size={14} /></button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <TxnPager list={list} />
          </>
        ) : (
          <>
            <div className="sr-table-wrap">
              <table className="sr-table">
                <thead><tr><th>Name</th><th>Mobile</th><th>Village</th><th>Default rate</th></tr></thead>
                <tbody>
                  {list.paged.map((r) => (
                    <tr key={r.id}>
                      <td>{r.name}</td>
                      <td>{r.mobile || '—'}</td>
                      <td>{r.village || '—'}</td>
                      <td>{money(r.default_rate)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <TxnPager list={list} />
          </>
        )}
      </div>

      {custModal && (
        <TxnModal title="New customer" onClose={() => setCustModal(false)} wide={false} saving={saving}>
          <form onSubmit={async (e) => {
            e.preventDefault(); setSaving(true); setError('');
            try {
              await createMyDairyCustomer({
                name: custForm.name.trim(),
                mobile: custForm.mobile.trim() || undefined,
                village: custForm.village || undefined,
                default_rate: Number(custForm.default_rate) || 0,
              });
              setCustModal(false);
              await load();
            } catch (err) {
              setError(err.response?.data?.error || 'Failed');
            } finally {
              setSaving(false);
            }
          }}>
            {error && <div className="sr-error" style={{ marginBottom: 10 }}>{error}</div>}
            <div className="txn-form-grid-2">
              <label>Name<input required value={custForm.name} onChange={(e) => setCustForm({ ...custForm, name: e.target.value })} /></label>
              <label>Mobile<input value={custForm.mobile} onChange={(e) => setCustForm({ ...custForm, mobile: e.target.value })} /></label>
              <label>Village<input value={custForm.village} onChange={(e) => setCustForm({ ...custForm, village: e.target.value })} /></label>
              <label>Default rate<input type="number" min="0" step="0.01" value={custForm.default_rate} onChange={(e) => setCustForm({ ...custForm, default_rate: e.target.value })} /></label>
            </div>
            <div className="txn-form-actions">
              <button type="submit" className="sr-btn sr-btn-primary" disabled={saving}>Save</button>
            </div>
          </form>
        </TxnModal>
      )}

      {entryModal && (
        <TxnModal title="Owner dairy entry" onClose={() => setEntryModal(false)} saving={saving}>
          <form onSubmit={async (e) => {
            e.preventDefault(); setSaving(true); setError('');
            try {
              const cust = customers.find((c) => String(c.id) === String(form.customer_id));
              const qty = Number(form.quantity_liters) || 0;
              const rate = Number(form.rate_per_liter) || Number(cust?.default_rate) || 0;
              let amount = Number(form.amount) || 0;
              if (!amount && qty && rate) amount = qty * rate;
              await createMyOwnerDairyEntry({
                owner_kind: form.owner_kind,
                customer_id: form.customer_id ? Number(form.customer_id) : undefined,
                party_name: form.party_name || cust?.name,
                party_mobile: form.party_mobile || cust?.mobile,
                date: form.date,
                shift: form.shift,
                quantity_liters: qty,
                rate_per_liter: rate,
                amount,
                narration: form.narration || undefined,
              });
              setEntryModal(false);
              await load();
            } catch (err) {
              setError(err.response?.data?.error || 'Failed');
            } finally {
              setSaving(false);
            }
          }}>
            {error && <div className="sr-error" style={{ marginBottom: 10 }}>{error}</div>}
            <div className="txn-form-grid">
              <label>Type
                <select value={form.owner_kind} onChange={(e) => setForm({ ...form, owner_kind: e.target.value })}>
                  {KINDS.map((k) => <option key={k.id} value={k.id}>{k.label}</option>)}
                </select>
              </label>
              <label>Customer
                <select value={form.customer_id} onChange={(e) => {
                  const cust = customers.find((c) => String(c.id) === e.target.value);
                  setForm({
                    ...form,
                    customer_id: e.target.value,
                    party_name: cust?.name || form.party_name,
                    party_mobile: cust?.mobile || form.party_mobile,
                    rate_per_liter: cust?.default_rate ? String(cust.default_rate) : form.rate_per_liter,
                  });
                }}>
                  <option value="">Select / manual</option>
                  {customers.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
                </select>
              </label>
              <label>Party name<input value={form.party_name} onChange={(e) => setForm({ ...form, party_name: e.target.value })} /></label>
              <label>Mobile<input value={form.party_mobile} onChange={(e) => setForm({ ...form, party_mobile: e.target.value })} /></label>
              <label>Liters<input type="number" min="0" step="0.01" value={form.quantity_liters} onChange={(e) => setForm({ ...form, quantity_liters: e.target.value })} /></label>
              <label>Rate<input type="number" min="0" step="0.01" value={form.rate_per_liter} onChange={(e) => setForm({ ...form, rate_per_liter: e.target.value })} /></label>
              <label>Amount<input type="number" min="0" step="0.01" value={form.amount} onChange={(e) => setForm({ ...form, amount: e.target.value })} /></label>
              <label>Date<input required type="date" value={form.date} onChange={(e) => setForm({ ...form, date: e.target.value })} /></label>
              <label>Shift
                <select value={form.shift} onChange={(e) => setForm({ ...form, shift: e.target.value })}>
                  <option value="morning">Morning</option>
                  <option value="evening">Evening</option>
                </select>
              </label>
              <label className="txn-span-3">Narration<input value={form.narration} onChange={(e) => setForm({ ...form, narration: e.target.value })} /></label>
            </div>
            <div className="txn-form-actions">
              <button type="submit" className="sr-btn sr-btn-primary" disabled={saving}>Save</button>
            </div>
          </form>
        </TxnModal>
      )}
    </div>
  );
};

export default DairyOwnerEntry;
