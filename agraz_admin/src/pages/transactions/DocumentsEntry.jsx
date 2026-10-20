import React, { useCallback, useEffect, useState } from 'react';
import { FolderOpen, Loader2, Plus, Trash2, Upload } from 'lucide-react';
import {
  browseMyDocuments, createMyDocumentFolder, deleteMyDocumentFolder,
  createMyDocument, deleteMyDocument, uploadMyDocumentImages, getUploadsBaseUrl,
} from '../../api/api';
import { useTxnList, TxnToolbar, TxnPager, TxnModal } from './txnList.jsx';
import '../ServiceRegistrations.css';
import './Transactions.css';

const DocumentsEntry = () => {
  const [folderId, setFolderId] = useState(null);
  const [folders, setFolders] = useState([]);
  const [documents, setDocuments] = useState([]);
  const [loading, setLoading] = useState(true);
  const [folderModal, setFolderModal] = useState(false);
  const [docModal, setDocModal] = useState(false);
  const [folderName, setFolderName] = useState('');
  const [docName, setDocName] = useState('');
  const [images, setImages] = useState([]);
  const [saving, setSaving] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState('');

  const folderList = useTxnList(folders, {
    searchKeys: ['name'],
    defaultSort: 'name_asc',
  });
  const docList = useTxnList(documents, {
    searchKeys: ['name'],
    defaultSort: 'name_asc',
  });

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const params = {};
      if (folderId) params.folder_id = folderId;
      const data = await browseMyDocuments(params);
      setFolders(data.folders || data.data?.folders || []);
      setDocuments(data.documents || data.data?.documents || data.data || []);
    } catch (e) {
      console.error(e);
      setFolders([]);
      setDocuments([]);
    } finally {
      setLoading(false);
    }
  }, [folderId]);

  useEffect(() => { load(); }, [load]);

  const mediaUrl = (path) => {
    if (!path) return '';
    if (/^https?:\/\//i.test(path)) return path;
    const base = getUploadsBaseUrl();
    return path.startsWith('/') ? `${base}${path}` : `${base}/${path}`;
  };

  return (
    <div className="service-reg-page">
      <div className="sr-page-header">
        <div className="title-area">
          <h1><FolderOpen size={22} style={{ marginRight: 8, verticalAlign: -4 }} />Documents</h1>
          <p>Family papers in folders — same as the app.</p>
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          <button type="button" className="sr-btn sr-btn-ghost" onClick={() => { setError(''); setFolderName(''); setFolderModal(true); }}>
            <Plus size={16} /> Folder
          </button>
          <button type="button" className="sr-btn sr-btn-primary" onClick={() => { setError(''); setDocName(''); setImages([]); setDocModal(true); }}>
            <Plus size={16} /> Document
          </button>
        </div>
      </div>

      {folderId && (
        <button type="button" className="sr-btn sr-btn-ghost" style={{ alignSelf: 'flex-start' }} onClick={() => setFolderId(null)}>
          ← All folders
        </button>
      )}

      {!folderId && (
        <TxnToolbar
          list={folderList}
          placeholder="Search folders…"
          sortOptions={[
            { id: 'name_asc', label: 'Name A–Z' },
            { id: 'name_desc', label: 'Name Z–A' },
          ]}
        />
      )}
      {(folderId || documents.length > 0) && (
        <TxnToolbar
          list={docList}
          placeholder="Search documents…"
          sortOptions={[
            { id: 'name_asc', label: 'Name A–Z' },
            { id: 'name_desc', label: 'Name Z–A' },
          ]}
        />
      )}

      <div className="sr-list-card">
        {loading ? (
          <div className="sr-empty"><Loader2 className="spin" size={22} /> Loading…</div>
        ) : (
          <>
            {!folderId && folderList.total > 0 && (
              <>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))', gap: 12, padding: 16 }}>
                  {folderList.paged.map((f) => (
                    <div key={f.id} style={{ border: '1px solid var(--border)', borderRadius: 8, padding: 12, display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8 }}>
                      <button type="button" style={{ background: 'none', border: 0, fontWeight: 700, cursor: 'pointer', color: 'var(--primary)', textAlign: 'left' }} onClick={() => setFolderId(f.id)}>
                        {f.name}
                      </button>
                      <button type="button" className="sr-btn sr-btn-ghost" onClick={async () => {
                        if (!window.confirm('Delete folder?')) return;
                        await deleteMyDocumentFolder(f.id);
                        load();
                      }}><Trash2 size={14} /></button>
                    </div>
                  ))}
                </div>
                <TxnPager list={folderList} />
              </>
            )}
            {docList.total === 0 && (folderId || folderList.total === 0) ? (
              <div className="sr-empty">No documents yet.</div>
            ) : docList.total > 0 && (
              <>
                <div className="sr-table-wrap">
                  <table className="sr-table">
                    <thead><tr><th>Name</th><th>Images</th><th /></tr></thead>
                    <tbody>
                      {docList.paged.map((d) => (
                        <tr key={d.id}>
                          <td>{d.name}</td>
                          <td>
                            {(d.images || []).slice(0, 3).map((img, i) => (
                              <a key={i} href={mediaUrl(img)} target="_blank" rel="noreferrer" style={{ marginRight: 6 }}>#{i + 1}</a>
                            ))}
                          </td>
                          <td>
                            <button type="button" className="sr-btn sr-btn-ghost" onClick={async () => {
                              if (!window.confirm('Delete?')) return;
                              await deleteMyDocument(d.id);
                              load();
                            }}><Trash2 size={14} /></button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
                <TxnPager list={docList} />
              </>
            )}
          </>
        )}
      </div>

      {folderModal && (
        <TxnModal title="New folder" onClose={() => setFolderModal(false)} wide={false} saving={saving}>
          <form onSubmit={async (e) => {
            e.preventDefault(); setSaving(true); setError('');
            try {
              await createMyDocumentFolder({ name: folderName.trim() });
              setFolderModal(false);
              await load();
            } catch (err) {
              setError(err.response?.data?.error || 'Failed');
            } finally {
              setSaving(false);
            }
          }}>
            {error && <div className="sr-error" style={{ marginBottom: 10 }}>{error}</div>}
            <div className="txn-form-grid-2">
              <label className="txn-span-2">Folder name (person)<input required value={folderName} onChange={(e) => setFolderName(e.target.value)} /></label>
            </div>
            <div className="txn-form-actions">
              <button type="submit" className="sr-btn sr-btn-primary" disabled={saving}>Save</button>
            </div>
          </form>
        </TxnModal>
      )}

      {docModal && (
        <TxnModal title="New document" onClose={() => setDocModal(false)} saving={saving}>
          <form onSubmit={async (e) => {
            e.preventDefault(); setSaving(true); setError('');
            try {
              await createMyDocument({
                name: docName.trim(),
                folder_id: folderId || undefined,
                images,
              });
              setDocModal(false);
              await load();
            } catch (err) {
              setError(err.response?.data?.error || 'Failed');
            } finally {
              setSaving(false);
            }
          }}>
            {error && <div className="sr-error" style={{ marginBottom: 10 }}>{error}</div>}
            <div className="txn-form-grid">
              <label className="txn-span-2">Document name<input required value={docName} onChange={(e) => setDocName(e.target.value)} /></label>
              <label>
                Photos
                <div style={{ marginTop: 4 }}>
                  <label className="sr-btn sr-btn-ghost" style={{ cursor: 'pointer' }}>
                    <Upload size={14} /> {uploading ? 'Uploading…' : 'Upload images'}
                    <input type="file" hidden multiple accept="image/*" onChange={async (e) => {
                      const files = e.target.files;
                      if (!files?.length) return;
                      setUploading(true);
                      try {
                        const res = await uploadMyDocumentImages([...files]);
                        const urls = res.urls || res.images || res.paths || [];
                        setImages((prev) => [...prev, ...urls]);
                      } catch (err) {
                        setError(err.response?.data?.error || 'Upload failed');
                      } finally {
                        setUploading(false);
                      }
                    }} />
                  </label>
                  <div style={{ fontSize: 13, color: 'var(--text-muted)', marginTop: 6 }}>{images.length} image(s)</div>
                </div>
              </label>
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

export default DocumentsEntry;
