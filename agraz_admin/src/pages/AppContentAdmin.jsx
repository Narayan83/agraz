import React, { useCallback, useEffect, useState } from "react";
import { FileText, Loader2, Plus, Pencil, Trash2 } from "lucide-react";
import {
  getAdminAppContents,
  createAdminAppContent,
  updateAdminAppContent,
  deleteAdminAppContent,
} from "../api/api";
import "./ServiceRegistrations.css";

const emptyForm = {
  menu_key: "",
  title: "",
  body: "",
  locale: "en",
  is_active: true,
};

const AppContentAdmin = () => {
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [form, setForm] = useState(emptyForm);
  const [editingId, setEditingId] = useState(null);
  const [saving, setSaving] = useState(false);
  const [showForm, setShowForm] = useState(false);

  const fetchRows = useCallback(async () => {
    setLoading(true);
    try {
      const data = await getAdminAppContents();
      setRows(data.data || data || []);
    } catch (e) {
      console.error(e);
      setRows([]);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchRows();
  }, [fetchRows]);

  const openCreate = () => {
    setEditingId(null);
    setForm(emptyForm);
    setShowForm(true);
  };

  const openEdit = (row) => {
    setEditingId(row.id);
    setForm({
      menu_key: row.menu_key || "",
      title: row.title || "",
      body: row.body || "",
      locale: row.locale || "en",
      is_active: row.is_active !== false,
    });
    setShowForm(true);
  };

  const onSave = async (e) => {
    e.preventDefault();
    setSaving(true);
    try {
      if (editingId) {
        await updateAdminAppContent(editingId, form);
      } else {
        await createAdminAppContent(form);
      }
      setShowForm(false);
      await fetchRows();
    } catch (err) {
      console.error(err);
      alert(err?.response?.data?.error || err.message || "Save failed");
    } finally {
      setSaving(false);
    }
  };

  const onDelete = async (id) => {
    if (!window.confirm("Delete this content?")) return;
    try {
      await deleteAdminAppContent(id);
      await fetchRows();
    } catch (err) {
      console.error(err);
      alert(err?.response?.data?.error || err.message || "Delete failed");
    }
  };

  return (
    <div className="sr-page">
      <div className="sr-header">
        <div>
          <h1>
            <FileText size={22} style={{ marginRight: 8, verticalAlign: -4 }} />
            App Contents
          </h1>
          <p>CMS copy for app menus</p>
        </div>
        <button type="button" className="sr-btn primary" onClick={openCreate}>
          <Plus size={16} /> Add
        </button>
      </div>

      {showForm && (
        <form className="sr-card" onSubmit={onSave} style={{ marginBottom: 16 }}>
          <div className="mr-filter-row">
            <label>
              Menu key
              <input
                required
                value={form.menu_key}
                onChange={(e) => setForm((f) => ({ ...f, menu_key: e.target.value }))}
              />
            </label>
            <label>
              Locale
              <input
                value={form.locale}
                onChange={(e) => setForm((f) => ({ ...f, locale: e.target.value }))}
              />
            </label>
            <label>
              Active
              <select
                value={form.is_active ? "true" : "false"}
                onChange={(e) =>
                  setForm((f) => ({ ...f, is_active: e.target.value === "true" }))
                }
              >
                <option value="true">Yes</option>
                <option value="false">No</option>
              </select>
            </label>
          </div>
          <label style={{ display: "block", marginTop: 8 }}>
            Title
            <input
              style={{ width: "100%" }}
              value={form.title}
              onChange={(e) => setForm((f) => ({ ...f, title: e.target.value }))}
            />
          </label>
          <label style={{ display: "block", marginTop: 8 }}>
            Body
            <textarea
              rows={5}
              style={{ width: "100%" }}
              value={form.body}
              onChange={(e) => setForm((f) => ({ ...f, body: e.target.value }))}
            />
          </label>
          <div style={{ marginTop: 12, display: "flex", gap: 8 }}>
            <button type="submit" className="sr-btn primary" disabled={saving}>
              {saving ? "Saving…" : "Save"}
            </button>
            <button
              type="button"
              className="sr-btn"
              onClick={() => setShowForm(false)}
            >
              Cancel
            </button>
          </div>
        </form>
      )}

      {loading ? (
        <div className="sr-loading">
          <Loader2 className="spin" size={28} />
        </div>
      ) : (
        <div className="sr-table-wrap">
          <table className="sr-table">
            <thead>
              <tr>
                <th>Key</th>
                <th>Title</th>
                <th>Locale</th>
                <th>Active</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {rows.length === 0 && (
                <tr>
                  <td colSpan={5} style={{ textAlign: "center" }}>
                    No contents
                  </td>
                </tr>
              )}
              {rows.map((r) => (
                <tr key={r.id}>
                  <td>{r.menu_key}</td>
                  <td>{r.title}</td>
                  <td>{r.locale || "en"}</td>
                  <td>{r.is_active ? "Yes" : "No"}</td>
                  <td>
                    <button type="button" className="sr-btn" onClick={() => openEdit(r)}>
                      <Pencil size={14} />
                    </button>{" "}
                    <button type="button" className="sr-btn" onClick={() => onDelete(r.id)}>
                      <Trash2 size={14} />
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
};

export default AppContentAdmin;
