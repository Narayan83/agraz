import { useMemo, useState, useEffect, useRef } from 'react';
import { Search, ChevronLeft, ChevronRight, X } from 'lucide-react';

/** Client-side search + sort + paginate for transaction lists. */
export function useTxnList(
  rows,
  {
    searchKeys = [],
    defaultSort = 'date_desc',
    pageSize: initialSize = 20,
    /** When set, enables exact name select (typeahead) filtering on this field. */
    nameKey = null,
  } = {}
) {
  const [q, setQ] = useState('');
  const [selectedName, setSelectedName] = useState('');
  const [sort, setSort] = useState(defaultSort);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(initialSize);
  const [filterType, setFilterType] = useState('');

  useEffect(() => {
    setPage(1);
  }, [q, selectedName, sort, pageSize, filterType, rows]);

  const nameSuggestions = useMemo(() => {
    if (!nameKey) return [];
    const needle = q.trim().toLowerCase();
    if (!needle || selectedName) return [];
    const seen = new Map();
    for (const row of rows || []) {
      const name = String(pick(row, nameKey) ?? '').trim();
      if (!name) continue;
      const key = name.toLowerCase();
      if (!key.includes(needle)) continue;
      if (!seen.has(key)) seen.set(key, name);
    }
    return [...seen.values()].sort((a, b) => a.localeCompare(b)).slice(0, 12);
  }, [rows, q, selectedName, nameKey]);

  const filtered = useMemo(() => {
    let list = Array.isArray(rows) ? [...rows] : [];
    const needle = q.trim().toLowerCase();
    if (filterType) {
      list = list.filter((r) => {
        const t = String(
          r.type || r.entry_kind || r.kind || r.owner_kind || r.recurrence || r.status || ''
        ).toLowerCase();
        return t === filterType.toLowerCase();
      });
    }
    if (nameKey && selectedName) {
      // Exact person filter after picking a name from suggestions.
      const want = selectedName.trim().toLowerCase();
      list = list.filter((r) => String(pick(r, nameKey) ?? '').trim().toLowerCase() === want);
    } else if (!nameKey && needle && searchKeys.length) {
      // Free-text search for pages without name select.
      list = list.filter((r) =>
        searchKeys.some((k) => String(pick(r, k) ?? '').toLowerCase().includes(needle))
      );
    }
    list.sort((a, b) => compareRows(a, b, sort));
    return list;
  }, [rows, q, selectedName, sort, filterType, searchKeys, nameKey]);

  const total = filtered.length;
  const totalPages = Math.max(1, Math.ceil(total / pageSize) || 1);
  const safePage = Math.min(page, totalPages);
  const paged = filtered.slice((safePage - 1) * pageSize, safePage * pageSize);

  const selectName = (name) => {
    const next = String(name || '').trim();
    setSelectedName(next);
    setQ(next);
  };

  const clearName = () => {
    setSelectedName('');
    setQ('');
  };

  return {
    q,
    setQ,
    selectedName,
    setSelectedName,
    selectName,
    clearName,
    nameKey,
    nameSuggestions,
    sort,
    setSort,
    page: safePage,
    setPage,
    pageSize,
    setPageSize,
    filterType,
    setFilterType,
    filtered,
    paged,
    total,
    totalPages,
  };
}

function pick(row, key) {
  if (!key.includes('.')) return row?.[key];
  return key.split('.').reduce((o, k) => o?.[k], row);
}

function rowDate(r) {
  return String(r.date || r.event_date || r.entry_date || r.created_at || r.updated_at || '');
}

function compareRows(a, b, sort) {
  switch (sort) {
    case 'date_asc':
      return rowDate(a).localeCompare(rowDate(b)) || (a.id || 0) - (b.id || 0);
    case 'date_desc':
      return rowDate(b).localeCompare(rowDate(a)) || (b.id || 0) - (a.id || 0);
    case 'amount_asc':
      return (Number(a.amount ?? a.wage ?? a.estimate_cost) || 0) - (Number(b.amount ?? b.wage ?? b.estimate_cost) || 0);
    case 'amount_desc':
      return (Number(b.amount ?? b.wage ?? b.estimate_cost) || 0) - (Number(a.amount ?? a.wage ?? a.estimate_cost) || 0);
    case 'name_asc':
      return String(a.name || a.party_name || a.title || a.plan_name || a.survey_number || '').localeCompare(
        String(b.name || b.party_name || b.title || b.plan_name || b.survey_number || '')
      );
    case 'name_desc':
      return String(b.name || b.party_name || b.title || b.plan_name || b.survey_number || '').localeCompare(
        String(a.name || a.party_name || a.title || a.plan_name || a.survey_number || '')
      );
    default:
      return (b.id || 0) - (a.id || 0);
  }
}

