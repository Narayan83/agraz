import React, { useCallback, useEffect, useState } from 'react';
import { FileText, Loader2, Plus, Trash2 } from 'lucide-react';
import { getMyDiaryEntries, createMyDiaryEntry, deleteMyDiaryEntry } from '../../api/api';
import { todayIso } from '../../lib/transactions';
import { useTxnList, TxnToolbar, TxnPager, TxnModal } from './txnList.jsx';
import '../ServiceRegistrations.css';
import './Transactions.css';

const NotesEntry = () => {
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [modalOpen, setModalOpen] = useState(false);
  const [form, setForm] = useState({ entry_type: 'note', title: '', body: '', label: '', date: todayIso() });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const list = useTxnList(rows, {
    searchKeys: ['kind', 'title', 'content', 'body'],
    defaultSort: 'date_desc',
  });

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const data = await getMyDiaryEntries({ page: 1, limit: 200 });
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
          <h1><FileText size={22} style={{ marginRight: 8, verticalAlign: -4 }} />Notes</h1>
          <p>Daily notes and lists that are not money accounts.</p>
        </div>
        <button type="button" className="sr-btn sr-btn-primary" onClick={() => {
          setForm({ entry_type: 'note', title: '', body: '', label: '', date: todayIso() });
          setError('');
          setModalOpen(true);
        }}>
          <Plus size={16} /> Add note
        </button>
      </div>

      <TxnToolbar
        list={list}
        placeholder="Search title or content…"
        filterOptions={[
          { id: 'note', label: 'Note' },
          { id: 'list', label: 'List' },
        ]}
        filterLabel="Kind"
        sortOptions={[
          { id: 'date_desc', label: 'Date ↓' },
          { id: 'date_asc', label: 'Date ↑' },
          { id: 'name_asc', label: 'Title A–Z' },
          { id: 'name_desc', label: 'Title Z–A' },
        ]}
      />

      <div className="sr-list-card">
        {loading ? (
          <div className="sr-empty"><Loader2 className="spin" size={22} /> Loading…</div>
        ) : list.total === 0 ? (
          <div className="sr-empty">No notes match.</div>
        ) : (
          <>
            <div className="sr-table-wrap">
              <table className="sr-table">
                <thead><tr><th>Date</th><th>Type</th><th>Title</th><th>Label</th><th /></tr></thead>
                <tbody>
                  {list.paged.map((r) => (
                    <tr key={r.id}>
                      <td>{String(r.date || r.created_at || '').slice(0, 10)}</td>
                      <td>{r.kind || r.entry_type || r.type || 'note'}</td>
                      <td>{r.title || r.content || r.body || '—'}</td>
                      <td>{r.label?.name || r.label || '—'}</td>
                      <td>
                        <button type="button" className="sr-btn sr-btn-ghost" onClick={async () => {
                          if (!window.confirm('Delete?')) return;
                          await deleteMyDiaryEntry(r.id);
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
        <TxnModal title="New note" onClose={() => setModalOpen(false)} saving={saving}>
          <form onSubmit={async (e) => {
            e.preventDefault(); setSaving(true); setError('');
            try {
              await createMyDiaryEntry({
                kind: form.entry_type,
                title: form.title.trim(),
                content: form.body,
                date: form.date,
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
              <label>Type
                <select value={form.entry_type} onChange={(e) => setForm({ ...form, entry_type: e.target.value })}>
                  <option value="note">Note</option>
                  <option value="list">List</option>
                </select>
              </label>
              <label>Date<input type="date" value={form.date} onChange={(e) => setForm({ ...form, date: e.target.value })} /></label>
              <label>Label<input value={form.label} onChange={(e) => setForm({ ...form, label: e.target.value })} placeholder="money, work…" /></label>
              <label className="txn-span-3">Title<input required value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} /></label>
              <label className="txn-span-3">Content<textarea rows={4} value={form.body} onChange={(e) => setForm({ ...form, body: e.target.value })} /></label>
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

export default NotesEntry;
