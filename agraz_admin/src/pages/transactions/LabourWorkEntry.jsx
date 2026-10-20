import React, { useCallback, useEffect, useState } from 'react';
import { ClipboardList, Loader2, Plus, Trash2 } from 'lucide-react';
import { getMyLaborWorks, createMyLaborWork, deleteMyLaborWork } from '../../api/api';
import { LABOR_CATEGORIES, LABOR_SHIFTS, todayIso, money } from '../../lib/transactions';
import { useTxnList, TxnToolbar, TxnPager, TxnModal } from './txnList.jsx';
import '../ServiceRegistrations.css';
import './Transactions.css';

const emptyForm = () => ({
  name: '', mobile: '', category: 'Plucking', shift: 'fullday', gender: 'Male',
  hours: '1', wage: '', date: todayIso(), narration: '',
});

const LabourWorkEntry = () => {
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [modalOpen, setModalOpen] = useState(false);
  const [form, setForm] = useState(emptyForm());
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const list = useTxnList(rows, {
    searchKeys: ['name', 'mobile', 'category', 'narration', 'shift'],
    defaultSort: 'date_desc',
  });

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const data = await getMyLaborWorks({ page: 1, limit: 200 });
      setRows(data.data || data || []);
    } catch (e) {
      console.error(e);
      setRows([]);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  const save = async (e) => {
    e.preventDefault();
    setSaving(true);
    setError('');
    try {
      await createMyLaborWork({
        name: form.name.trim(),
        mobile: form.mobile.trim() || undefined,
        category: form.category,
        shift: form.shift,
        gender: form.gender,
        hours: Number(form.hours) || 1,
        wage: Number(form.wage) || 0,
        number_of_labours: 1,
        work_type: 'Daily Wages',
        location: 'Farm',
        entry_kind: 'receivable',
        date: form.date,
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
          <h1><ClipboardList size={22} style={{ marginRight: 8, verticalAlign: -4 }} />Labour Work Entry</h1>
          <p>Daily work entries for family confirmation.</p>
        </div>
        <button type="button" className="sr-btn sr-btn-primary" onClick={() => { setForm(emptyForm()); setError(''); setModalOpen(true); }}>
          <Plus size={16} /> Add work
        </button>
      </div>

      <TxnToolbar list={list} placeholder="Search name, category…" />

      <div className="sr-list-card">
        {loading ? (
          <div className="sr-empty"><Loader2 className="spin" size={22} /> Loading…</div>
        ) : list.total === 0 ? (
          <div className="sr-empty">No work entries match.</div>
        ) : (
          <>
            <div className="sr-table-wrap">
              <table className="sr-table">
                <thead>
                  <tr><th>Date</th><th>Name</th><th>Category</th><th>Shift</th><th>Wage</th><th>Narration</th><th /></tr>
                </thead>
                <tbody>
                  {list.paged.map((r) => (
                    <tr key={r.id}>
                      <td>{String(r.date || '').slice(0, 10)}</td>
                      <td>{r.name}</td>
                      <td>{r.category}</td>
                      <td>{r.shift}</td>
                      <td>{money(r.wage)}</td>
                      <td>{r.narration || '—'}</td>
                      <td>
                        <button type="button" className="sr-btn sr-btn-ghost" onClick={async () => {
                          if (!window.confirm('Delete?')) return;
                          await deleteMyLaborWork(r.id);
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
        <TxnModal title="Work entry" onClose={() => setModalOpen(false)} saving={saving}>
          <form onSubmit={save}>
            {error && <div className="sr-error" style={{ marginBottom: 10 }}>{error}</div>}
            <div className="txn-form-grid">
              <label>Name<input required value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} /></label>
              <label>Mobile<input value={form.mobile} onChange={(e) => setForm({ ...form, mobile: e.target.value })} /></label>
              <label>Category
                <select value={form.category} onChange={(e) => setForm({ ...form, category: e.target.value })}>
                  {LABOR_CATEGORIES.map((c) => <option key={c}>{c}</option>)}
                </select>
              </label>
              <label>Shift
                <select value={form.shift} onChange={(e) => setForm({ ...form, shift: e.target.value })}>
                  {LABOR_SHIFTS.map((s) => <option key={s.id} value={s.id}>{s.label}</option>)}
                </select>
              </label>
              <label>Gender
                <select value={form.gender} onChange={(e) => setForm({ ...form, gender: e.target.value })}>
                  <option>Male</option><option>Female</option>
                </select>
              </label>
              <label>Days/Hours<input type="number" min="0" step="0.5" value={form.hours} onChange={(e) => setForm({ ...form, hours: e.target.value })} /></label>
              <label>Rate<input required type="number" min="0" step="0.01" value={form.wage} onChange={(e) => setForm({ ...form, wage: e.target.value })} /></label>
              <label>Date<input required type="date" value={form.date} onChange={(e) => setForm({ ...form, date: e.target.value })} /></label>
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

export default LabourWorkEntry;
