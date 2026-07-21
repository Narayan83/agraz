import React, { useState, useEffect } from "react";
import { useLocation } from "react-router-dom";
import { 
  Menu as MenuIcon, 
  Plus, 
  Search, 
  Edit, 
  Trash2, 
  X, 
  Folder, 
  FileText, 
  ChevronRight, 
  ChevronDown,
  Layout,
  ExternalLink,
  ChevronLeft,
  Loader2,
  Lock,
  Eye,
  Settings,
  Activity
} from "lucide-react";
import { getMenus, getMenuTree, createMenu, updateMenu, deleteMenu } from "../api/api";
import "./MenuManagement.css";

const MenuManagement = () => {
  const location = useLocation();
  const [menus, setMenus] = useState([]);
  const [menuTree, setMenuTree] = useState([]);
  const [viewMode, setViewMode] = useState(location.pathname === "/existingmenus" ? "tree" : "list"); 
  const [loading, setLoading] = useState(true);
  
  // Pagination
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [searchTerm, setSearchTerm] = useState("");
  const limit = 10;

  // Modal & Form
  const [modalOpen, setModalOpen] = useState(false);
  const [selectedMenu, setSelectedMenu] = useState(null);
  const [formData, setFormData] = useState({
    menu_name: "",
    description: "",
    url: "",
    icon: "LayoutDashboard",
    parent_id: null,
    sort_order: 0,
    menu_type: "main",
    is_active: true,
    requires_auth: false
  });

  const [expandedNodes, setExpandedNodes] = useState(new Set());

  // Sync viewMode with URL path when it changes
  useEffect(() => {
    if (location.pathname === "/existingmenus") {
      setViewMode("tree");
    } else {
      setViewMode("list");
    }
    setPage(1);
  }, [location.pathname]);

  useEffect(() => {
    if (viewMode === "list") {
      fetchMenus();
    } else {
      fetchMenuTree();
    }
  }, [viewMode, page, searchTerm]);

  const fetchMenus = async () => {
    setLoading(true);
    try {
      const response = await getMenus(page, limit, searchTerm);
      setMenus(response.data || []);
      setTotalPages(Math.ceil(response.total / limit) || 1);
    } catch (err) {
      console.error("Error fetching menus:", err);
    } finally {
      setLoading(false);
    }
  };

  const fetchMenuTree = async () => {
    setLoading(true);
    try {
      const data = await getMenuTree();
      setMenuTree(data || []);
      console.log("Tree Data Loaded:", data);
    } catch (err) {
      console.error("Error fetching menu tree:", err);
    } finally {
      setLoading(false);
    }
  };

  const handleRefresh = () => {
    if (viewMode === 'list') fetchMenus(); else fetchMenuTree();
  };

  const openModal = (menu = null) => {
    if (menu) {
      setSelectedMenu(menu);
      setFormData({
        menu_name: menu.menu_name || "",
        description: menu.description || "",
        url: menu.url || "",
        icon: menu.icon || "LayoutDashboard",
        parent_id: menu.parent_id || null,
        sort_order: menu.sort_order || 0,
        menu_type: menu.menu_type || "main",
        is_active: menu.is_active ?? true,
        requires_auth: menu.requires_auth ?? false
      });
    } else {
      setSelectedMenu(null);
      setFormData({
        menu_name: "",
        description: "",
        url: "",
        icon: "LayoutDashboard",
        parent_id: null,
        sort_order: 0,
        menu_type: "main",
        is_active: true,
        requires_auth: false
      });
    }
    setModalOpen(true);
  };

  const closeModal = () => {
    setModalOpen(false);
    setSelectedMenu(null);
  };

  const handleInputChange = (e) => {
    const { name, value, type, checked } = e.target;
    setFormData(prev => ({
      ...prev,
      [name]: type === 'checkbox' ? checked : (name === 'parent_id' && value === '' ? null : (name === 'sort_order' || name === 'parent_id' ? Number(value) : value))
    }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      if (selectedMenu) {
        await updateMenu(selectedMenu.id, formData);
      } else {
        await createMenu(formData);
      }
      closeModal();
      if (viewMode === "list") fetchMenus(); else fetchMenuTree();
    } catch (err) {
      console.error("Error saving menu:", err);
      alert(err.response?.data?.error || "Failed to save menu");
    }
  };

  const handleDelete = async (id) => {
    if (window.confirm("Are you sure you want to delete this menu item? Children will also be affected.")) {
      try {
        await deleteMenu(id);
        if (viewMode === "list") fetchMenus(); else fetchMenuTree();
      } catch (err) {
        console.error("Error deleting menu:", err);
      }
    }
  };

  const toggleNode = (id) => {
    const newExpanded = new Set(expandedNodes);
    if (newExpanded.has(id)) newExpanded.delete(id);
    else newExpanded.add(id);
    setExpandedNodes(newExpanded);
  };

  const renderTreeNode = (node, depth = 0) => {
    const hasChildren = node.children && node.children.length > 0;
    const isExpanded = expandedNodes.has(node.id);

    return (
      <div key={node.id} className="tree-row-container">
        <div 
          className="tree-row" 
          style={{ paddingLeft: `${depth * 2}rem` }}
        >
          <div className="tree-content">
            <div className="tree-trigger" onClick={() => hasChildren && toggleNode(node.id)}>
              {hasChildren ? (isExpanded ? <ChevronDown size={18} /> : <ChevronRight size={18} />) : <div style={{width: 18}} />}
              <span className="icon-badge">
                {node.url ? <ExternalLink size={14} /> : <Folder size={14} />}
              </span>
              <span className="menu-name">{node.menu_name}</span>
            </div>
            <div className="row-meta">
              <span className="url-badge">{node.url || '/'}</span>
              <span className={`type-badge ${node.menu_type}`}>{node.menu_type}</span>
              <span className={`status-pill ${node.is_active ? 'active' : 'inactive'}`}>
                {node.is_active ? 'Active' : 'Hidden'}
              </span>
            </div>
            <div className="row-actions">
              <button onClick={() => openModal(node)} title="Edit"><Edit size={16} /></button>
              <button className="del" onClick={() => handleDelete(node.id)} title="Delete"><Trash2 size={16} /></button>
            </div>
          </div>
        </div>
        {hasChildren && isExpanded && (
          <div className="tree-children">
            {node.children.map(child => renderTreeNode(child, depth + 1))}
          </div>
        )}
      </div>
    );
  };

  return (
    <div className="menu-mgmt-page">
      <div className="page-header">
        <div className="title-area">
          <MenuIcon className="header-icon" />
          <div>
            <h1>Menu & Navigation</h1>
            <p>Structure and manage the application's sidebar and navigation</p>
          </div>
        </div>
        <div className="header-btns">
          <div className="view-toggle">
            <button 
              className={viewMode === 'list' ? 'active' : ''} 
              onClick={() => { setViewMode('list'); setPage(1); }}
            >
              List View
            </button>
            <button 
              className={viewMode === 'tree' ? 'active' : ''} 
              onClick={() => setViewMode('tree')}
            >
              Tree Structure
            </button>
          </div>
          <button className="secondary-btn icon-only" onClick={handleRefresh} title="Refresh Data">
            <Activity size={18} />
          </button>
          <button className="primary-btn" onClick={() => openModal()}>
            <Plus size={18} />
            Create Menu
          </button>
        </div>
      </div>

      <div className="mgmt-container">
        {viewMode === 'list' ? (
          <>
            <div className="list-filters">
              <div className="search-box">
                <Search size={18} />
                <input 
                  type="text" 
                  placeholder="Search menus..." 
                  value={searchTerm}
                  onChange={(e) => { setSearchTerm(e.target.value); setPage(1); }}
                />
              </div>
              <div className="pagination">
                <span>Page {page} of {totalPages}</span>
                <div className="page-btns">
                  <button disabled={page === 1} onClick={() => setPage(p => p - 1)}><ChevronLeft size={18} /></button>
                  <button disabled={page === totalPages} onClick={() => setPage(p => p + 1)}><ChevronRight size={18} /></button>
                </div>
              </div>
            </div>

            <div className="table-responsive">
              <table className="flat-table">
                <thead>
                  <tr>
                    <th>Menu Name</th>
                    <th>URL Path</th>
                    <th>Type</th>
                    <th>Order</th>
                    <th>Auth?</th>
                    <th>Status</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {loading ? (
                    <tr><td colSpan="7" className="loader-cell"><Loader2 size={32} className="spinner" /></td></tr>
                  ) : menus.length === 0 ? (
                    <tr><td colSpan="7" className="empty-cell">No items found.</td></tr>
                  ) : (
                    menus.map(menu => (
                      <tr key={menu.id}>
                        <td className="name-cell">
                          <span className="icon-shell"><Folder size={16} /></span>
                          {menu.menu_name}
                        </td>
                        <td><code>{menu.url || '/'}</code></td>
                        <td><span className={`type-tag ${menu.menu_type}`}>{menu.menu_type}</span></td>
                        <td>{menu.sort_order}</td>
                        <td>{menu.requires_auth ? <Lock size={14} className="auth-lock" /> : <Eye size={14} className="public-eye" />}</td>
                        <td>
                          <span className={`status-pill ${menu.is_active ? 'active' : 'inactive'}`}>
                            {menu.is_active ? 'Active' : 'Inactive'}
                          </span>
                        </td>
                        <td className="actions">
                          <button onClick={() => openModal(menu)}><Edit size={16} /></button>
                          <button onClick={() => handleDelete(menu.id)} className="del"><Trash2 size={16} /></button>
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </>
        ) : (
          <div className="tree-view-area">
            {loading ? (
              <div className="panel-loader"><Loader2 size={40} className="spinner" /></div>
            ) : menuTree.length === 0 ? (
              <div className="empty-panel">No menu hierarchy established yet.</div>
            ) : (
              <div className="tree-legend">
                {menuTree.map(rootNode => renderTreeNode(rootNode))}
              </div>
            )}
          </div>
        )}
      </div>

      {modalOpen && (
        <div className="modal-overlay">
          <div className="modal-content large">
            <div className="modal-header">
              <h3>{selectedMenu ? 'Edit Navigation Item' : 'New Navigation Item'}</h3>
              <button className="close-btn" onClick={closeModal}><X size={20} /></button>
            </div>
            <form onSubmit={handleSubmit} className="menu-form">
              <div className="form-grid">
                <div className="form-group half">
                  <label>Menu Display Name</label>
                  <div className="input-wrapper">
                    <Layout size={16} />
                    <input name="menu_name" value={formData.menu_name} onChange={handleInputChange} required placeholder="Dashboard, Invoices, etc." />
                  </div>
                </div>

                <div className="form-group half">
                  <label>Menu Type</label>
                  <div className="input-wrapper">
                    <Settings size={16} />
                    <select name="menu_type" value={formData.menu_type} onChange={handleInputChange}>
                      <option value="main">Main Navigation</option>
                      <option value="admin">Admin Portal</option>
                      <option value="user">User Settings</option>
                    </select>
                  </div>
                </div>

                <div className="form-group full">
                  <label>Description</label>
                  <div className="input-wrapper">
                    <FileText size={16} />
                    <textarea name="description" value={formData.description} onChange={handleInputChange} placeholder="Brief summary of this section..." rows="2" />
                  </div>
                </div>

                <div className="form-group half">
                  <label>URL / Route Path</label>
                  <div className="input-wrapper">
                    <ExternalLink size={16} />
                    <input name="url" value={formData.url} onChange={handleInputChange} placeholder="/home, /settings, etc." />
                  </div>
                </div>

                <div className="form-group half">
                  <label>Parent Item (For Tree View)</label>
                  <div className="input-wrapper">
                    <Folder size={16} />
                    <select name="parent_id" value={formData.parent_id || ''} onChange={handleInputChange}>
                      <option value="">No Parent (Root)</option>
                      {/* Show all menus as potential parents */}
                      {menus.map(m => (
                        <option key={m.id} value={m.id}>
                          {m.menu_name} ({m.menu_type})
                        </option>
                      ))}
                    </select>
                  </div>
                </div>

                <div className="form-group half">
                  <label>Icon Identifier</label>
                  <div className="input-wrapper">
                    <MenuIcon size={16} />
                    <input name="icon" value={formData.icon} onChange={handleInputChange} placeholder="Heroicon or Lucide name" />
                  </div>
                </div>

                <div className="form-group half">
                  <label>Sort Order Priority</label>
                  <div className="input-wrapper">
                    <Plus size={16} />
                    <input type="number" name="sort_order" value={formData.sort_order} onChange={handleInputChange} />
                  </div>
                </div>

                <div className="checkbox-row">
                  <label className="checkbox-item">
                    <input type="checkbox" name="is_active" checked={formData.is_active} onChange={handleInputChange} />
                    <span className="label">Is Visible?</span>
                  </label>
                  <label className="checkbox-item">
                    <input type="checkbox" name="requires_auth" checked={formData.requires_auth} onChange={handleInputChange} />
                    <span className="label">Requires Login?</span>
                  </label>
                </div>
              </div>

              <div className="modal-footer">
                <button type="button" className="secondary-btn" onClick={closeModal}>Cancel</button>
                <button type="submit" className="primary-btn">
                  {selectedMenu ? 'Apply Changes' : 'Create Entry'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

export default MenuManagement;
