import React, { useCallback, useEffect, useMemo, useState } from "react";
import {
  BarChart3,
  Plus,
  Edit,
  Trash2,
  X,
  Loader2,
  ChevronLeft,
  ChevronRight,
} from "lucide-react";
import {
  getAdminMarketAgents,
  createAdminMarketAgent,
  updateAdminMarketAgent,
  deleteAdminMarketAgent,
  getAdminMarketAPMCs,
  createAdminMarketAPMC,
  updateAdminMarketAPMC,
  deleteAdminMarketAPMC,
  getAdminMarketVarieties,
  createAdminMarketVariety,
  updateAdminMarketVariety,
  deleteAdminMarketVariety,
  getAdminMarketDailyPrices,
  createAdminMarketDailyPrice,
  updateAdminMarketDailyPrice,
  deleteAdminMarketDailyPrice,
  getAdminMarketLots,
  createAdminMarketLot,
  updateAdminMarketLot,
  deleteAdminMarketLot,
  getAdminMarketQuantities,
  createAdminMarketQuantity,
  updateAdminMarketQuantity,
  deleteAdminMarketQuantity,
  getAdminMarketAnalytics,
} from "../api/api";
import "./ServiceRegistrations.css";
import "./MarketReports.css";

const TABS = [
  { id: "overview", label: "Overview" },
  { id: "prices", label: "Enter Rates" },
  { id: "history", label: "Rate History" },
  { id: "qty", label: "Arrival / Trade / Stock" },
  { id: "lots", label: "Lot Details" },
  { id: "masters", label: "Agent / APMC / Variety" },
];

const limit = 15;

function isoDate(d = new Date()) {
  return d.toISOString().slice(0, 10);
}

function daysAgo(n) {
  const d = new Date();
  d.setDate(d.getDate() - n);
  return isoDate(d);
}

function dateInputValue(v) {
  if (!v) return "";
  const s = String(v);
  return s.length >= 10 ? s.slice(0, 10) : "";
}

function fmtNum(v) {
  if (v == null || v === "") return "—";
  const n = Number(v);
  return Number.isFinite(n) ? n.toLocaleString("en-IN") : String(v);
}

function emptyPrice() {
  return {
    date: new Date().toISOString().slice(0, 10),
    variety_id: "",
    agent_id: "",
    apmc_id: "",
    taluk: "",
    min_price: "",
    max_price: "",
    avg_price: "",
    notes: "",
  };
}

function emptyLot() {
  return {
    date: new Date().toISOString().slice(0, 10),
    lot_no: "",
    price: "",
    quantity: "",
    purchaser: "",
    variety_id: "",
    agent_id: "",
    apmc_id: "",
    taluk: "",
    notes: "",
  };
}

function emptyQty() {
  return {
    date: new Date().toISOString().slice(0, 10),
    variety_id: "",
    agent_id: "",
    apmc_id: "",
    taluk: "",
    arrival_qty: "",
    trade_qty: "",
    stock_qty: "",
    notes: "",
  };
}

function SimpleLineChart({ series, height = 260 }) {
  const points = series || [];
  if (!points.length) {
    return <p className="sr-empty">No chart data for current filters.</p>;
  }
  const width = 640;
  const pad = 36;
  const values = points.map((p) => p.avg);
  const minY = Math.min(...values) * 0.98;
  const maxY = Math.max(...values) * 1.02;
  const span = Math.max(maxY - minY, 1);
  const coords = points.map((p, i) => {
    const x = pad + (i * (width - pad * 2)) / Math.max(points.length - 1, 1);
    const y = height - pad - ((p.avg - minY) / span) * (height - pad * 2);
    return { x, y, ...p };
  });
  const path = coords.map((c, i) => `${i === 0 ? "M" : "L"} ${c.x} ${c.y}`).join(" ");
  const colors = { Rashi: "#2563eb", Chali: "#dc2626", Pepper: "#059669" };
  const byVariety = {};
  points.forEach((p, i) => {
    const key = p.variety || "Item";
    if (!byVariety[key]) byVariety[key] = [];
    byVariety[key].push(coords[i]);
  });

  return (
    <svg viewBox={`0 0 ${width} ${height}`} width="100%" height={height} role="img">
      {[0, 0.25, 0.5, 0.75, 1].map((t) => {
        const y = pad + t * (height - pad * 2);
        const val = maxY - t * span;
        return (
          <g key={t}>
            <line x1={pad} y1={y} x2={width - pad} y2={y} stroke="#e5e7eb" />
            <text x={4} y={y + 4} fontSize="10" fill="#6b7280">
              {Math.round(val).toLocaleString("en-IN")}
            </text>
          </g>
        );
      })}
      {Object.keys(byVariety).length <= 1 ? (
        <path d={path} fill="none" stroke="#2563eb" strokeWidth="2.5" />
      ) : (
        Object.entries(byVariety).map(([name, pts]) => {
          const d = pts.map((c, i) => `${i === 0 ? "M" : "L"} ${c.x} ${c.y}`).join(" ");
          return <path key={name} d={d} fill="none" stroke={colors[name] || "#7c3aed"} strokeWidth="2.5" />;
        })
      )}
      {coords.map((c, i) => (
        <circle key={i} cx={c.x} cy={c.y} r="3.5" fill="#111827" />
      ))}
    </svg>
  );
}

