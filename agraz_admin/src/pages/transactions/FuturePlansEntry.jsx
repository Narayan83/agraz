import React, { useCallback, useEffect, useState } from 'react';
import { CalendarDays, Loader2, Plus, Trash2 } from 'lucide-react';
import { getMyFuturePlans, createMyFuturePlan, deleteMyFuturePlan } from '../../api/api';
import { todayIso, money } from '../../lib/transactions';
import { useTxnList, TxnToolbar, TxnPager, TxnModal } from './txnList.jsx';
import '../ServiceRegistrations.css';
import './Transactions.css';

const FuturePlansEntry = () => {
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [modalOpen, setModalOpen] = useState(false);
  const [form, setForm] = useState({ name: '', date: todayIso(), status: 'planned', line_desc: '', estimate_cost: '' });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const list = useTxnList(rows, {
    searchKeys: ['plan_name', 'name', 'title', 'status'],
    defaultSort: 'date_desc',
  });

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const data = await getMyFuturePlans({ page: 1, limit: 200 });
      setRows(data.data || data || []);
    } catch (e) {
      console.error(e);
      setRows([]);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  return (
    <div className="service-reg-page">
      <div className="sr-page-header">
        <div className="title-area">
          <h1><CalendarDays size={22} style={{ marginRight: 8, verticalAlign: -4 }} />Future Plans</h1>
          <p>Plan upcoming work with estimate cost.</p>
        </div>
        <button type="button" className="sr-btn sr-btn-primary" onClick={() => {
          setForm({ name: '', date: todayIso(), status: 'planned', line_desc: '', estimate_cost: '' });
          setError('');
          setModalOpen(true);
        }}>
          <Plus size={16} /> Add plan
        </button>
      </div>

      <TxnToolbar
        list={list}
        placeholder="Search plan name…"
        filterOptions={[
          { id: 'planned', label: 'Planned' },
          { id: 'in_progress', label: 'In progress' },
          { id: 'completed', label: 'Completed' },
          { id: 'cancelled', label: 'Cancelled' },
        ]}
        filterLabel="Status"
      />

      <div className="sr-list-card">
        {loading ? (
          <div className="sr-empty"><Loader2 className="spin" size={22} /> Loading…</div>
        ) : list.total === 0 ? (
          <div className="sr-empty">No plans match.</div>
        ) : (
          <>
            <div className="sr-table-wrap">
              <table className="sr-table">
                <thead><tr><th>Date</th><th>Name</th><th>Status</th><th>Estimate</th><th /></tr></thead>
                <tbody>
                  {list.paged.map((r) => (
                    <tr key={r.id}>
                      <td>{String(r.entry_date || r.date || r.plan_date || '').slice(0, 10)}</td>
                      <td>{r.plan_name || r.name || r.title}</td>
                      <td>{r.status || 'planned'}</td>
                      <td>{money(r.estimate_cost || r.total_estimate || (r.lines || []).reduce((s, l) => s + (Number(l.estimate_cost) || 0), 0))}</td>
                      <td>
                        <button type="button" className="sr-btn sr-btn-ghost" onClick={async () => {
                          if (!window.confirm('Delete?')) return;
                          await deleteMyFuturePlan(r.id);
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
        <TxnModal title="New plan" onClose={() => setModalOpen(false)} saving={saving}>
          <form onSubmit={async (e) => {
            e.preventDefault(); setSaving(true); setError('');
            try {
              await createMyFuturePlan({
                plan_name: form.name.trim(),
                entry_date: form.date,
                status: form.status || 'planned',
                lines: form.line_desc
                  ? [{ description: form.line_desc, estimate_cost: Number(form.estimate_cost) || 0 }]
                  : [],
                line_count: form.line_desc ? 1 : 0,
              });
              setModalOpen(false);
              await load();
            } catch (err) {
              setError(err.response?.data?.error || 'Save failed');
            } finally {
              setSaving(false);
            }
          }}>
            {error && <div className="sr-error" style={{ marginBottom: 10 }}>{error}</div>}
            <div className="txn-form-grid">
              <label className="txn-span-2">Name<input required value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} /></label>
              <label>Date<input required type="date" value={form.date} onChange={(e) => setForm({ ...form, date: e.target.value })} /></label>
              <label className="txn-span-2">Work line<input value={form.line_desc} onChange={(e) => setForm({ ...form, line_desc: e.target.value })} /></label>
              <label>Estimate (₹)<input type="number" min="0" step="0.01" value={form.estimate_cost} onChange={(e) => setForm({ ...form, estimate_cost: e.target.value })} /></label>
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

export default FuturePlansEntry;
