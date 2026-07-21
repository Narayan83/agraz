import React, { useState, useEffect, useCallback } from "react";
import {
  ClipboardList,
  Edit,
  Trash2,
  X,
  ChevronLeft,
  ChevronRight,
  Loader2,
  CheckCircle2,
  CircleDashed,
  Smartphone,
  Building2,
  Tag,
  Upload,
  User,
  MapPin,
  Link2,
} from "lucide-react";
import {
  getServiceRegistrations,
  updateServiceRegistration,
  deleteServiceRegistration,
  uploadServiceRegistrationImages,
  removeServiceRegistrationImage,
  getUploadsBaseUrl,
  uploadServiceProviderPhoto,
  uploadCustomServiceImage,
} from "../api/api";
import ServiceRegistrationMapPicker from "../components/ServiceRegistrationMapPicker";
import "./ServiceRegistrations.css";

const limit = 10;

function formatImagePathsForForm(val) {
  if (val == null || val === "") return "[]";
  if (typeof val === "string") {
    try {
      return JSON.stringify(JSON.parse(val), null, 2);
    } catch {
      return val;
    }
  }
  return JSON.stringify(val, null, 2);
}

function parseImagePaths(text) {
  const t = text.trim();
  if (t === "") return [];
  const parsed = JSON.parse(t);
  return parsed;
}

function pathsAsStrings(parsed) {
  if (!Array.isArray(parsed)) return [];
  return parsed.filter((x) => typeof x === "string");
}

function getPreviewPaths(jsonStr) {
  try {
    const p = JSON.parse((jsonStr || "").trim() || "[]");
    return pathsAsStrings(p);
  } catch {
    return [];
  }
}

function normalizeCustomServices(raw) {
  if (!raw) return [];
  if (Array.isArray(raw)) {
    return raw.map((x) => ({
      name: x?.name ?? "",
      image_url: x?.image_url ?? "",
    }));
  }
  if (typeof raw === "string") {
    try {
      const p = JSON.parse(raw);
      return normalizeCustomServices(p);
    } catch {
      return [];
    }
  }
  return [];
}

function emptyForm() {
  return {
    mobile: "",
    secondary_contact: "",
    whatsapp: "",
    name: "",
    email: "",
    business_name: "",
    business_address: "",
    customer_address: "",
    service_provider_photo: "",
    aadhar: "",
    main_category: "",
    sub_category: "",
    image_paths_json: "[]",
    approved: false,
    latitude: "",
    longitude: "",
    custom_services: [],
    social_facebook: "",
    social_website: "",
    social_instagram: "",
    social_youtube: "",
  };
}