function SimpleBarChart({ items, height = 220 }) {
  const rows = items || [];
  if (!rows.length) return <p className="sr-empty">No comparison data.</p>;
  const max = Math.max(...rows.map((r) => r.value), 1);
  return (
    <div style={{ display: "grid", gap: "0.65rem" }}>
      {rows.map((r) => (
        <div key={r.label} style={{ display: "grid", gridTemplateColumns: "110px 1fr 70px", gap: "0.5rem", alignItems: "center" }}>
          <span style={{ fontSize: "0.8rem", color: "var(--text-muted)" }}>{r.label}</span>
          <div style={{ background: "var(--bg-main)", borderRadius: 6, height: 14, overflow: "hidden" }}>
            <div style={{ width: `${(r.value / max) * 100}%`, height: "100%", background: r.color || "var(--primary)" }} />
          </div>
          <span style={{ fontSize: "0.8rem", textAlign: "right" }}>{fmtNum(r.value)}</span>
        </div>
      ))}
    </div>
  );
}

const MarketReports = () => {
  const [tab, setTab] = useState("prices");
  const [agents, setAgents] = useState([]);
  const [apmcs, setApmcs] = useState([]);
  const [varieties, setVarieties] = useState([]);
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [filterDate, setFilterDate] = useState(isoDate());
  const [filterFrom, setFilterFrom] = useState(daysAgo(7));
  const [filterTo, setFilterTo] = useState(isoDate());
  const [rangeDays, setRangeDays] = useState(7);
  const [filterAgent, setFilterAgent] = useState("");
  const [filterApmc, setFilterApmc] = useState("");
  const [filterTaluk, setFilterTaluk] = useState("");
  const [filterVariety, setFilterVariety] = useState("");

  const [modalOpen, setModalOpen] = useState(false);
  const [selected, setSelected] = useState(null);
  const [form, setForm] = useState(emptyPrice);
  const [saving, setSaving] = useState(false);

  const [metaType, setMetaType] = useState("agent");
  const [metaModal, setMetaModal] = useState(false);
  const [metaForm, setMetaForm] = useState({ name: "", code: "", taluk: "", district: "", status: "active", sort_order: 0 });
  const [metaSelected, setMetaSelected] = useState(null);
  const [metaSaving, setMetaSaving] = useState(false);

  const [analytics, setAnalytics] = useState({ price_series: [], qty_series: [] });
  const [dayPrices, setDayPrices] = useState([]);

  const loadLookups = useCallback(async () => {
    try {
      const [a, p, v] = await Promise.all([
        getAdminMarketAgents(),
        getAdminMarketAPMCs(),
        getAdminMarketVarieties(),
      ]);
      setAgents(a.data || []);
      setApmcs(p.data || []);
      setVarieties(v.data || []);
    } catch (e) {
      console.error(e);
    }
  }, []);

  const sharedFilters = useMemo(() => {
    const params = {};
    if (filterAgent) params.agent_id = filterAgent;
    if (filterApmc) params.apmc_id = filterApmc;
    if (filterTaluk) params.taluk = filterTaluk;
    if (filterVariety) params.variety_id = filterVariety;
    return params;
  }, [filterAgent, filterApmc, filterTaluk, filterVariety]);

  const filterParams = useMemo(() => {
    const params = { page, limit, ...sharedFilters };
    if (tab === "history") {
      if (filterFrom) params.from = filterFrom;
      if (filterTo) params.to = filterTo;
    } else if (filterDate) {
      params.date = filterDate;
    }
    return params;
  }, [page, tab, filterDate, filterFrom, filterTo, sharedFilters]);

  const fetchRows = useCallback(async () => {
    if (tab === "masters" || tab === "overview") return;
    setLoading(true);
    try {
      let data;
      if (tab === "prices" || tab === "history") {
        data = await getAdminMarketDailyPrices(filterParams);
      } else if (tab === "lots") {
        data = await getAdminMarketLots(filterParams);
      } else {
        data = await getAdminMarketQuantities(filterParams);
      }
      setRows(data.data || []);
      setTotal(data.total ?? 0);
    } catch (e) {
      console.error(e);
      setRows([]);
      setTotal(0);
    } finally {
      setLoading(false);
    }
  }, [tab, filterParams]);

  const fetchOverview = useCallback(async () => {
    setLoading(true);
    try {
      const dayParams = { ...sharedFilters, date: filterDate || isoDate(), limit: 100 };
      const histParams = {
        ...sharedFilters,
        from: filterFrom || daysAgo(rangeDays),
        to: filterTo || isoDate(),
        limit: 500,
      };
      const [day, hist, analyticsData] = await Promise.all([
        getAdminMarketDailyPrices(dayParams),
        getAdminMarketDailyPrices(histParams),
        getAdminMarketAnalytics({
          ...sharedFilters,
          from: filterFrom || daysAgo(rangeDays),
          to: filterTo || isoDate(),
        }),
      ]);
      setDayPrices(day.data || []);
      setRows(hist.data || []);
      setTotal(hist.total ?? 0);
      setAnalytics(analyticsData || { price_series: [], qty_series: [] });
    } catch (e) {
      console.error(e);
      setDayPrices([]);
      setRows([]);
      setAnalytics({ price_series: [], qty_series: [] });
    } finally {
      setLoading(false);
    }
  }, [sharedFilters, filterDate, filterFrom, filterTo, rangeDays]);

  const fetchAnalytics = useCallback(async () => {
    setLoading(true);
    try {
      const params = { ...sharedFilters };
      params.from = filterFrom || daysAgo(rangeDays);
      params.to = filterTo || isoDate();
      const data = await getAdminMarketAnalytics(params);
      setAnalytics(data || { price_series: [], qty_series: [] });
    } catch (e) {
      console.error(e);
      setAnalytics({ price_series: [], qty_series: [] });
    } finally {
      setLoading(false);
    }
  }, [sharedFilters, filterFrom, filterTo, rangeDays]);

  useEffect(() => {
    loadLookups();
  }, [loadLookups]);

  useEffect(() => {
    setPage(1);
  }, [tab, filterDate, filterFrom, filterTo, filterAgent, filterApmc, filterTaluk, filterVariety]);

  useEffect(() => {
    if (tab === "overview") fetchOverview();
    else if (tab === "masters") setLoading(false);
    else fetchRows();
  }, [tab, fetchRows, fetchOverview]);

  const applyRange = (days) => {
    setRangeDays(days);
    setFilterFrom(daysAgo(days));
    setFilterTo(isoDate());
  };

  const totalPages = Math.max(1, Math.ceil(total / limit) || 1);
  const talukOptions = useMemo(() => {
    const set = new Set(apmcs.map((a) => a.taluk).filter(Boolean));
    return Array.from(set);
  }, [apmcs]);

  const openCreate = () => {
    setSelected(null);
    if (tab === "prices" || tab === "history") setForm(emptyPrice());
    else if (tab === "lots") setForm(emptyLot());
    else setForm(emptyQty());
    setModalOpen(true);
  };

  const openEdit = (row) => {
    setSelected(row);
    if (tab === "prices" || tab === "history" || tab === "overview") {
      setForm({
        date: dateInputValue(row.date),
        variety_id: String(row.variety_id || ""),
        agent_id: String(row.agent_id || ""),
        apmc_id: String(row.apmc_id || ""),
        taluk: row.taluk || "",
        min_price: String(row.min_price ?? ""),
        max_price: String(row.max_price ?? ""),
        avg_price: String(row.avg_price ?? ""),
        notes: row.notes || "",
      });
    } else if (tab === "lots") {
      setForm({
        date: dateInputValue(row.date),
        lot_no: row.lot_no || "",
        price: String(row.price ?? ""),
        quantity: String(row.quantity ?? ""),
        purchaser: row.purchaser || "",
        variety_id: String(row.variety_id || ""),
        agent_id: String(row.agent_id || ""),
        apmc_id: String(row.apmc_id || ""),
        taluk: row.taluk || "",
        notes: row.notes || "",
      });
    } else {
      setForm({
        date: dateInputValue(row.date),
        variety_id: String(row.variety_id || ""),
        agent_id: String(row.agent_id || ""),
        apmc_id: String(row.apmc_id || ""),
        taluk: row.taluk || "",
        arrival_qty: String(row.arrival_qty ?? ""),
        trade_qty: String(row.trade_qty ?? ""),
        stock_qty: String(row.stock_qty ?? ""),
        notes: row.notes || "",
      });
    }
    setModalOpen(true);
  };

  const handleFormChange = (e) => {
    const { name, value } = e.target;
    setForm((prev) => {
      const next = { ...prev, [name]: value };
      if (name === "apmc_id") {
        const ap = apmcs.find((x) => String(x.id) === value);
        if (ap) next.taluk = ap.taluk || "";
      }
      if ((tab === "prices" || tab === "history" || tab === "overview") && (name === "min_price" || name === "max_price")) {
        const min = Number(name === "min_price" ? value : next.min_price);
        const max = Number(name === "max_price" ? value : next.max_price);
        if (Number.isFinite(min) && Number.isFinite(max) && min > 0 && max > 0) {
          next.avg_price = String(Math.round((min + max) / 2));
        }
      }
      return next;
    });
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSaving(true);
    try {
      const payload = {
        ...form,
        variety_id: Number(form.variety_id),
        agent_id: Number(form.agent_id),
        apmc_id: Number(form.apmc_id),
      };
      if (tab === "lots") {
        if (selected) await updateAdminMarketLot(selected.id, payload);
        else await createAdminMarketLot(payload);
      } else if (tab === "qty") {
        if (selected) await updateAdminMarketQuantity(selected.id, payload);
        else await createAdminMarketQuantity(payload);
      } else {
        if (selected) await updateAdminMarketDailyPrice(selected.id, payload);
        else await createAdminMarketDailyPrice(payload);
      }
      setModalOpen(false);
      if (tab === "overview") await fetchOverview();
      else await fetchRows();
    } catch (err) {
      alert(err?.response?.data?.error || "Save failed");
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async (row) => {
    if (!window.confirm("Delete this record?")) return;
    try {
      if (tab === "lots") await deleteAdminMarketLot(row.id);
      else if (tab === "qty") await deleteAdminMarketQuantity(row.id);
      else await deleteAdminMarketDailyPrice(row.id);
      if (tab === "overview") await fetchOverview();
      else await fetchRows();
    } catch (err) {
      alert(err?.response?.data?.error || "Delete failed");
    }
  };

  const openMetaCreate = (type) => {
    setMetaType(type);
    setMetaSelected(null);
    setMetaForm({ name: "", code: "", taluk: "", district: "", status: "active", sort_order: 0 });
    setMetaModal(true);
  };

  const openMetaEdit = (type, row) => {
    setMetaType(type);
    setMetaSelected(row);
    setMetaForm({
      name: row.name || "",
      code: row.code || "",
      taluk: row.taluk || "",
      district: row.district || "",
      status: row.status || "active",
      sort_order: row.sort_order ?? 0,
    });
    setMetaModal(true);
  };

  const saveMeta = async (e) => {
    e.preventDefault();
    setMetaSaving(true);
    try {
      const payload = { ...metaForm, sort_order: Number(metaForm.sort_order) || 0 };
      if (metaType === "agent") {
        if (metaSelected) await updateAdminMarketAgent(metaSelected.id, payload);
        else await createAdminMarketAgent(payload);
      } else if (metaType === "apmc") {
        if (metaSelected) await updateAdminMarketAPMC(metaSelected.id, payload);
        else await createAdminMarketAPMC(payload);
      } else {
        if (metaSelected) await updateAdminMarketVariety(metaSelected.id, payload);
        else await createAdminMarketVariety(payload);
      }
      setMetaModal(false);
      await loadLookups();
    } catch (err) {
      alert(err?.response?.data?.error || "Save failed");
    } finally {
      setMetaSaving(false);
    }
  };

  const deleteMeta = async (type, row) => {
    if (!window.confirm(`Delete ${row.name}?`)) return;
    try {
      if (type === "agent") await deleteAdminMarketAgent(row.id);
      else if (type === "apmc") await deleteAdminMarketAPMC(row.id);
      else await deleteAdminMarketVariety(row.id);
      await loadLookups();
    } catch (err) {
      alert(err?.response?.data?.error || "Delete failed");
    }
  };

  const overviewStats = useMemo(() => {
    const prices = dayPrices || [];
    const varietiesCount = new Set(prices.map((p) => p.variety_id)).size;
    const avgs = prices.map((p) => Number(p.avg_price)).filter((n) => Number.isFinite(n));
    const overallAvg = avgs.length ? avgs.reduce((a, b) => a + b, 0) / avgs.length : 0;
    const qty = analytics.qty_series || [];
    const lastQty = qty.length ? qty[qty.length - 1] : null;
    return {
      varietiesCount,
      overallAvg,
      arrival: lastQty?.arrival ?? 0,
      traded: lastQty?.trade ?? 0,
    };
  }, [dayPrices, analytics]);

  const latestComparison = useMemo(() => {
    const prices = dayPrices.length ? dayPrices : [];
    if (prices.length) {
      return prices.map((p) => ({
        label: `${p.variety?.name || "Item"}`,
        value: Number(p.avg_price) || 0,
        color: p.variety?.name === "Chali" ? "#dc2626" : p.variety?.name === "Pepper" ? "#059669" : "#2563eb",
      }));
    }
    const series = analytics.price_series || [];
    if (!series.length) return [];
    const lastDate = series[series.length - 1].date;
    return series
      .filter((p) => p.date === lastDate)
      .map((p) => ({ label: `${p.variety} avg`, value: p.avg, color: p.variety === "Chali" ? "#dc2626" : p.variety === "Pepper" ? "#059669" : "#2563eb" }));
  }, [dayPrices, analytics]);

  const qtyBars = useMemo(() => {
    const series = analytics.qty_series || [];
    if (!series.length) return [];
    const last = series[series.length - 1];
    return [
      { label: "Arrival", value: last.arrival, color: "#0ea5e9" },
      { label: "Trade", value: last.trade, color: "#f59e0b" },
      { label: "Stock", value: last.stock, color: "#10b981" },
    ];
  }, [analytics]);

  const showEntryButton = tab === "prices" || tab === "lots" || tab === "qty" || tab === "history";
  const showPriceTable = tab === "prices" || tab === "history";
  const showDataTable = showPriceTable || tab === "lots" || tab === "qty";

  return (
    <div className="service-reg-page">
      <div className="sr-toolbar">
        <div>
          <h1 style={{ display: "flex", alignItems: "center", gap: "0.5rem", margin: 0 }}>
            <BarChart3 size={22} /> Market Reports
          </h1>
          <p style={{ margin: "0.35rem 0 0", color: "var(--text-muted)", fontSize: "0.9rem" }}>
            Enter daily rates, review history, and manage agents / APMCs / varieties (matches mobile Market Reports)
          </p>
        </div>
        {showEntryButton && (
          <button type="button" className="sr-btn sr-btn-primary" onClick={openCreate}>
            <Plus size={16} /> {tab === "prices" ? "Enter rate" : "Add entry"}
          </button>
        )}
      </div>

      <div className="sr-filter-tabs">
        {TABS.map((t) => (
          <button
            key={t.id}
            type="button"
            className={`sr-filter-tab ${tab === t.id ? "active" : ""}`}
            onClick={() => setTab(t.id)}
          >
            {t.label}
          </button>
        ))}
      </div>

      {tab !== "masters" && (
        <div className="sr-list-card" style={{ padding: "1rem 1.25rem" }}>
          <div className="mr-filters">
            {(tab === "overview" || tab === "prices" || tab === "lots" || tab === "qty") && (
              <label className="mr-filter-label">
                Report date
                <input type="date" value={filterDate} onChange={(e) => setFilterDate(e.target.value)} className="sr-input" />
              </label>
            )}
            {(tab === "overview" || tab === "history") && (
              <>
                <label className="mr-filter-label">
                  From
                  <input type="date" value={filterFrom} onChange={(e) => setFilterFrom(e.target.value)} className="sr-input" />
                </label>
                <label className="mr-filter-label">
                  To
                  <input type="date" value={filterTo} onChange={(e) => setFilterTo(e.target.value)} className="sr-input" />
                </label>
                <div className="mr-range-btns">
                  {[7, 14, 30].map((d) => (
                    <button
                      key={d}
                      type="button"
                      className={`sr-btn ${rangeDays === d ? "sr-btn-primary" : "sr-btn-ghost"}`}
                      onClick={() => applyRange(d)}
                    >
                      {d}D
                    </button>
                  ))}
                </div>
              </>
            )}
            <select value={filterAgent} onChange={(e) => setFilterAgent(e.target.value)} className="sr-input">
              <option value="">All agents</option>
              {agents.map((a) => (
                <option key={a.id} value={a.id}>{a.name}</option>
              ))}
            </select>
            <select value={filterApmc} onChange={(e) => setFilterApmc(e.target.value)} className="sr-input">
              <option value="">All APMCs</option>
              {apmcs.map((a) => (
                <option key={a.id} value={a.id}>{a.name}</option>
              ))}
            </select>
            <select value={filterTaluk} onChange={(e) => setFilterTaluk(e.target.value)} className="sr-input">
              <option value="">All taluks</option>
              {talukOptions.map((t) => (
                <option key={t} value={t}>{t}</option>
              ))}
            </select>
            <select value={filterVariety} onChange={(e) => setFilterVariety(e.target.value)} className="sr-input">
              <option value="">All varieties</option>
              {varieties.map((v) => (
                <option key={v.id} value={v.id}>{v.name}</option>
              ))}
            </select>
          </div>
        </div>
      )}

      {tab === "overview" && (
        <div style={{ display: "grid", gap: "1.25rem" }}>
          <div className="mr-stats">
            <div className="mr-stat-card"><span>Varieties</span><strong>{overviewStats.varietiesCount}</strong></div>
            <div className="mr-stat-card"><span>Overall avg</span><strong>₹{fmtNum(Math.round(overviewStats.overallAvg))}</strong></div>
            <div className="mr-stat-card"><span>Arrival</span><strong>{fmtNum(overviewStats.arrival)}</strong></div>
            <div className="mr-stat-card"><span>Traded</span><strong>{fmtNum(overviewStats.traded)}</strong></div>
          </div>
          <div className="sr-list-card">
            <div className="sr-list-header">
              <h3 style={{ margin: 0 }}>Today&apos;s market rates ({filterDate})</h3>
              <button
                type="button"
                className="sr-btn sr-btn-primary"
                onClick={() => {
                  setTab("prices");
                  setSelected(null);
                  setForm(emptyPrice());
                  setModalOpen(true);
                }}
              >
                <Plus size={14} /> Enter rate
              </button>
            </div>
            {loading ? (
              <div className="sr-loader"><Loader2 className="spinner" size={36} /><p>Loading…</p></div>
            ) : (
              <div className="mr-table-wrap">
                <table className="mr-table">
                  <thead>
                    <tr>
                      <th>Variety</th><th>Agent</th><th>APMC</th><th>Min</th><th>Max</th><th>Avg</th><th>Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {dayPrices.length === 0 ? (
                      <tr><td colSpan={7}><div className="sr-empty">No rates for this date — use Enter Rates</div></td></tr>
                    ) : dayPrices.map((row) => (
                      <tr key={row.id}>
                        <td>{row.variety?.name || "—"}</td>
                        <td>{row.agent?.name || "—"}</td>
                        <td>{row.apmc?.name || "—"}</td>
                        <td>{fmtNum(row.min_price)}</td>
                        <td>{fmtNum(row.max_price)}</td>
                        <td>{fmtNum(row.avg_price)}</td>
                        <td>
                          <button type="button" className="mr-icon-btn" onClick={() => openEdit(row)}><Edit size={16} /></button>
                          <button type="button" className="mr-icon-btn danger" onClick={() => handleDelete(row)}><Trash2 size={16} /></button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
          <div className="mr-analytics">
            <div className="sr-list-card" style={{ padding: "1.25rem" }}>
              <h3 style={{ marginTop: 0 }}>Variety comparison (avg)</h3>
              {loading ? <Loader2 className="spinner" /> : <SimpleBarChart items={latestComparison} />}
            </div>
            <div className="sr-list-card" style={{ padding: "1.25rem" }}>
              <h3 style={{ marginTop: 0 }}>Price trend ({rangeDays}D)</h3>
              {loading ? <Loader2 className="spinner" /> : <SimpleLineChart series={analytics.price_series} />}
            </div>
            <div className="sr-list-card" style={{ padding: "1.25rem" }}>
              <h3 style={{ marginTop: 0 }}>Arrival / Trade / Stock</h3>
              {loading ? <Loader2 className="spinner" /> : <SimpleBarChart items={qtyBars} />}
            </div>
          </div>
        </div>
      )}

      {tab === "masters" && (
        <div style={{ display: "grid", gap: "1.25rem" }}>
          {[
            { type: "agent", title: "Agents", list: agents, cols: ["Name", "Code", "Status"] },
            { type: "apmc", title: "APMCs", list: apmcs, cols: ["Name", "Taluk", "District"] },
            { type: "variety", title: "Varieties", list: varieties, cols: ["Name", "Status", "Order"] },
          ].map((block) => (
            <div key={block.type} className="sr-list-card">
              <div className="sr-list-header">
                <h3 style={{ margin: 0 }}>{block.title}</h3>
                <button type="button" className="sr-btn sr-btn-primary" onClick={() => openMetaCreate(block.type)}>
                  <Plus size={14} /> Add
                </button>
              </div>
              <div className="mr-table-wrap">
                <table className="mr-table">
                  <thead>
                    <tr>
                      {block.cols.map((c) => <th key={c}>{c}</th>)}
                      <th>Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {block.list.map((row) => (
                      <tr key={row.id}>
                        {block.type === "agent" && (
                          <>
                            <td>{row.name}</td>
                            <td>{row.code}</td>
                            <td>{row.status}</td>
                          </>
                        )}
                        {block.type === "apmc" && (
                          <>
                            <td>{row.name}</td>
                            <td>{row.taluk}</td>
                            <td>{row.district}</td>
                          </>
                        )}
                        {block.type === "variety" && (
                          <>
                            <td>{row.name}</td>
                            <td>{row.status}</td>
                            <td>{row.sort_order}</td>
                          </>
                        )}
                        <td>
                          <button type="button" className="mr-icon-btn" onClick={() => openMetaEdit(block.type, row)}><Edit size={16} /></button>
                          <button type="button" className="mr-icon-btn danger" onClick={() => deleteMeta(block.type, row)}><Trash2 size={16} /></button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          ))}
        </div>
      )}

      {showDataTable && (
        <div className="sr-list-card">
          <div className="sr-list-header">
            <h3 style={{ margin: 0 }}>
              {tab === "prices"
                ? "Enter / edit daily rates"
                : tab === "history"
                  ? `Rate history (${filterFrom} → ${filterTo})`
                  : tab === "lots"
                    ? "Lot Details"
                    : "Quantities"}{" "}
              ({total})
            </h3>
            <div style={{ display: "flex", gap: "0.5rem", alignItems: "center" }}>
              <button type="button" className="mr-icon-btn" disabled={page <= 1} onClick={() => setPage((p) => p - 1)}><ChevronLeft size={16} /></button>
              <span style={{ fontSize: "0.85rem" }}>{page} / {totalPages}</span>
              <button type="button" className="mr-icon-btn" disabled={page >= totalPages} onClick={() => setPage((p) => p + 1)}><ChevronRight size={16} /></button>
            </div>
          </div>
          {loading ? (
            <div className="sr-loader"><Loader2 className="spinner" size={36} /><p>Loading…</p></div>
          ) : (
            <div className="mr-table-wrap">
              <table className="mr-table">
                <thead>
                  <tr>
                    <th>Date</th>
                    {tab === "lots" && <th>Lot No</th>}
                    <th>Variety</th>
                    <th>Agent</th>
                    <th>APMC</th>
                    <th>Taluk</th>
                    {showPriceTable && (<><th>Min</th><th>Max</th><th>Avg</th></>)}
                    {tab === "lots" && (<><th>Price</th><th>Qty</th><th>Purchaser</th></>)}
                    {tab === "qty" && (<><th>Arrival</th><th>Trade</th><th>Stock</th></>)}
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {rows.length === 0 ? (
                    <tr><td colSpan={12}><div className="sr-empty">No records</div></td></tr>
                  ) : rows.map((row) => (
                    <tr key={row.id}>
                      <td>{dateInputValue(row.date)}</td>
                      {tab === "lots" && <td>{row.lot_no}</td>}
                      <td>{row.variety?.name || "—"}</td>
                      <td>{row.agent?.name || "—"}</td>
                      <td>{row.apmc?.name || "—"}</td>
                      <td>{row.taluk || "—"}</td>
                      {showPriceTable && (<><td>{fmtNum(row.min_price)}</td><td>{fmtNum(row.max_price)}</td><td>{fmtNum(row.avg_price)}</td></>)}
                      {tab === "lots" && (<><td>{fmtNum(row.price)}</td><td>{fmtNum(row.quantity)}</td><td>{row.purchaser || "—"}</td></>)}
                      {tab === "qty" && (<><td>{fmtNum(row.arrival_qty)}</td><td>{fmtNum(row.trade_qty)}</td><td>{fmtNum(row.stock_qty)}</td></>)}
                      <td>
                        <button type="button" className="mr-icon-btn" onClick={() => openEdit(row)}><Edit size={16} /></button>
                        <button type="button" className="mr-icon-btn danger" onClick={() => handleDelete(row)}><Trash2 size={16} /></button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}

      {modalOpen && (
        <div className="modal-overlay" onClick={() => setModalOpen(false)}>
          <div className="modal-content sr-modal" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header sr-modal-header">
              <h3>
                {selected ? "Edit" : "Add"}{" "}
                {tab === "lots" ? "Lot" : tab === "qty" ? "Quantity" : "Daily Price"}
              </h3>
              <button type="button" className="close-btn" onClick={() => setModalOpen(false)}><X size={18} /></button>
            </div>
            <form onSubmit={handleSubmit} className="sr-form">
              <div className="mr-form-grid">
                <label>Date<input required type="date" name="date" value={form.date} onChange={handleFormChange} /></label>
                <label>Variety
                  <select required name="variety_id" value={form.variety_id} onChange={handleFormChange}>
                    <option value="">Select</option>
                    {varieties.map((v) => <option key={v.id} value={v.id}>{v.name}</option>)}
                  </select>
                </label>
                <label>Agent
                  <select required name="agent_id" value={form.agent_id} onChange={handleFormChange}>
                    <option value="">Select</option>
                    {agents.map((a) => <option key={a.id} value={a.id}>{a.name}</option>)}
                  </select>
                </label>
                <label>APMC
                  <select required name="apmc_id" value={form.apmc_id} onChange={handleFormChange}>
                    <option value="">Select</option>
                    {apmcs.map((a) => <option key={a.id} value={a.id}>{a.name}</option>)}
                  </select>
                </label>
                <label>Taluk<input name="taluk" value={form.taluk} onChange={handleFormChange} /></label>
                {(tab === "prices" || tab === "history" || tab === "overview" || form.min_price !== undefined) && tab !== "lots" && tab !== "qty" && (
                  <>
                    <label>Min<input required type="number" name="min_price" value={form.min_price} onChange={handleFormChange} /></label>
                    <label>Max<input required type="number" name="max_price" value={form.max_price} onChange={handleFormChange} /></label>
                    <label>Average<input required type="number" name="avg_price" value={form.avg_price} onChange={handleFormChange} /></label>
                  </>
                )}
                {tab === "lots" && (
                  <>
                    <label>Lot No<input required name="lot_no" value={form.lot_no} onChange={handleFormChange} /></label>
                    <label>Price<input required type="number" name="price" value={form.price} onChange={handleFormChange} /></label>
                    <label>Quantity<input required type="number" name="quantity" value={form.quantity} onChange={handleFormChange} /></label>
                    <label>Purchaser<input name="purchaser" value={form.purchaser} onChange={handleFormChange} /></label>
                  </>
                )}
                {tab === "qty" && (
                  <>
                    <label>Arrival Qty<input type="number" name="arrival_qty" value={form.arrival_qty} onChange={handleFormChange} /></label>
                    <label>Trade Qty<input type="number" name="trade_qty" value={form.trade_qty} onChange={handleFormChange} /></label>
                    <label>Stock<input type="number" name="stock_qty" value={form.stock_qty} onChange={handleFormChange} /></label>
                  </>
                )}
                <label className="full">Notes<textarea name="notes" value={form.notes} onChange={handleFormChange} rows={2} /></label>
              </div>
              <div className="mr-modal-actions">
                <button type="button" className="sr-btn sr-btn-ghost" onClick={() => setModalOpen(false)}>Cancel</button>
                <button type="submit" className="sr-btn sr-btn-primary" disabled={saving}>
                  {saving ? <Loader2 className="spinner" size={16} /> : "Save"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {metaModal && (
        <div className="modal-overlay" onClick={() => setMetaModal(false)}>
          <div className="modal-content sr-modal" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header sr-modal-header">
              <h3>{metaSelected ? "Edit" : "Add"} {metaType}</h3>
              <button type="button" className="close-btn" onClick={() => setMetaModal(false)}><X size={18} /></button>
            </div>
            <form onSubmit={saveMeta} className="sr-form">
              <div className="mr-form-grid">
                <label>Name<input required name="name" value={metaForm.name} onChange={(e) => setMetaForm((p) => ({ ...p, name: e.target.value }))} /></label>
                {metaType === "agent" && (
                  <label>Code<input name="code" value={metaForm.code} onChange={(e) => setMetaForm((p) => ({ ...p, code: e.target.value }))} /></label>
                )}
                {metaType === "apmc" && (
                  <>
                    <label>Taluk<input name="taluk" value={metaForm.taluk} onChange={(e) => setMetaForm((p) => ({ ...p, taluk: e.target.value }))} /></label>
                    <label>District<input name="district" value={metaForm.district} onChange={(e) => setMetaForm((p) => ({ ...p, district: e.target.value }))} /></label>
                  </>
                )}
                <label>Status
                  <select name="status" value={metaForm.status} onChange={(e) => setMetaForm((p) => ({ ...p, status: e.target.value }))}>
                    <option value="active">active</option>
                    <option value="inactive">inactive</option>
                  </select>
                </label>
                <label>Sort order<input type="number" name="sort_order" value={metaForm.sort_order} onChange={(e) => setMetaForm((p) => ({ ...p, sort_order: e.target.value }))} /></label>
              </div>
              <div className="mr-modal-actions">
                <button type="button" className="sr-btn sr-btn-ghost" onClick={() => setMetaModal(false)}>Cancel</button>
                <button type="submit" className="sr-btn sr-btn-primary" disabled={metaSaving}>
                  {metaSaving ? <Loader2 className="spinner" size={16} /> : "Save"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

export default MarketReports;
