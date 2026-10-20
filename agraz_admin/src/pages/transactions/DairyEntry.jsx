import React, { useCallback, useEffect, useState } from 'react';
import { Milk, Loader2, Plus, Trash2 } from 'lucide-react';
import { getMyDairySummary, getMyDairyEntries, createMyDairyEntry, deleteMyDairyEntry } from '../../api/api';
import { todayIso, money } from '../../lib/transactions';
import { useTxnList, TxnToolbar, TxnPager, TxnModal } from './txnList.jsx';
import '../ServiceRegistrations.css';
import './Transactions.css';

const KINDS = [
  { id: 'milk_given', label: 'Milk given' },
  { id: 'milk_bought', label: 'Milk bought' },
  { id: 'payment_received', label: 'Payment received' },
  { id: 'payment_made', label: 'Payment made' },
];

const emptyForm = () => ({
  kind: 'milk_given', party_name: '', party_mobile: '', date: todayIso(),
  shift: 'morning', quantity_liters: '', rate_per_liter: '', amount: '', narration: '',
});

const DairyEntry = () => {
  const [rows, setRows] = useState([]);
  const [summary, setSummary] = useState(null);
  const [loading, setLoading] = useState(true);
  const [modalOpen, setModalOpen] = useState(false);
  const [form, setForm] = useState(emptyForm());
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const list = useTxnList(rows, {
    searchKeys: ['kind', 'party_name', 'party_mobile', 'narration'],
    defaultSort: 'date_desc',
  });

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const [s, e] = await Promise.all([getMyDairySummary(), getMyDairyEntries({ page: 1, limit: 200 })]);
      setSummary(s.data || s || null);
      setRows(e.data || e || []);
    } catch (err) {
      console.error(err);
      setRows([]);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  const save = async (ev) => {
    ev.preventDefault();
    setSaving(true);
    setError('');
    try {
      const qty = Number(form.quantity_liters) || 0;
      const rate = Number(form.rate_per_liter) || 0;
      let amount = Number(form.amount) || 0;
      if (!amount && qty && rate) amount = qty * rate;
      await createMyDairyEntry({
        kind: form.kind,
        party_name: form.party_name.trim(),
        party_mobile: form.party_mobile.trim() || undefined,
        date: form.date,
        shift: form.shift,
        quantity_liters: qty,
        rate_per_liter: rate,
        amount,
        narration: form.narration || undefined,
      });
      setModalOpen(false);
      await load();
    } catch (err) {
      setError(err.response?.data?.error || 'Save failed');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="service-reg-page">
      <div className="sr-page-header">
        <div className="title-area">
          <h1><Milk size={22} style={{ marginRight: 8, verticalAlign: -4 }} />Dairy</h1>
          <p>Milk given / bought and payments with your dairy party.</p>
        </div>
        <button type="button" className="sr-btn sr-btn-primary" onClick={() => { setForm(emptyForm()); setError(''); setModalOpen(true); }}>
          <Plus size={16} /> Add entry
        </button>
      </div>

      {summary && (
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 12, marginBottom: 8 }}>
          <div className="sr-list-card" style={{ padding: '0.75rem 1rem' }}>Given: {summary.given_liters ?? summary.liters_given ?? 0} L</div>
          <div className="sr-list-card" style={{ padding: '0.75rem 1rem' }}>Bought: {summary.bought_liters ?? summary.liters_bought ?? 0} L</div>
          <div className="sr-list-card" style={{ padding: '0.75rem 1rem' }}>Receivable: {money(summary.receivable ?? summary.total_receivable)}</div>
          <div className="sr-list-card" style={{ padding: '0.75rem 1rem' }}>Payable: {money(summary.payable ?? summary.total_payable)}</div>
        </div>
      )}

      <TxnToolbar
        list={list}
        placeholder="Search party, narration…"
        filterOptions={KINDS}
        filterLabel="Kind"
      />

      <div className="sr-list-card">
        {loading ? (
          <div className="sr-empty"><Loader2 className="spin" size={22} /> Loading…</div>
        ) : list.total === 0 ? (
          <div className="sr-empty">No dairy entries match.</div>
        ) : (
          <>
            <div className="sr-table-wrap">
              <table className="sr-table">
                <thead>
                  <tr><th>Date</th><th>Kind</th><th>Party</th><th>Liters</th><th>Amount</th><th>Narration</th><th /></tr>
                </thead>
                <tbody>
                  {list.paged.map((r) => (
                    <tr key={r.id}>
                      <td>{String(r.date || '').slice(0, 10)}</td>
                      <td>{r.kind || r.entry_kind}</td>
                      <td>{r.party_name}</td>
                      <td>{r.quantity_liters ?? '—'}</td>
                      <td>{money(r.amount)}</td>
                      <td>{r.narration || '—'}</td>
                      <td>
                        <button type="button" className="sr-btn sr-btn-ghost" onClick={async () => {
                          if (!window.confirm('Delete?')) return;
                          await deleteMyDairyEntry(r.id);
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
        )}
      </div>

      {modalOpen && (
        <TxnModal title="Dairy entry" onClose={() => setModalOpen(false)} saving={saving}>
          <form onSubmit={save}>
            {error && <div className="sr-error" style={{ marginBottom: 10 }}>{error}</div>}
            <div className="txn-form-grid">
              <label>Type
                <select value={form.kind} onChange={(e) => setForm({ ...form, kind: e.target.value })}>
                  {KINDS.map((k) => <option key={k.id} value={k.id}>{k.label}</option>)}
                </select>
              </label>
              <label>Party name<input required value={form.party_name} onChange={(e) => setForm({ ...form, party_name: e.target.value })} /></label>
              <label>Mobile<input value={form.party_mobile} onChange={(e) => setForm({ ...form, party_mobile: e.target.value })} /></label>
              <label>Date<input required type="date" value={form.date} onChange={(e) => setForm({ ...form, date: e.target.value })} /></label>
              <label>Shift
                <select value={form.shift} onChange={(e) => setForm({ ...form, shift: e.target.value })}>
                  <option value="morning">Morning</option>
                  <option value="evening">Evening</option>
                </select>
              </label>
              <label>Liters<input type="number" min="0" step="0.01" value={form.quantity_liters} onChange={(e) => setForm({ ...form, quantity_liters: e.target.value })} /></label>
              <label>Rate / L<input type="number" min="0" step="0.01" value={form.rate_per_liter} onChange={(e) => setForm({ ...form, rate_per_liter: e.target.value })} /></label>
              <label>Amount<input type="number" min="0" step="0.01" value={form.amount} onChange={(e) => setForm({ ...form, amount: e.target.value })} /></label>
              <label className="txn-span-3">Narration<input value={form.narration} onChange={(e) => setForm({ ...form, narration: e.target.value })} /></label>
            </div>
            <div className="txn-form-actions">
              <button type="button" className="sr-btn sr-btn-ghost" disabled={saving} onClick={() => setModalOpen(false)}>Cancel</button>
              <button type="submit" className="sr-btn sr-btn-primary" disabled={saving}>{saving ? 'Saving…' : 'Save'}</button>
            </div>
          </form>
        </TxnModal>
      )}
    </div>
  );
};

export default DairyEntry;
