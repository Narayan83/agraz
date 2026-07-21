import React, { useCallback, useEffect, useState } from "react";
import { ChevronDown, ChevronUp, Loader2, Plus, Save, Trash2, Upload } from "lucide-react";
import {
  listAdminStorefrontBanners,
  createAdminStorefrontBanner,
  updateAdminStorefrontBanner,
  deleteAdminStorefrontBanner,
  reorderAdminStorefrontBanners,
  uploadAdminEcomImage,
  getUploadsBaseUrl,
} from "../api/api";
import "./StorefrontHero.css";

const SLOT = "home";

const copyDefaults = {
  title: "Welcome to ARICA..!",
  subtitle: "Discover the charm of handcrafted elegance, made to adorn your space.",
  cta_label: "Explore Our Products",
  cta_href: "#products",
};

function previewURL(imageUrl) {
  if (!imageUrl) return "";
  if (imageUrl.startsWith("http")) return imageUrl;
  const base = getUploadsBaseUrl();
  return `${base}${imageUrl.startsWith("/") ? "" : "/"}${imageUrl}`;
}

const StorefrontHero = () => {
  const [loading, setLoading] = useState(true);
  const [slides, setSlides] = useState([]);
  const [error, setError] = useState("");
  const [uploadingId, setUploadingId] = useState(null);
  const [savingId, setSavingId] = useState(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const res = await listAdminStorefrontBanners(SLOT);
      setSlides(res?.data || []);
    } catch (e) {
      setError(e?.response?.data?.error || e?.message || "Failed to load");
      setSlides([]);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const addSlideWithUpload = async (e) => {
    const file = e.target.files?.[0];
    e.target.value = "";
    if (!file) return;
    setError("");
    setUploadingId(-1);
    try {
      const up = await uploadAdminEcomImage({ kind: "hero", file });
      const url = up?.url;
      if (!url) throw new Error("Upload did not return a URL");
      await createAdminStorefrontBanner({
        slot: SLOT,
        image_url: url,
        ...copyDefaults,
        is_active: true,
      });
      await load();
    } catch (err) {
      setError(err?.response?.data?.error || err?.message || "Upload failed");
    } finally {
      setUploadingId(null);
    }
  };

  const saveSlide = async (row) => {
    setSavingId(row.id);
    setError("");
    try {
      await updateAdminStorefrontBanner(row.id, {
        title: row.title,
        subtitle: row.subtitle,
        cta_label: row.cta_label,
        cta_href: row.cta_href,
        is_active: row.is_active,
        image_url: row.image_url,
      });
      await load();
    } catch (e) {
      setError(e?.response?.data?.error || e?.message || "Save failed");
    } finally {
      setSavingId(null);
    }
  };

  const removeSlide = async (id) => {
    if (!window.confirm("Delete this banner slide?")) return;
    setError("");
    try {
      await deleteAdminStorefrontBanner(id);
      await load();
    } catch (e) {
      setError(e?.response?.data?.error || e?.message || "Delete failed");
    }
  };

  const moveSlide = async (index, dir) => {
    const j = index + dir;
    if (j < 0 || j >= slides.length) return;
    const next = [...slides];
    const t = next[index];
    next[index] = next[j];
    next[j] = t;
    const ids = next.map((s) => s.id);
    setError("");
    try {
      await reorderAdminStorefrontBanners({ slot: SLOT, ids });
      await load();
    } catch (e) {
      setError(e?.response?.data?.error || e?.message || "Reorder failed");
    }
  };

  const onSlideFile = async (slideId, e) => {
    const file = e.target.files?.[0];
    e.target.value = "";
    if (!file) return;
    setUploadingId(slideId);
    setError("");
    try {
      const up = await uploadAdminEcomImage({ kind: "hero", file });
      const url = up?.url;
      if (!url) throw new Error("Upload did not return a URL");
      setSlides((rows) =>
        rows.map((r) => (r.id === slideId ? { ...r, image_url: url, is_active: true } : r))
      );
      await updateAdminStorefrontBanner(slideId, { image_url: url, is_active: true });
      await load();
    } catch (err) {
      setError(err?.response?.data?.error || err?.message || "Upload failed");
    } finally {
      setUploadingId(null);
    }
  };

  const patchLocal = (id, patch) => {
    setSlides((rows) => rows.map((r) => (r.id === id ? { ...r, ...patch } : r)));
  };

  if (loading) {
    return (
      <div className="storefront-hero-page storefront-hero-page--center">
        <Loader2 className="spin" size={32} aria-hidden />
        <p>Loading banners…</p>
      </div>
    );
  }

  return (
    <div className="storefront-hero-page">
      <header className="storefront-hero-page__head">
        <div>
          <h1>Storefront home banners</h1>
          <p className="storefront-hero-page__sub">
            Add multiple wide images; the shop home page shows them in a carousel. Text and button are
            drawn over each image (not baked into the file).
          </p>
        </div>
        <label className="storefront-hero-page__add">
          <input type="file" accept="image/*" onChange={addSlideWithUpload} hidden disabled={uploadingId != null} />
          {uploadingId === -1 ? <Loader2 className="spin" size={18} /> : <Plus size={18} />}
          Add banner (upload image)
        </label>
      </header>

      {error ? (
        <div className="storefront-hero-page__err" role="alert">
          {error}
        </div>
      ) : null}

      {slides.length === 0 ? (
        <p className="storefront-hero-page__empty">No slides yet. Upload a banner image to create the first one.</p>
      ) : (
        <ul className="storefront-banner-list">
          {slides.map((row, index) => (
            <li key={row.id} className="storefront-banner-card">
              <div className="storefront-banner-card__top">
                <span className="storefront-banner-card__badge">
                  Slide {index + 1} · order {row.sort_order}
                </span>
                <div className="storefront-banner-card__reorder">
                  <button
                    type="button"
                    className="icon-btn"
                    aria-label="Move up"
                    disabled={index === 0}
                    onClick={() => moveSlide(index, -1)}
                  >
                    <ChevronUp size={18} />
                  </button>
                  <button
                    type="button"
                    className="icon-btn"
                    aria-label="Move down"
                    disabled={index === slides.length - 1}
                    onClick={() => moveSlide(index, 1)}
                  >
                    <ChevronDown size={18} />
                  </button>
                </div>
              </div>
              <div
                className="storefront-hero-preview storefront-hero-preview--sm"
                style={
                  row.image_url
                    ? { backgroundImage: `url(${previewURL(row.image_url)})` }
                    : { background: "linear-gradient(120deg,#1a535c,#94a3b8)" }
                }
              />
              <label className="storefront-hero-upload storefront-hero-upload--inline">
                <input
                  type="file"
                  accept="image/*"
                  onChange={(e) => onSlideFile(row.id, e)}
                  disabled={uploadingId != null}
                  hidden
                />
                {uploadingId === row.id ? <Loader2 className="spin" size={16} /> : <Upload size={16} />}
                Replace image
              </label>
              <label className="storefront-hero-field">
                <span>Heading</span>
                <input value={row.title} onChange={(e) => patchLocal(row.id, { title: e.target.value })} />
              </label>
              <label className="storefront-hero-field">
                <span>Subheading</span>
                <textarea
                  rows={2}
                  value={row.subtitle}
                  onChange={(e) => patchLocal(row.id, { subtitle: e.target.value })}
                />
              </label>
              <div className="storefront-banner-card__row2">
                <label className="storefront-hero-field">
                  <span>Button</span>
                  <input value={row.cta_label} onChange={(e) => patchLocal(row.id, { cta_label: e.target.value })} />
                </label>
                <label className="storefront-hero-field">
                  <span>Link</span>
                  <input value={row.cta_href} onChange={(e) => patchLocal(row.id, { cta_href: e.target.value })} />
                </label>
              </div>
              <label className="storefront-hero-check">
                <input
                  type="checkbox"
                  checked={row.is_active}
                  onChange={(e) => patchLocal(row.id, { is_active: e.target.checked })}
                />
                <span>Visible on website</span>
              </label>
              <div className="storefront-banner-card__foot">
                <button
                  type="button"
                  className="storefront-hero-page__save"
                  onClick={() => saveSlide(row)}
                  disabled={savingId === row.id || uploadingId != null}
                >
                  {savingId === row.id ? <Loader2 className="spin" size={16} /> : <Save size={16} />}
                  Save
                </button>
                <button type="button" className="storefront-banner-card__delete" onClick={() => removeSlide(row.id)}>
                  <Trash2 size={16} />
                  Delete
                </button>
              </div>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
};

export default StorefrontHero;
