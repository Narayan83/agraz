export const IE_CATEGORIES = {
  Income: {
    'Farming Income': [
      'Arecanut', 'Banana', 'Coconut', 'Cardamom', 'Pepper', 'Coffee', 'Cocoa',
      'Vanilla', 'Other Crop', 'By-products', 'Livestock & Dairy', 'Rental / Service',
    ],
    'Non-Farming Income': ['Government / Subsidy', 'Asset & Miscellaneous'],
  },
  Expense: {
    'Farming Expense': [
      'Labour', 'Manure', 'Chemicals', 'Machinery Rent', 'Vehicle Rent', 'Implements',
      'Irrigation', 'Machinery Purchase', 'Special Works', 'Cattle Feed', 'Fodder',
      'Vet Medicines and Care', 'Live Stock Purchase', 'Others',
    ],
    'Living Expense': [
      'Grocery', 'Fruits & Veg', 'Milk & Ghee', 'Medicine', 'Vehicle Maintenance',
      'Pooja', 'Donation', 'Gift', 'Mobile & Currency', 'Lifestyle', 'Misc',
      'Vehicle Rent', 'Refreshing', 'Gas', 'Education', 'Electricity', 'Repair',
      'Transportation Expense', 'Entertainment', 'Tour & Travel', 'Newspapers & Books',
      'Lifestyle Others',
    ],
  },
};

export const LABOR_CATEGORIES = [
  'Plucking', 'Cutting', 'Drying', 'Grading', 'Packing', 'Transport', 'Others', 'Opening Balance',
];

export const LABOR_SHIFTS = [
  { id: 'fullday', label: 'Full day' },
  { id: 'morning', label: 'Morning' },
  { id: 'evening', label: 'Evening' },
  { id: 'night', label: 'Night' },
];

export const TRANSACTION_LINKS = [
  { to: '/transactions/income-expense', label: 'Income & Expenses', desc: 'Farm and house money entries' },
  { to: '/transactions/organizations', label: 'Manage Organization', desc: 'Farm ledgers and transfers' },
  { to: '/transactions/labour', label: 'Labour Entry', desc: 'Wages, contract and payments' },
  { to: '/transactions/labour-work', label: 'Labour Work Entry', desc: 'Daily work for family confirm' },
  { to: '/transactions/dairy', label: 'Dairy', desc: 'Milk given, bought and payments' },
  { to: '/transactions/dairy-owner', label: 'Dairy Owner', desc: 'Collect / sell milk ledger' },
  { to: '/transactions/notes', label: 'Notes', desc: 'Notes and checklists' },
  { to: '/transactions/future-plans', label: 'Future Plans', desc: 'Planned work with estimates' },
  { to: '/transactions/rtc', label: 'RTC Entry', desc: 'Land RTC records' },
  { to: '/transactions/documents', label: 'Documents', desc: 'Family papers and photos' },
  { to: '/transactions/events', label: 'Event Manage', desc: 'Reminders and renewals' },
];

export function todayIso() {
  return new Date().toISOString().slice(0, 10);
}

export function money(v) {
  const n = Number(v) || 0;
  return `₹${n.toLocaleString('en-IN', { maximumFractionDigits: 2 })}`;
}

function roleNames(user) {
  const roles = user?.Roles || user?.roles || [];
  return roles.map((r) => (r?.RoleName || r?.role_name || r || '').toString());
}

export function isStaffUser(user) {
  if (!user) return false;
  return roleNames(user).some((n) => n === 'Super Admin' || n === 'Admin');
}

/** Super Admin role only. The Admin role does not qualify. */
export function isSuperAdminUser(user) {
  if (!user) return false;
  return roleNames(user).some((n) => n === 'Super Admin');
}

/** Walk paginated `{ data, total }` list endpoints until every row is loaded. */
export async function fetchAllPages(request, pageSize = 500) {
  const all = [];
  let page = 1;
  let total = Infinity;
  while (all.length < total && page <= 40) {
    const res = await request({ page, limit: pageSize });
    const batch = Array.isArray(res?.data) ? res.data : (Array.isArray(res) ? res : []);
    const reported = Number(res?.total);
    total = Number.isFinite(reported) ? reported : all.length + batch.length;
    all.push(...batch);
    if (!batch.length || batch.length < pageSize) break;
    page += 1;
  }
  return all;
}

export function readStoredUser() {
  try {
    const raw = localStorage.getItem('user');
    if (!raw || raw === 'undefined') return null;
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

export const fieldStyle = {
  display: 'block',
  width: '100%',
  marginTop: 6,
  padding: '0.6rem 0.75rem',
  borderRadius: 8,
  border: '1px solid var(--border)',
};
