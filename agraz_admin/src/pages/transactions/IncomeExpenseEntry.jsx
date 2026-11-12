import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { Download, Wallet, Loader2, Plus, Trash2 } from 'lucide-react';
import {
  getIncomeExpenses,
  createIncomeExpense,
  deleteIncomeExpense,
  getMyOrganizations,
} from '../../api/api';
import { IE_CATEGORIES, todayIso, money, fetchAllPages } from '../../lib/transactions';
import { downloadExcel, isoToDisplay } from '../../lib/excel';
import { blankMoney, incomeExpenseLedger } from '../../lib/ledger';
import { useTxnList, TxnToolbar, TxnPager, TxnModal } from './txnList.jsx';
import '../ServiceRegistrations.css';
import './Transactions.css';

const IE_HEADERS = ['Date', 'Category', 'Sub category', 'Name', 'Narration', 'Income', 'Expense', 'Balance'];

function exportIncomeExpenseExcel(rows) {
  const ledger = incomeExpenseLedger(rows);
  const ordered = [...(rows || [])].sort((a, b) => String(a.date || '').localeCompare(String(b.date || '')) || (a.id || 0) - (b.id || 0));
  const data = ordered.map((row) => {
    const cell = ledger.byId.get(row.id) || {};
    return [
      isoToDisplay(row.date || row.transaction_date),
      row.category || '',
      row.sub_category || row.subCategory || '',
      row.name || '',
      row.narration || '',
      blankMoney(cell.income),
      blankMoney(cell.expense),
      cell.balance ?? 0,
    ];
  });
  data.push(['', '', '', '', 'Total', ledger.income, ledger.expense, ledger.balance]);
  downloadExcel(`income_expense_${todayIso()}.xlsx`, [{ name: 'Income & Expense', headers: IE_HEADERS, rows: data }]);
}

const emptyForm = () => ({
  type: 'Expense',
  category: '',
  subCategory: '',
  amount: '',
  date: todayIso(),
  transaction_mode: 'Cash',
  organization_id: '',
  name: '',
  mobile: '',
  narration: '',
  village: '',
});

