import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { Map, Loader2, Plus, Trash2, Upload } from 'lucide-react';
import {
  getMyLandRtcs, createMyLandRtc, updateMyLandRtc, deleteMyLandRtc,
  uploadMyLandRtcDocument, getUploadsBaseUrl,
} from '../../api/api';
import { useTxnList, TxnToolbar, TxnPager, TxnModal } from './txnList.jsx';
import '../ServiceRegistrations.css';
import './Transactions.css';

const TALUKS = [
  'Sirsi', 'Siddapur', 'Yellapur', 'Mundgod', 'Haliyal', 'Joida',
  'Dandeli', 'Karwar', 'Ankola', 'Kumta', 'Honnavar', 'Bhatkal',
];
const HOBLIS = {
  Sirsi: ['Sirsi', 'Banavasi', 'Sonda', 'Sugavi', 'Chipgi', 'Hulekal', 'Devanalli', 'Bisalkoppa', 'Sampakanda'],
  Siddapur: ['Siddapur', 'Kansur', 'Kyadgi', 'Hareguli', 'Bilagi'],
  Yellapur: ['Yellapur', 'Kiravatti', 'Idagundi', 'Vajralli'],
  Mundgod: ['Mundgod', 'Pala', 'Bedasgaon'],
  Haliyal: ['Haliyal', 'Bhagawati'],
  Joida: ['Joida', 'Castle Rock'],
  Dandeli: ['Dandeli'],
  Karwar: ['Karwar'],
  Ankola: ['Ankola'],
  Kumta: ['Kumta', 'Gokarna'],
  Honnavar: ['Honnavar'],
  Bhatkal: ['Bhatkal', 'Murdeshwar'],
};

const emptyForm = () => ({
  state: 'Karnataka', district: 'Uttara Kannada', taluk: 'Sirsi', hobli: 'Sirsi', grama: 'Sirsi',
  survey_number: '', hissa: '', acre: 0, gunta: 0, ana: 0, details: '', document_url: '',
});

