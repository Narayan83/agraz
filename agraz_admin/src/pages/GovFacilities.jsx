import React, { useState, useEffect, useCallback } from "react";
import {
  Landmark,
  Plus,
  Edit,
  Trash2,
  X,
  Loader2,
  ChevronLeft,
  ChevronRight,
  Upload,
  Building2,
  Leaf,
} from "lucide-react";
import {
  getAdminGovDepartments,
  createAdminGovDepartment,
  updateAdminGovDepartment,
  deleteAdminGovDepartment,
  getAdminGovCrops,
  createAdminGovCrop,
  updateAdminGovCrop,
  deleteAdminGovCrop,
  getAdminGovFacilities,
  createAdminGovFacility,
  updateAdminGovFacility,
  deleteAdminGovFacility,
  uploadGovFacilityApplication,
  getUploadsBaseUrl,
} from "../api/api";
import "./ServiceRegistrations.css";

const limit = 10;

const CATEGORIES = [
  { value: "loans", label: "Loans" },
  { value: "insurance", label: "Insurance" },
  { value: "grants", label: "Grants" },
];

function emptyFacilityForm() {
  return {
    department_id: "",
    crop_id: "",
    category: "loans",
    title: "",
    description: "",
    place: "",
    contact_person: "",
    email: "",
    website: "",
    phone: "",
    application_url: "",
    valid_from: "",
    valid_to: "",
    notes: "",
    status: "active",
    sort_order: 0,
  };
}

function dateInputValue(v) {
  if (!v) return "";
  const s = String(v);
  if (s.length >= 10) return s.slice(0, 10);
  return "";
}

function facilityToForm(row) {
  return {
    department_id: row.department_id ? String(row.department_id) : "",
    crop_id: row.crop_id ? String(row.crop_id) : "",
    category: row.category || "loans",
    title: row.title || "",
    description: row.description || "",
    place: row.place || "",
    contact_person: row.contact_person || "",
    email: row.email || "",
    website: row.website || "",
    phone: row.phone || "",
    application_url: row.application_url || "",
    valid_from: dateInputValue(row.valid_from),
    valid_to: dateInputValue(row.valid_to),
    notes: row.notes || "",
    status: row.status || "active",
    sort_order: row.sort_order ?? 0,
  };
}

function categoryLabel(v) {
  return CATEGORIES.find((c) => c.value === v)?.label || v;
}

