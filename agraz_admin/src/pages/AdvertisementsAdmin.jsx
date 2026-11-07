import React, { useCallback, useEffect, useMemo, useState } from "react";
import {
  ChevronDown,
  ChevronUp,
  Loader2,
  Megaphone,
  Pencil,
  Plus,
  Power,
  Search,
  Trash2,
  Upload,
  X,
} from "lucide-react";
import {
  listAdminAdvertisements,
  createAdminAdvertisement,
  updateAdminAdvertisement,
  patchAdminAdvertisementStatus,
  reorderAdminAdvertisements,
  deleteAdminAdvertisement,
  getUploadsBaseUrl,
} from "../api/api";
import "./AdvertisementsAdmin.css";

const STATUS_TABS = [
  { id: "all", label: "All" },
  { id: "active", label: "Active" },
  { id: "inactive", label: "Inactive" },
  { id: "scheduled", label: "Scheduled" },
  { id: "expired", label: "Expired" },
];

const LINK_TYPES = [
  { value: "none", label: "None" },
  { value: "external_url", label: "External URL" },
  { value: "in_app_screen", label: "In-app screen" },
];

const IN_APP_SCREENS = [
  { value: "market_report", label: "Market Report" },
  { value: "buy_sell", label: "Buy & Sell" },
  { value: "services", label: "Services" },
  { value: "weather", label: "Weather" },
  { value: "income-expense", label: "Income & Expense" },
  { value: "organizations", label: "Organizations" },
  { value: "labour", label: "Labour" },
  { value: "work-entry", label: "Work Entry" },
  { value: "daily-log", label: "Daily Log" },
];

const emptyForm = () => ({
  title: "",
  subtitle: "",
  tag: "",
  link_type: "none",
  link_value: "",
  start_date: "",
  end_date: "",
  is_active: true,
  imageFile: null,
  imagePreview: "",
  image_url: "",
});

function previewURL(imageUrl) {
  if (!imageUrl) return "";
  if (imageUrl.startsWith("blob:") || imageUrl.startsWith("http")) return imageUrl;
  const base = getUploadsBaseUrl();
  return `${base}${imageUrl.startsWith("/") ? "" : "/"}${imageUrl}`;
}

function statusBadgeClass(status) {
  switch (status) {
    case "active":
      return "ad-badge ad-badge--active";
    case "inactive":
      return "ad-badge ad-badge--inactive";
    case "scheduled":
      return "ad-badge ad-badge--scheduled";
    case "expired":
      return "ad-badge ad-badge--expired";
    default:
      return "ad-badge";
  }
}

function toDateInput(v) {
  if (!v) return "";
  const d = new Date(v);
  if (Number.isNaN(d.getTime())) return String(v).slice(0, 10);
  return d.toISOString().slice(0, 10);
}