const IncomeExpenseEntry = () => {
  const [rows, setRows] = useState([]);
  const [orgs, setOrgs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [modalOpen, setModalOpen] = useState(false);
  const [form, setForm] = useState(emptyForm());
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');

  const list = useTxnList(rows, {
    searchKeys: ['type', 'category', 'sub_category', 'subCategory', 'narration', 'name', 'mobile'],
    defaultSort: 'date_desc',
  });
  const ledger = useMemo(() => incomeExpenseLedger(list.filtered), [list.filtered]);

  const categories = useMemo(
    () => Object.keys(IE_CATEGORIES[form.type] || {}),
    [form.type]
  );
  const subCategories = useMemo(
    () => (form.category ? IE_CATEGORIES[form.type]?.[form.category] || [] : []),
    [form.type, form.category]
  );

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const [ie, orgRes] = await Promise.all([
        fetchAllPages((params) => getIncomeExpenses(params)),
        getMyOrganizations(),
      ]);
      setRows(Array.isArray(ie) ? ie : (ie.data || []));
      setOrgs(orgRes.data || orgRes || []);
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
      const payload = {
        type: form.type,
        category: form.category,
        subCategory: form.subCategory,
        subCategories: [form.subCategory],
        amount: Number(form.amount),
        date: form.date,
        transaction_mode: form.transaction_mode,
        transactionMode: form.transaction_mode,
        name: form.name || undefined,
        mobile: form.mobile || undefined,
        narration: form.narration || undefined,
        village: form.village || undefined,
      };
      if (form.transaction_mode === 'Transfer' || form.organization_id) {
        payload.organization_id = Number(form.organization_id) || undefined;
      }
      await createIncomeExpense(payload);
      setModalOpen(false);
      await load();
    } catch (err) {
      setError(err.response?.data?.error || err.response?.data?.message || 'Save failed');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="service-reg-page">
      <div className="sr-page-header">
        <div className="title-area">
          <h1><Wallet size={22} style={{ marginRight: 8, verticalAlign: -4 }} />Income &amp; Expenses</h1>
          <p>Record farm and house income or expense — same as the app.</p>
        </div>
        <div className="txn-header-actions">
          <button
            type="button"
            className="sr-btn sr-btn-ghost"
            disabled={loading || list.total === 0}
            title="One sheet with Income, Expense, and Balance"
            onClick={() => exportIncomeExpenseExcel(list.filtered)}
          >
            <Download size={16} /> Export Excel
          </button>
          <button type="button" className="sr-btn sr-btn-primary" onClick={() => { setForm(emptyForm()); setError(''); setModalOpen(true); }}>
            <Plus size={16} /> Add entry
          </button>
        </div>
      </div>

      <TxnToolbar
        list={list}
        placeholder="Search category, name, narration…"
        filterOptions={[
          { id: 'Income', label: 'Income' },
          { id: 'Expense', label: 'Expense' },
        ]}
      />

      {!loading && (
        <div className="txn-totals">
          <div className="txn-total"><span>Income</span><strong className="txn-in">{money(ledger.income)}</strong></div>
          <div className="txn-total"><span>Expense</span><strong className="txn-out">{money(ledger.expense)}</strong></div>
          <div className="txn-total"><span>Balance</span><strong className={ledger.balance < 0 ? 'txn-out' : 'txn-in'}>{money(ledger.balance)}</strong></div>
        </div>
      )}

      <div className="sr-list-card">
        {loading ? (
          <div className="sr-empty"><Loader2 className="spin" size={22} /> Loading…</div>
        ) : list.total === 0 ? (
          <div className="sr-empty">No entries match.</div>
        ) : (
          <>
            <div className="sr-table-wrap">
              <table className="sr-table">
                <thead>
                  <tr>
                    <th>Date</th>
                    <th>Category</th>
                    <th>Sub</th>
                    <th>Narration</th>
                    <th className="txn-num">Income</th>
                    <th className="txn-num">Expense</th>
                    <th className="txn-num">Balance</th>
                    <th />
                  </tr>
                </thead>
                <tbody>
                  {list.paged.map((r) => {
                    const cell = ledger.byId.get(r.id) || {};
                    return (
                    <tr key={r.id}>
                      <td>{String(r.date || r.transaction_date || '').slice(0, 10)}</td>
                      <td>{r.category}</td>
                      <td>{r.sub_category || r.subCategory}</td>
                      <td>{r.narration || '—'}</td>
                      <td className="txn-num txn-in">{cell.income == null ? '—' : money(cell.income)}</td>
                      <td className="txn-num txn-out">{cell.expense == null ? '—' : money(cell.expense)}</td>
                      <td className={`txn-num ${cell.balance < 0 ? 'txn-out' : 'txn-in'}`}>{money(cell.balance || 0)}</td>
                      <td>
                        <button type="button" className="sr-btn sr-btn-ghost" onClick={async () => {
                          if (!window.confirm('Delete this entry?')) return;
                          await deleteIncomeExpense(r.id);
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
        <TxnModal title="New income / expense" onClose={() => setModalOpen(false)} saving={saving}>
          <form onSubmit={save}>
            {error && <div className="sr-error" style={{ marginBottom: 10 }}>{error}</div>}
            <div className="txn-form-grid">
              <label>Type
                <select value={form.type} onChange={(e) => setForm({ ...form, type: e.target.value, category: '', subCategory: '' })}>
                  <option>Income</option><option>Expense</option>
                </select>
              </label>
              <label>Category
                <select required value={form.category} onChange={(e) => setForm({ ...form, category: e.target.value, subCategory: '' })}>
                  <option value="">Select</option>
                  {categories.map((c) => <option key={c} value={c}>{c}</option>)}
                </select>
              </label>
              <label>Sub category
                <select required value={form.subCategory} onChange={(e) => setForm({ ...form, subCategory: e.target.value })}>
                  <option value="">Select</option>
                  {subCategories.map((c) => <option key={c} value={c}>{c}</option>)}
                </select>
              </label>
              <label>Amount (₹)
                <input required type="number" min="0.01" step="0.01" value={form.amount} onChange={(e) => setForm({ ...form, amount: e.target.value })} />
              </label>
              <label>Date
                <input required type="date" value={form.date} onChange={(e) => setForm({ ...form, date: e.target.value })} />
              </label>
              <label>Mode
                <select value={form.transaction_mode} onChange={(e) => setForm({ ...form, transaction_mode: e.target.value })}>
                  <option>Cash</option><option>Transfer</option>
                </select>
              </label>
              <label>Organization
                <select required={form.transaction_mode === 'Transfer'} value={form.organization_id} onChange={(e) => setForm({ ...form, organization_id: e.target.value })}>
                  <option value="">Select</option>
                  {orgs.map((o) => <option key={o.id} value={o.id}>{o.name}</option>)}
                </select>
              </label>
              <label>Person name
                <input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
              </label>
              <label>Mobile
                <input value={form.mobile} onChange={(e) => setForm({ ...form, mobile: e.target.value })} />
              </label>
              <label className="txn-span-2">Narration
                <input value={form.narration} onChange={(e) => setForm({ ...form, narration: e.target.value })} />
              </label>
              <label>Village
                <input value={form.village} onChange={(e) => setForm({ ...form, village: e.target.value })} />
              </label>
            </div>
            <div className="txn-form-actions">
              <button type="button" className="sr-btn sr-btn-ghost" disabled={saving} onClick={() => setModalOpen(false)}>Cancel</button>
              <button type="submit" className="sr-btn sr-btn-primary" disabled={saving}>
                {saving ? <Loader2 className="spin" size={16} /> : 'Save'}
              </button>
            </div>
          </form>
        </TxnModal>
      )}
    </div>
  );
};

export default IncomeExpenseEntry;
