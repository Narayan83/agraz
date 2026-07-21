import React, { useEffect, useMemo, useState, useCallback } from "react";
import { useSearchParams } from "react-router-dom";
import {
  Plus,
  Trash2,
  Edit,
  X,
  Search,
  Package,
  Layers,
  Palette,
  Tag as TagIcon,
  Save,
  Loader2,
  ExternalLink,
} from "lucide-react";
import {
  getAdminCategories,
  getAdminSubCategories,
  getAdminColors,
  getAdminProducts,
  getAdminProduct,
  createAdminCategory,
  updateAdminCategory,
  deleteAdminCategory,
  createAdminSubCategory,
  updateAdminSubCategory,
  deleteAdminSubCategory,
  createAdminColor,
  updateAdminColor,
  deleteAdminColor,
  createAdminProduct,
  updateAdminProduct,
  deleteAdminProduct,
  getUploadsBaseUrl,
} from "../api/api";
import ImageCropUploadModal from "../components/ImageCropUploadModal";
import "./EcomAdmin.css";

const TAB = {
  CATEGORIES: "categories",
  SUB_CATEGORIES: "sub_categories",
  COLORS: "colors",
  PRODUCTS: "products",
};

/** URL ?tab= value for each tab (sidebar + deep links). */
const TAB_TO_QUERY = {
  [TAB.CATEGORIES]: "categories",
  [TAB.SUB_CATEGORIES]: "sub-categories",
  [TAB.COLORS]: "colors",
  [TAB.PRODUCTS]: "products",
};

function tabFromSearchParam(param) {
  switch (param) {
    case "categories":
      return TAB.CATEGORIES;
    case "sub-categories":
      return TAB.SUB_CATEGORIES;
    case "colors":
      return TAB.COLORS;
    case "products":
      return TAB.PRODUCTS;
    default:
      return TAB.PRODUCTS;
  }
}

const statusOptions = ["active", "inactive"];

function safeParseJSON(text) {
  const t = (text || "").trim();
  if (!t) return null;
  try {
    return JSON.parse(t);
  } catch {
    return null;
  }
}

function toDecimalOrNull(v) {
  const t = (v ?? "").toString().trim();
  if (!t) return null;
  return t;
}

function toIntOrNull(v) {
  const t = (v ?? "").toString().trim();
  if (!t) return null;
  const n = Number(t);
  if (!Number.isFinite(n)) return null;
  return Math.trunc(n);
}

function sanitizeSlug(s) {
  return (s || "")
    .toString()
    .trim()
    .toLowerCase()
    .replace(/\s+/g, "-")
    .replace(/[^a-z0-9-]/g, "");
}

function adminProductThumbUrl(product, uploadsOrigin) {
  const imgs = product?.images || [];
  const primary = imgs.find((i) => i.is_primary) || imgs[0];
  if (primary?.image_url) {
    const u = primary.image_url;
    if (u.startsWith("http")) return u;
    const path = u.startsWith("/") ? u : `/${u}`;
    return `${uploadsOrigin}${path}`;
  }
  const v = (product?.variants || []).find((x) => x.image_url);
  if (v?.image_url) {
    const u = v.image_url;
    if (u.startsWith("http")) return u;
    const path = u.startsWith("/") ? u : `/${u}`;
    return `${uploadsOrigin}${path}`;
  }
  return null;
}

function ModalShell({ title, onClose, children, footer }) {
  return (
    <div className="ecom-modal-overlay" onClick={onClose}>
      <div className="ecom-modal-content" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h3>{title}</h3>
          <button type="button" className="close-btn" onClick={onClose}>
            <X size={20} />
          </button>
        </div>
        <div className="ecom-modal-body">{children}</div>
        {footer}
      </div>
    </div>
  );
}

