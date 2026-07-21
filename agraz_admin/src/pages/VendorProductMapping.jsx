import React, { useState, useEffect, useCallback } from "react";
import {
  Share2,
  Plus,
  Trash2,
  Loader2,
  Package,
  Store,
} from "lucide-react";
import { useSearchParams } from "react-router-dom";
import {
  getVendors,
  getAdminProducts,
  getVendorProductMappings,
  replaceVendorProductMappings,
} from "../api/api";
import "./ServiceRegistrations.css";

const productLimit = 500;

const VendorProductMapping = () => {
  const [searchParams] = useSearchParams();
  const storedUser = (() => {
    try {
      return JSON.parse(localStorage.getItem("user") || "{}");
    } catch {
      return {};
    }
  })();
  const isVendorUser = Boolean(storedUser.is_vendor_user);
  const lockedVendorId = storedUser.vendor_id ? String(storedUser.vendor_id) : "";

  const [vendors, setVendors] = useState([]);
  const [products, setProducts] = useState([]);
  const [vendorId, setVendorId] = useState(() => {
    if (isVendorUser && lockedVendorId) return lockedVendorId;
    return searchParams.get("vendor_id") || "";
  });
  const [lines, setLines] = useState([]);
  const [loadingMeta, setLoadingMeta] = useState(true);
  const [loadingMappings, setLoadingMappings] = useState(false);
  const [saving, setSaving] = useState(false);

  const loadMeta = useCallback(async () => {
    setLoadingMeta(true);
    try {
      const [vRes, pRes] = await Promise.all([
        getVendors({ page: 1, limit: 500 }),
        getAdminProducts({ page: 1, limit: productLimit }),
      ]);
      setVendors(vRes.data || []);
      setProducts(pRes.data || []);
    } catch (e) {
      console.error(e);
      setVendors([]);
      setProducts([]);
    } finally {
      setLoadingMeta(false);
    }
  }, []);

  useEffect(() => {
    loadMeta();
  }, [loadMeta]);

  useEffect(() => {
    const fromUrl = searchParams.get("vendor_id");
    if (fromUrl && fromUrl !== vendorId) {
      setVendorId(fromUrl);
    }
  }, [searchParams, vendorId]);

  const loadMappingsForVendor = useCallback(async (id) => {
    if (!id) {
      setLines([]);
      return;
    }
    setLoadingMappings(true);
    try {
      const data = await getVendorProductMappings({
        vendor_id: id,
        page: 1,
        limit: 500,
      });
      const list = data.data || [];
      setLines(
        list.map((m) => ({
          product_id: m.product_id,
          quantity: m.quantity > 0 ? m.quantity : 1,
        }))
      );
    } catch (e) {
      console.error(e);
      setLines([]);
    } finally {
      setLoadingMappings(false);
    }
  }, []);

  useEffect(() => {
    const id = vendorId ? Number(vendorId) : 0;
    if (!id) {
      setLines([]);
      return;
    }
    loadMappingsForVendor(id);
  }, [vendorId, loadMappingsForVendor]);

  const addLine = () => {
    setLines((prev) => [...prev, { product_id: "", quantity: 1 }]);
  };

  const removeLine = (index) => {
    setLines((prev) => prev.filter((_, i) => i !== index));
  };

  const updateLine = (index, field, value) => {
    setLines((prev) => {
      const next = [...prev];
      const row = { ...next[index] };
      if (field === "product_id") {
        row.product_id = value === "" ? "" : Number(value);
      } else if (field === "quantity") {
        const n = parseInt(value, 10);
        row.quantity = Number.isFinite(n) && n >= 1 ? n : 1;
      }
      next[index] = row;
      return next;
    });
  };

  const handleSave = async (e) => {
    e.preventDefault();
    const id = Number(vendorId);
    if (!id) {
      alert("Select a vendor first.");
      return;
    }
    const mappings = lines
      .filter((l) => l.product_id && Number(l.product_id) > 0)
      .map((l) => ({
        product_id: Number(l.product_id),
        quantity: l.quantity < 1 ? 1 : l.quantity,
      }));
    setSaving(true);
    try {
      await replaceVendorProductMappings(id, { mappings });
      await loadMappingsForVendor(id);
    } catch (err) {
      alert(err.response?.data?.error || err.message || "Save failed");
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="service-reg-page">
      <div className="page-header">
        <div className="title-area">
          <Share2 className="header-icon" />
          <div>
            <h1>{isVendorUser ? "My products" : "Vendor and product mapping"}</h1>
            <p>
              {isVendorUser
                ? "Products linked to your vendor account and their quantities."
                : "Choose a vendor, add products and quantities. The same catalog product can be linked to multiple vendors."}
            </p>
          </div>
        </div>
      </div>

      {loadingMeta ? (
        <div className="sr-loader">
          <Loader2 className="spinner" size={36} />
          <p>Loading vendors and products…</p>
        </div>
      ) : (
        <div className="sr-list-card">
          <div className="sr-list-header">
            <span className="sr-count">Map products to a vendor</span>
          </div>
          <div style={{ padding: "1.25rem 1.5rem" }}>
            <form onSubmit={handleSave} className="sr-form sr-form-compact">
              <div className="form-group" style={{ maxWidth: "420px" }}>
                <label>
                  <Store size={14} style={{ display: "inline", verticalAlign: "middle", marginRight: 6 }} />
                  Vendor
                </label>
                <select
                  value={vendorId}
                  onChange={(e) => setVendorId(e.target.value)}
                  required={false}
                  disabled={isVendorUser}
                >
                  <option value="">— Select vendor —</option>
                  {vendors.map((v) => (
                    <option key={v.id} value={String(v.id)}>
                      #{v.id} · {v.business_name}
                    </option>
                  ))}
                </select>
              </div>

              {loadingMappings && vendorId ? (
                <p className="sr-images-intro">
                  <Loader2 size={16} className="spinner" style={{ display: "inline" }} /> Loading current
                  mappings…
                </p>
              ) : null}

              <section className="sr-form-section">
                <h4>
                  <Package size={14} style={{ display: "inline", verticalAlign: "middle", marginRight: 6 }} />
                  Products for this vendor
                </h4>
                <p className="sr-images-intro">
                  Each row is one product and how many units you associate with this vendor. Saving replaces
                  the full list for the selected vendor.
                </p>

                {!vendorId ? (
                  <div className="sr-empty" style={{ marginTop: "0.5rem" }}>
                    Select a vendor to edit mappings.
                  </div>
                ) : (
                  <>
                    <div className="mapping-table-wrap">
                      <table className="mapping-table">
                        <thead>
                          <tr>
                            <th>Product</th>
                            <th style={{ width: "120px" }}>Quantity</th>
                            <th style={{ width: "52px" }} />
                          </tr>
                        </thead>
                        <tbody>
                          {lines.length === 0 ? (
                            <tr>
                              <td colSpan={3} className="mapping-table-empty">
                                No products yet. Use “Add product row”.
                              </td>
                            </tr>
                          ) : (
                            lines.map((line, index) => (
                              <tr key={index}>
                                <td>
                                  <select
                                    value={line.product_id === "" ? "" : String(line.product_id)}
                                    onChange={(e) =>
                                      updateLine(index, "product_id", e.target.value)
                                    }
                                  >
                                    <option value="">— Product —</option>
                                    {products.map((p) => (
                                      <option key={p.id} value={String(p.id)}>
                                        #{p.id} · {p.name}
                                      </option>
                                    ))}
                                  </select>
                                </td>
                                <td>
                                  <input
                                    type="number"
                                    min={1}
                                    value={line.quantity}
                                    onChange={(e) =>
                                      updateLine(index, "quantity", e.target.value)
                                    }
                                  />
                                </td>
                                <td>
                                  <button
                                    type="button"
                                    className="sr-btn sr-btn-danger"
                                    title="Remove row"
                                    onClick={() => removeLine(index)}
                                  >
                                    <Trash2 size={16} />
                                  </button>
                                </td>
                              </tr>
                            ))
                          )}
                        </tbody>
                      </table>
                    </div>
                    <div style={{ display: "flex", gap: "0.75rem", flexWrap: "wrap", marginTop: "1rem" }}>
                      <button type="button" className="secondary-btn" onClick={addLine} disabled={!vendorId}>
                        <Plus size={16} style={{ display: "inline", verticalAlign: "middle" }} /> Add product
                        row
                      </button>
                      <button type="submit" className="primary-btn" disabled={!vendorId || saving}>
                        {saving ? <Loader2 size={18} className="spinner" /> : "Save mappings"}
                      </button>
                    </div>
                  </>
                )}
              </section>
            </form>
          </div>
        </div>
      )}

      <style>{`
        .mapping-table-wrap { overflow-x: auto; border: 1px solid var(--border); border-radius: var(--radius-md); }
        .mapping-table { width: 100%; border-collapse: collapse; font-size: 0.875rem; }
        .mapping-table th, .mapping-table td { padding: 0.65rem 0.75rem; text-align: left; border-bottom: 1px solid var(--border); }
        .mapping-table th { background: var(--bg-main); color: var(--text-muted); font-weight: 600; }
        .mapping-table td select, .mapping-table td input { width: 100%; padding: 0.45rem 0.5rem; border-radius: var(--radius-sm); border: 1px solid var(--border); background: var(--surface); color: var(--text-main); }
        .mapping-table-empty { color: var(--text-muted); font-style: italic; }
      `}</style>
    </div>
  );
};

export default VendorProductMapping;
