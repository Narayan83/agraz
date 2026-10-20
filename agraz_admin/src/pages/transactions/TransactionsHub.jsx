import React from 'react';
import { Link } from 'react-router-dom';
import { Wallet } from 'lucide-react';
import { TRANSACTION_LINKS } from '../../lib/transactions';
import '../ServiceRegistrations.css';
import './Transactions.css';

const TransactionsHub = () => (
  <div className="service-reg-page">
    <div className="sr-page-header">
      <div className="title-area">
        <h1><Wallet size={22} style={{ marginRight: 8, verticalAlign: -4 }} />Transactions</h1>
        <p>Enter your farm records here — same options as the AgRaz app.</p>
      </div>
    </div>
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(240px, 1fr))', gap: '1rem' }}>
      {TRANSACTION_LINKS.map((item) => (
        <Link
          key={item.to}
          to={item.to}
          style={{
            display: 'block',
            padding: '1.1rem 1.2rem',
            background: 'var(--surface)',
            border: '1px solid var(--border)',
            borderRadius: 'var(--radius-md)',
            textDecoration: 'none',
            color: 'inherit',
          }}
        >
          <div style={{ fontWeight: 700, color: 'var(--primary)', marginBottom: 4 }}>{item.label}</div>
          <div style={{ fontSize: '0.875rem', color: 'var(--text-muted)' }}>{item.desc}</div>
        </Link>
      ))}
    </div>
  </div>
);

export default TransactionsHub;
