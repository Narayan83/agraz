import React from 'react';
import { Link } from 'react-router-dom';
import { Wrench } from 'lucide-react';
import { CONTRACT_LINKS } from '../../lib/contractManage';
import '../ServiceRegistrations.css';

const ContractManageHub = () => (
  <div className="service-reg-page">
    <div className="sr-page-header">
      <div className="title-area">
        <h1>
          <Wrench size={22} style={{ marginRight: 8, verticalAlign: -4 }} />
          Contract Manage
        </h1>
        <p>Civil contractor workspace — same options as the AgRaz app.</p>
      </div>
    </div>
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(240px, 1fr))', gap: '1rem' }}>
      {CONTRACT_LINKS.map((item) => (
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

export default ContractManageHub;
