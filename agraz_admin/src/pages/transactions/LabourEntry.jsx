import React, { useCallback, useEffect, useState } from 'react';
import { Briefcase, Loader2, Plus, Trash2 } from 'lucide-react';
import { getMyLabors, createMyLabor, deleteMyLabor } from '../../api/api';
import { LABOR_CATEGORIES, LABOR_SHIFTS, todayIso, money } from '../../lib/transactions';
import { useTxnList, TxnToolbar, TxnPager, TxnModal } from './txnList.jsx';
import '../ServiceRegistrations.css';
import './Transactions.css';

const emptyForm = () => ({
  name: '', mobile: '', category: 'Plucking', shift: 'fullday', gender: 'Male',
  work_type: 'Daily Wages', labour_head: '', hours: '1', wage: '', number_of_labours: '1',
  paid_amount: '', entry_kind: 'payable', date: todayIso(), location: 'Farm',
  narration: '', rent: '', food: '', bonus: '',
});

const LabourEntry = () => {
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [modalOpen, setModalOpen] = useState(false);
  const [form, setForm] = useState(emptyForm());
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const list = useTxnList(rows, {
    searchKeys: ['name', 'mobile', 'category', 'narration', 'entry_kind', 'shift'],
    defaultSort: 'date_desc',
  });

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const data = await getMyLabors({ page: 1, limit: 200 });
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
      await createMyLabor({
        name: form.name.trim(),
        mobile: form.mobile.trim() || undefined,
        category: form.category,
        shift: form.shift,
        gender: form.gender,
        work_type: form.work_type,
        labour_head: form.labour_head || undefined,
        hours: Number(form.hours) || 1,
        wage: Number(form.wage) || 0,
        number_of_labours: Number(form.number_of_labours) || 1,
        paid_amount: Number(form.paid_amount) || 0,
        entry_kind: form.entry_kind,
        date: form.date,
        location: form.location || 'Farm',
        narration: form.narration || undefined,
        rent: Number(form.rent) || 0,
        food: Number(form.food) || 0,
        bonus: Number(form.bonus) || 0,
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
          <h1><Briefcase size={22} style={{ marginRight: 8, verticalAlign: -4 }} />Labour Entry</h1>
          <p>Daily wages, contract work, and payments.</p>
        </div>
        <button type="button" className="sr-btn sr-btn-primary" onClick={() => { setForm(emptyForm()); setError(''); setModalOpen(true); }}>
          <Plus size={16} /> Add labour
        </button>
      </div>

      <TxnToolbar
        list={list}
        placeholder="Search name, category, narration…"
        filterOptions={[
          { id: 'payable', label: 'Work (payable)' },
          { id: 'payment', label: 'Payment' },
          { id: 'tally', label: 'Tally' },
          { id: 'opening', label: 'Opening' },
        ]}
        filterLabel="Kind"
      />

      <div className="sr-list-card">
        {loading ? (
          <div className="sr-empty"><Loader2 className="spin" size={22} /> Loading…</div>
        ) : list.total === 0 ? (
          <div className="sr-empty">No labour entries match.</div>
        ) : (
          <>
            <div className="sr-table-wrap">
              <table className="sr-table">
                <thead>
                  <tr><th>Date</th><th>Name</th><th>Category</th><th>Shift</th><th>Wage</th><th>Kind</th><th>Narration</th><th /></tr>
                </thead>
                <tbody>
                  {list.paged.map((r) => (
                    <tr key={r.id}>
                      <td>{String(r.date || '').slice(0, 10)}</td>
                      <td>{r.name}</td>
                      <td>{r.category}</td>
                      <td>{r.shift}</td>
                      <td>{money(r.wage)}</td>
                      <td>{r.entry_kind || 'payable'}</td>
                      <td>{r.narration || '—'}</td>
                      <td>
                        <button type="button" className="sr-btn sr-btn-ghost" onClick={async () => {
                          if (!window.confirm('Delete?')) return;
                          await deleteMyLabor(r.id);
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
        <TxnModal title="Labour entry" onClose={() => setModalOpen(false)} saving={saving}>
          <form onSubmit={save}>
            {error && <div className="sr-error" style={{ marginBottom: 10 }}>{error}</div>}
            <div className="txn-form-grid">
              <label>Entry kind
                <select value={form.entry_kind} onChange={(e) => setForm({ ...form, entry_kind: e.target.value })}>
                  <option value="payable">Work (payable)</option>
                  <option value="payment">Payment only</option>
                  <option value="tally">Tally / closing</option>
                  <option value="opening">Opening balance</option>
                </select>
              </label>
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
              <label>Work type
                <select value={form.work_type} onChange={(e) => setForm({ ...form, work_type: e.target.value })}>
                  <option>Daily Wages</option><option>Contract</option>
                </select>
              </label>
              <label>Gender
                <select value={form.gender} onChange={(e) => setForm({ ...form, gender: e.target.value })}>
                  <option>Male</option><option>Female</option>
                </select>
              </label>
              {form.work_type === 'Contract' && (
                <label>Labour head<input value={form.labour_head} onChange={(e) => setForm({ ...form, labour_head: e.target.value })} /></label>
              )}
              <label>Days/Hours<input type="number" min="0" step="0.5" value={form.hours} onChange={(e) => setForm({ ...form, hours: e.target.value })} /></label>
              <label>Rate / wage<input required type="number" min="0" step="0.01" value={form.wage} onChange={(e) => setForm({ ...form, wage: e.target.value })} /></label>
              <label>No. of labours<input type="number" min="1" value={form.number_of_labours} onChange={(e) => setForm({ ...form, number_of_labours: e.target.value })} /></label>
              <label>Paid now<input type="number" min="0" step="0.01" value={form.paid_amount} onChange={(e) => setForm({ ...form, paid_amount: e.target.value })} /></label>
              <label>Date<input required type="date" value={form.date} onChange={(e) => setForm({ ...form, date: e.target.value })} /></label>
              <label>Rent<input type="number" min="0" value={form.rent} onChange={(e) => setForm({ ...form, rent: e.target.value })} /></label>
              <label>Food<input type="number" min="0" value={form.food} onChange={(e) => setForm({ ...form, food: e.target.value })} /></label>
              <label>Bonus<input type="number" min="0" value={form.bonus} onChange={(e) => setForm({ ...form, bonus: e.target.value })} /></label>
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

export default LabourEntry;
