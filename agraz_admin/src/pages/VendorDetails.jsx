import React, { useState, useEffect, useCallback } from "react";
import {
  Store,
  Plus,
  Edit,
  Trash2,
  X,
  Loader2,
  ChevronLeft,
  ChevronRight,
  Building2,
  Smartphone,
  Share2,
} from "lucide-react";
import { useNavigate } from "react-router-dom";
import {
  getVendors,
  createVendor,
  updateVendor,
  deleteVendor,
} from "../api/api";
import "./ServiceRegistrations.css";

const limit = 10;

const BUSINESS_TYPES = [
  { value: "individual", label: "Individual" },
  { value: "sole_proprietorship", label: "Sole proprietorship" },
  { value: "partnership", label: "Partnership" },
];

function emptyForm() {
  return {
    business_type: "individual",
    business_name: "",
    address: "",
    phone_number: "",
    mobile_number: "",
    whatsapp_number: "",
    location: "",
    pincode: "",
    owner_name: "",
    owner_address: "",
    owner_phone: "",
    owner_whatsapp: "",
  };
}

function rowToForm(row) {
  return {
    business_type: row.business_type || "individual",
    business_name: row.business_name || "",
    address: row.address || "",
    phone_number: row.phone_number || "",
    mobile_number: row.mobile_number || "",
    whatsapp_number: row.whatsapp_number || "",
    location: row.location || "",
    pincode: row.pincode || "",
    owner_name: row.owner_name || "",
    owner_address: row.owner_address || "",
    owner_phone: row.owner_phone || "",
    owner_whatsapp: row.owner_whatsapp || "",
  };
}

function businessTypeLabel(v) {
  const f = BUSINESS_TYPES.find((x) => x.value === v);
  return f ? f.label : v;
}

