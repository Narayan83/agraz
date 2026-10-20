import React, { useCallback, useEffect, useState } from 'react';
import { Building2, Loader2, Plus, Trash2 } from 'lucide-react';
import {
  getMyOrganizations, createMyOrganization, deleteMyOrganization,
  getMyOrgLedgers, createMyOrgLedger,
  getMyOrgTransactions, createMyOrgTransaction, deleteMyOrgTransaction,
} from '../../api/api';
import { todayIso, money } from '../../lib/transactions';
import { useTxnList, TxnToolbar, TxnPager, TxnModal } from './txnList.jsx';
import '../ServiceRegistrations.css';
import './Transactions.css';

const OrganizationsEntry = () => {
  const [tab, setTab] = useState('transactions');
  const [orgs, setOrgs] = useState([]);
  const [ledgers, setLedgers] = useState([]);
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [orgModal, setOrgModal] = useState(false);
  const [ledgerModal, setLedgerModal] = useState(false);
  const [txnModal, setTxnModal] = useState(false);
  const [orgName, setOrgName] = useState('');
  const [ledgerName, setLedgerName] = useState('');
  const [form, setForm] = useState({
    type: 'Expense', organization_id: '', ledger_id: '', amount: '', date: todayIso(),
    transaction_mode: 'Cash', transfer_to_organization_id: '', narration: '',
  });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');

  const list = useTxnList(rows, {
    searchKeys: tab === 'transactions'
      ? ['type', 'narration', 'transaction_mode', 'organization.name', 'ledger.name']
      : ['name'],
    defaultSort: tab === 'transactions' ? 'date_desc' : 'name_asc',
  });

  const loadMeta = useCallback(async () => {
    const [o, l] = await Promise.all([getMyOrganizations(), getMyOrgLedgers()]);
    setOrgs(o.data || o || []);
    setLedgers(l.data || l || []);
  }, []);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      await loadMeta();
      if (tab === 'transactions') {
        const t = await getMyOrgTransactions({ page: 1, limit: 200 });
        setRows(t.data || t || []);
      } else if (tab === 'organizations') {
        const o = await getMyOrganizations();
        setRows(o.data || o || []);
      } else {
        const l = await getMyOrgLedgers();
        setRows(l.data || l || []);
      }
    } catch (e) {
      console.error(e);
      setRows([]);
    } finally {
      setLoading(false);
    }
  }, [tab, loadMeta]);

  useEffect(() => { load(); }, [load]);

  return (
    <div className="service-reg-page">
      <div className="sr-page-header">
        <div className="title-area">
          <h1><Building2 size={22} style={{ marginRight: 8, verticalAlign: -4 }} />Manage Organization</h1>
          <p>Separate books per farm / unit with ledgers.</p>
        </div>
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          <button type="button" className="sr-btn sr-btn-ghost" onClick={() => { setError(''); setOrgName(''); setOrgModal(true); }}>
            <Plus size={16} /> Org
          </button>
          <button type="button" className="sr-btn sr-btn-ghost" onClick={() => { setError(''); setLedgerName(''); setLedgerModal(true); }}>
            <Plus size={16} /> Ledger
          </button>
          <button type="button" className="sr-btn sr-btn-primary" onClick={() => {
            setError('');
            setForm({
              type: 'Expense',
              organization_id: orgs[0]?.id ? String(orgs[0].id) : '',
              ledger_id: ledgers[0]?.id ? String(ledgers[0].id) : '',
              amount: '', date: todayIso(), transaction_mode: 'Cash',
              transfer_to_organization_id: '', narration: '',
            });
            setTxnModal(true);
          }}>
            <Plus size={16} /> Entry
          </button>
        </div>
      </div>

      <div className="sr-toolbar">
        <div className="sr-filter-tabs">
          {['transactions', 'organizations', 'ledgers'].map((t) => (
            <button key={t} type="button" className={`sr-filter-tab${tab === t ? ' active' : ''}`} onClick={() => setTab(t)}>
              {t.charAt(0).toUpperCase() + t.slice(1)}
            </button>
          ))}
        </div>
      </div>

      <TxnToolbar
        list={list}
        placeholder={tab === 'transactions' ? 'Search narration, org…' : 'Search name…'}
        filterOptions={tab === 'transactions' ? [
          { id: 'Income', label: 'Income' },
          { id: 'Expense', label: 'Expense' },
        ] : null}
        sortOptions={tab === 'transactions' ? undefined : [
          { id: 'name_asc', label: 'Name A–Z' },
          { id: 'name_desc', label: 'Name Z–A' },
        ]}
      />

      <div className="sr-list-card">
        {loading ? (
          <div className="sr-empty"><Loader2 className="spin" size={22} /> Loading…</div>
        ) : list.total === 0 ? (
          <div className="sr-empty">Nothing matches.</div>
        ) : tab === 'transactions' ? (
          <>
            <div className="sr-table-wrap">
              <table className="sr-table">
                <thead>
                  <tr><th>Date</th><th>Type</th><th>Org</th><th>Ledger</th><th>Amount</th><th>Mode</th><th>Narration</th><th /></tr>
                </thead>
                <tbody>
                  {list.paged.map((r) => (
                    <tr key={r.id}>
                      <td>{String(r.date || '').slice(0, 10)}</td>
                      <td>{r.type}</td>
                      <td>{r.organization?.name || r.organization_id}</td>
                      <td>{r.ledger?.name || r.ledger_id}</td>
                      <td>{money(r.amount)}</td>
                      <td>{r.transaction_mode}</td>
                      <td>{r.narration || '—'}</td>
                      <td>
                        <button type="button" className="sr-btn sr-btn-ghost" onClick={async () => {
                          if (!window.confirm('Delete?')) return;
                          await deleteMyOrgTransaction(r.id);
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
                <thead><tr><th>Name</th><th /></tr></thead>
                <tbody>
                  {list.paged.map((r) => (
                    <tr key={r.id}>
                      <td>{r.name}</td>
                      <td>
                        {tab === 'organizations' && (
                          <button type="button" className="sr-btn sr-btn-ghost" onClick={async () => {
                            if (!window.confirm('Delete organization?')) return;
                            try { await deleteMyOrganization(r.id); load(); }
                            catch (err) { alert(err.response?.data?.error || 'Delete failed'); }
                          }}><Trash2 size={14} /></button>
                        )}
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

      {orgModal && (
        <TxnModal title="New organization" onClose={() => setOrgModal(false)} wide={false} saving={saving}>
          <form onSubmit={async (e) => {
            e.preventDefault(); setSaving(true); setError('');
            try { await createMyOrganization({ name: orgName.trim() }); setOrgModal(false); await load(); }
            catch (err) { setError(err.response?.data?.error || 'Failed'); }
            finally { setSaving(false); }
          }}>
            {error && <div className="sr-error" style={{ marginBottom: 10 }}>{error}</div>}
            <div className="txn-form-grid-2">
              <label className="txn-span-2">Name<input required value={orgName} onChange={(e) => setOrgName(e.target.value)} /></label>
            </div>
            <div className="txn-form-actions">
              <button type="submit" className="sr-btn sr-btn-primary" disabled={saving}>Save</button>
            </div>
          </form>
        </TxnModal>
      )}

      {ledgerModal && (
        <TxnModal title="New ledger" onClose={() => setLedgerModal(false)} wide={false} saving={saving}>
          <form onSubmit={async (e) => {
            e.preventDefault(); setSaving(true); setError('');
            try { await createMyOrgLedger({ name: ledgerName.trim() }); setLedgerModal(false); await load(); }
            catch (err) { setError(err.response?.data?.error || 'Failed'); }
            finally { setSaving(false); }
          }}>
            {error && <div className="sr-error" style={{ marginBottom: 10 }}>{error}</div>}
            <div className="txn-form-grid-2">
              <label className="txn-span-2">Name<input required value={ledgerName} onChange={(e) => setLedgerName(e.target.value)} /></label>
            </div>
            <div className="txn-form-actions">
              <button type="submit" className="sr-btn sr-btn-primary" disabled={saving}>Save</button>
            </div>
          </form>
        </TxnModal>
      )}

      {txnModal && (
        <TxnModal title="Organization entry" onClose={() => setTxnModal(false)} saving={saving}>
          <form onSubmit={async (e) => {
            e.preventDefault(); setSaving(true); setError('');
            try {
              const payload = {
                type: form.type,
                organization_id: Number(form.organization_id),
                ledger_id: Number(form.ledger_id),
                amount: Number(form.amount),
                date: form.date,
                transaction_mode: form.transaction_mode,
                narration: form.narration || undefined,
              };
              if (form.transaction_mode === 'Transfer') {
                payload.transfer_to_organization_id = Number(form.transfer_to_organization_id);
              }
              await createMyOrgTransaction(payload);
              setTxnModal(false);
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
                <select value={form.type} onChange={(e) => setForm({ ...form, type: e.target.value })}>
                  <option>Income</option><option>Expense</option>
                </select>
              </label>
              <label>Organization
                <select required value={form.organization_id} onChange={(e) => setForm({ ...form, organization_id: e.target.value })}>
                  <option value="">Select</option>
                  {orgs.map((o) => <option key={o.id} value={o.id}>{o.name}</option>)}
                </select>
              </label>
              <label>Ledger
                <select required value={form.ledger_id} onChange={(e) => setForm({ ...form, ledger_id: e.target.value })}>
                  <option value="">Select</option>
                  {ledgers.map((l) => <option key={l.id} value={l.id}>{l.name}</option>)}
                </select>
              </label>
              <label>Amount<input required type="number" min="0.01" step="0.01" value={form.amount} onChange={(e) => setForm({ ...form, amount: e.target.value })} /></label>
              <label>Date<input required type="date" value={form.date} onChange={(e) => setForm({ ...form, date: e.target.value })} /></label>
              <label>Mode
                <select value={form.transaction_mode} onChange={(e) => setForm({ ...form, transaction_mode: e.target.value })}>
                  <option>Cash</option><option>Transfer</option>
                </select>
              </label>
              {form.transaction_mode === 'Transfer' && (
                <label>Transfer to
                  <select required value={form.transfer_to_organization_id} onChange={(e) => setForm({ ...form, transfer_to_organization_id: e.target.value })}>
                    <option value="">Select</option>
                    {orgs.filter((o) => String(o.id) !== String(form.organization_id)).map((o) => (
                      <option key={o.id} value={o.id}>{o.name}</option>
                    ))}
                  </select>
                </label>
              )}
              <label className="txn-span-2">Narration<input value={form.narration} onChange={(e) => setForm({ ...form, narration: e.target.value })} /></label>
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

export default OrganizationsEntry;
