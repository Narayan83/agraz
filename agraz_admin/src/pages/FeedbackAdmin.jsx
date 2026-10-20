import React, { useCallback, useEffect, useRef, useState } from "react";
import {
  MessageSquare,
  Loader2,
  ChevronLeft,
  ChevronRight,
  Pencil,
  Trash2,
  X,
  RotateCcw,
  Upload,
} from "lucide-react";
import {
  getAdminFeedbacks,
  setAdminFeedbackVerified,
  updateAdminFeedback,
  deleteAdminFeedback,
  getAdminFeedbackDeletionLogs,
  revokeAdminFeedbackDeletion,
  importAdminAppSurvey,
} from "../api/api";
import "./ServiceRegistrations.css";

const limit = 20;

function fmtDate(v) {
  if (!v) return "—";
  const d = new Date(v);
  if (Number.isNaN(d.getTime())) return String(v).slice(0, 16);
  return d.toLocaleString("en-IN", { dateStyle: "medium", timeStyle: "short" });
}

/** Strip survey question prompts like "[What would you improve]" from imported text. */
function cleanSurveyMessage(raw) {
  let s = String(raw || "").trim();
  while (true) {
    const next = s.replace(/^\s*\[[^\]]*\]\s*/, "").trim();
    if (next === s) break;
    s = next;
  }
  return s;
}

const FILTERS = [
  { id: "all", label: "All" },
  { id: "true", label: "Verified" },
  { id: "false", label: "Not verified" },
];

const TABS = [
  { id: "active", label: "Feedback" },
  { id: "deleted", label: "Deletion log" },
];

const inputStyle = {
  display: "block",
  width: "100%",
  marginTop: 6,
  padding: "0.6rem 0.75rem",
  borderRadius: 8,
  border: "1px solid var(--border)",
  fontFamily: "inherit",
};

async function confirmTwice(actionLabel) {
  const first = window.confirm(
    `Are you sure you want to ${actionLabel}?\n\nThis is confirmation 1 of 2.`
  );
  if (!first) return false;
  return window.confirm(
    `Please confirm again to ${actionLabel}.\n\nThis is confirmation 2 of 2.`
  );
}