const RtcEntry = () => {
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [modalOpen, setModalOpen] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [form, setForm] = useState(emptyForm());
  const [saving, setSaving] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState('');
  const list = useTxnList(rows, {
    searchKeys: ['taluk', 'hobli', 'grama', 'survey_number', 'hissa', 'details'],
    defaultSort: 'name_asc',
  });
  const hobliOptions = useMemo(() => HOBLIS[form.taluk] || [form.taluk], [form.taluk]);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const data = await getMyLandRtcs({ page: 1, limit: 200 });
      setRows(data.data || data || []);
    } catch (e) {
      console.error(e);
      setRows([]);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  const docHref = (path) => {
    if (!path) return '';
    if (/^https?:\/\//i.test(path)) return path;
    const base = getUploadsBaseUrl();
    return path.startsWith('/') ? `${base}${path}` : `${base}/${path}`;
  };

  return (
    <div className="service-reg-page">
      <div className="sr-page-header">
        <div className="title-area">
          <h1><Map size={22} style={{ marginRight: 8, verticalAlign: -4 }} />RTC Entry</h1>
          <p>Keep your land RTC records with survey number and area.</p>
        </div>
        <button type="button" className="sr-btn sr-btn-primary" onClick={() => {
          setEditingId(null); setForm(emptyForm()); setError(''); setModalOpen(true);
        }}>
          <Plus size={16} /> Add RTC
        </button>
      </div>

      <TxnToolbar
        list={list}
        placeholder="Search survey, taluk, hobli…"
        sortOptions={[
          { id: 'name_asc', label: 'Survey A–Z' },
          { id: 'name_desc', label: 'Survey Z–A' },
          { id: 'date_desc', label: 'Newest' },
          { id: 'date_asc', label: 'Oldest' },
        ]}
      />

      <div className="sr-list-card">
        {loading ? (
          <div className="sr-empty"><Loader2 className="spin" size={22} /> Loading…</div>
        ) : list.total === 0 ? (
          <div className="sr-empty">No RTC records match.</div>
        ) : (
          <>
            <div className="sr-table-wrap">
              <table className="sr-table">
                <thead>
                  <tr><th>Taluk</th><th>Hobli</th><th>Survey</th><th>Hissa</th><th>Area</th><th>Details</th><th /></tr>
                </thead>
                <tbody>
                  {list.paged.map((r) => (
                    <tr key={r.id}>
                      <td>{r.taluk}</td>
                      <td>{r.hobli}</td>
                      <td>{r.survey_number}</td>
                      <td>{r.hissa || '—'}</td>
                      <td>{`${r.acre || 0}A ${r.gunta || 0}G ${r.ana || 0}An`}</td>
                      <td>{r.details || '—'}</td>
                      <td style={{ whiteSpace: 'nowrap' }}>
                        <button type="button" className="sr-btn sr-btn-ghost" onClick={() => {
                          setEditingId(r.id);
                          setForm({
                            state: r.state || 'Karnataka',
                            district: r.district || 'Uttara Kannada',
                            taluk: r.taluk || 'Sirsi',
                            hobli: r.hobli || '',
                            grama: r.grama || '',
                            survey_number: r.survey_number || '',
                            hissa: r.hissa || '',
                            acre: r.acre || 0,
                            gunta: r.gunta || 0,
                            ana: r.ana || 0,
                            details: r.details || '',
                            document_url: r.document_url || '',
                          });
                          setError('');
                          setModalOpen(true);
                        }}>Edit</button>
                        <button type="button" className="sr-btn sr-btn-ghost" onClick={async () => {
                          if (!window.confirm('Delete?')) return;
                          await deleteMyLandRtc(r.id);
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
        <TxnModal title={editingId ? 'Edit RTC' : 'New RTC'} onClose={() => setModalOpen(false)} saving={saving}>
          <form onSubmit={async (e) => {
            e.preventDefault(); setSaving(true); setError('');
            try {
              const payload = {
                ...form,
                acre: Number(form.acre) || 0,
                gunta: Number(form.gunta) || 0,
                ana: Number(form.ana) || 0,
              };
              if (editingId) await updateMyLandRtc(editingId, payload);
              else await createMyLandRtc(payload);
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
              <label>District
                <select value={form.district} onChange={(e) => setForm({ ...form, district: e.target.value })}>
                  <option>Uttara Kannada</option>
                </select>
              </label>
              <label>Taluk
                <select value={form.taluk} onChange={(e) => {
                  const taluk = e.target.value;
                  const hobli = (HOBLIS[taluk] || [taluk])[0];
                  setForm({ ...form, taluk, hobli, grama: hobli });
                }}>
                  {TALUKS.map((t) => <option key={t}>{t}</option>)}
                </select>
              </label>
              <label>Hobli
                <select value={form.hobli} onChange={(e) => setForm({ ...form, hobli: e.target.value, grama: e.target.value })}>
                  {hobliOptions.map((h) => <option key={h}>{h}</option>)}
                </select>
              </label>
              <label>Grama<input value={form.grama} onChange={(e) => setForm({ ...form, grama: e.target.value })} /></label>
              <label>Survey number<input required value={form.survey_number} onChange={(e) => setForm({ ...form, survey_number: e.target.value })} /></label>
              <label>Hissa<input value={form.hissa} onChange={(e) => setForm({ ...form, hissa: e.target.value })} /></label>
              <label>Acre<input type="number" min="0" value={form.acre} onChange={(e) => setForm({ ...form, acre: e.target.value })} /></label>
              <label>Gunta<input type="number" min="0" value={form.gunta} onChange={(e) => setForm({ ...form, gunta: e.target.value })} /></label>
              <label>Ana<input type="number" min="0" value={form.ana} onChange={(e) => setForm({ ...form, ana: e.target.value })} /></label>
              <label className="txn-span-3">Details<textarea rows={2} value={form.details} onChange={(e) => setForm({ ...form, details: e.target.value })} /></label>
              <label className="txn-span-3">
                Document
                <div style={{ display: 'flex', gap: 8, alignItems: 'center', marginTop: 4 }}>
                  <label className="sr-btn sr-btn-ghost" style={{ cursor: 'pointer' }}>
                    <Upload size={14} /> {uploading ? 'Uploading…' : 'Upload'}
                    <input type="file" hidden accept="image/*,.pdf" onChange={async (e) => {
                      const file = e.target.files?.[0];
                      if (!file) return;
                      setUploading(true);
                      try {
                        const res = await uploadMyLandRtcDocument(file);
                        setForm((f) => ({ ...f, document_url: res.url || res.path || res.document_url || '' }));
                      } catch (err) {
                        setError(err.response?.data?.error || 'Upload failed');
                      } finally {
                        setUploading(false);
                      }
                    }} />
                  </label>
                  {form.document_url && <a href={docHref(form.document_url)} target="_blank" rel="noreferrer">View file</a>}
                </div>
              </label>
            </div>
            <div className="txn-form-actions">
              <button type="submit" className="sr-btn sr-btn-primary" disabled={saving}>{saving ? 'Saving…' : 'Save'}</button>
            </div>
          </form>
        </TxnModal>
      )}
    </div>
  );
};

export default RtcEntry;
