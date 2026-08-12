import React, { useCallback, useEffect, useState } from "react";
import { Link } from "react-router-dom";
import {
  Activity,
  Loader2,
  ChevronLeft,
  ChevronRight,
  X,
  Users,
  Briefcase,
  Wallet,
  MessageSquare,
} from "lucide-react";
import { getAdminEntryAnalytics, getAdminEntryAnalyticsEntries } from "../api/api";
import "./ServiceRegistrations.css";
import "./MarketReports.css";

const entryLimit = 20;

function fmtDate(v) {
  if (!v) return "—";
  const s = String(v);
  if (s.length >= 10) return s.slice(0, 10);
  const d = new Date(v);
  if (Number.isNaN(d.getTime())) return s;
  return d.toISOString().slice(0, 10);
}

function fmtDateTime(v) {
  if (!v) return "—";
  const d = new Date(v);
  if (Number.isNaN(d.getTime())) return String(v).slice(0, 16);
  return d.toLocaleString("en-IN", { dateStyle: "medium", timeStyle: "short" });
}

const MENU_CARDS = [
  { key: "labor", label: "Labour", totalKey: "labors", icon: Briefcase, color: "#2563eb" },
  { key: "income_expense", label: "Income & Expense", totalKey: "income_expenses", icon: Wallet, color: "#059669" },
  { key: "feedback", label: "Feedback", totalKey: "feedbacks", icon: MessageSquare, color: "#d97706" },
];

