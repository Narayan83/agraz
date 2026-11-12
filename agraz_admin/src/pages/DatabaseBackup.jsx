import { useState } from 'react';
import { Database, Download, Loader2 } from 'lucide-react';
import { downloadSqlBackup } from '../api/api';
import { isSuperAdminUser, readStoredUser } from '../lib/transactions';
import './ServiceRegistrations.css';

const DatabaseBackup = () => {
  const allowed = isSuperAdminUser(readStoredUser());
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [done, setDone] = useState('');

  const download = async () => {
    if (!window.confirm('Download a full SQL backup of the database? The file includes every account and record.')) {
      return;
    }
    setBusy(true);
    setError('');
    setDone('');
    try {
      const name = await downloadSqlBackup();
      setDone(`Downloaded ${name}`);
    } catch (err) {
      setError(err.message || 'Backup failed');
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="service-reg-page">
      <div className="sr-page-header">
        <div className="title-area">
          <h1><Database size={22} style={{ marginRight: 8, verticalAlign: -4 }} />SQL backup</h1>
          <p>Download a PostgreSQL .sql file of the whole database. Super Admin only.</p>
        </div>
      </div>

      <div className="sr-list-card" style={{ padding: '1.25rem 1.35rem' }}>
        {!allowed ? (
          <p>This download is available only to the Super Admin account.</p>
        ) : (
          <>
            <p style={{ margin: '0 0 1rem', color: 'var(--text-muted)', maxWidth: 640, lineHeight: 1.5 }}>
              The file is a full database backup. It includes users, passwords, and every transaction.
              Keep the download private. Restore it with psql into a database, for example
              {' '}<code>psql -d agraz -f agraz-backup.sql</code>.
            </p>
            {error ? <div className="sr-error" style={{ marginBottom: 12 }}>{error}</div> : null}
            {done ? <p style={{ margin: '0 0 12px', color: 'var(--primary)' }}>{done}</p> : null}
            <button type="button" className="sr-btn sr-btn-primary" onClick={download} disabled={busy}>
              {busy ? <Loader2 className="spin" size={16} /> : <Download size={16} />}
              {busy ? 'Preparing backup…' : 'Download .sql backup'}
            </button>
          </>
        )}
      </div>
    </div>
  );
};

export default DatabaseBackup;