const ServiceRegistrations = () => {
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [approval, setApproval] = useState("all");
  const [mobileFilter, setMobileFilter] = useState("");
  const [mobileFilterDebounced, setMobileFilterDebounced] = useState("");

  const [modalOpen, setModalOpen] = useState(false);
  const [selected, setSelected] = useState(null);
  const [form, setForm] = useState(emptyForm);
  const [saving, setSaving] = useState(false);
  const [toggleBusyId, setToggleBusyId] = useState(null);
  const [uploadingImages, setUploadingImages] = useState(false);
  const [uploadingProvider, setUploadingProvider] = useState(false);
  const [uploadingCustomIdx, setUploadingCustomIdx] = useState(null);

  useEffect(() => {
    const t = setTimeout(() => setMobileFilterDebounced(mobileFilter.trim()), 350);
    return () => clearTimeout(t);
  }, [mobileFilter]);

  const fetchRows = useCallback(async () => {
    setLoading(true);
    try {
      const params = { page, limit, approval };
      if (mobileFilterDebounced) params.mobile = mobileFilterDebounced;
      const data = await getServiceRegistrations(params);
      setRows(data.data || []);
      setTotal(data.total ?? 0);
    } catch (e) {
      console.error(e);
      setRows([]);
    } finally {
      setLoading(false);
    }
  }, [page, approval, mobileFilterDebounced]);

  useEffect(() => {
    fetchRows();
  }, [fetchRows]);

  const totalPages = Math.max(1, Math.ceil(total / limit) || 1);

  const openEdit = (row) => {
    setSelected(row);
    setForm({
      ...emptyForm(),
      mobile: row.mobile || "",
      secondary_contact: row.secondary_contact || "",
      whatsapp: row.whatsapp || "",
      name: row.name || "",
      email: row.email || "",
      business_name: row.business_name || "",
      business_address: row.business_address || "",
      customer_address: row.customer_address || "",
      service_provider_photo: row.service_provider_photo || "",
      aadhar: row.aadhar || "",
      main_category: row.main_category || "",
      sub_category: row.sub_category || "",
      image_paths_json: formatImagePathsForForm(row.image_paths),
      approved: !!row.approved,
      latitude: row.latitude != null && row.latitude !== "" ? String(row.latitude) : "",
      longitude: row.longitude != null && row.longitude !== "" ? String(row.longitude) : "",
      custom_services: normalizeCustomServices(row.custom_services),
      social_facebook: row.social_facebook || "",
      social_website: row.social_website || "",
      social_instagram: row.social_instagram || "",
      social_youtube: row.social_youtube || "",
    });
    setModalOpen(true);
  };

  const closeModal = () => {
    setModalOpen(false);
    setSelected(null);
  };

  const handleFormChange = (e) => {
    const { name, value, type, checked } = e.target;
    setForm((prev) => ({
      ...prev,
      [name]: type === "checkbox" ? checked : value,
    }));
  };

  const buildUpdatePayload = () => {
    const payload = {
      mobile: form.mobile,
      name: form.name,
      main_category: form.main_category,
      sub_category: form.sub_category || null,
      business_name: form.business_name,
      business_address: form.business_address || null,
      customer_address: form.customer_address || null,
      service_provider_photo: form.service_provider_photo || null,
      aadhar: form.aadhar || null,
      secondary_contact: form.secondary_contact || null,
      whatsapp: form.whatsapp || null,
      email: form.email || null,
      social_facebook: form.social_facebook || null,
      social_website: form.social_website || null,
      social_instagram: form.social_instagram || null,
      social_youtube: form.social_youtube || null,
      approved: form.approved,
      custom_services: form.custom_services,
    };

    const la =
      form.latitude === "" || form.latitude == null ? NaN : parseFloat(form.latitude);
    const lo =
      form.longitude === "" || form.longitude == null ? NaN : parseFloat(form.longitude);
    payload.latitude = Number.isFinite(la) ? la : null;
    payload.longitude = Number.isFinite(lo) ? lo : null;

    return payload;
  };

  const handleSave = async (e) => {
    e.preventDefault();
    if (!selected) return;
    let image_paths;
    try {
      image_paths = parseImagePaths(form.image_paths_json);
      if (!Array.isArray(image_paths)) {
        alert('image_paths must be a JSON array (e.g. ["/uploads/..."]).');
        return;
      }
    } catch {
      alert("Image paths must be valid JSON (array of path strings).");
      return;
    }
    setSaving(true);
    try {
      const payload = buildUpdatePayload();
      await updateServiceRegistration(selected.id, {
        ...payload,
        image_paths,
      });
      closeModal();
      fetchRows();
    } catch (err) {
      alert(err.response?.data?.error || err.message || "Save failed");
    } finally {
      setSaving(false);
    }
  };

  const handleToggleApproved = async (row) => {
    const next = !row.approved;
    setToggleBusyId(row.id);
    try {
      await updateServiceRegistration(row.id, { approved: next });
      fetchRows();
    } catch (err) {
      alert(err.response?.data?.error || err.message || "Update failed");
    } finally {
      setToggleBusyId(null);
    }
  };

  const handleDelete = async (row) => {
    if (!window.confirm(`Delete registration #${row.id} (${row.name})?`)) return;
    try {
      await deleteServiceRegistration(row.id);
      fetchRows();
    } catch (err) {
      alert(err.response?.data?.error || err.message || "Delete failed");
    }
  };

  const setApprovalFilter = (v) => {
    setApproval(v);
    setPage(1);
  };

  const uploadsBase = getUploadsBaseUrl();

  const handlePickImages = async (e) => {
    const list = Array.from(e.target.files || []);
    e.target.value = "";
    if (!list.length || !selected) return;
    setUploadingImages(true);
    try {
      const data = await uploadServiceRegistrationImages({
        registrationId: selected.id,
        files: list,
      });
      if (data.record) {
        setForm((f) => ({
          ...f,
          image_paths_json: formatImagePathsForForm(data.record.image_paths),
        }));
      } else if (data.paths?.length) {
        setForm((f) => {
          const cur = getPreviewPaths(f.image_paths_json);
          const merged = [...cur, ...data.paths];
          return {
            ...f,
            image_paths_json: JSON.stringify(merged, null, 2),
          };
        });
      }
    } catch (err) {
      alert(err.response?.data?.error || err.message || "Upload failed");
    } finally {
      setUploadingImages(false);
    }
  };

  const handleRemoveImage = async (path) => {
    if (!selected) return;
    try {
      const data = await removeServiceRegistrationImage(selected.id, path);
      if (data.record) {
        setForm((f) => ({
          ...f,
          image_paths_json: formatImagePathsForForm(data.record.image_paths),
        }));
      }
    } catch (err) {
      alert(err.response?.data?.error || err.message || "Remove failed");
    }
  };

  const handleProviderPhoto = async (e) => {
    const file = e.target.files?.[0];
    e.target.value = "";
    if (!file || !selected) return;
    setUploadingProvider(true);
    try {
      const data = await uploadServiceProviderPhoto(selected.id, file);
      const url = data?.url || data?.record?.service_provider_photo;
      if (url) {
        setForm((f) => ({ ...f, service_provider_photo: url }));
      }
    } catch (err) {
      alert(err.response?.data?.error || err.message || "Upload failed");
    } finally {
      setUploadingProvider(false);
    }
  };

  const handleCustomServiceImage = async (index, e) => {
    const file = e.target.files?.[0];
    e.target.value = "";
    if (!file || !selected) return;
    setUploadingCustomIdx(index);
    try {
      const data = await uploadCustomServiceImage(selected.id, file);
      const url = data?.url;
      if (url) {
        setForm((f) => {
          const next = [...(f.custom_services || [])];
          if (!next[index]) next[index] = { name: "", image_url: "" };
          next[index] = { ...next[index], image_url: url };
          return { ...f, custom_services: next };
        });
      }
    } catch (err) {
      alert(err.response?.data?.error || err.message || "Upload failed");
    } finally {
      setUploadingCustomIdx(null);
    }
  };

  const addCustomService = () => {
    setForm((f) => ({
      ...f,
      custom_services: [...(f.custom_services || []), { name: "", image_url: "" }],
    }));
  };

  const removeCustomService = (index) => {
    setForm((f) => ({
      ...f,
      custom_services: (f.custom_services || []).filter((_, i) => i !== index),
    }));
  };

  const updateCustomServiceName = (index, name) => {
    setForm((f) => {
      const next = [...(f.custom_services || [])];
      if (!next[index]) next[index] = { name: "", image_url: "" };
      next[index] = { ...next[index], name };
      return { ...f, custom_services: next };
    });
  };

  return (
    <div className="service-reg-page">
      <div className="page-header">
        <div className="title-area">
          <ClipboardList className="header-icon" />
          <div>
            <h1>Service registrations</h1>
            <p>Review, approve, edit, and manage service provider sign-ups</p>
          </div>
        </div>
      </div>

      <div className="sr-toolbar">
        <div className="sr-filter-tabs" role="tablist">
          {[
            { key: "all", label: "All" },
            { key: "pending", label: "Pending" },
            { key: "approved", label: "Approved" },
          ].map(({ key, label }) => (
            <button
              key={key}
              type="button"
              role="tab"
              aria-selected={approval === key}
              className={`sr-filter-tab ${approval === key ? "active" : ""}`}
              onClick={() => setApprovalFilter(key)}
            >
              {label}
            </button>
          ))}
        </div>
        <div className="sr-search">
          <Smartphone size={18} />
          <input
            type="text"
            placeholder="Filter by mobile…"
            value={mobileFilter}
            onChange={(e) => {
              setMobileFilter(e.target.value);
              setPage(1);
            }}
          />
        </div>
      </div>

      <div className="sr-list-card">
        <div className="sr-list-header">
          <span className="sr-count">
            {total} record{total !== 1 ? "s" : ""}
          </span>
          <div className="sr-pagination">
            <span>
              Page {page} / {totalPages}
            </span>
            <div className="sr-page-btns">
              <button
                type="button"
                disabled={page <= 1}
                onClick={() => setPage((p) => Math.max(1, p - 1))}
              >
                <ChevronLeft size={18} />
              </button>
              <button
                type="button"
                disabled={page >= totalPages}
                onClick={() => setPage((p) => p + 1)}
              >
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
          <div className="sr-empty">No registrations match this filter.</div>
        ) : (
          <div className="sr-grid">
            {rows.map((row) => (
              <article key={row.id} className="sr-card">
                <div className="sr-card-top">
                  <span className="sr-id">#{row.id}</span>
                  <span
                    className={`sr-status-pill ${row.approved ? "approved" : "pending"}`}
                  >
                    {row.approved ? (
                      <>
                        <CheckCircle2 size={14} /> Approved
                      </>
                    ) : (
                      <>
                        <CircleDashed size={14} /> Pending
                      </>
                    )}
                  </span>
                </div>
                <h3 className="sr-card-title">{row.business_name}</h3>
                <p className="sr-card-sub">Owner: {row.name}</p>
                <dl className="sr-dl">
                  <div>
                    <dt>
                      <Smartphone size={14} /> Mobile
                    </dt>
                    <dd>{row.mobile}</dd>
                  </div>
                  {row.secondary_contact ? (
                    <div>
                      <dt>
                        <Smartphone size={14} /> Secondary
                      </dt>
                      <dd>{row.secondary_contact}</dd>
                    </div>
                  ) : null}
                  {row.whatsapp ? (
                    <div>
                      <dt>WhatsApp</dt>
                      <dd>{row.whatsapp}</dd>
                    </div>
                  ) : null}
                  {row.email ? (
                    <div>
                      <dt>Email</dt>
                      <dd className="sr-dd-truncate">{row.email}</dd>
                    </div>
                  ) : null}
                  <div>
                    <dt>
                      <Tag size={14} /> Categories
                    </dt>
                    <dd>
                      {row.main_category}
                      {row.sub_category ? ` · ${row.sub_category}` : ""}
                    </dd>
                  </div>
                  <div>
                    <dt>
                      <Building2 size={14} /> Registered
                    </dt>
                    <dd>
                      {row.created_at
                        ? new Date(row.created_at).toLocaleString()
                        : "—"}
                    </dd>
                  </div>
                </dl>
                <div className="sr-card-actions">
                  <button
                    type="button"
                    className="sr-btn sr-btn-ghost"
                    disabled={toggleBusyId === row.id}
                    onClick={() => handleToggleApproved(row)}
                    title={row.approved ? "Mark as pending" : "Approve"}
                  >
                    {toggleBusyId === row.id ? (
                      <Loader2 size={16} className="spinner" />
                    ) : row.approved ? (
                      "Unapprove"
                    ) : (
                      "Approve"
                    )}
                  </button>
                  <button
                    type="button"
                    className="sr-btn sr-btn-primary"
                    onClick={() => openEdit(row)}
                  >
                    <Edit size={16} /> Edit
                  </button>
                  <button
                    type="button"
                    className="sr-btn sr-btn-danger"
                    onClick={() => handleDelete(row)}
                  >
                    <Trash2 size={16} />
                  </button>
                </div>
              </article>
            ))}
          </div>
        )}
      </div>

      {modalOpen && selected && (
        <div className="modal-overlay" onClick={closeModal}>
          <div
            className="modal-content sr-modal sr-modal-wide"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="modal-header sr-modal-header">
              <h3>Edit registration #{selected.id}</h3>
              <button type="button" className="close-btn" onClick={closeModal}>
                <X size={20} />
              </button>
            </div>
            <form onSubmit={handleSave} className="sr-form sr-form-compact">
              <section className="sr-form-section">
                <h4>Contact</h4>
                <div className="sr-form-grid sr-form-grid-3">
                  <div className="form-group">
                    <label>Mobile</label>
                    <input
                      name="mobile"
                      value={form.mobile}
                      onChange={handleFormChange}
                      required
                      maxLength={15}
                    />
                  </div>
                  <div className="form-group">
                    <label>Secondary contact</label>
                    <input
                      name="secondary_contact"
                      value={form.secondary_contact}
                      onChange={handleFormChange}
                      maxLength={20}
                      placeholder="Phone"
                    />
                  </div>
                  <div className="form-group">
                    <label>WhatsApp number</label>
                    <input
                      name="whatsapp"
                      value={form.whatsapp}
                      onChange={handleFormChange}
                      maxLength={20}
                    />
                  </div>
                  <div className="form-group">
                    <label>Owner name</label>
                    <input
                      name="name"
                      value={form.name}
                      onChange={handleFormChange}
                      required
                      placeholder="Registered owner / contact person"
                    />
                  </div>
                  <div className="form-group sr-form-span-2">
                    <label>Email</label>
                    <input
                      type="email"
                      name="email"
                      value={form.email}
                      onChange={handleFormChange}
                      placeholder="name@example.com"
                    />
                  </div>
                </div>
              </section>

              <section className="sr-form-section">
                <h4>Business</h4>
                <div className="form-group">
                  <label>Business name</label>
                  <input
                    name="business_name"
                    value={form.business_name}
                    onChange={handleFormChange}
                    required
                  />
                </div>
                <div className="form-group">
                  <label>Business address</label>
                  <textarea
                    name="business_address"
                    value={form.business_address}
                    onChange={handleFormChange}
                    rows={3}
                    className="sr-textarea"
                    placeholder="Full business / service location address"
                  />
                </div>
              </section>

              <section className="sr-form-section">
                <h4>Customer</h4>
                <div className="form-group">
                  <label>Customer address</label>
                  <textarea
                    name="customer_address"
                    value={form.customer_address}
                    onChange={handleFormChange}
                    rows={3}
                    className="sr-textarea"
                    placeholder="Customer / contact address"
                  />
                </div>
              </section>

              <section className="sr-form-section">
                <h4>
                  <User size={14} style={{ display: "inline", verticalAlign: "middle", marginRight: 6 }} />
                  Service provider photo
                </h4>
                <p className="sr-images-intro">
                  Profile photo for the service provider (stored under uploads).
                </p>
                <div className="sr-provider-row">
                  {form.service_provider_photo ? (
                    <img
                      src={`${uploadsBase}${form.service_provider_photo}`}
                      alt=""
                      className="sr-provider-thumb"
                    />
                  ) : (
                    <div className="sr-provider-placeholder">No photo</div>
                  )}
                  <label className={`sr-upload-zone sr-upload-inline ${uploadingProvider ? "busy" : ""}`}>
                    <Upload size={20} />
                    <span>{uploadingProvider ? "Uploading…" : "Choose photo"}</span>
                    <input
                      type="file"
                      accept="image/jpeg,image/png,image/webp,image/gif,.jpg,.jpeg,.png,.webp,.gif"
                      disabled={uploadingProvider}
                      onChange={handleProviderPhoto}
                    />
                  </label>
                </div>
              </section>

              <section className="sr-form-section">
                <h4>Aadhaar (optional)</h4>
                <div className="form-group">
                  <label>Aadhaar number</label>
                  <input
                    name="aadhar"
                    value={form.aadhar}
                    onChange={handleFormChange}
                    maxLength={20}
                    placeholder="Optional KYC reference"
                  />
                </div>
              </section>

              <section className="sr-form-section">
                <h4>
                  <MapPin size={14} style={{ display: "inline", verticalAlign: "middle", marginRight: 6 }} />
                  Location map
                </h4>
                <p className="sr-images-intro">
                  Search or click the map to set the business / service area pin. Latitude and longitude update
                  automatically.
                </p>
                <div className="sr-form-grid sr-form-grid-2">
                  <div className="form-group">
                    <label>Latitude</label>
                    <input
                      name="latitude"
                      value={form.latitude}
                      onChange={handleFormChange}
                      placeholder="e.g. 28.6139"
                    />
                  </div>
                  <div className="form-group">
                    <label>Longitude</label>
                    <input
                      name="longitude"
                      value={form.longitude}
                      onChange={handleFormChange}
                      placeholder="e.g. 77.2090"
                    />
                  </div>
                </div>
                <ServiceRegistrationMapPicker
                  latitude={
                    form.latitude === ""
                      ? null
                      : Number.isFinite(parseFloat(form.latitude))
                        ? parseFloat(form.latitude)
                        : null
                  }
                  longitude={
                    form.longitude === ""
                      ? null
                      : Number.isFinite(parseFloat(form.longitude))
                        ? parseFloat(form.longitude)
                        : null
                  }
                  onChange={(lat, lng) => {
                    setForm((f) => ({
                      ...f,
                      latitude: Number.isFinite(lat) ? String(lat) : "",
                      longitude: Number.isFinite(lng) ? String(lng) : "",
                    }));
                  }}
                />
                <button
                  type="button"
                  className="secondary-btn sr-clear-loc"
                  onClick={() => setForm((f) => ({ ...f, latitude: "", longitude: "" }))}
                >
                  Clear location
                </button>
              </section>

              <section className="sr-form-section">
                <h4>Custom services (name + image)</h4>
                <p className="sr-images-intro">
                  List specific offerings under your sub-category (for example catering: Kesari, Bunde, Chudva,
                  Avalakki). Upload an optional image per item. Saved with <strong>Save changes</strong>.
                </p>
                {(form.custom_services || []).map((cs, idx) => (
                  <div key={idx} className="sr-custom-svc-card">
                    <div className="form-group">
                      <label>Service name</label>
                      <input
                        value={cs.name}
                        onChange={(e) => updateCustomServiceName(idx, e.target.value)}
                        placeholder="e.g. Kesari, JCB rental, soil testing…"
                      />
                    </div>
                    <div className="sr-custom-svc-img">
                      {cs.image_url ? (
                        <img src={`${uploadsBase}${cs.image_url}`} alt="" className="sr-custom-thumb" />
                      ) : (
                        <div className="sr-custom-thumb-placeholder">No image</div>
                      )}
                      <label className={`sr-upload-zone sr-upload-tiny ${uploadingCustomIdx === idx ? "busy" : ""}`}>
                        <Upload size={16} />
                        <span>{uploadingCustomIdx === idx ? "…" : "Upload"}</span>
                        <input
                          type="file"
                          accept="image/*"
                          disabled={uploadingCustomIdx === idx}
                          onChange={(e) => handleCustomServiceImage(idx, e)}
                        />
                      </label>
                    </div>
                    <button
                      type="button"
                      className="sr-btn sr-btn-danger sr-custom-remove"
                      onClick={() => removeCustomService(idx)}
                      title="Remove row"
                    >
                      <Trash2 size={16} />
                    </button>
                  </div>
                ))}
                <button type="button" className="secondary-btn" onClick={addCustomService}>
                  + Add custom service
                </button>
              </section>

              <section className="sr-form-section">
                <h4>Categories</h4>
                <div className="sr-form-grid sr-form-grid-2">
                  <div className="form-group">
                    <label>Main category</label>
                    <input
                      name="main_category"
                      value={form.main_category}
                      onChange={handleFormChange}
                      required
                      placeholder="e.g. Farming service"
                    />
                  </div>
                  <div className="form-group">
                    <label>Sub category</label>
                    <input
                      name="sub_category"
                      value={form.sub_category}
                      onChange={handleFormChange}
                      placeholder="e.g. Catering, equipment hire…"
                    />
                  </div>
                </div>
              </section>

              <section className="sr-form-section">
                <h4>Business location photos</h4>
                <p className="sr-images-intro">
                  Upload 3–4 images of your shop or work premises / service area. Photos append on upload and remove
                  immediately when deleted; use <strong>Save changes</strong> for text fields.
                </p>
                <label className={`sr-upload-zone ${uploadingImages ? "busy" : ""}`}>
                  <Upload size={22} />
                  <span>
                    {uploadingImages
                      ? "Uploading…"
                      : "Choose multiple images (JPEG, PNG, WebP, GIF)"}
                  </span>
                  <input
                    type="file"
                    accept="image/jpeg,image/png,image/webp,image/gif,.jpg,.jpeg,.png,.webp,.gif"
                    multiple
                    disabled={uploadingImages}
                    onChange={handlePickImages}
                  />
                </label>
                <div className="sr-preview-grid">
                  {getPreviewPaths(form.image_paths_json).map((path) => (
                    <div key={path} className="sr-preview-tile">
                      <img src={`${uploadsBase}${path}`} alt="" loading="lazy" />
                      <button
                        type="button"
                        className="sr-preview-remove"
                        onClick={() => handleRemoveImage(path)}
                        title="Remove image"
                      >
                        <X size={14} />
                      </button>
                    </div>
                  ))}
                </div>
                <details className="sr-json-details">
                  <summary>Advanced: edit paths as JSON</summary>
                  <div className="form-group full-width">
                    <textarea
                      name="image_paths_json"
                      rows={5}
                      value={form.image_paths_json}
                      onChange={handleFormChange}
                      className="sr-json-area"
                      spellCheck={false}
                    />
                    <p className="sr-hint">
                      Array of URL paths, e.g.{" "}
                      <code>[&quot;/uploads/service-registrations/12/….jpg&quot;]</code>
                    </p>
                  </div>
                </details>
              </section>

              <section className="sr-form-section">
                <h4>
                  <Link2 size={14} style={{ display: "inline", verticalAlign: "middle", marginRight: 6 }} />
                  Social & web
                </h4>
                <div className="sr-form-grid sr-form-grid-2">
                  <div className="form-group">
                    <label>Facebook</label>
                    <input name="social_facebook" value={form.social_facebook} onChange={handleFormChange} placeholder="URL" />
                  </div>
                  <div className="form-group">
                    <label>Website</label>
                    <input name="social_website" value={form.social_website} onChange={handleFormChange} placeholder="URL" />
                  </div>
                  <div className="form-group">
                    <label>Instagram</label>
                    <input name="social_instagram" value={form.social_instagram} onChange={handleFormChange} placeholder="URL" />
                  </div>
                  <div className="form-group">
                    <label>YouTube</label>
                    <input name="social_youtube" value={form.social_youtube} onChange={handleFormChange} placeholder="URL" />
                  </div>
                </div>
              </section>

              <section className="sr-form-section">
                <h4>Status</h4>
                <label className="switch-label">
                  <input
                    type="checkbox"
                    name="approved"
                    checked={form.approved}
                    onChange={handleFormChange}
                  />
                  <span className="slider" />
                  <span className="label-text">Approved</span>
                </label>
              </section>

              <div className="modal-footer">
                <button type="button" className="secondary-btn" onClick={closeModal}>
                  Cancel
                </button>
                <button type="submit" className="primary-btn" disabled={saving}>
                  {saving ? <Loader2 size={18} className="spinner" /> : "Save changes"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

export default ServiceRegistrations;