const VendorDetails = () => {
  const navigate = useNavigate();
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [search, setSearch] = useState("");
  const [searchDebounced, setSearchDebounced] = useState("");

  const [modalOpen, setModalOpen] = useState(false);
  const [selected, setSelected] = useState(null);
  const [form, setForm] = useState(emptyForm);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    const t = setTimeout(() => setSearchDebounced(search.trim()), 300);
    return () => clearTimeout(t);
  }, [search]);

  const fetchRows = useCallback(async () => {
    setLoading(true);
    try {
      const params = { page, limit };
      if (searchDebounced) params.search = searchDebounced;
      const data = await getVendors(params);
      setRows(data.data || []);
      setTotal(data.total ?? 0);
    } catch (e) {
      console.error(e);
      setRows([]);
    } finally {
      setLoading(false);
    }
  }, [page, searchDebounced]);

  useEffect(() => {
    fetchRows();
  }, [fetchRows]);

  const totalPages = Math.max(1, Math.ceil(total / limit) || 1);

  const openCreate = () => {
    setSelected(null);
    setForm(emptyForm());
    setModalOpen(true);
  };

  const openEdit = (row) => {
    setSelected(row);
    setForm(rowToForm(row));
    setModalOpen(true);
  };

  const closeModal = () => {
    setModalOpen(false);
    setSelected(null);
  };

  const handleChange = (e) => {
    const { name, value } = e.target;
    setForm((prev) => ({ ...prev, [name]: value }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSaving(true);
    try {
      const payload = {
        business_type: form.business_type,
        business_name: form.business_name.trim(),
        address: form.address.trim(),
        phone_number: form.phone_number.trim(),
        mobile_number: form.mobile_number.trim(),
        whatsapp_number: form.whatsapp_number.trim() || null,
        location: form.location.trim() || null,
        pincode: form.pincode.trim() || null,
        owner_name: form.owner_name.trim(),
        owner_address: form.owner_address.trim() || null,
        owner_phone: form.owner_phone.trim() || null,
        owner_whatsapp: form.owner_whatsapp.trim() || null,
      };
      if (selected) {
        await updateVendor(selected.id, payload);
      } else {
        await createVendor(payload);
      }
      closeModal();
      fetchRows();
    } catch (err) {
      alert(err.response?.data?.error || err.message || "Save failed");
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async (row) => {
    if (!window.confirm(`Delete vendor “${row.business_name}”?`)) return;
    try {
      await deleteVendor(row.id);
      fetchRows();
    } catch (err) {
      alert(err.response?.data?.error || err.message || "Delete failed");
    }
  };

  return (
    <div className="service-reg-page">
      <div className="page-header">
        <div className="title-area">
          <Store className="header-icon" />
          <div>
            <h1>Vendor details</h1>
            <p>Business type, contact, location, and owner information</p>
          </div>
        </div>
        <button type="button" className="primary-btn" onClick={openCreate}>
          <Plus size={18} />
          Add vendor
        </button>
      </div>

      <div className="sr-toolbar">
        <div className="sr-search" style={{ maxWidth: "360px" }}>
          <Building2 size={18} />
          <input
            type="search"
            placeholder="Search business, owner, mobile…"
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
            {total} vendor{total !== 1 ? "s" : ""}
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
          <div className="sr-empty">No vendors yet. Add one to get started.</div>
        ) : (
          <div className="sr-grid">
            {rows.map((row) => (
              <article key={row.id} className="sr-card">
                <div className="sr-card-top">
                  <span className="sr-id">#{row.id}</span>
                  <span className="sr-status-pill approved" style={{ textTransform: "none" }}>
                    {businessTypeLabel(row.business_type)}
                  </span>
                </div>
                <h3 className="sr-card-title">{row.business_name}</h3>
                <p className="sr-card-sub">Owner: {row.owner_name}</p>
                <dl className="sr-dl">
                  <div>
                    <dt>
                      <Smartphone size={14} /> Mobile
                    </dt>
                    <dd>{row.mobile_number}</dd>
                  </div>
                  <div>
                    <dt>Phone</dt>
                    <dd>{row.phone_number}</dd>
                  </div>
                  {row.whatsapp_number ? (
                    <div>
                      <dt>WhatsApp</dt>
                      <dd>{row.whatsapp_number}</dd>
                    </div>
                  ) : null}
                  {row.location || row.pincode ? (
                    <div>
                      <dt>Location</dt>
                      <dd>
                        {[row.location, row.pincode].filter(Boolean).join(" · ") || "—"}
                      </dd>
                    </div>
                  ) : null}
                </dl>
                <div className="sr-card-actions">
                  <button
                    type="button"
                    className="sr-btn sr-btn-primary"
                    onClick={() => navigate(`/vendor-product-mapping?vendor_id=${row.id}`)}
                  >
                    <Share2 size={16} /> Map products
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

      {modalOpen && (
        <div className="modal-overlay" onClick={closeModal}>
          <div
            className="modal-content sr-modal sr-modal-wide"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="modal-header sr-modal-header">
              <h3>{selected ? `Edit vendor #${selected.id}` : "New vendor"}</h3>
              <button type="button" className="close-btn" onClick={closeModal}>
                <X size={20} />
              </button>
            </div>
            <form onSubmit={handleSubmit} className="sr-form sr-form-compact">
              <section className="sr-form-section">
                <h4>Business</h4>
                <div className="sr-form-grid sr-form-grid-2">
                  <div className="form-group">
                    <label>Business type *</label>
                    <select
                      name="business_type"
                      value={form.business_type}
                      onChange={handleChange}
                      required
                      aria-required="true"
                    >
                      {BUSINESS_TYPES.map((o) => (
                        <option key={o.value} value={o.value}>
                          {o.label}
                        </option>
                      ))}
                    </select>
                  </div>
                  <div className="form-group">
                    <label>Business name</label>
                    <input
                      name="business_name"
                      value={form.business_name}
                      onChange={handleChange}
                      required
                    />
                  </div>
                </div>
                <div className="form-group">
                  <label>Address</label>
                  <textarea
                    name="address"
                    value={form.address}
                    onChange={handleChange}
                    rows={3}
                    className="sr-textarea"
                    required
                  />
                </div>
                <div className="sr-form-grid sr-form-grid-3">
                  <div className="form-group">
                    <label>Phone number</label>
                    <input
                      name="phone_number"
                      value={form.phone_number}
                      onChange={handleChange}
                      required
                    />
                  </div>
                  <div className="form-group">
                    <label>Mobile number</label>
                    <input
                      name="mobile_number"
                      value={form.mobile_number}
                      onChange={handleChange}
                      required
                    />
                  </div>
                  <div className="form-group">
                    <label>WhatsApp number</label>
                    <input
                      name="whatsapp_number"
                      value={form.whatsapp_number}
                      onChange={handleChange}
                    />
                  </div>
                  <div className="form-group">
                    <label>Location</label>
                    <input name="location" value={form.location} onChange={handleChange} />
                  </div>
                  <div className="form-group">
                    <label>Pincode</label>
                    <input name="pincode" value={form.pincode} onChange={handleChange} />
                  </div>
                </div>
              </section>

              <section className="sr-form-section">
                <h4>Owner</h4>
                <div className="sr-form-grid sr-form-grid-2">
                  <div className="form-group">
                    <label>Owner name</label>
                    <input
                      name="owner_name"
                      value={form.owner_name}
                      onChange={handleChange}
                      required
                    />
                  </div>
                  <div className="form-group">
                    <label>Owner phone</label>
                    <input name="owner_phone" value={form.owner_phone} onChange={handleChange} />
                  </div>
                </div>
                <div className="form-group">
                  <label>Owner address</label>
                  <textarea
                    name="owner_address"
                    value={form.owner_address}
                    onChange={handleChange}
                    rows={2}
                    className="sr-textarea"
                  />
                </div>
                <div className="form-group">
                  <label>Owner WhatsApp</label>
                  <input
                    name="owner_whatsapp"
                    value={form.owner_whatsapp}
                    onChange={handleChange}
                  />
                </div>
              </section>

              <div className="modal-footer">
                <button type="button" className="secondary-btn" onClick={closeModal}>
                  Cancel
                </button>
                <button type="submit" className="primary-btn" disabled={saving}>
                  {saving ? <Loader2 size={18} className="spinner" /> : "Save"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

export default VendorDetails;
