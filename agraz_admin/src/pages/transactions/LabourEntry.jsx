import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { Briefcase, Download, Loader2, Plus, Trash2 } from 'lucide-react';
import { getMyLabors, createMyLabor, deleteMyLabor } from '../../api/api';
import { LABOR_CATEGORIES, LABOR_SHIFTS, todayIso, money, fetchAllPages } from '../../lib/transactions';
import { downloadExcel, isoToDisplay } from '../../lib/excel';
import { blankMoney, labourLedger } from '../../lib/ledger';
import { useTxnList, TxnToolbar, TxnPager, TxnModal } from './txnList.jsx';
import '../ServiceRegistrations.css';
import './Transactions.css';

const LABOUR_HEADERS = ['Date', 'Name', 'Category', 'Shift', 'Rate', 'Qty', 'Amount', 'Payable', 'Payment', 'Balance', 'Narration'];

function exportLabourExcel(rows) {
  const ledger = labourLedger(rows);
  const ordered = [...(rows || [])].sort((a, b) => String(a.date || '').localeCompare(String(b.date || '')) || (a.id || 0) - (b.id || 0));
  const data = ordered.map((row) => {
    const cell = ledger.byId.get(row.id) || {};
    return [
      isoToDisplay(row.date),
      row.name || '',
      row.category || '',
      row.shift || '',
      blankMoney(cell.rate),
      blankMoney(cell.qty),
      blankMoney(cell.amount),
      blankMoney(cell.payable),
      blankMoney(cell.payment),
      cell.balance ?? 0,
      row.narration || '',
    ];
  });
  data.push(['', '', '', '', '', '', 'Total', ledger.payable, ledger.payment, ledger.balance, '']);
  downloadExcel(`labour_${todayIso()}.xlsx`, [{ name: 'Labour', headers: LABOUR_HEADERS, rows: data }]);
}

function formatQty(cell) {
  if (cell.qty == null) return '—';
  if (cell.people > 1) return `${cell.days} × ${cell.people}`;
  return String(cell.qty);
}

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
    defaultSort: 'date_asc',
    nameKey: 'name',
  });
  const ledger = useMemo(() => labourLedger(list.filtered), [list.filtered]);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      setRows(await fetchAllPages((params) => getMyLabors(params)));
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
          <p>One running balance for all labour, in date order. Payable adds, payment subtracts.</p>
        </div>
        <div className="txn-header-actions">
          <button
            type="button"
            className="sr-btn sr-btn-ghost"
            disabled={loading || list.total === 0}
            title="Download the rows matching the current search and filters"
            onClick={() => exportLabourExcel(list.filtered)}
          >
            <Download size={16} /> Export Excel
          </button>
          <button type="button" className="sr-btn sr-btn-primary" onClick={() => { setForm(emptyForm()); setError(''); setModalOpen(true); }}>
            <Plus size={16} /> Add labour
          </button>
        </div>
      </div>

      <TxnToolbar
        list={list}
        nameSelect
        placeholder="Type a name, then select…"
        filterOptions={[
          { id: 'payable', label: 'Work (payable)' },
          { id: 'payment', label: 'Payment' },
          { id: 'tally', label: 'Tally' },
          { id: 'opening', label: 'Opening' },
        ]}
        filterLabel="Kind"
      />

      {!loading && (
        <div className="txn-totals">
          <div className="txn-total"><span>Payable</span><strong className="txn-out">{money(ledger.payable)}</strong></div>
          <div className="txn-total"><span>Payment</span><strong className="txn-in">{money(ledger.payment)}</strong></div>
          <div className="txn-total"><span>Balance</span><strong className={ledger.balance > 0 ? 'txn-out' : 'txn-in'}>{money(ledger.balance)}</strong></div>
        </div>
      )}

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
                  <tr>
                    <th>Date</th><th>Name</th><th>Category</th><th>Shift</th>
                    <th className="txn-num">Rate</th>
                    <th className="txn-num">Qty</th>
                    <th className="txn-num">Amount</th>
                    <th className="txn-num">Payable</th>
                    <th className="txn-num">Payment</th>
                    <th className="txn-num">Balance</th>
                    <th>Narration</th><th />
                  </tr>
                </thead>
                <tbody>
                  {list.paged.map((r) => {
                    const cell = ledger.byId.get(r.id) || {};
                    const kind = String(r.entry_kind || 'payable').toLowerCase();
                    return (
                    <tr key={r.id}>
                      <td>{String(r.date || '').slice(0, 10)}</td>
                      <td>
                        {r.name}
                        {(kind === 'opening' || kind === 'tally') && <div className="txn-kind">{kind}</div>}
                      </td>
                      <td>{r.category}</td>
                      <td>{r.shift}</td>
                      <td className="txn-num">{cell.rate == null ? '—' : money(cell.rate)}</td>
                      <td className="txn-num">{cell.qty == null ? '—' : formatQty(cell)}</td>
                      <td className="txn-num">{cell.amount == null ? '—' : money(cell.amount)}</td>
                      <td className="txn-num txn-out">{cell.payable == null ? '—' : money(cell.payable)}</td>
                      <td className="txn-num txn-in">{cell.payment == null ? '—' : money(cell.payment)}</td>
                      <td className={`txn-num ${cell.balance > 0 ? 'txn-out' : 'txn-in'}`}>{money(cell.balance || 0)}</td>
                      <td>{r.narration || '—'}</td>
                      <td>
                        <button type="button" className="sr-btn sr-btn-ghost" onClick={async () => {
                          if (!window.confirm('Delete?')) return;
                          await deleteMyLabor(r.id);
                          load();
                        }}><Trash2 size={14} /></button>
                      </td>
                    </tr>
                    );
                  })}
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
