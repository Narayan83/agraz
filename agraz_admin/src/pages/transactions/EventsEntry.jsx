import React, { useCallback, useEffect, useState } from 'react';
import { CalendarDays, Loader2, Plus, Trash2 } from 'lucide-react';
import { getMyEvents, createMyEvent, updateMyEvent, deleteMyEvent } from '../../api/api';
import { todayIso } from '../../lib/transactions';
import { useTxnList, TxnToolbar, TxnPager, TxnModal } from './txnList.jsx';
import '../ServiceRegistrations.css';
import './Transactions.css';

const RECURRENCE = [
  { id: 'yearly', label: 'Yearly' },
  { id: 'monthly', label: 'Monthly' },
  { id: 'weekly', label: 'Weekly' },
  { id: 'daily', label: 'Daily' },
];

const emptyForm = () => ({
  name: '',
  event_date: todayIso(),
  recurrence: 'yearly',
  notify_time: '09:00',
});

const EventsEntry = () => {
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [modalOpen, setModalOpen] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [form, setForm] = useState(emptyForm());
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const list = useTxnList(rows, {
    searchKeys: ['name', 'recurrence', 'notify_time'],
    defaultSort: 'date_asc',
  });

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const data = await getMyEvents({ page: 1, limit: 200 });
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
          <h1><CalendarDays size={22} style={{ marginRight: 8, verticalAlign: -4 }} />Event Manage</h1>
          <p>Birthdays, renewals, and farm reminders.</p>
        </div>
        <button type="button" className="sr-btn sr-btn-primary" onClick={() => {
          setEditingId(null); setForm(emptyForm()); setError(''); setModalOpen(true);
        }}>
          <Plus size={16} /> Add event
        </button>
      </div>

      <TxnToolbar
        list={list}
        placeholder="Search event name…"
        filterOptions={RECURRENCE}
        filterLabel="Recurrence"
        sortOptions={[
          { id: 'date_asc', label: 'Date ↑' },
          { id: 'date_desc', label: 'Date ↓' },
          { id: 'name_asc', label: 'Name A–Z' },
          { id: 'name_desc', label: 'Name Z–A' },
        ]}
      />

      <div className="sr-list-card">
        {loading ? (
          <div className="sr-empty"><Loader2 className="spin" size={22} /> Loading…</div>
        ) : list.total === 0 ? (
          <div className="sr-empty">No events match.</div>
        ) : (
          <>
            <div className="sr-table-wrap">
              <table className="sr-table">
                <thead><tr><th>Name</th><th>Date</th><th>Recurrence</th><th>Time</th><th /></tr></thead>
                <tbody>
                  {list.paged.map((r) => (
                    <tr key={r.id}>
                      <td>{r.name}</td>
                      <td>{String(r.event_date || r.date || '').slice(0, 10)}</td>
                      <td>{r.recurrence || 'yearly'}</td>
                      <td>{r.notify_time || '—'}</td>
                      <td style={{ whiteSpace: 'nowrap' }}>
                        <button type="button" className="sr-btn sr-btn-ghost" onClick={() => {
                          setEditingId(r.id);
                          setForm({
                            name: r.name || '',
                            event_date: String(r.event_date || r.date || todayIso()).slice(0, 10),
                            recurrence: r.recurrence || 'yearly',
                            notify_time: r.notify_time || '09:00',
                          });
                          setModalOpen(true);
                        }}>Edit</button>
                        <button type="button" className="sr-btn sr-btn-ghost" onClick={async () => {
                          if (!window.confirm('Delete?')) return;
                          await deleteMyEvent(r.id);
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
        <TxnModal title={editingId ? 'Edit event' : 'New event'} onClose={() => setModalOpen(false)} saving={saving}>
          <form onSubmit={async (e) => {
            e.preventDefault(); setSaving(true); setError('');
            try {
              const payload = {
                name: form.name.trim(),
                event_date: form.event_date,
                recurrence: form.recurrence,
                notify_time: form.notify_time,
              };
              if (editingId) await updateMyEvent(editingId, payload);
              else await createMyEvent(payload);
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
              <label>Date<input required type="date" value={form.event_date} onChange={(e) => setForm({ ...form, event_date: e.target.value })} /></label>
              <label>Recurrence
                <select value={form.recurrence} onChange={(e) => setForm({ ...form, recurrence: e.target.value })}>
                  {RECURRENCE.map((r) => <option key={r.id} value={r.id}>{r.label}</option>)}
                </select>
              </label>
              <label>Notify time<input type="time" value={form.notify_time} onChange={(e) => setForm({ ...form, notify_time: e.target.value })} /></label>
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

export default EventsEntry;