const EntryAnalytics = () => {
  const [loading, setLoading] = useState(true);
  const [totals, setTotals] = useState({ labors: 0, income_expenses: 0, feedbacks: 0, by_menu: {} });
  const [byUser, setByUser] = useState([]);
  const [recent, setRecent] = useState([]);
  const [from, setFrom] = useState("");
  const [to, setTo] = useState("");

  const [drill, setDrill] = useState(null); // { menu, user_id?, user_name? }
  const [entries, setEntries] = useState([]);
  const [entriesTotal, setEntriesTotal] = useState(0);
  const [entriesPage, setEntriesPage] = useState(1);
  const [entriesLoading, setEntriesLoading] = useState(false);

  const fetchSummary = useCallback(async () => {
    setLoading(true);
    try {
      const params = {};
      if (from) params.from = from;
      if (to) params.to = to;
      const data = await getAdminEntryAnalytics(params);
      setTotals(data.totals || { labors: 0, income_expenses: 0, feedbacks: 0, by_menu: {} });
      setByUser(data.by_user || []);
      setRecent(data.recent || []);
    } catch (e) {
      console.error(e);
      setTotals({ labors: 0, income_expenses: 0, feedbacks: 0, by_menu: {} });
      setByUser([]);
      setRecent([]);
    } finally {
      setLoading(false);
    }
  }, [from, to]);

  useEffect(() => {
    fetchSummary();
  }, [fetchSummary]);

  const fetchEntries = useCallback(async () => {
    if (!drill || drill.menu === "feedback") {
      setEntries([]);
      setEntriesTotal(0);
      return;
    }
    setEntriesLoading(true);
    try {
      const params = {
        menu: drill.menu,
        page: entriesPage,
        limit: entryLimit,
      };
      if (drill.user_id) params.user_id = drill.user_id;
      if (from) params.from = from;
      if (to) params.to = to;
      const data = await getAdminEntryAnalyticsEntries(params);
      setEntries(data.data || []);
      setEntriesTotal(data.total ?? 0);
    } catch (e) {
      console.error(e);
      setEntries([]);
      setEntriesTotal(0);
      alert(e?.response?.data?.error || "Failed to load entries");
    } finally {
      setEntriesLoading(false);
    }
  }, [drill, entriesPage, from, to]);

  useEffect(() => {
    if (drill) fetchEntries();
  }, [drill, fetchEntries]);

  const openDrill = (menu, user = null) => {
    setEntriesPage(1);
    setDrill({
      menu,
      user_id: user?.user_id || null,
      user_name: user?.name || null,
    });
  };

  const closeDrill = () => {
    setDrill(null);
    setEntries([]);
    setEntriesTotal(0);
    setEntriesPage(1);
  };

  const entriesPages = Math.max(1, Math.ceil(entriesTotal / entryLimit) || 1);

  const feedbackUsers = (byUser || []).filter((u) => (u.feedback_count || 0) > 0);
  const drillFeedbackUsers = drill?.user_id
    ? feedbackUsers.filter((u) => u.user_id === drill.user_id)
    : feedbackUsers;

  return (
    <div className="service-reg-page">
      <div className="sr-toolbar">
        <div>
          <h1 style={{ display: "flex", alignItems: "center", gap: "0.5rem", margin: 0 }}>
            <Activity size={22} /> Entry Analytics
          </h1>
          <p style={{ margin: "0.35rem 0 0", color: "var(--text-muted)", fontSize: "0.9rem" }}>
            Who is entering labour, income/expense, and feedback — click a card or user to drill in.
          </p>
        </div>
      </div>

      <div className="sr-list-card" style={{ padding: "1rem 1.25rem" }}>
        <div className="mr-filters">
          <label className="mr-filter-label">
            From
            <input type="date" className="sr-input" value={from} onChange={(e) => setFrom(e.target.value)} />
          </label>
          <label className="mr-filter-label">
            To
            <input type="date" className="sr-input" value={to} onChange={(e) => setTo(e.target.value)} />
          </label>
          {(from || to) && (
            <button type="button" className="sr-btn sr-btn-ghost" onClick={() => { setFrom(""); setTo(""); }}>
              Clear dates
            </button>
          )}
        </div>
      </div>

      {loading ? (
        <div className="sr-empty" style={{ padding: "2rem", display: "flex", justifyContent: "center" }}>
          <Loader2 className="spinner" size={28} />
        </div>
      ) : (
        <>
          <div className="mr-stats">
            {MENU_CARDS.map((card) => {
              const Icon = card.icon;
              const count = totals[card.totalKey] ?? totals.by_menu?.[card.key] ?? 0;
              return (
                <button
                  key={card.key}
                  type="button"
                  className="mr-stat-card"
                  style={{ cursor: "pointer", textAlign: "left", borderColor: card.color }}
                  onClick={() => openDrill(card.key)}
                >
                  <span style={{ display: "flex", alignItems: "center", gap: "0.35rem" }}>
                    <Icon size={14} style={{ color: card.color }} />
                    {card.label}
                  </span>
                  <strong>{Number(count).toLocaleString("en-IN")}</strong>
                </button>
              );
            })}
          </div>

          <div className="sr-list-card">
            <div className="sr-list-header">
              <span className="sr-count" style={{ display: "flex", alignItems: "center", gap: "0.4rem" }}>
                <Users size={16} /> Entries by user ({byUser.length})
              </span>
            </div>
            <div style={{ overflowX: "auto" }}>
              <table className="mr-table">
                <thead>
                  <tr>
                    <th>User</th>
                    <th>Email</th>
                    <th>Labour</th>
                    <th>I&amp;E</th>
                    <th>Feedback</th>
                    <th>Total</th>
                  </tr>
                </thead>
                <tbody>
                  {byUser.length === 0 ? (
                    <tr>
                      <td colSpan={6}>
                        <div className="sr-empty">No entries for this range</div>
                      </td>
                    </tr>
                  ) : (
                    byUser.map((u) => (
                      <tr key={u.user_id}>
                        <td>
                          <button
                            type="button"
                            className="sr-btn sr-btn-ghost"
                            style={{ padding: "0.2rem 0.4rem" }}
                            onClick={() => openDrill(u.labor_count ? "labor" : u.ie_count ? "income_expense" : "feedback", u)}
                          >
                            {u.name || `User #${u.user_id}`}
                          </button>
                        </td>
                        <td>{u.email || "—"}</td>
                        <td>
                          <button type="button" className="sr-btn sr-btn-ghost" style={{ padding: "0.15rem 0.35rem" }} onClick={() => openDrill("labor", u)}>
                            {u.labor_count}
                          </button>
                        </td>
                        <td>
                          <button type="button" className="sr-btn sr-btn-ghost" style={{ padding: "0.15rem 0.35rem" }} onClick={() => openDrill("income_expense", u)}>
                            {u.ie_count}
                          </button>
                        </td>
                        <td>
                          <button type="button" className="sr-btn sr-btn-ghost" style={{ padding: "0.15rem 0.35rem" }} onClick={() => openDrill("feedback", u)}>
                            {u.feedback_count}
                          </button>
                        </td>
                        <td>
                          <strong>{u.total}</strong>
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </div>

          <div className="sr-list-card">
            <div className="sr-list-header">
              <span className="sr-count">Recent entries</span>
            </div>
            <div style={{ overflowX: "auto" }}>
              <table className="mr-table">
                <thead>
                  <tr>
                    <th>Menu</th>
                    <th>User</th>
                    <th>Summary</th>
                    <th>Date</th>
                    <th>Created</th>
                  </tr>
                </thead>
                <tbody>
                  {recent.length === 0 ? (
                    <tr>
                      <td colSpan={5}>
                        <div className="sr-empty">No recent entries</div>
                      </td>
                    </tr>
                  ) : (
                    recent.map((r) => (
                      <tr key={`${r.menu}-${r.id}`}>
                        <td>
                          <button type="button" className="sr-btn sr-btn-ghost" style={{ padding: "0.15rem 0.35rem" }} onClick={() => openDrill(r.menu)}>
                            {r.menu}
                          </button>
                        </td>
                        <td>
                          <button
                            type="button"
                            className="sr-btn sr-btn-ghost"
                            style={{ padding: "0.15rem 0.35rem" }}
                            onClick={() => openDrill(r.menu, { user_id: r.user_id, name: r.user_name })}
                          >
                            {r.user_name || `#${r.user_id}`}
                          </button>
                        </td>
                        <td style={{ whiteSpace: "normal", maxWidth: 320 }}>{r.summary}</td>
                        <td>{fmtDate(r.date)}</td>
                        <td>{fmtDateTime(r.created_at)}</td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </>
      )}

      {drill && (
        <div className="modal-overlay" onClick={closeDrill}>
          <div className="modal-content sr-modal sr-modal-wide" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header sr-modal-header">
              <h3>
                {drill.menu}
                {drill.user_name ? ` · ${drill.user_name}` : drill.user_id ? ` · User #${drill.user_id}` : ""}
              </h3>
              <button type="button" className="close-btn" onClick={closeDrill}>
                <X size={18} />
              </button>
            </div>

            {drill.menu === "feedback" ? (
              <div style={{ padding: "0 1rem 1rem" }}>
                <p style={{ color: "var(--text-muted)", fontSize: "0.875rem" }}>
                  Feedback detail listing is on the <Link to="/feedback">Feedback</Link> page (entries API is labour / I&amp;E only). Counts below:
                </p>
                <table className="mr-table">
                  <thead>
                    <tr>
                      <th>User</th>
                      <th>Email</th>
                      <th>Feedback count</th>
                    </tr>
                  </thead>
                  <tbody>
                    {drillFeedbackUsers.length === 0 ? (
                      <tr>
                        <td colSpan={3}>
                          <div className="sr-empty">No feedback counts for this filter</div>
                        </td>
                      </tr>
                    ) : (
                      drillFeedbackUsers.map((u) => (
                        <tr key={u.user_id}>
                          <td>{u.name || `#${u.user_id}`}</td>
                          <td>{u.email || "—"}</td>
                          <td>{u.feedback_count}</td>
                        </tr>
                      ))
                    )}
                  </tbody>
                </table>
              </div>
            ) : entriesLoading ? (
              <div className="sr-empty" style={{ padding: "2rem", display: "flex", justifyContent: "center" }}>
                <Loader2 className="spinner" size={24} />
              </div>
            ) : (
              <div style={{ padding: "0 1rem 1rem" }}>
                <div className="sr-list-header" style={{ padding: "0 0 0.75rem", border: "none" }}>
                  <span className="sr-count">{entriesTotal} entries</span>
                  <div className="sr-pagination">
                    <span>
                      Page {entriesPage} / {entriesPages}
                    </span>
                    <div className="sr-page-btns">
                      <button
                        type="button"
                        className="sr-btn sr-btn-ghost"
                        disabled={entriesPage <= 1}
                        onClick={() => setEntriesPage((p) => Math.max(1, p - 1))}
                      >
                        <ChevronLeft size={16} />
                      </button>
                      <button
                        type="button"
                        className="sr-btn sr-btn-ghost"
                        disabled={entriesPage >= entriesPages}
                        onClick={() => setEntriesPage((p) => Math.min(entriesPages, p + 1))}
                      >
                        <ChevronRight size={16} />
                      </button>
                    </div>
                  </div>
                </div>
                <div style={{ overflowX: "auto" }}>
                  {drill.menu === "labor" ? (
                    <table className="mr-table">
                      <thead>
                        <tr>
                          <th>Date</th>
                          <th>Name</th>
                          <th>Category</th>
                          <th>Shift</th>
                          <th>User ID</th>
                        </tr>
                      </thead>
                      <tbody>
                        {entries.length === 0 ? (
                          <tr>
                            <td colSpan={5}>
                              <div className="sr-empty">No labour entries</div>
                            </td>
                          </tr>
                        ) : (
                          entries.map((row) => (
                            <tr key={row.id}>
                              <td>{fmtDate(row.date)}</td>
                              <td>{row.name}</td>
                              <td>{row.category}</td>
                              <td>{row.shift}</td>
                              <td>{row.user_id}</td>
                            </tr>
                          ))
                        )}
                      </tbody>
                    </table>
                  ) : (
                    <table className="mr-table">
                      <thead>
                        <tr>
                          <th>Date</th>
                          <th>Type</th>
                          <th>Category</th>
                          <th>Sub</th>
                          <th>Amount</th>
                          <th>User ID</th>
                        </tr>
                      </thead>
                      <tbody>
                        {entries.length === 0 ? (
                          <tr>
                            <td colSpan={6}>
                              <div className="sr-empty">No I&amp;E entries</div>
                            </td>
                          </tr>
                        ) : (
                          entries.map((row) => (
                            <tr key={row.id}>
                              <td>{fmtDate(row.date)}</td>
                              <td>{row.type}</td>
                              <td>{row.category}</td>
                              <td>{row.sub_category || row.SubCategory || "—"}</td>
                              <td>{row.amount != null ? String(row.amount) : "—"}</td>
                              <td>{row.user_id}</td>
                            </tr>
                          ))
                        )}
                      </tbody>
                    </table>
                  )}
                </div>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
};

export default EntryAnalytics;