const FeedbackAdmin = () => {
  const [tab, setTab] = useState("active");
  const [rows, setRows] = useState([]);
  const [logs, setLogs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [verified, setVerified] = useState("all");
  const [togglingId, setTogglingId] = useState(null);
  const [selectedId, setSelectedId] = useState(null);
  const [busyId, setBusyId] = useState(null);

  const [editOpen, setEditOpen] = useState(false);
  const [editRow, setEditRow] = useState(null);
  const [editSubject, setEditSubject] = useState("");
  const [editMessage, setEditMessage] = useState("");
  const [editMenu, setEditMenu] = useState("");
  const [editVerified, setEditVerified] = useState(false);
  const [saving, setSaving] = useState(false);

  const importRef = useRef(null);

  const fetchRows = useCallback(async () => {
    setLoading(true);
    try {
      if (tab === "deleted") {
        const data = await getAdminFeedbackDeletionLogs({ page, limit, open: "true" });
        setLogs(data.data || []);
        setRows([]);
        setTotal(data.total ?? 0);
      } else {
        const data = await getAdminFeedbacks({ page, limit, verified });
        setRows(data.data || []);
        setLogs([]);
        setTotal(data.total ?? 0);
      }
    } catch (e) {
      console.error(e);
      setRows([]);
      setLogs([]);
      setTotal(0);
    } finally {
      setLoading(false);
    }
  }, [page, verified, tab]);

  useEffect(() => {
    setPage(1);
    setSelectedId(null);
  }, [verified, tab]);

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

  const openEdit = (row) => {
    setEditRow(row);
    setEditSubject(row.subject || "");
    setEditMessage(row.message || "");
    setEditMenu(row.menu || "");
    setEditVerified(Boolean(row.verified));
    setEditOpen(true);
  };

  const saveEdit = async () => {
    if (!editRow) return;
    const message = cleanSurveyMessage(editMessage);
    if (!message) {
      alert("Message is required");
      return;
    }
    setSaving(true);
    try {
      const updated = await updateAdminFeedback(editRow.id, {
        subject: editSubject,
        message,
        menu: editMenu,
        verified: editVerified,
      });
      setRows((prev) => prev.map((r) => (r.id === editRow.id ? { ...r, ...updated } : r)));
      setEditOpen(false);
      setEditRow(null);
    } catch (err) {
      alert(err?.response?.data?.error || "Failed to save feedback");
    } finally {
      setSaving(false);
    }
  };

  const removeFeedback = async (row) => {
    const ok = await confirmTwice(`delete feedback #${row.id}`);
    if (!ok) return;
    setBusyId(row.id);
    try {
      await deleteAdminFeedback(row.id);
      setSelectedId(null);
      await fetchRows();
    } catch (err) {
      alert(err?.response?.data?.error || "Failed to delete feedback");
    } finally {
      setBusyId(null);
    }
  };

  const revokeDeletion = async (log) => {
    const ok = await confirmTwice(`revoke deletion and restore feedback #${log.feedback_id}`);
    if (!ok) return;
    setBusyId(log.id);
    try {
      await revokeAdminFeedbackDeletion(log.id);
      await fetchRows();
    } catch (err) {
      alert(err?.response?.data?.error || "Failed to revoke deletion");
    } finally {
      setBusyId(null);
    }
  };

  const handleImportFile = async (event) => {
    const file = event.target.files?.[0];
    event.target.value = "";
    if (!file) return;
    try {
      const text = await file.text();
      let rows = [];
      if (file.name.toLowerCase().endsWith(".json")) {
        const parsed = JSON.parse(text);
        rows = Array.isArray(parsed) ? parsed : parsed.rows || [];
      } else {
        // Simple CSV: first column message, optional subject
        const lines = text.split(/\r?\n/).map((l) => l.trim()).filter(Boolean);
        rows = lines.slice(1).map((line) => {
          const parts = line.split(",").map((p) => p.replace(/^"|"$/g, "").trim());
          return {
            message: cleanSurveyMessage(parts[0] || ""),
            subject: parts[1] || "Imported survey",
            user_name: parts[2] || "",
            user_email: parts[3] || "",
            user_phone: parts[4] || "",
          };
        });
      }
      rows = rows.map((r) => ({
        ...r,
        message: cleanSurveyMessage(r.message || r.feedback || r.comment || r.answer || ""),
      }));
      const result = await importAdminAppSurvey({ rows });
      alert(`Imported ${result.imported || 0}, skipped ${result.skipped || 0}`);
      setTab("active");
      await fetchRows();
    } catch (err) {
      // Fallback: import from DB table app_survey with no body
      try {
        const result = await importAdminAppSurvey({});
        alert(`Imported ${result.imported || 0} from app_survey (skipped ${result.skipped || 0})`);
        setTab("active");
        await fetchRows();
      } catch (e2) {
        alert(err?.response?.data?.error || e2?.response?.data?.error || "Import failed");
      }
    }
  };

  const importFromTable = async () => {
    try {
      const result = await importAdminAppSurvey({});
      alert(`Imported ${result.imported || 0} from app_survey (skipped ${result.skipped || 0})`);
      setTab("active");
      await fetchRows();
    } catch (err) {
      alert(err?.response?.data?.error || "Import from app_survey failed");
    }
  };

  useEffect(() => {
    if (tab !== "active") return undefined;
    const onKeyDown = (e) => {
      if (e.key !== "Delete") return;
      if (editOpen) return;
      const tag = (e.target?.tagName || "").toLowerCase();
      if (tag === "input" || tag === "textarea" || e.target?.isContentEditable) return;
      const row = rows.find((r) => r.id === selectedId);
      if (!row) return;
      e.preventDefault();
      removeFeedback(row);
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [tab, editOpen, rows, selectedId]);

  return (
    <div className="service-reg-page">
      <div className="sr-toolbar">
        <div>
          <h1 style={{ display: "flex", alignItems: "center", gap: "0.5rem", margin: 0 }}>
            <MessageSquare size={22} /> Manage Feedback
          </h1>
          <p style={{ margin: "0.35rem 0 0", color: "var(--text-muted)", fontSize: "0.9rem" }}>
            Edit or delete feedback. Deleted items go to the deletion log where you can revoke.
            Press Delete after selecting a row (asks twice).
          </p>
        </div>
        <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
          <input
            ref={importRef}
            type="file"
            accept=".json,.csv,text/csv,application/json"
            style={{ display: "none" }}
            onChange={handleImportFile}
          />
          <button
            type="button"
            className="sr-btn sr-btn-ghost"
            onClick={() => importRef.current?.click()}
            title="Import JSON/CSV (bracketed survey prompts are removed)"
          >
            <Upload size={16} /> Import file
          </button>
          <button
            type="button"
            className="sr-btn sr-btn-ghost"
            onClick={importFromTable}
            title="Import from app_survey table"
          >
            <Upload size={16} /> Import app_survey
          </button>
        </div>
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

      {tab === "active" && (
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
      )}

      <div className="sr-list-card">
        <div className="sr-list-header">
          <span className="sr-count">
            {total} {tab === "deleted" ? "deletion" : "feedback"}
            {total === 1 ? "" : "s"}
          </span>
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
        ) : tab === "deleted" ? (
          <div className="sr-table-wrap" style={{ overflowX: "auto" }}>
            <table className="sr-table" style={{ width: "100%", borderCollapse: "collapse", fontSize: "0.875rem" }}>
              <thead>
                <tr>
                  <th style={thStyle}>Feedback #</th>
                  <th style={thStyle}>User</th>
                  <th style={thStyle}>Subject</th>
                  <th style={thStyle}>Message</th>
                  <th style={thStyle}>Deleted at</th>
                  <th style={{ ...thStyle, textAlign: "center", width: 72 }} />
                </tr>
              </thead>
              <tbody>
                {logs.length === 0 ? (
                  <tr>
                    <td colSpan={6}>
                      <div className="sr-empty" style={{ padding: "1.5rem" }}>No deletions to revoke</div>
                    </td>
                  </tr>
                ) : (
                  logs.map((log) => (
                    <tr key={log.id}>
                      <td style={tdStyle}>#{log.feedback_id}</td>
                      <td style={tdStyle}>
                        <div style={{ fontWeight: 600 }}>{log.user_name || `User #${log.user_id}`}</div>
                        <div style={{ fontSize: "0.75rem", color: "var(--text-muted)" }}>
                          {[log.user_email, log.user_phone].filter(Boolean).join(" · ") || "—"}
                        </div>
                      </td>
                      <td style={tdStyle}>{log.subject || "—"}</td>
                      <td style={{ ...tdStyle, maxWidth: 360, whiteSpace: "pre-wrap", wordBreak: "break-word" }}>
                        {log.message}
                      </td>
                      <td style={{ ...tdStyle, whiteSpace: "nowrap" }}>{fmtDate(log.deleted_at)}</td>
                      <td style={{ ...tdStyle, textAlign: "center" }}>
                        <button
                          type="button"
                          className="sr-btn sr-btn-ghost"
                          title="Revoke deletion"
                          aria-label={`Revoke deletion of feedback ${log.feedback_id}`}
                          disabled={busyId === log.id}
                          onClick={() => revokeDeletion(log)}
                          style={{ padding: "0.35rem 0.45rem" }}
                        >
                          {busyId === log.id ? <Loader2 className="spinner" size={16} /> : <RotateCcw size={16} />}
                        </button>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        ) : (
          <div className="sr-table-wrap" style={{ overflowX: "auto" }}>
            <table className="sr-table" style={{ width: "100%", borderCollapse: "collapse", fontSize: "0.875rem" }}>
              <thead>
                <tr>
                  <th style={thStyle}>User</th>
                  <th style={thStyle}>Subject</th>
                  <th style={thStyle}>Message</th>
                  <th style={thStyle}>Menu</th>
                  <th style={thStyle}>Date</th>
                  <th style={{ ...thStyle, textAlign: "center" }}>Verified</th>
                  <th style={{ ...thStyle, textAlign: "center", width: 48 }}>Edit</th>
                  <th style={{ ...thStyle, textAlign: "center", width: 48 }} />
                </tr>
              </thead>
              <tbody>
                {rows.length === 0 ? (
                  <tr>
                    <td colSpan={8}>
                      <div className="sr-empty" style={{ padding: "1.5rem" }}>No feedback found</div>
                    </td>
                  </tr>
                ) : (
                  rows.map((row) => (
                    <tr
                      key={row.id}
                      onClick={() => setSelectedId(row.id)}
                      style={{
                        background: selectedId === row.id ? "rgba(37, 99, 235, 0.08)" : undefined,
                        cursor: "pointer",
                      }}
                    >
                      <td style={tdStyle}>
                        <div style={{ fontWeight: 600 }}>{row.user_name || `User #${row.user_id}`}</div>
                        <div style={{ fontSize: "0.75rem", color: "var(--text-muted)" }}>
                          {[row.user_email, row.user_phone].filter(Boolean).join(" · ") || "—"}
                        </div>
                      </td>
                      <td style={tdStyle}>{row.subject || "—"}</td>
                      <td style={{ ...tdStyle, maxWidth: 360, whiteSpace: "pre-wrap", wordBreak: "break-word" }}>
                        {row.message}
                      </td>
                      <td style={tdStyle}>{row.menu || "—"}</td>
                      <td style={{ ...tdStyle, whiteSpace: "nowrap" }}>{fmtDate(row.created_at)}</td>
                      <td style={{ ...tdStyle, textAlign: "center" }}>
                        {togglingId === row.id ? (
                          <Loader2 className="spinner" size={16} />
                        ) : (
                          <input
                            type="checkbox"
                            checked={Boolean(row.verified)}
                            onChange={() => toggleVerified(row)}
                            onClick={(e) => e.stopPropagation()}
                            title={row.verified ? "Unverify" : "Verify (shows in app)"}
                            aria-label={`Verify feedback ${row.id}`}
                          />
                        )}
                      </td>
                      <td style={{ ...tdStyle, textAlign: "center" }} onClick={(e) => e.stopPropagation()}>
                        <button
                          type="button"
                          className="sr-btn sr-btn-ghost"
                          title="Edit"
                          aria-label={`Edit feedback ${row.id}`}
                          onClick={() => openEdit(row)}
                          style={{ padding: "0.35rem 0.45rem" }}
                        >
                          <Pencil size={16} />
                        </button>
                      </td>
                      <td style={{ ...tdStyle, textAlign: "center" }} onClick={(e) => e.stopPropagation()}>
                        <button
                          type="button"
                          className="sr-btn sr-btn-ghost"
                          title="Delete"
                          aria-label={`Delete feedback ${row.id}`}
                          disabled={busyId === row.id}
                          onClick={() => removeFeedback(row)}
                          style={{ padding: "0.35rem 0.45rem", color: "#b91c1c" }}
                        >
                          {busyId === row.id ? <Loader2 className="spinner" size={16} /> : <Trash2 size={16} />}
                        </button>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {editOpen && (
        <div
          style={{
            position: "fixed",
            inset: 0,
            background: "rgba(15,23,42,0.45)",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            zIndex: 50,
            padding: 16,
          }}
          onClick={() => !saving && setEditOpen(false)}
        >
          <div
            style={{
              background: "var(--surface, #fff)",
              borderRadius: 12,
              width: "min(560px, 100%)",
              padding: "1.25rem",
              boxShadow: "0 20px 40px rgba(0,0,0,0.18)",
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 12 }}>
              <h2 style={{ margin: 0, fontSize: "1.1rem" }}>Edit feedback #{editRow?.id}</h2>
              <button type="button" className="sr-btn sr-btn-ghost" onClick={() => setEditOpen(false)} aria-label="Close">
                <X size={18} />
              </button>
            </div>
            <label style={{ display: "block", marginBottom: 12, fontSize: "0.875rem" }}>
              Subject
              <input style={inputStyle} value={editSubject} onChange={(e) => setEditSubject(e.target.value)} />
            </label>
            <label style={{ display: "block", marginBottom: 12, fontSize: "0.875rem" }}>
              Message
              <textarea
                style={{ ...inputStyle, minHeight: 120, resize: "vertical" }}
                value={editMessage}
                onChange={(e) => setEditMessage(e.target.value)}
              />
            </label>
            <label style={{ display: "block", marginBottom: 12, fontSize: "0.875rem" }}>
              Menu
              <input style={inputStyle} value={editMenu} onChange={(e) => setEditMenu(e.target.value)} />
            </label>
            <label style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 16, fontSize: "0.875rem" }}>
              <input type="checkbox" checked={editVerified} onChange={(e) => setEditVerified(e.target.checked)} />
              Verified (show in app)
            </label>
            <div style={{ display: "flex", justifyContent: "flex-end", gap: 8 }}>
              <button type="button" className="sr-btn sr-btn-ghost" disabled={saving} onClick={() => setEditOpen(false)}>
                Cancel
              </button>
              <button type="button" className="sr-btn" disabled={saving} onClick={saveEdit}>
                {saving ? <Loader2 className="spinner" size={16} /> : "Save"}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

const thStyle = {
  padding: "0.75rem 1rem",
  textAlign: "left",
  borderBottom: "1px solid var(--border)",
};

const tdStyle = {
  padding: "0.75rem 1rem",
  borderBottom: "1px solid var(--border)",
  verticalAlign: "top",
};

export default FeedbackAdmin;