const GovFacilities = () => {
  const [tab, setTab] = useState("facilities");

  const [departments, setDepartments] = useState([]);
  const [crops, setCrops] = useState([]);

  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [filterDept, setFilterDept] = useState("");
  const [filterCrop, setFilterCrop] = useState("");
  const [filterCat, setFilterCat] = useState("");
  const [search, setSearch] = useState("");
  const [searchDebounced, setSearchDebounced] = useState("");

  const [modalOpen, setModalOpen] = useState(false);
  const [selected, setSelected] = useState(null);
  const [form, setForm] = useState(emptyFacilityForm);
  const [saving, setSaving] = useState(false);
  const [uploading, setUploading] = useState(false);

  const [metaModal, setMetaModal] = useState(null); // { type: 'dept'|'crop', row? }
  const [metaForm, setMetaForm] = useState({ name: "", status: "active", sort_order: 0 });
  const [metaSaving, setMetaSaving] = useState(false);

  useEffect(() => {
    const t = setTimeout(() => setSearchDebounced(search.trim()), 350);
    return () => clearTimeout(t);
  }, [search]);

  const loadLookups = useCallback(async () => {
    try {
      const [d, c] = await Promise.all([getAdminGovDepartments(), getAdminGovCrops()]);
      setDepartments(d.data || []);
      setCrops(c.data || []);
    } catch (e) {
      console.error(e);
    }
  }, []);

  const fetchFacilities = useCallback(async () => {
    setLoading(true);
    try {
      const params = { page, limit };
      if (filterDept) params.department_id = filterDept;
      if (filterCrop) params.crop_id = filterCrop;
      if (filterCat) params.category = filterCat;
      if (searchDebounced) params.q = searchDebounced;
      const data = await getAdminGovFacilities(params);
      setRows(data.data || []);
      setTotal(data.total ?? 0);
    } catch (e) {
      console.error(e);
      setRows([]);
    } finally {
      setLoading(false);
    }
  }, [page, filterDept, filterCrop, filterCat, searchDebounced]);

  useEffect(() => {
    loadLookups();
  }, [loadLookups]);

  useEffect(() => {
    if (tab === "facilities") fetchFacilities();
  }, [tab, fetchFacilities]);

  const totalPages = Math.max(1, Math.ceil(total / limit) || 1);

  const openCreate = () => {
    setSelected(null);
    setForm(emptyFacilityForm());
    setModalOpen(true);
  };

  const openEdit = (row) => {
    setSelected(row);
    setForm(facilityToForm(row));
    setModalOpen(true);
  };

  const closeModal = () => {
    setModalOpen(false);
    setSelected(null);
  };

  const handleFormChange = (e) => {
    const { name, value } = e.target;
    setForm((prev) => ({ ...prev, [name]: value }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSaving(true);
    try {
      const payload = {
        ...form,
        department_id: Number(form.department_id),
        crop_id: Number(form.crop_id),
        sort_order: Number(form.sort_order) || 0,
      };
      if (selected) {
        await updateAdminGovFacility(selected.id, payload);
      } else {
        await createAdminGovFacility(payload);
      }
      closeModal();
      fetchFacilities();
    } catch (err) {
      alert(err.response?.data?.error || err.message || "Save failed");
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async (row) => {
    if (!window.confirm(`Delete facility "${row.title}"?`)) return;
    try {
      await deleteAdminGovFacility(row.id);
      fetchFacilities();
    } catch (err) {
      alert(err.response?.data?.error || err.message || "Delete failed");
    }
  };

  const handleUpload = async (e) => {
    const file = e.target.files?.[0];
    e.target.value = "";
    if (!file) return;
    setUploading(true);
    try {
      const res = await uploadGovFacilityApplication(file);
      setForm((prev) => ({ ...prev, application_url: res.url || "" }));
    } catch (err) {
      alert(err.response?.data?.error || err.message || "Upload failed");
    } finally {
      setUploading(false);
    }
  };

  const openMeta = (type, row = null) => {
    setMetaModal({ type, row });
    setMetaForm({
      name: row?.name || "",
      status: row?.status || "active",
      sort_order: row?.sort_order ?? 0,
    });
  };

  const saveMeta = async (e) => {
    e.preventDefault();
    if (!metaModal) return;
    setMetaSaving(true);
    try {
      const payload = {
        name: metaForm.name.trim(),
        status: metaForm.status,
        sort_order: Number(metaForm.sort_order) || 0,
      };
      if (metaModal.type === "dept") {
        if (metaModal.row) await updateAdminGovDepartment(metaModal.row.id, payload);
        else await createAdminGovDepartment(payload);
      } else {
        if (metaModal.row) await updateAdminGovCrop(metaModal.row.id, payload);
        else await createAdminGovCrop(payload);
      }
      setMetaModal(null);
      await loadLookups();
    } catch (err) {
      alert(err.response?.data?.error || err.message || "Save failed");
    } finally {
      setMetaSaving(false);
    }
  };

  const deleteMeta = async (type, row) => {
    if (!window.confirm(`Delete "${row.name}"?`)) return;
    try {
      if (type === "dept") await deleteAdminGovDepartment(row.id);
      else await deleteAdminGovCrop(row.id);
      await loadLookups();
    } catch (err) {
      alert(err.response?.data?.error || err.message || "Delete failed");
    }
  };

  const appUrlFull = form.application_url
    ? form.application_url.startsWith("http")
      ? form.application_url
      : `${getUploadsBaseUrl()}${form.application_url}`
    : "";

  return (
    <div className="service-reg-page">
      <div className="sr-toolbar">
        <div>
          <h2 style={{ margin: 0, display: "flex", alignItems: "center", gap: 10 }}>
            <Landmark size={22} /> Government Facilities
          </h2>
          <p style={{ margin: "0.35rem 0 0", color: "var(--text-muted)", fontSize: "0.875rem" }}>
            Manage departments, crops, and schemes (loans / insurance / grants)
          </p>
        </div>
        {tab === "facilities" && (
          <button type="button" className="sr-btn sr-btn-primary" onClick={openCreate}>
            <Plus size={16} /> Add facility
          </button>
        )}
        {tab === "departments" && (
          <button type="button" className="sr-btn sr-btn-primary" onClick={() => openMeta("dept")}>
            <Plus size={16} /> Add department
          </button>
        )}
        {tab === "crops" && (
          <button type="button" className="sr-btn sr-btn-primary" onClick={() => openMeta("crop")}>
            <Plus size={16} /> Add crop
          </button>
        )}
      </div>

      <div className="sr-filter-tabs">
        {[
          { id: "facilities", label: "Facilities" },
          { id: "departments", label: "Departments" },
          { id: "crops", label: "Crops" },
        ].map((t) => (
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

      {tab === "facilities" && (
        <>
          <div className="sr-toolbar" style={{ marginTop: "0.5rem" }}>
            <div style={{ display: "flex", flexWrap: "wrap", gap: "0.65rem" }}>
              <select
                value={filterDept}
                onChange={(e) => {
                  setFilterDept(e.target.value);
                  setPage(1);
                }}
                style={{ padding: "0.5rem 0.75rem", borderRadius: 8, border: "1px solid var(--border)" }}
              >
                <option value="">All departments</option>
                {departments.map((d) => (
                  <option key={d.id} value={d.id}>
                    {d.name}
                  </option>
                ))}
              </select>
              <select
                value={filterCrop}
                onChange={(e) => {
                  setFilterCrop(e.target.value);
                  setPage(1);
                }}
                style={{ padding: "0.5rem 0.75rem", borderRadius: 8, border: "1px solid var(--border)" }}
              >
                <option value="">All crops</option>
                {crops.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.name}
                  </option>
                ))}
              </select>
              <select
                value={filterCat}
                onChange={(e) => {
                  setFilterCat(e.target.value);
                  setPage(1);
                }}
                style={{ padding: "0.5rem 0.75rem", borderRadius: 8, border: "1px solid var(--border)" }}
              >
                <option value="">All categories</option>
                {CATEGORIES.map((c) => (
                  <option key={c.value} value={c.value}>
                    {c.label}
                  </option>
                ))}
              </select>
            </div>
            <div className="sr-search">
              <input
                placeholder="Search title, place…"
                value={search}
                onChange={(e) => {
                  setSearch(e.target.value);
                  setPage(1);
                }}
              />
            </div>
          </div>

          <div className="sr-list-card">
            <div className="sr-list-header">
              <span className="sr-count">
                {total} facilit{total !== 1 ? "ies" : "y"}
              </span>
              <div className="sr-pagination">
                <span>
                  Page {page} / {totalPages}
                </span>
                <div className="sr-page-btns">
                  <button type="button" disabled={page <= 1} onClick={() => setPage((p) => Math.max(1, p - 1))}>
                    <ChevronLeft size={18} />
                  </button>
                  <button type="button" disabled={page >= totalPages} onClick={() => setPage((p) => p + 1)}>
                    <ChevronRight size={18} />
                  </button>
                </div>
              </div>
            </div>

            {loading ? (
              <div className="sr-loader">
                <Loader2 className="spinner" size={36} />
                <p>Loading…</p>
              </div>
            ) : rows.length === 0 ? (
              <div className="sr-empty">No facilities yet. Add one to get started.</div>
            ) : (
              <div className="sr-grid">
                {rows.map((row) => (
                  <article key={row.id} className="sr-card">
                    <div className="sr-card-top">
                      <span className="sr-id">#{row.id}</span>
                      <span className="sr-status-pill approved" style={{ textTransform: "none" }}>
                        {categoryLabel(row.category)}
                      </span>
                    </div>
                    <h3 className="sr-card-title">{row.title}</h3>
                    <p className="sr-card-sub">
                      {row.department?.name || "—"} · {row.crop?.name || "—"}
                    </p>
                    <dl className="sr-dl">
                      <div>
                        <dt>Place</dt>
                        <dd>{row.place || "—"}</dd>
                      </div>
                      <div>
                        <dt>Contact</dt>
                        <dd>{row.contact_person || "—"}</dd>
                      </div>
                      <div>
                        <dt>Phone</dt>
                        <dd>{row.phone || "—"}</dd>
                      </div>
                      <div>
                        <dt>Availability</dt>
                        <dd>
                          {dateInputValue(row.valid_from) || "—"} → {dateInputValue(row.valid_to) || "—"}
                        </dd>
                      </div>
                    </dl>
                    <div className="sr-card-actions">
                      <button type="button" className="sr-btn sr-btn-primary" onClick={() => openEdit(row)}>
                        <Edit size={16} /> Edit
                      </button>
                      <button type="button" className="sr-btn sr-btn-danger" onClick={() => handleDelete(row)}>
                        <Trash2 size={16} />
                      </button>
                    </div>
                  </article>
                ))}
              </div>
            )}
          </div>
        </>
      )}

      {tab === "departments" && (
        <div className="sr-list-card">
          <div className="sr-list-header">
            <span className="sr-count">{departments.length} department(s)</span>
          </div>
          {departments.length === 0 ? (
            <div className="sr-empty">No departments yet.</div>
          ) : (
            <div className="sr-grid">
              {departments.map((row) => (
                <article key={row.id} className="sr-card">
                  <div className="sr-card-top">
                    <Building2 size={18} />
                    <span className={`sr-status-pill ${row.status === "active" ? "approved" : ""}`}>
                      {row.status}
                    </span>
                  </div>
                  <h3 className="sr-card-title">{row.name}</h3>
                  <p className="sr-card-sub">slug: {row.slug}</p>
                  <div className="sr-card-actions">
                    <button type="button" className="sr-btn sr-btn-primary" onClick={() => openMeta("dept", row)}>
                      <Edit size={16} /> Edit
                    </button>
                    <button type="button" className="sr-btn sr-btn-danger" onClick={() => deleteMeta("dept", row)}>
                      <Trash2 size={16} />
                    </button>
                  </div>
                </article>
              ))}
            </div>
          )}
        </div>
      )}

      {tab === "crops" && (
        <div className="sr-list-card">
          <div className="sr-list-header">
            <span className="sr-count">{crops.length} crop(s)</span>
          </div>
          {crops.length === 0 ? (
            <div className="sr-empty">No crops yet.</div>
          ) : (
            <div className="sr-grid">
              {crops.map((row) => (
                <article key={row.id} className="sr-card">
                  <div className="sr-card-top">
                    <Leaf size={18} />
                    <span className={`sr-status-pill ${row.status === "active" ? "approved" : ""}`}>
                      {row.status}
                    </span>
                  </div>
                  <h3 className="sr-card-title">{row.name}</h3>
                  <p className="sr-card-sub">slug: {row.slug}</p>
                  <div className="sr-card-actions">
                    <button type="button" className="sr-btn sr-btn-primary" onClick={() => openMeta("crop", row)}>
                      <Edit size={16} /> Edit
                    </button>
                    <button type="button" className="sr-btn sr-btn-danger" onClick={() => deleteMeta("crop", row)}>
                      <Trash2 size={16} />
                    </button>
                  </div>
                </article>
              ))}
            </div>
          )}
        </div>
      )}

      {modalOpen && (
        <div className="modal-overlay" onClick={closeModal}>
          <div className="modal-content sr-modal sr-modal-wide" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header sr-modal-header">
              <h3>{selected ? `Edit facility #${selected.id}` : "New facility"}</h3>
              <button type="button" className="close-btn" onClick={closeModal}>
                <X size={20} />
              </button>
            </div>
            <form onSubmit={handleSubmit} className="sr-form sr-form-compact">
              <section className="sr-form-section">
                <h4>Classification</h4>
                <div className="sr-form-grid sr-form-grid-2">
                  <div className="form-group">
                    <label>Department *</label>
                    <select name="department_id" value={form.department_id} onChange={handleFormChange} required>
                      <option value="">Select…</option>
                      {departments.map((d) => (
                        <option key={d.id} value={d.id}>
                          {d.name}
                        </option>
                      ))}
                    </select>
                  </div>
                  <div className="form-group">
                    <label>Crop *</label>
                    <select name="crop_id" value={form.crop_id} onChange={handleFormChange} required>
                      <option value="">Select…</option>
                      {crops.map((c) => (
                        <option key={c.id} value={c.id}>
                          {c.name}
                        </option>
                      ))}
                    </select>
                  </div>
                  <div className="form-group">
                    <label>Category *</label>
                    <select name="category" value={form.category} onChange={handleFormChange} required>
                      {CATEGORIES.map((c) => (
                        <option key={c.value} value={c.value}>
                          {c.label}
                        </option>
                      ))}
                    </select>
                  </div>
                  <div className="form-group">
                    <label>Status</label>
                    <select name="status" value={form.status} onChange={handleFormChange}>
                      <option value="active">Active</option>
                      <option value="inactive">Inactive</option>
                    </select>
                  </div>
                </div>
              </section>

              <section className="sr-form-section">
                <h4>Details</h4>
                <div className="sr-form-grid sr-form-grid-2">
                  <div className="form-group" style={{ gridColumn: "1 / -1" }}>
                    <label>Title *</label>
                    <input name="title" value={form.title} onChange={handleFormChange} required />
                  </div>
                  <div className="form-group" style={{ gridColumn: "1 / -1" }}>
                    <label>Description</label>
                    <textarea name="description" value={form.description} onChange={handleFormChange} rows={4} />
                  </div>
                  <div className="form-group">
                    <label>Place</label>
                    <input name="place" value={form.place} onChange={handleFormChange} />
                  </div>
                  <div className="form-group">
                    <label>Contact person</label>
                    <input name="contact_person" value={form.contact_person} onChange={handleFormChange} />
                  </div>
                  <div className="form-group">
                    <label>Email</label>
                    <input name="email" type="email" value={form.email} onChange={handleFormChange} />
                  </div>
                  <div className="form-group">
                    <label>Phone</label>
                    <input name="phone" value={form.phone} onChange={handleFormChange} />
                  </div>
                  <div className="form-group" style={{ gridColumn: "1 / -1" }}>
                    <label>Website</label>
                    <input name="website" value={form.website} onChange={handleFormChange} placeholder="https://…" />
                  </div>
                  <div className="form-group">
                    <label>Available from</label>
                    <input name="valid_from" type="date" value={form.valid_from} onChange={handleFormChange} />
                  </div>
                  <div className="form-group">
                    <label>Available to</label>
                    <input name="valid_to" type="date" value={form.valid_to} onChange={handleFormChange} />
                  </div>
                  <div className="form-group" style={{ gridColumn: "1 / -1" }}>
                    <label>Notes</label>
                    <textarea name="notes" value={form.notes} onChange={handleFormChange} rows={3} />
                  </div>
                  <div className="form-group" style={{ gridColumn: "1 / -1" }}>
                    <label>Application form</label>
                    <div style={{ display: "flex", flexWrap: "wrap", gap: 8, alignItems: "center" }}>
                      <label className="sr-btn sr-btn-primary" style={{ cursor: "pointer", margin: 0 }}>
                        <Upload size={16} /> {uploading ? "Uploading…" : "Upload file"}
                        <input type="file" accept=".pdf,.doc,.docx,.jpg,.jpeg,.png" hidden onChange={handleUpload} disabled={uploading} />
                      </label>
                      {form.application_url ? (
                        <a href={appUrlFull} target="_blank" rel="noreferrer" style={{ fontSize: "0.875rem" }}>
                          {form.application_url}
                        </a>
                      ) : (
                        <span style={{ color: "var(--text-muted)", fontSize: "0.875rem" }}>No file uploaded</span>
                      )}
                      {form.application_url ? (
                        <button
                          type="button"
                          className="sr-btn"
                          onClick={() => setForm((p) => ({ ...p, application_url: "" }))}
                        >
                          Clear
                        </button>
                      ) : null}
                    </div>
                    <input
                      name="application_url"
                      value={form.application_url}
                      onChange={handleFormChange}
                      placeholder="Or paste URL /uploads/…"
                      style={{ marginTop: 8 }}
                    />
                  </div>
                  <div className="form-group">
                    <label>Sort order</label>
                    <input name="sort_order" type="number" value={form.sort_order} onChange={handleFormChange} />
                  </div>
                </div>
              </section>

              <div className="sr-form-actions">
                <button type="button" className="sr-btn" onClick={closeModal}>
                  Cancel
                </button>
                <button type="submit" className="sr-btn sr-btn-primary" disabled={saving}>
                  {saving ? <Loader2 className="spinner" size={16} /> : null}
                  {selected ? "Save changes" : "Create"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {metaModal && (
        <div className="modal-overlay" onClick={() => setMetaModal(null)}>
          <div className="modal-content sr-modal" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header sr-modal-header">
              <h3>
                {metaModal.row ? "Edit" : "New"} {metaModal.type === "dept" ? "department" : "crop"}
              </h3>
              <button type="button" className="close-btn" onClick={() => setMetaModal(null)}>
                <X size={20} />
              </button>
            </div>
            <form onSubmit={saveMeta} className="sr-form sr-form-compact">
              <div className="form-group">
                <label>Name *</label>
                <input
                  value={metaForm.name}
                  onChange={(e) => setMetaForm((p) => ({ ...p, name: e.target.value }))}
                  required
                />
              </div>
              <div className="form-group">
                <label>Status</label>
                <select
                  value={metaForm.status}
                  onChange={(e) => setMetaForm((p) => ({ ...p, status: e.target.value }))}
                >
                  <option value="active">Active</option>
                  <option value="inactive">Inactive</option>
                </select>
              </div>
              <div className="form-group">
                <label>Sort order</label>
                <input
                  type="number"
                  value={metaForm.sort_order}
                  onChange={(e) => setMetaForm((p) => ({ ...p, sort_order: e.target.value }))}
                />
              </div>
              <div className="sr-form-actions">
                <button type="button" className="sr-btn" onClick={() => setMetaModal(null)}>
                  Cancel
                </button>
                <button type="submit" className="sr-btn sr-btn-primary" disabled={metaSaving}>
                  {metaSaving ? <Loader2 className="spinner" size={16} /> : null}
                  Save
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

export default GovFacilities;