const EcomAdmin = () => {
  const [searchParams, setSearchParams] = useSearchParams();
  const activeTab = useMemo(
    () => tabFromSearchParam(searchParams.get("tab")),
    [searchParams]
  );

  const setActiveTab = useCallback(
    (next) => {
      const q = TAB_TO_QUERY[next];
      setSearchParams(q ? { tab: q } : {}, { replace: true });
    },
    [setSearchParams]
  );

  const [loading, setLoading] = useState(true);

  const [categories, setCategories] = useState([]);
  const [subCategories, setSubCategories] = useState([]);
  const [colors, setColors] = useState([]);
  const [products, setProducts] = useState([]);
  const [productsMeta, setProductsMeta] = useState({ total: 0, page: 1, limit: 10 });

  // Shared filters
  const [productSearch, setProductSearch] = useState("");
  const [productStatus, setProductStatus] = useState("");
  const [productInStock, setProductInStock] = useState(""); // "", "true", "false"

  const [catPage] = useState(1);
  const [catLimit] = useState(50);

  // Category modal state
  const [catModalOpen, setCatModalOpen] = useState(false);
  const [catEditing, setCatEditing] = useState(null);
  const [catForm, setCatForm] = useState({
    name: "",
    slug: "",
    description: "",
    parent_id: "",
    image: "",
    status: "active",
  });

  // SubCategory modal state
  const [subModalOpen, setSubModalOpen] = useState(false);
  const [subEditing, setSubEditing] = useState(null);
  const [subForm, setSubForm] = useState({
    category_id: "",
    name: "",
    slug: "",
    description: "",
    status: "active",
  });

  // Color modal state
  const [colorModalOpen, setColorModalOpen] = useState(false);
  const [colorEditing, setColorEditing] = useState(null);
  const [colorForm, setColorForm] = useState({ name: "", hex_code: "", status: "active" });

  // Product modal state
  const [productModalOpen, setProductModalOpen] = useState(false);
  const [productEditing, setProductEditing] = useState(null);
  const [productSaving, setProductSaving] = useState(false);

  // Image upload + crop modal state (required before setting image_url)
  const [cropOpen, setCropOpen] = useState(false);
  const [cropFile, setCropFile] = useState(null);
  const [cropTarget, setCropTarget] = useState(null); // { kind: 'product'|'variant', variantIndex?, imageIndex? }

  const blankProductForm = useMemo(
    () => ({
      name: "",
      slug: "",
      description: "",
      status: "active",
      is_featured: false,

      price: "",
      compare_at_price: "",
      cost: "",
      sku: "",
      barcode: "",
      quantity_override: "", // optional; if empty backend sums variants
      low_stock_threshold: "",
      weight: "",
      dimensions_json: "",
      seo_title: "",
      seo_description: "",

      categories_map: [{ category_id: "", sub_category_id: "" }],
      variants: [
        {
          color_id: "",
          sku: "",
          barcode: "",
          price: "",
          compare_at_price: "",
          quantity: "",
          image_url: "",
          status: "active",
        },
      ],
      product_images: [
        {
          image_url: "",
          is_primary: true,
          sort_order: 0,
          variant_id: "",
        },
      ],
    }),
    []
  );

  const [productForm, setProductForm] = useState(blankProductForm);

  const activeSubCatsForCategory = useMemo(() => {
    // we fetch on demand; for the form we just show whatever is currently in `subCategories`
    return subCategories;
  }, [subCategories]);

  const uploadsBase = getUploadsBaseUrl();

  const refreshAll = async () => {
    setLoading(true);
    try {
      const [catRes, colorRes] = await Promise.all([
        getAdminCategories({ page: catPage, limit: catLimit, status: "" }),
        getAdminColors({ page: 1, limit: 200, status: "" }),
      ]);
      setCategories(catRes?.data || []);
      setColors(colorRes?.data || []);
    } finally {
      setLoading(false);
    }
  };

  const refreshProducts = async () => {
    setLoading(true);
    try {
      const params = {
        page: productsMeta.page || 1,
        limit: productsMeta.limit || 10,
        status: productStatus || "",
        in_stock: productInStock || "",
        search: productSearch || "",
      };
      const res = await getAdminProducts(params);
      setProducts(res?.data || []);
      if (res?.total !== undefined) {
        setProductsMeta((m) => ({
          ...m,
          total: res.total,
          page: res.page || m.page,
          limit: res.limit || m.limit,
        }));
      } else if (res?.data?.total !== undefined) {
        setProductsMeta((m) => ({
          ...m,
          total: res.data.total,
          page: res.data.page || m.page,
          limit: res.data.limit || m.limit,
        }));
      }
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    refreshAll();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    if (activeTab === TAB.PRODUCTS) refreshProducts();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeTab, productSearch, productStatus, productInStock]);

  const openCategoryModal = (row = null) => {
    setCatEditing(row);
    setCatForm({
      name: row?.name || "",
      slug: row?.slug || "",
      description: row?.description || "",
      parent_id: row?.parent_id || "",
      image: row?.image || "",
      status: row?.status || "active",
    });
    setCatModalOpen(true);
  };

  const openSubCategoryModal = (row = null) => {
    setSubEditing(row);
    setSubForm({
      category_id: row?.category_id || "",
      name: row?.name || "",
      slug: row?.slug || "",
      description: row?.description || "",
      status: row?.status || "active",
    });
    setSubModalOpen(true);
  };

  const openColorModal = (row = null) => {
    setColorEditing(row);
    setColorForm({
      name: row?.name || "",
      hex_code: row?.hex_code || "",
      status: row?.status || "active",
    });
    setColorModalOpen(true);
  };

  const loadSubCategoriesFor = async (category_id) => {
    if (!category_id) {
      setSubCategories([]);
      return;
    }
    const res = await getAdminSubCategories({ category_id });
    setSubCategories(res?.data || []);
  };

  const pickImageForCrop = (nextFile, target) => {
    if (!nextFile) return;
    setCropFile(nextFile);
    setCropTarget(target);
    setCropOpen(true);
  };

  const handleCropUploaded = (url) => {
    if (!url || !cropTarget) return;
    setProductForm((f) => {
      if (!cropTarget) return f;
      if (cropTarget.kind === "variant") {
        const idx = cropTarget.variantIndex;
        if (typeof idx !== "number") return f;
        const next = [...(f.variants || [])];
        if (!next[idx]) return f;
        next[idx] = { ...next[idx], image_url: url };
        return { ...f, variants: next };
      }
      if (cropTarget.kind === "product") {
        const idx = cropTarget.imageIndex;
        if (typeof idx !== "number") return f;
        const next = [...(f.product_images || [])];
        if (!next[idx]) return f;
        next[idx] = { ...next[idx], image_url: url };
        return { ...f, product_images: next };
      }
      return f;
    });

    setCropOpen(false);
    setCropFile(null);
    setCropTarget(null);
  };

  const openProductModal = async (row = null) => {
    if (!row) {
      setProductEditing(null);
      setProductForm(blankProductForm);
      setProductModalOpen(true);
      return;
    }

    setProductSaving(false);
    setProductEditing(row);
    const res = await getAdminProduct(row.id);
    const p = res?.product || {};

    // categories mapping
    const catMap = (res?.categories || []).map((m) => ({
      category_id: m.category_id ?? "",
      sub_category_id: m.sub_category_id ?? "",
    })).slice(0, 1);

    // variants mapping
    const varRows = (res?.variants || []).map((v) => ({
      color_id: v.color_id ?? "",
      sku: v.sku ?? "",
      barcode: v.barcode ?? "",
      price: v.price ?? "",
      compare_at_price: v.compare_at_price ?? "",
      quantity: v.quantity ?? "",
      image_url: v.image_url ?? "",
      status: v.status ?? "active",
    }));

    const imgRows = (res?.images || []).map((img) => ({
      image_url: img.image_url ?? "",
      is_primary: !!img.is_primary,
      sort_order: img.sort_order ?? 0,
      variant_id: img.variant_id ?? "",
    }));

    setProductForm({
      name: p.name || "",
      slug: p.slug || "",
      description: p.description || "",
      status: p.status || "active",
      is_featured: !!p.is_featured,

      price: p.price ?? "",
      compare_at_price: p.compare_at_price ?? "",
      cost: p.cost ?? "",
      sku: p.sku ?? "",
      barcode: p.barcode ?? "",
      quantity_override: "",
      low_stock_threshold: p.low_stock_threshold ?? "",
      weight: p.weight ?? "",
      dimensions_json: p.dimensions ? JSON.stringify(p.dimensions, null, 2) : "",
      seo_title: p.seo_title ?? "",
      seo_description: p.seo_description ?? "",

      categories_map: catMap.length ? catMap : [{ category_id: "", sub_category_id: "" }],
      variants: varRows.length ? varRows : blankProductForm.variants,
      product_images: imgRows.length ? imgRows : [{ image_url: "", is_primary: true, sort_order: 0, variant_id: "" }],
    });

    // preload subcategories for first category row
    const firstCat = catMap[0]?.category_id;
    if (firstCat) await loadSubCategoriesFor(firstCat);

    setProductModalOpen(true);
  };

  const closeProductModal = () => {
    setProductModalOpen(false);
    setProductEditing(null);
  };

  const deleteProduct = async (row) => {
    if (!window.confirm(`Delete product ${row.name}?`)) return;
    await deleteAdminProduct(row.id);
    await refreshProducts();
  };

  const deleteCategory = async (row) => {
    if (!window.confirm(`Delete category ${row.name}?`)) return;
    await deleteAdminCategory(row.id);
    await refreshAll();
  };

  const deleteSubCategory = async (row) => {
    if (!window.confirm(`Delete sub-category ${row.name}?`)) return;
    await deleteAdminSubCategory(row.id);
    const cid = subForm.category_id || "";
    if (cid) await loadSubCategoriesFor(cid);
  };

  const deleteColor = async (row) => {
    if (!window.confirm(`Delete color ${row.name}?`)) return;
    await deleteAdminColor(row.id);
    await refreshAll();
  };

  const handleCategorySubmit = async (e) => {
    e.preventDefault();
    const payload = {
      name: catForm.name,
      slug: sanitizeSlug(catForm.slug || catForm.name),
      description: catForm.description || null,
      parent_id: catForm.parent_id ? Number(catForm.parent_id) : null,
      image: catForm.image || null,
      status: catForm.status,
    };
    if (catEditing) {
      await updateAdminCategory(catEditing.id, payload);
    } else {
      await createAdminCategory(payload);
    }
    setCatModalOpen(false);
    setCatEditing(null);
    await refreshAll();
  };

  const handleSubCategorySubmit = async (e) => {
    e.preventDefault();
    const payload = {
      category_id: Number(subForm.category_id),
      name: subForm.name,
      slug: sanitizeSlug(subForm.slug || subForm.name),
      description: subForm.description || null,
      status: subForm.status,
    };
    if (subEditing) {
      await updateAdminSubCategory(subEditing.id, payload);
    } else {
      await createAdminSubCategory(payload);
    }
    setSubModalOpen(false);
    setSubEditing(null);
    await loadSubCategoriesFor(payload.category_id);
  };

  const handleColorSubmit = async (e) => {
    e.preventDefault();
    const payload = {
      name: colorForm.name,
      hex_code: colorForm.hex_code,
      status: colorForm.status,
    };
    if (colorEditing) {
      await updateAdminColor(colorEditing.id, payload);
    } else {
      await createAdminColor(payload);
    }
    setColorModalOpen(false);
    setColorEditing(null);
    await refreshAll();
  };

  const productPayloadFromForm = () => {
    const categories = (productForm.categories_map || []).filter((r) => r.category_id);
    const variants = (productForm.variants || []).filter((v) => v.color_id && v.sku);
    const product_images = (productForm.product_images || []).filter((im) => im.image_url);

    const catPayload = categories.map((r) => ({
      category_id: Number(r.category_id),
      sub_category_id: r.sub_category_id ? Number(r.sub_category_id) : null,
    }));

    const varPayload = variants.map((v) => ({
      color_id: Number(v.color_id),
      sku: v.sku,
      barcode: v.barcode ? v.barcode : null,
      price: toDecimalOrNull(v.price) || "0",
      compare_at_price: toDecimalOrNull(v.compare_at_price),
      quantity: toIntOrNull(v.quantity) ?? 0,
      image_url: v.image_url ? v.image_url : null,
      status: v.status || "active",
    }));

    const imgPayload = product_images.map((im, idx) => ({
      image_url: im.image_url,
      is_primary: im.is_primary ?? false,
      sort_order: typeof im.sort_order === "number" ? im.sort_order : toIntOrNull(im.sort_order) ?? idx,
      variant_id: im.variant_id ? Number(im.variant_id) : null,
    }));

    return {
      name: productForm.name,
      description: productForm.description || null,
      slug: sanitizeSlug(productForm.slug || productForm.name),
      status: productForm.status || "active",
      is_featured: !!productForm.is_featured,

      price: toDecimalOrNull(productForm.price) || "0",
      compare_at_price: toDecimalOrNull(productForm.compare_at_price),
      cost: toDecimalOrNull(productForm.cost) || "0",
      sku: productForm.sku ? productForm.sku : null,
      barcode: productForm.barcode ? productForm.barcode : null,
      quantity: null, // keep backend computed from variants unless you explicitly add override support
      low_stock_threshold: toIntOrNull(productForm.low_stock_threshold),
      weight: toDecimalOrNull(productForm.weight) || "0",

      dimensions: safeParseJSON(productForm.dimensions_json),
      seo_title: productForm.seo_title || null,
      seo_description: productForm.seo_description || null,

      categories: catPayload,
      variants: varPayload,
      product_images: imgPayload,
    };
  };

  const handleProductSave = async (e) => {
    e.preventDefault();
    setProductSaving(true);
    try {
      const payload = productPayloadFromForm();
      if (!payload.categories.length) {
        alert("Please add at least one category mapping.");
        return;
      }
      if (!payload.variants.length) {
        alert("Please add at least one variant (color + sku).");
        return;
      }
      if (!payload.product_images.length) {
        alert("Please upload at least one product image (cover).");
        return;
      }
      if (!payload.product_images.some((im) => im.is_primary)) {
        alert("Please mark one product image as Primary (cover).");
        return;
      }
      if (productEditing) {
        await updateAdminProduct(productEditing.id, payload);
      } else {
        await createAdminProduct(payload);
      }
      closeProductModal();
      await refreshProducts();
      await refreshAll();
    } catch (err) {
      alert(err?.response?.data?.error || err.message || "Save failed");
    } finally {
      setProductSaving(false);
    }
  };

  const renderCategoriesTab = () => (
    <div className="ecom-tab-panel">
      <div className="ecom-toolbar">
        <button className="primary-btn" type="button" onClick={() => openCategoryModal(null)}>
          <Plus size={18} />
          Add Category
        </button>
      </div>

      <div className="ecom-table-wrap">
        <table className="ecom-table">
          <thead>
            <tr>
              <th>Name</th>
              <th>Slug</th>
              <th>Parent</th>
              <th>Status</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {(categories || []).map((row) => (
              <tr key={row.id}>
                <td>{row.name}</td>
                <td><code className="ecom-code">{row.slug}</code></td>
                <td>{row.parent_id ?? "—"}</td>
                <td>{row.status}</td>
                <td className="ecom-actions">
                  <button className="ecom-icon-btn" type="button" onClick={() => openCategoryModal(row)}>
                    <Edit size={16} />
                  </button>
                  <button className="ecom-icon-btn ecom-danger" type="button" onClick={() => deleteCategory(row)}>
                    <Trash2 size={16} />
                  </button>
                </td>
              </tr>
            ))}
            {!categories.length && (
              <tr>
                <td colSpan={5} className="ecom-empty">
                  No categories.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );

  const renderSubCategoriesTab = () => (
    <div className="ecom-tab-panel">
      <div className="ecom-toolbar">
        <select
          className="ecom-select"
          value={subForm.category_id}
          onChange={(e) => {
            const v = e.target.value;
            setSubForm((f) => ({ ...f, category_id: v }));
            loadSubCategoriesFor(v);
          }}
        >
          <option value="">Select Category</option>
          {categories.map((c) => (
            <option key={c.id} value={c.id}>
              {c.name}
            </option>
          ))}
        </select>
        <button
          className="primary-btn"
          type="button"
          onClick={() => {
            if (!subForm.category_id) return alert("Select a category first.");
            openSubCategoryModal(null);
          }}
        >
          <Plus size={18} />
          Add Sub-Category
        </button>
      </div>

      <div className="ecom-table-wrap">
        <table className="ecom-table">
          <thead>
            <tr>
              <th>Name</th>
              <th>Slug</th>
              <th>Category</th>
              <th>Status</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {(subCategories || []).map((row) => (
              <tr key={row.id}>
                <td>{row.name}</td>
                <td><code className="ecom-code">{row.slug}</code></td>
                <td>{row.category_id}</td>
                <td>{row.status}</td>
                <td className="ecom-actions">
                  <button className="ecom-icon-btn" type="button" onClick={() => openSubCategoryModal(row)}>
                    <Edit size={16} />
                  </button>
                  <button className="ecom-icon-btn ecom-danger" type="button" onClick={() => deleteSubCategory(row)}>
                    <Trash2 size={16} />
                  </button>
                </td>
              </tr>
            ))}
            {!subCategories.length && (
              <tr>
                <td colSpan={5} className="ecom-empty">
                  No sub-categories. Select a category.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );

  const renderColorsTab = () => (
    <div className="ecom-tab-panel">
      <div className="ecom-toolbar">
        <button className="primary-btn" type="button" onClick={() => openColorModal(null)}>
          <Plus size={18} />
          Add Color
        </button>
      </div>

      <div className="ecom-table-wrap">
        <table className="ecom-table">
          <thead>
            <tr>
              <th>Name</th>
              <th>Hex</th>
              <th>Status</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {(colors || []).map((row) => (
              <tr key={row.id}>
                <td>{row.name}</td>
                <td>
                  <span className="ecom-color-dot" style={{ background: row.hex_code }} />{" "}
                  <code className="ecom-code">{row.hex_code}</code>
                </td>
                <td>{row.status}</td>
                <td className="ecom-actions">
                  <button className="ecom-icon-btn" type="button" onClick={() => openColorModal(row)}>
                    <Edit size={16} />
                  </button>
                  <button className="ecom-icon-btn ecom-danger" type="button" onClick={() => deleteColor(row)}>
                    <Trash2 size={16} />
                  </button>
                </td>
              </tr>
            ))}
            {!colors.length && (
              <tr>
                <td colSpan={4} className="ecom-empty">
                  No colors.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );

  const renderProductsTab = () => (
    <div className="ecom-tab-panel">
      <div className="ecom-toolbar ecom-toolbar-wrap">
        <div className="ecom-search">
          <Search size={18} />
          <input
            value={productSearch}
            onChange={(e) => setProductSearch(e.target.value)}
            placeholder="Search by name or slug"
          />
        </div>
        <div className="ecom-filters">
          <select className="ecom-select" value={productStatus} onChange={(e) => setProductStatus(e.target.value)}>
            <option value="">Status: all</option>
            {statusOptions.map((s) => (
              <option key={s} value={s}>
                {s}
              </option>
            ))}
          </select>
          <select className="ecom-select" value={productInStock} onChange={(e) => setProductInStock(e.target.value)}>
            <option value="">Stock: all</option>
            <option value="true">In stock</option>
            <option value="false">Out / low stock</option>
          </select>
        </div>

        <button className="primary-btn" type="button" onClick={() => openProductModal(null)}>
          <Plus size={18} />
          Add Product
        </button>
      </div>

      <div className="ecom-table-wrap">
        <table className="ecom-table">
          <thead>
            <tr>
              <th>Image</th>
              <th>Name</th>
              <th>Slug</th>
              <th>Price</th>
              <th>Stock</th>
              <th>Status</th>
              <th>Featured</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {(products || []).map((p) => {
              const qty = Number(p.quantity ?? 0);
              const lowThreshold = Number(p.low_stock_threshold ?? 0);
              const low =
                lowThreshold > 0 && qty > 0 && qty <= lowThreshold;
              const stockLabel = qty <= 0 ? "Out" : low ? "Low" : "In";
              const stockClass = low ? "warn" : qty <= 0 ? "danger" : "ok";

              const thumb = adminProductThumbUrl(p, getUploadsBaseUrl());
              return (
                <tr key={p.id}>
                  <td className="ecom-td-thumb">
                    {thumb ? (
                      <img className="ecom-product-thumb" src={thumb} alt="" width={44} height={44} loading="lazy" />
                    ) : (
                      <span className="ecom-thumb-fallback">—</span>
                    )}
                  </td>
                  <td>{p.name}</td>
                  <td><code className="ecom-code">{p.slug}</code></td>
                  <td>₹{p.price ?? "0"}</td>
                  <td>
                    <span className={`ecom-stock-badge ${stockClass}`}>
                      {stockLabel}
                    </span>
                    <span className="ecom-stock-qty">({qty})</span>
                  </td>
                  <td>{p.status}</td>
                  <td>{p.is_featured ? "Yes" : "No"}</td>
                  <td className="ecom-actions">
                    <button className="ecom-icon-btn" type="button" onClick={() => openProductModal(p)}>
                      <Edit size={16} />
                    </button>
                    <button className="ecom-icon-btn ecom-danger" type="button" onClick={() => deleteProduct(p)}>
                      <Trash2 size={16} />
                    </button>
                  </td>
                </tr>
              );
            })}
            {!products.length && (
              <tr>
                <td colSpan={8} className="ecom-empty">
                  No products.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      {/* Pagination can be added later; for now the list uses server pagination (page/limit) */}
    </div>
  );

  return (
    <div className="ecom-page">
      <div className="page-header ecom-page-header-row">
        <div className="title-area">
          <Layers className="header-icon" />
          <div>
            <h1>E-commerce Admin</h1>
            <p>Manage categories, sub-categories, colors, and products with variants.</p>
          </div>
        </div>
        <a
          className="text-btn ecom-storefront-link"
          href="http://localhost:5174/"
          target="_blank"
          rel="noopener noreferrer"
        >
          <ExternalLink size={16} /> View storefront
        </a>
      </div>

      <div className="ecom-tabs">
        <button className={`ecom-tab-btn ${activeTab === TAB.CATEGORIES ? "active" : ""}`} type="button" onClick={() => setActiveTab(TAB.CATEGORIES)}>
          <TagIcon size={16} /> Categories
        </button>
        <button className={`ecom-tab-btn ${activeTab === TAB.SUB_CATEGORIES ? "active" : ""}`} type="button" onClick={() => setActiveTab(TAB.SUB_CATEGORIES)}>
          <Package size={16} /> Sub-categories
        </button>
        <button className={`ecom-tab-btn ${activeTab === TAB.COLORS ? "active" : ""}`} type="button" onClick={() => setActiveTab(TAB.COLORS)}>
          <Palette size={16} /> Colors
        </button>
        <button className={`ecom-tab-btn ${activeTab === TAB.PRODUCTS ? "active" : ""}`} type="button" onClick={() => setActiveTab(TAB.PRODUCTS)}>
          <Layers size={16} /> Products
        </button>
      </div>

      {loading && activeTab !== TAB.PRODUCTS ? <div className="ecom-loader">Loading…</div> : null}
      {!loading && activeTab === TAB.CATEGORIES ? renderCategoriesTab() : null}
      {!loading && activeTab === TAB.SUB_CATEGORIES ? renderSubCategoriesTab() : null}
      {!loading && activeTab === TAB.COLORS ? renderColorsTab() : null}
      {!loading && activeTab === TAB.PRODUCTS ? renderProductsTab() : null}

      {catModalOpen && (
        <ModalShell title={catEditing ? "Edit Category" : "Add Category"} onClose={() => setCatModalOpen(false)}>
          <form className="ecom-form" onSubmit={handleCategorySubmit}>
            <div className="ecom-grid">
              <div className="ecom-field">
                <label>Name</label>
                <input
                  value={catForm.name}
                  onChange={(e) => {
                    const v = e.target.value;
                    setCatForm((f) => ({ ...f, name: v, slug: f.slug || sanitizeSlug(v) }));
                  }}
                  required
                />
              </div>
              <div className="ecom-field">
                <label>Slug</label>
                <input value={catForm.slug} onChange={(e) => setCatForm((f) => ({ ...f, slug: e.target.value }))} required />
              </div>
            </div>
            <div className="ecom-grid">
              <div className="ecom-field">
                <label>Description</label>
                <textarea value={catForm.description} onChange={(e) => setCatForm((f) => ({ ...f, description: e.target.value }))} rows={3} />
              </div>
              <div className="ecom-field">
                <label>Parent ID (optional)</label>
                <input value={catForm.parent_id} onChange={(e) => setCatForm((f) => ({ ...f, parent_id: e.target.value }))} />
              </div>
            </div>
            <div className="ecom-grid">
              <div className="ecom-field">
                <label>Image URL (optional)</label>
                <input value={catForm.image} onChange={(e) => setCatForm((f) => ({ ...f, image: e.target.value }))} placeholder="/uploads/..." />
              </div>
              <div className="ecom-field">
                <label>Status</label>
                <select value={catForm.status} onChange={(e) => setCatForm((f) => ({ ...f, status: e.target.value }))}>
                  {statusOptions.map((s) => (
                    <option key={s} value={s}>{s}</option>
                  ))}
                </select>
              </div>
            </div>
            <div className="modal-footer">
              <button type="button" className="secondary-btn" onClick={() => setCatModalOpen(false)}>Cancel</button>
              <button type="submit" className="primary-btn"><Save size={18} /> {catEditing ? "Update" : "Create"}</button>
            </div>
          </form>
        </ModalShell>
      )}

      {subModalOpen && (
        <ModalShell title={subEditing ? "Edit Sub-Category" : "Add Sub-Category"} onClose={() => setSubModalOpen(false)}>
          <form className="ecom-form" onSubmit={handleSubCategorySubmit}>
            <div className="ecom-grid">
              <div className="ecom-field">
                <label>Category</label>
                <select value={subForm.category_id} onChange={(e) => setSubForm((f) => ({ ...f, category_id: e.target.value }))} required>
                  <option value="">Select</option>
                  {categories.map((c) => (
                    <option key={c.id} value={c.id}>{c.name}</option>
                  ))}
                </select>
              </div>
              <div className="ecom-field">
                <label>Name</label>
                <input value={subForm.name} onChange={(e) => {
                  const v = e.target.value;
                  setSubForm((f) => ({ ...f, name: v, slug: f.slug || sanitizeSlug(v) }));
                }} required />
              </div>
            </div>
            <div className="ecom-grid">
              <div className="ecom-field">
                <label>Slug</label>
                <input value={subForm.slug} onChange={(e) => setSubForm((f) => ({ ...f, slug: e.target.value }))} required />
              </div>
              <div className="ecom-field">
                <label>Status</label>
                <select value={subForm.status} onChange={(e) => setSubForm((f) => ({ ...f, status: e.target.value }))}>
                  {statusOptions.map((s) => (
                    <option key={s} value={s}>{s}</option>
                  ))}
                </select>
              </div>
            </div>
            <div className="ecom-grid">
              <div className="ecom-field">
                <label>Description</label>
                <textarea value={subForm.description} onChange={(e) => setSubForm((f) => ({ ...f, description: e.target.value }))} rows={3} />
              </div>
            </div>
            <div className="modal-footer">
              <button type="button" className="secondary-btn" onClick={() => setSubModalOpen(false)}>Cancel</button>
              <button type="submit" className="primary-btn"><Save size={18} /> {subEditing ? "Update" : "Create"}</button>
            </div>
          </form>
        </ModalShell>
      )}

      {colorModalOpen && (
        <ModalShell title={colorEditing ? "Edit Color" : "Add Color"} onClose={() => setColorModalOpen(false)}>
          <form className="ecom-form" onSubmit={handleColorSubmit}>
            <div className="ecom-grid">
              <div className="ecom-field">
                <label>Name</label>
                <input value={colorForm.name} onChange={(e) => setColorForm((f) => ({ ...f, name: e.target.value }))} required />
              </div>
              <div className="ecom-field">
                <label>Hex code</label>
                <input value={colorForm.hex_code} onChange={(e) => setColorForm((f) => ({ ...f, hex_code: e.target.value }))} required placeholder="#ff0000" />
              </div>
            </div>
            <div className="ecom-grid">
              <div className="ecom-field">
                <label>Status</label>
                <select value={colorForm.status} onChange={(e) => setColorForm((f) => ({ ...f, status: e.target.value }))}>
                  {statusOptions.map((s) => (
                    <option key={s} value={s}>{s}</option>
                  ))}
                </select>
              </div>
              <div className="ecom-field">
                <label>Preview</label>
                <div className="ecom-color-preview">
                  <span className="ecom-color-dot-lg" style={{ background: colorForm.hex_code || "#fff" }} />
                </div>
              </div>
            </div>
            <div className="modal-footer">
              <button type="button" className="secondary-btn" onClick={() => setColorModalOpen(false)}>Cancel</button>
              <button type="submit" className="primary-btn"><Save size={18} /> {colorEditing ? "Update" : "Create"}</button>
            </div>
          </form>
        </ModalShell>
      )}

      {productModalOpen && (
        <ModalShell
          title={productEditing ? `Edit Product #${productEditing.id}` : "Add Product"}
          onClose={closeProductModal}
          footer={
            <div />
          }
        >
          <form className="ecom-form ecom-form-scroll" onSubmit={handleProductSave}>
            <div className="ecom-section">
              <h4>Basic</h4>
              <div className="ecom-grid">
                <div className="ecom-field">
                  <label>Name</label>
                  <input value={productForm.name} onChange={(e) => {
                    const v = e.target.value;
                    setProductForm((f) => ({ ...f, name: v, slug: f.slug || sanitizeSlug(v) }));
                  }} required />
                </div>
                <div className="ecom-field">
                  <label>Slug</label>
                  <input value={productForm.slug} onChange={(e) => setProductForm((f) => ({ ...f, slug: e.target.value }))} required />
                </div>
              </div>
              <div className="ecom-grid">
                <div className="ecom-field">
                  <label>Description</label>
                  <textarea rows={3} value={productForm.description} onChange={(e) => setProductForm((f) => ({ ...f, description: e.target.value }))} />
                </div>
                <div className="ecom-field">
                  <label>Status</label>
                  <select value={productForm.status} onChange={(e) => setProductForm((f) => ({ ...f, status: e.target.value }))}>
                    {statusOptions.map((s) => <option key={s} value={s}>{s}</option>)}
                  </select>
                  <label className="sr-only">is featured</label>
                  <div className="ecom-check">
                    <label className="switch-label">
                      <input
                        type="checkbox"
                        checked={productForm.is_featured}
                        onChange={(e) => setProductForm((f) => ({ ...f, is_featured: e.target.checked }))}
                      />
                      <span className="slider" />
                      <span className="label-text">Featured</span>
                    </label>
                  </div>
                </div>
              </div>
              <div className="ecom-grid-4">
                <div className="ecom-field">
                  <label>Price</label>
                  <input value={productForm.price} onChange={(e) => setProductForm((f) => ({ ...f, price: e.target.value }))} />
                </div>
                <div className="ecom-field">
                  <label>Compare at</label>
                  <input value={productForm.compare_at_price} onChange={(e) => setProductForm((f) => ({ ...f, compare_at_price: e.target.value }))} />
                </div>
                <div className="ecom-field">
                  <label>Cost</label>
                  <input value={productForm.cost} onChange={(e) => setProductForm((f) => ({ ...f, cost: e.target.value }))} />
                </div>
                <div className="ecom-field">
                  <label>SKU</label>
                  <input value={productForm.sku} onChange={(e) => setProductForm((f) => ({ ...f, sku: e.target.value }))} />
                </div>
              </div>
              <div className="ecom-grid-4">
                <div className="ecom-field">
                  <label>Barcode</label>
                  <input value={productForm.barcode} onChange={(e) => setProductForm((f) => ({ ...f, barcode: e.target.value }))} />
                </div>
                <div className="ecom-field">
                  <label>Low stock threshold</label>
                  <input value={productForm.low_stock_threshold} onChange={(e) => setProductForm((f) => ({ ...f, low_stock_threshold: e.target.value }))} />
                </div>
                <div className="ecom-field">
                  <label>Weight</label>
                  <input value={productForm.weight} onChange={(e) => setProductForm((f) => ({ ...f, weight: e.target.value }))} />
                </div>
                <div className="ecom-field">
                  <label>Quantity override (optional)</label>
                  <input value={productForm.quantity_override} onChange={(e) => setProductForm((f) => ({ ...f, quantity_override: e.target.value }))} placeholder="leave empty to auto" />
                </div>
              </div>
            </div>

            <div className="ecom-section">
              <h4>Categories mapping</h4>
              <div className="ecom-rows">
                {productForm.categories_map.slice(0, 1).map((row, idx) => (
                  <div className="ecom-row-variants" key={idx}>
                    <select
                      className="ecom-select"
                      value={row.category_id}
                      onChange={async (e) => {
                        const v = e.target.value;
                        setProductForm((f) => {
                          const next = [...f.categories_map];
                          next[idx] = { ...next[idx], category_id: v, sub_category_id: "" };
                          return { ...f, categories_map: next };
                        });
                        await loadSubCategoriesFor(v);
                      }}
                      required
                    >
                      <option value="">Select category</option>
                      {categories.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
                    </select>
                    <select
                      className="ecom-select"
                      value={row.sub_category_id}
                      onChange={(e) => {
                        const v = e.target.value;
                        setProductForm((f) => {
                          const next = [...f.categories_map];
                          next[idx] = { ...next[idx], sub_category_id: v };
                          return { ...f, categories_map: next };
                        });
                      }}
                    >
                      <option value="">No sub-category</option>
                      {activeSubCatsForCategory.map((sc) => (
                        <option key={sc.id} value={sc.id}>{sc.name}</option>
                      ))}
                    </select>
                  </div>
                ))}
              </div>
            </div>

            <div className="ecom-section">
              <h4>Variants (color)</h4>
              <div className="ecom-rows">
                {productForm.variants.map((v, idx) => (
                  <div className="ecom-row-variants" key={idx}>
                    <select
                      className="ecom-select"
                      value={v.color_id}
                      onChange={(e) => {
                        const val = e.target.value;
                        setProductForm((f) => {
                          const next = [...f.variants];
                          next[idx] = { ...next[idx], color_id: val };
                          return { ...f, variants: next };
                        });
                      }}
                      required
                    >
                      <option value="">Select color</option>
                      {colors.map((c) => (
                        <option key={c.id} value={c.id}>{c.name}</option>
                      ))}
                    </select>
                    <input
                      className="ecom-input"
                      value={v.sku}
                      placeholder="Variant SKU"
                      onChange={(e) => {
                        const val = e.target.value;
                        setProductForm((f) => {
                          const next = [...f.variants];
                          next[idx] = { ...next[idx], sku: val };
                          return { ...f, variants: next };
                        });
                      }}
                      required
                    />
                    <input
                      className="ecom-input"
                      value={v.price}
                      placeholder="Price"
                      onChange={(e) => {
                        const val = e.target.value;
                        setProductForm((f) => {
                          const next = [...f.variants];
                          next[idx] = { ...next[idx], price: val };
                          return { ...f, variants: next };
                        });
                      }}
                    />
                    <input
                      className="ecom-input"
                      value={v.quantity}
                      placeholder="Qty"
                      onChange={(e) => {
                        const val = e.target.value;
                        setProductForm((f) => {
                          const next = [...f.variants];
                          next[idx] = { ...next[idx], quantity: val };
                          return { ...f, variants: next };
                        });
                      }}
                    />
                    <div className="ecom-image-cell">
                      {v.image_url ? (
                        <img src={`${uploadsBase}${v.image_url}`} alt="" loading="lazy" className="ecom-thumb" />
                      ) : (
                        <div className="ecom-image-placeholder">No image</div>
                      )}
                      <label className="ecom-upload-btn" title="Upload image (crop required)">
                        Upload & Crop
                        <input
                          type="file"
                          accept="image/*"
                          style={{ display: "none" }}
                          onChange={(e) => {
                            const f = e.target.files?.[0];
                            e.target.value = "";
                            pickImageForCrop(f, { kind: "variant", variantIndex: idx });
                          }}
                        />
                      </label>
                    </div>
                    <select
                      className="ecom-select"
                      value={v.status}
                      onChange={(e) => {
                        const val = e.target.value;
                        setProductForm((f) => {
                          const next = [...f.variants];
                          next[idx] = { ...next[idx], status: val };
                          return { ...f, variants: next };
                        });
                      }}
                    >
                      {statusOptions.map((s) => <option key={s} value={s}>{s}</option>)}
                    </select>
                    <button
                      type="button"
                      className="ecom-icon-btn ecom-danger"
                      onClick={() =>
                        setProductForm((f) => ({
                          ...f,
                          variants: f.variants.length > 1 ? f.variants.filter((_, i) => i !== idx) : f.variants,
                        }))
                      }
                      title="Remove variant"
                    >
                      <Trash2 size={16} />
                    </button>
                  </div>
                ))}
              </div>
              <button
                type="button"
                className="secondary-btn"
                onClick={() =>
                  setProductForm((f) => ({
                    ...f,
                    variants: [
                      ...f.variants,
                      { color_id: "", sku: "", barcode: "", price: "", compare_at_price: "", quantity: "", image_url: "", status: "active" },
                    ],
                  }))
                }
              >
                <Plus size={16} /> Add variant
              </button>
            </div>

            <div className="ecom-section">
              <h4>Product images (Upload + Crop)</h4>
              <p className="ecom-note">
                Upload images from your device. Crop is required before the image is stored.
              </p>
              <div className="ecom-rows">
                {productForm.product_images.map((im, idx) => (
                  <div className="ecom-row-images" key={idx}>
                    <div className="ecom-image-cell">
                      {im.image_url ? (
                        <img src={`${uploadsBase}${im.image_url}`} alt="" loading="lazy" className="ecom-thumb" />
                      ) : (
                        <div className="ecom-image-placeholder">No image</div>
                      )}
                      <label className="ecom-upload-btn" title="Upload image (crop required)">
                        Upload & Crop
                        <input
                          type="file"
                          accept="image/*"
                          style={{ display: "none" }}
                          onChange={(e) => {
                            const f = e.target.files?.[0];
                            e.target.value = "";
                            pickImageForCrop(f, { kind: "product", imageIndex: idx });
                          }}
                        />
                      </label>
                    </div>
                    <label className="switch-label">
                      <input
                        type="checkbox"
                        checked={!!im.is_primary}
                        onChange={(e) => {
                          const v = e.target.checked;
                          setProductForm((f) => {
                            const next = [...f.product_images];
                            next[idx] = { ...next[idx], is_primary: v };
                            return { ...f, product_images: next };
                          });
                        }}
                      />
                      <span className="slider" />
                      <span className="label-text">Primary</span>
                    </label>
                    <input
                      className="ecom-input"
                      value={im.sort_order}
                      placeholder="Sort order"
                      onChange={(e) => {
                        const val = e.target.value;
                        setProductForm((f) => {
                          const next = [...f.product_images];
                          next[idx] = { ...next[idx], sort_order: toIntOrNull(val) ?? 0 };
                          return { ...f, product_images: next };
                        });
                      }}
                    />
                    <select
                      className="ecom-select"
                      value={im.variant_id}
                      onChange={(e) => {
                        const val = e.target.value;
                        setProductForm((f) => {
                          const next = [...f.product_images];
                          next[idx] = { ...next[idx], variant_id: val };
                          return { ...f, product_images: next };
                        });
                      }}
                    >
                      <option value="">Variant (optional)</option>
                      {(productForm.variants || [])
                        .filter((v) => v.id)
                        .map((v) => (
                          <option key={v.id} value={v.id}>
                            {v.sku} ({v.color?.name || v.color_id})
                          </option>
                        ))}
                    </select>
                    <button
                      type="button"
                      className="ecom-icon-btn ecom-danger"
                      onClick={() =>
                        setProductForm((f) => ({
                          ...f,
                          product_images:
                            f.product_images.length > 1 ? f.product_images.filter((_, i) => i !== idx) : f.product_images,
                        }))
                      }
                      title="Remove image"
                    >
                      <Trash2 size={16} />
                    </button>
                  </div>
                ))}
              </div>
              <button
                type="button"
                className="secondary-btn"
                onClick={() =>
                  setProductForm((f) => ({
                    ...f,
                    product_images: [
                      ...f.product_images,
                      { image_url: "", is_primary: false, sort_order: (f.product_images.length || 0), variant_id: "" },
                    ],
                  }))
                }
              >
                <Plus size={16} /> Add image
              </button>
            </div>

            <div className="ecom-section">
              <h4>SEO & dimensions</h4>
              <div className="ecom-grid">
                <div className="ecom-field">
                  <label>SEO title</label>
                  <input value={productForm.seo_title} onChange={(e) => setProductForm((f) => ({ ...f, seo_title: e.target.value }))} />
                </div>
                <div className="ecom-field">
                  <label>SEO description</label>
                  <input value={productForm.seo_description} onChange={(e) => setProductForm((f) => ({ ...f, seo_description: e.target.value }))} />
                </div>
              </div>
              <div className="ecom-grid">
                <div className="ecom-field ecom-field-full">
                  <label>Dimensions JSON (optional)</label>
                  <textarea
                    rows={4}
                    value={productForm.dimensions_json}
                    onChange={(e) => setProductForm((f) => ({ ...f, dimensions_json: e.target.value }))}
                    placeholder='e.g. { "length": 10, "width": 5, "height": 2 }'
                  />
                </div>
              </div>
            </div>

            <div className="modal-footer">
              <button type="button" className="secondary-btn" onClick={closeProductModal}>
                Cancel
              </button>
              <button type="submit" className="primary-btn" disabled={productSaving}>
                {productSaving ? <Loader2 size={18} className="spinner" /> : <Save size={18} />}
                Save Product
              </button>
            </div>
          </form>
        </ModalShell>
      )}

      <ImageCropUploadModal
        open={cropOpen}
        file={cropFile}
        kind={cropTarget?.kind}
        onClose={() => {
          setCropOpen(false);
          setCropFile(null);
          setCropTarget(null);
        }}
        onUploaded={handleCropUploaded}
      />
    </div>
  );
};

export default EcomAdmin;

