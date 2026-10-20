export const CONTRACT_LINKS = [
  { to: '/contract-manage/projects', label: 'Projects', desc: 'Customer-mapped jobs with start/end/status + ledger' },
  { to: '/contract-manage/customers', label: 'Customers', desc: 'Site owners / clients' },
  { to: '/contract-manage/labour-suppliers', label: 'Labour Suppliers', desc: 'Labour leads' },
  { to: '/contract-manage/labours', label: 'Labours', desc: 'Workers under leads' },
  { to: '/contract-manage/labour-works', label: 'Labour Work', desc: 'Send gangs to site (men/women, rates, days)' },
  { to: '/contract-manage/dealers', label: 'Dealers', desc: 'Sand, cement suppliers' },
  { to: '/contract-manage/materials', label: 'Materials', desc: 'Stock master' },
  { to: '/contract-manage/purchases', label: 'Purchases / Stock', desc: 'Buy for project or own yard' },
  { to: '/contract-manage/stock-issues', label: 'Stock Issues', desc: 'Use / transfer stock on site' },
  { to: '/contract-manage/stock-report', label: 'Stock Report', desc: 'Own vs customer site' },
  { to: '/contract-manage/payments', label: 'Payments', desc: 'Advances, receipts, dealer & labour pays' },
  { to: '/contract-manage/customer-summary', label: 'Customer Summary', desc: 'Cross-project customer view' },
  { to: '/contract-manage/assets', label: 'Assets', desc: 'JCB and equipment' },
  { to: '/contract-manage/audit', label: 'Audit Log', desc: 'Create/update/delete history' },
];

export function todayIso() {
  return new Date().toISOString().slice(0, 10);
}
