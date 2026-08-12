import React, { useCallback, useEffect, useState } from "react";
import { MessageSquare, Loader2, ChevronLeft, ChevronRight } from "lucide-react";
import { getAdminFeedbacks, setAdminFeedbackVerified } from "../api/api";
import "./ServiceRegistrations.css";

const limit = 20;

function fmtDate(v) {
  if (!v) return "—";
  const d = new Date(v);
  if (Number.isNaN(d.getTime())) return String(v).slice(0, 16);
  return d.toLocaleString("en-IN", { dateStyle: "medium", timeStyle: "short" });
}

const FILTERS = [
  { id: "all", label: "All" },
  { id: "true", label: "Verified" },
  { id: "false", label: "Not verified" },
];

const FeedbackAdmin = () => {
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [verified, setVerified] = useState("all");
  const [togglingId, setTogglingId] = useState(null);

  const fetchRows = useCallback(async () => {
    setLoading(true);
    try {
      const data = await getAdminFeedbacks({ page, limit, verified });
      setRows(data.data || []);
      setTotal(data.total ?? 0);
    } catch (e) {
      console.error(e);
      setRows([]);
      setTotal(0);
    } finally {
      setLoading(false);
    }
  }, [page, verified]);

  useEffect(() => {
    setPage(1);
  }, [verified]);

  useEffect(() => {
    fetchRows();
  }, [fetchRows]);

  const totalPages = Math.max(1, Math.ceil(total / limit) || 1);

  const toggleVerified = async (row) => {
    const next = !row.verified;
    setTogglingId(row.id);
    try {
      const updated = await setAdminFeedbackVerified(row.id, next);
      setRows((prev) => prev.map((r) => (r.id === row.id ? { ...r, ...updated } : r)));
    } catch (err) {
      alert(err?.response?.data?.error || "Failed to update verification");
    } finally {
      setTogglingId(null);
    }
  };

  return (
    <div className="service-reg-page">
      <div className="sr-toolbar">
        <div>
          <h1 style={{ display: "flex", alignItems: "center", gap: "0.5rem", margin: 0 }}>
            <MessageSquare size={22} /> Feedback
          </h1>
          <p style={{ margin: "0.35rem 0 0", color: "var(--text-muted)", fontSize: "0.9rem" }}>
            Review app feedback. Verified items appear in the mobile app.
          </p>
        </div>
      </div>

      <div className="sr-filter-tabs">
        {FILTERS.map((f) => (
          <button
            key={f.id}
            type="button"
            className={`sr-filter-tab ${verified === f.id ? "active" : ""}`}
            onClick={() => setVerified(f.id)}
          >
            {f.label}
          </button>
        ))}
      </div>

      <div className="sr-list-card">
        <div className="sr-list-header">
          <span className="sr-count">{total} feedback{total === 1 ? "" : "s"}</span>
          <div className="sr-pagination">
            <span>
              Page {page} / {totalPages}
            </span>
            <div className="sr-page-btns">
              <button
                type="button"
                className="sr-btn sr-btn-ghost"
                disabled={page <= 1 || loading}
                onClick={() => setPage((p) => Math.max(1, p - 1))}
              >
                <ChevronLeft size={16} />
              </button>
              <button
                type="button"
                className="sr-btn sr-btn-ghost"
                disabled={page >= totalPages || loading}
                onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
              >
                <ChevronRight size={16} />
              </button>
            </div>
          </div>
        </div>

        {loading ? (
          <div className="sr-empty" style={{ padding: "2rem", display: "flex", justifyContent: "center" }}>
            <Loader2 className="spinner" size={28} />
          </div>
        ) : (
          <div className="sr-table-wrap" style={{ overflowX: "auto" }}>
            <table className="sr-table" style={{ width: "100%", borderCollapse: "collapse", fontSize: "0.875rem" }}>
              <thead>
                <tr>
                  <th style={{ padding: "0.75rem 1rem", textAlign: "left", borderBottom: "1px solid var(--border)" }}>User</th>
                  <th style={{ padding: "0.75rem 1rem", textAlign: "left", borderBottom: "1px solid var(--border)" }}>Subject</th>
                  <th style={{ padding: "0.75rem 1rem", textAlign: "left", borderBottom: "1px solid var(--border)" }}>Message</th>
                  <th style={{ padding: "0.75rem 1rem", textAlign: "left", borderBottom: "1px solid var(--border)" }}>Menu</th>
                  <th style={{ padding: "0.75rem 1rem", textAlign: "left", borderBottom: "1px solid var(--border)" }}>Date</th>
                  <th style={{ padding: "0.75rem 1rem", textAlign: "center", borderBottom: "1px solid var(--border)" }}>Verified</th>
                </tr>
              </thead>
              <tbody>
                {rows.length === 0 ? (
                  <tr>
                    <td colSpan={6}>
                      <div className="sr-empty" style={{ padding: "1.5rem" }}>No feedback found</div>
                    </td>
                  </tr>
                ) : (
                  rows.map((row) => (
                    <tr key={row.id}>
                      <td style={{ padding: "0.75rem 1rem", borderBottom: "1px solid var(--border)", verticalAlign: "top" }}>
                        <div style={{ fontWeight: 600 }}>{row.user_name || `User #${row.user_id}`}</div>
                        <div style={{ fontSize: "0.75rem", color: "var(--text-muted)" }}>
                          {[row.user_email, row.user_phone].filter(Boolean).join(" · ") || "—"}
                        </div>
                      </td>
                      <td style={{ padding: "0.75rem 1rem", borderBottom: "1px solid var(--border)", verticalAlign: "top" }}>
                        {row.subject || "—"}
                      </td>
                      <td
                        style={{
                          padding: "0.75rem 1rem",
                          borderBottom: "1px solid var(--border)",
                          verticalAlign: "top",
                          maxWidth: 360,
                          whiteSpace: "pre-wrap",
                          wordBreak: "break-word",
                        }}
                      >
                        {row.message}
                      </td>
                      <td style={{ padding: "0.75rem 1rem", borderBottom: "1px solid var(--border)", verticalAlign: "top" }}>
                        {row.menu || "—"}
                      </td>
                      <td style={{ padding: "0.75rem 1rem", borderBottom: "1px solid var(--border)", verticalAlign: "top", whiteSpace: "nowrap" }}>
                        {fmtDate(row.created_at)}
                      </td>
                      <td style={{ padding: "0.75rem 1rem", borderBottom: "1px solid var(--border)", textAlign: "center", verticalAlign: "top" }}>
                        {togglingId === row.id ? (
                          <Loader2 className="spinner" size={16} />
                        ) : (
                          <input
                            type="checkbox"
                            checked={Boolean(row.verified)}
                            onChange={() => toggleVerified(row)}
                            title={row.verified ? "Unverify" : "Verify (shows in app)"}
                            aria-label={`Verify feedback ${row.id}`}
                          />
                        )}
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
};

export default FeedbackAdmin;