const AdvertisementsAdmin = () => {
  const [loading, setLoading] = useState(true);
  const [rows, setRows] = useState([]);
  const [error, setError] = useState("");
  const [toast, setToast] = useState("");
  const [status, setStatus] = useState("all");
  const [q, setQ] = useState("");
  const [saving, setSaving] = useState(false);
  const [modalOpen, setModalOpen] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [form, setForm] = useState(emptyForm());
  const [formError, setFormError] = useState("");

  const showToast = (msg) => {
    setToast(msg);
    window.setTimeout(() => setToast(""), 2800);
  };

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const res = await listAdminAdvertisements({
        status: status === "all" ? undefined : status,
        q: q.trim() || undefined,
        limit: 100,
      });
      setRows(res?.data || []);
    } catch (e) {
      setError(e?.response?.data?.error || e?.message || "Failed to load");
      setRows([]);
    } finally {
      setLoading(false);
    }
  }, [status, q]);

  useEffect(() => {
    load();
  }, [load]);

  const openCreate = () => {
    setEditingId(null);
    setForm(emptyForm());
    setFormError("");
    setModalOpen(true);
  };

  const openEdit = (row) => {
    setEditingId(row.id);
    setForm({
      title: row.title || "",
      subtitle: row.subtitle || "",
      tag: row.tag || "",
      link_type: row.link_type || "none",
      link_value: row.link_value || "",
      start_date: toDateInput(row.start_date),
      end_date: toDateInput(row.end_date),
      is_active: !!row.is_active,
      imageFile: null,
      imagePreview: previewURL(row.image_url),
      image_url: row.image_url || "",
    });
    setFormError("");
    setModalOpen(true);
  };

  const onPickImage = (file) => {
    if (!file) return;
    const okType = ["image/jpeg", "image/png", "image/webp"].includes(file.type);
    if (!okType) {
      setFormError("Only JPG, PNG and WebP are allowed");
      return;
    }
    if (file.size > 2 * 1024 * 1024) {
      setFormError("Image must be 2 MB or smaller");
      return;
    }
    setFormError("");
    setForm((f) => {
      if (f.imagePreview?.startsWith("blob:")) {
        try {
          URL.revokeObjectURL(f.imagePreview);
        } catch {
          /* ignore */
        }
      }
      return {
        ...f,
        imageFile: file,
        imagePreview: URL.createObjectURL(file),
        // Keep previous image_url only as fallback until save; new file takes priority.
        image_url: f.image_url,
      };
    });
  };

  const clearImage = () => {
    setFormError("");
    setForm((f) => {
      if (f.imagePreview?.startsWith("blob:")) {
        try {
          URL.revokeObjectURL(f.imagePreview);
        } catch {
          /* ignore */
        }
      }
      return {
        ...f,
        imageFile: null,
        imagePreview: "",
        image_url: "",
      };
    });
  };

  const validateForm = () => {
    const title = form.title.trim();
    if (!title) return "Title is required";
    if (title.length > 80) return "Title max length is 80";
    if (form.subtitle.trim().length > 120) return "Subtitle max length is 120";
    if (!form.imageFile && !form.image_url) return "Image is required — remove then upload a new one, or keep the current image";
    if (form.link_type === "external_url") {
      if (!form.link_value.trim().toLowerCase().startsWith("https://")) {
        return "External URL must start with https://";
      }
    }
    if (form.link_type === "in_app_screen" && !form.link_value.trim()) {
      return "Select an in-app screen";
    }
    return "";
  };

  const buildFormData = () => {
    const fd = new FormData();
    fd.append("title", form.title.trim());
    fd.append("subtitle", form.subtitle.trim());
    fd.append("tag", form.tag.trim());
    fd.append("link_type", form.link_type);
    if (form.link_type !== "none") {
      fd.append("link_value", form.link_value.trim());
    } else {
      fd.append("link_value", "");
    }
    if (form.start_date) fd.append("start_date", form.start_date);
    if (form.end_date) fd.append("end_date", form.end_date);
    fd.append("is_active", form.is_active ? "true" : "false");
    if (form.imageFile) fd.append("image", form.imageFile);
    else if (form.image_url) fd.append("image_url", form.image_url);
    return fd;
  };

  const saveForm = async (e) => {
    e?.preventDefault?.();
    const err = validateForm();
    if (err) {
      setFormError(err);
      return;
    }
    setSaving(true);
    setFormError("");
    try {
      const fd = buildFormData();
      if (editingId) {
        await updateAdminAdvertisement(editingId, fd);
        showToast("Advertisement updated");
      } else {
        await createAdminAdvertisement(fd);
        showToast("Advertisement created");
      }
      setModalOpen(false);
      await load();
    } catch (err2) {
      setFormError(err2?.response?.data?.error || err2?.message || "Save failed");
    } finally {
      setSaving(false);
    }
  };

  const toggleStatus = async (row) => {
    setError("");
    try {
      await patchAdminAdvertisementStatus(row.id, !row.is_active);
      showToast(row.is_active ? "Deactivated" : "Activated");
      await load();
    } catch (e) {
      setError(e?.response?.data?.error || e?.message || "Status update failed");
    }
  };

  const removeRow = async (row) => {
    if (!window.confirm(`Delete advertisement "${row.title}"?`)) return;
    setError("");
    try {
      await deleteAdminAdvertisement(row.id);
      showToast("Deleted");
      await load();
    } catch (e) {
      setError(e?.response?.data?.error || e?.message || "Delete failed");
    }
  };

  const moveRow = async (index, dir) => {
    const j = index + dir;
    if (j < 0 || j >= rows.length) return;
    const next = [...rows];
    const t = next[index];
    next[index] = next[j];
    next[j] = t;
    setRows(next);
    try {
      await reorderAdminAdvertisements(next.map((r) => r.id));
      showToast("Order saved");
      await load();
    } catch (e) {
      setError(e?.response?.data?.error || e?.message || "Reorder failed");
      await load();
    }
  };

  const livePreview = useMemo(
    () => ({
      title: form.title.trim() || "Smart Farming, Simplified",
      subtitle: form.subtitle.trim() || "Agriculture ERP for modern farms",
      tag: form.tag.trim() || "AD",
      image: form.imagePreview || "",
    }),
    [form]
  );

  return (
    <div className="ad-admin">
      <header className="ad-admin__head">
        <div className="title-area">
          <div className="header-icon" aria-hidden>
            <Megaphone size={22} />
          </div>
          <div>
            <h1>Advertisements</h1>
            <p>Manage the mobile home slider. Create images at <strong>1170×658</strong> (max 2 MB, JPG/PNG/WebP) so they fill with no gaps. Max 10 active ads.</p>
          </div>
        </div>
        <button type="button" className="primary-btn" onClick={openCreate}>
          <Plus size={16} /> New advertisement
        </button>
      </header>

      {toast ? <div className="ad-admin__toast" role="status">{toast}</div> : null}
      {error ? (
        <div className="ad-admin__err" role="alert">
          {error}
        </div>
      ) : null}

      <div className="ad-admin__toolbar">
        <div className="ad-admin__tabs" role="tablist">
          {STATUS_TABS.map((t) => (
            <button
              key={t.id}
              type="button"
              role="tab"
              aria-selected={status === t.id}
              className={status === t.id ? "is-active" : ""}
              onClick={() => setStatus(t.id)}
            >
              {t.label}
            </button>
          ))}
        </div>
        <label className="ad-admin__search">
          <Search size={16} aria-hidden />
          <input
            type="search"
            placeholder="Search title, tag…"
            value={q}
            onChange={(e) => setQ(e.target.value)}
          />
        </label>
      </div>

      {loading ? (
        <div className="ad-admin__center">
          <Loader2 className="spin" size={28} />
          <p>Loading…</p>
        </div>
      ) : rows.length === 0 ? (
        <p className="ad-admin__empty">No advertisements match this filter.</p>
      ) : (
        <div className="ad-admin__table-wrap">
          <table className="ad-admin__table">
            <thead>
              <tr>
                <th>Order</th>
                <th>Preview</th>
                <th>Title</th>
                <th>Status</th>
                <th>Dates</th>
                <th>Stats</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((row, index) => (
                <tr key={row.id}>
                  <td>
                    <div className="ad-admin__reorder">
                      <button type="button" className="icon-btn" aria-label="Move up" disabled={index === 0} onClick={() => moveRow(index, -1)}>
                        <ChevronUp size={16} />
                      </button>
                      <button type="button" className="icon-btn" aria-label="Move down" disabled={index === rows.length - 1} onClick={() => moveRow(index, 1)}>
                        <ChevronDown size={16} />
                      </button>
                      <span>{row.sort_order}</span>
                    </div>
                  </td>
                  <td>
                    <div
                      className="ad-admin__thumb"
                      style={{ backgroundImage: `url(${previewURL(row.image_url)})` }}
                    />
                  </td>
                  <td>
                    <strong>{row.title}</strong>
                    {row.tag ? <div className="ad-admin__muted">{row.tag}</div> : null}
                  </td>
                  <td>
                    <span className={statusBadgeClass(row.status)}>{row.status}</span>
                  </td>
                  <td className="ad-admin__muted">
                    {row.start_date || row.end_date
                      ? `${toDateInput(row.start_date) || "—"} → ${toDateInput(row.end_date) || "—"}`
                      : "Always"}
                  </td>
                  <td className="ad-admin__muted">
                    {row.impressions ?? 0} imp · {row.clicks ?? 0} clicks
                  </td>
                  <td>
                    <div className="ad-admin__actions">
                      <button type="button" className="secondary-btn" onClick={() => openEdit(row)}>
                        <Pencil size={14} /> Edit
                      </button>
                      <button type="button" className="secondary-btn" onClick={() => toggleStatus(row)}>
                        <Power size={14} /> {row.is_active ? "Deactivate" : "Activate"}
                      </button>
                      <button type="button" className="danger-btn" onClick={() => removeRow(row)}>
                        <Trash2 size={14} /> Delete
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {modalOpen ? (
        <div className="modal-overlay" role="dialog" aria-modal="true">
          <div className="modal-content ad-modal">
            <div className="ad-modal__head">
              <h2>{editingId ? "Edit advertisement" : "New advertisement"}</h2>
              <button type="button" className="icon-btn" aria-label="Close" onClick={() => setModalOpen(false)}>
                <X size={18} />
              </button>
            </div>
            <form className="ad-modal__grid" onSubmit={saveForm}>
              <div className="ad-modal__fields">
                {form.imagePreview ? (
                  <div className="ad-image-editor">
                    <div
                      className="ad-image-editor__thumb"
                      style={{ backgroundImage: `url(${form.imagePreview})` }}
                      role="img"
                      aria-label="Current advertisement image"
                    />
                    <div className="ad-image-editor__meta">
                      <strong>{form.imageFile ? "New image selected" : "Current image"}</strong>
                      <span className="ad-admin__muted">
                        {form.imageFile
                          ? "Will replace the previous image on save"
                          : "Remove this image, then upload a new one"}
                      </span>
                      <div className="ad-image-editor__actions">
                        <label className="secondary-btn ad-image-editor__file-btn">
                          <input
                            type="file"
                            accept="image/jpeg,image/png,image/webp"
                            hidden
                            onChange={(e) => {
                              onPickImage(e.target.files?.[0]);
                              e.target.value = "";
                            }}
                          />
                          <Upload size={14} /> Replace image
                        </label>
                        <button
                          type="button"
                          className="danger-btn"
                          onClick={clearImage}
                        >
                          <Trash2 size={14} /> Remove image
                        </button>
                      </div>
                    </div>
                  </div>
                ) : (
                  <label
                    className="ad-drop"
                    onDragOver={(e) => e.preventDefault()}
                    onDrop={(e) => {
                      e.preventDefault();
                      onPickImage(e.dataTransfer.files?.[0]);
                    }}
                  >
                    <input
                      type="file"
                      accept="image/jpeg,image/png,image/webp"
                      hidden
                      onChange={(e) => {
                        onPickImage(e.target.files?.[0]);
                        e.target.value = "";
                      }}
                    />
                    <Upload size={18} />
                    <span>{editingId ? "Upload a new image" : "Drop image or click to upload"}</span>
                    <small>Required size 1170×658 · max 2 MB · JPG/PNG/WebP</small>
                  </label>
                )}

                <label>
                  Title *
                  <input
                    maxLength={80}
                    value={form.title}
                    onChange={(e) => setForm((f) => ({ ...f, title: e.target.value }))}
                    required
                  />
                </label>
                <label>
                  Subtitle
                  <input
                    maxLength={120}
                    value={form.subtitle}
                    onChange={(e) => setForm((f) => ({ ...f, subtitle: e.target.value }))}
                  />
                </label>
                <label>
                  Tag
                  <input
                    maxLength={32}
                    placeholder="AD / SERVICES"
                    value={form.tag}
                    onChange={(e) => setForm((f) => ({ ...f, tag: e.target.value }))}
                  />
                </label>
                <label>
                  Link type
                  <select
                    value={form.link_type}
                    onChange={(e) => setForm((f) => ({ ...f, link_type: e.target.value, link_value: "" }))}
                  >
                    {LINK_TYPES.map((o) => (
                      <option key={o.value} value={o.value}>{o.label}</option>
                    ))}
                  </select>
                </label>
                {form.link_type === "external_url" ? (
                  <label>
                    HTTPS URL
                    <input
                      type="url"
                      placeholder="https://…"
                      value={form.link_value}
                      onChange={(e) => setForm((f) => ({ ...f, link_value: e.target.value }))}
                    />
                  </label>
                ) : null}
                {form.link_type === "in_app_screen" ? (
                  <label>
                    In-app screen
                    <select
                      value={form.link_value}
                      onChange={(e) => setForm((f) => ({ ...f, link_value: e.target.value }))}
                    >
                      <option value="">Select…</option>
                      {IN_APP_SCREENS.map((o) => (
                        <option key={o.value} value={o.value}>{o.label}</option>
                      ))}
                    </select>
                  </label>
                ) : null}
                <div className="ad-modal__dates">
                  <label>
                    Start date
                    <input
                      type="date"
                      value={form.start_date}
                      onChange={(e) => setForm((f) => ({ ...f, start_date: e.target.value }))}
                    />
                  </label>
                  <label>
                    End date
                    <input
                      type="date"
                      value={form.end_date}
                      onChange={(e) => setForm((f) => ({ ...f, end_date: e.target.value }))}
                    />
                  </label>
                </div>
                <label className="switch-label">
                  <input
                    type="checkbox"
                    checked={form.is_active}
                    onChange={(e) => setForm((f) => ({ ...f, is_active: e.target.checked }))}
                  />
                  Active
                </label>
                {formError ? <div className="ad-admin__err" role="alert">{formError}</div> : null}
                <div className="ad-modal__foot">
                  <button type="button" className="secondary-btn" onClick={() => setModalOpen(false)}>Cancel</button>
                  <button type="submit" className="primary-btn" disabled={saving}>
                    {saving ? <Loader2 className="spin" size={16} /> : null}
                    {editingId ? "Save changes" : "Create"}
                  </button>
                </div>
              </div>
              <div className="ad-modal__preview">
                <h3>Mobile slider preview</h3>
                <div
                  className="ad-slide-preview"
                  style={livePreview.image ? { backgroundImage: `url(${livePreview.image})` } : undefined}
                >
                  <div className="ad-slide-preview__scrim" />
                  {livePreview.tag ? <span className="ad-slide-preview__tag">{livePreview.tag}</span> : null}
                  <div className="ad-slide-preview__text">
                    <strong>{livePreview.title}</strong>
                    <span>{livePreview.subtitle}</span>
                  </div>
                </div>
                <p className="ad-admin__muted">App slider is 1170×658. Upload that size for a perfect fill.</p>
              </div>
            </form>
          </div>
        </div>
      ) : null}
    </div>
  );
};

export default AdvertisementsAdmin;