export function TxnToolbar({
  list,
  placeholder = 'Search…',
  sortOptions = [
    { id: 'date_desc', label: 'Date ↓' },
    { id: 'date_asc', label: 'Date ↑' },
    { id: 'amount_desc', label: 'Amount ↓' },
    { id: 'amount_asc', label: 'Amount ↑' },
    { id: 'name_asc', label: 'Name A–Z' },
    { id: 'name_desc', label: 'Name Z–A' },
  ],
  filterOptions = null,
  filterLabel = 'Type',
  /** Show typeahead so user can pick an exact name, then filter the grid. */
  nameSelect = false,
}) {
  const [open, setOpen] = useState(false);
  const wrapRef = useRef(null);
  const suggestions = nameSelect ? (list.nameSuggestions || []) : [];
  const showSuggest = nameSelect && open && !list.selectedName && suggestions.length > 0;

  useEffect(() => {
    if (!nameSelect || !open) return undefined;
    const close = (event) => {
      if (wrapRef.current && !wrapRef.current.contains(event.target)) setOpen(false);
    };
    document.addEventListener('mousedown', close);
    return () => document.removeEventListener('mousedown', close);
  }, [nameSelect, open]);

  return (
    <div className="txn-toolbar">
      <div className={`sr-search txn-name-search${nameSelect ? ' is-suggest' : ''}`} ref={wrapRef}>
        <Search size={16} />
        <input
          value={list.q}
          onChange={(e) => {
            const next = e.target.value;
            list.setQ(next);
            if (list.selectedName && next.trim().toLowerCase() !== list.selectedName.trim().toLowerCase()) {
              list.setSelectedName('');
            }
            setOpen(true);
          }}
          onFocus={() => setOpen(true)}
          onKeyDown={(e) => {
            if (e.key === 'Escape') setOpen(false);
            if (e.key === 'Enter' && suggestions.length === 1) {
              e.preventDefault();
              list.selectName(suggestions[0]);
              setOpen(false);
            }
          }}
          placeholder={nameSelect ? 'Type a name, then select…' : placeholder}
          aria-autocomplete={nameSelect ? 'list' : undefined}
          aria-expanded={nameSelect ? showSuggest : undefined}
        />
        {(list.q || list.selectedName) && (
          <button
            type="button"
            className="txn-name-clear"
            title="Clear"
            aria-label="Clear search"
            onClick={() => {
              if (typeof list.clearName === 'function') list.clearName();
              else list.setQ('');
              setOpen(false);
            }}
          >
            <X size={14} />
          </button>
        )}
        {list.selectedName && (
          <span className="txn-name-chip" title="Filtering by selected name">
            Selected
          </span>
        )}
        {showSuggest && (
          <ul className="txn-name-suggest" role="listbox">
            {suggestions.map((name) => (
              <li key={name}>
                <button
                  type="button"
                  role="option"
                  onMouseDown={(e) => e.preventDefault()}
                  onClick={() => {
                    list.selectName(name);
                    setOpen(false);
                  }}
                >
                  {name}
                </button>
              </li>
            ))}
          </ul>
        )}
      </div>
      {filterOptions && (
        <select value={list.filterType} onChange={(e) => list.setFilterType(e.target.value)} aria-label={filterLabel}>
          <option value="">All {filterLabel.toLowerCase()}s</option>
          {filterOptions.map((o) => (
            <option key={o.id} value={o.id}>{o.label}</option>
          ))}
        </select>
      )}
      <select value={list.sort} onChange={(e) => list.setSort(e.target.value)} aria-label="Sort">
        {sortOptions.map((o) => (
          <option key={o.id} value={o.id}>{o.label}</option>
        ))}
      </select>
      <select value={list.pageSize} onChange={(e) => list.setPageSize(Number(e.target.value))} aria-label="Page size">
        {[10, 20, 50, 100].map((n) => (
          <option key={n} value={n}>{n} / page</option>
        ))}
      </select>
    </div>
  );
}

export function TxnPager({ list }) {
  const from = list.total === 0 ? 0 : (list.page - 1) * list.pageSize + 1;
  const to = Math.min(list.page * list.pageSize, list.total);
  return (
    <div className="txn-pager">
      <span>
        Showing {from}–{to} of {list.total}
      </span>
      <div className="txn-pager-btns">
        <button
          type="button"
          className="sr-btn sr-btn-ghost"
          disabled={list.page <= 1}
          onClick={() => list.setPage((p) => Math.max(1, p - 1))}
        >
          <ChevronLeft size={16} /> Prev
        </button>
        <span>
          Page {list.page} / {list.totalPages}
        </span>
        <button
          type="button"
          className="sr-btn sr-btn-ghost"
          disabled={list.page >= list.totalPages}
          onClick={() => list.setPage((p) => Math.min(list.totalPages, p + 1))}
        >
          Next <ChevronRight size={16} />
        </button>
      </div>
    </div>
  );
}

export function TxnModal({ title, onClose, children, wide = true, saving = false }) {
  return (
    <div className="txn-modal-overlay" onClick={() => !saving && onClose()}>
      <div
        className={`txn-modal${wide ? '' : ' txn-modal-sm'}`}
        onClick={(e) => e.stopPropagation()}
        role="dialog"
        aria-modal="true"
      >
        <div className="txn-modal-header">
          <h2>{title}</h2>
          <button type="button" className="sr-btn sr-btn-ghost" onClick={onClose} aria-label="Close">
            ✕
          </button>
        </div>
        <div className="txn-modal-body">{children}</div>
      </div>
    </div>
  );
}
