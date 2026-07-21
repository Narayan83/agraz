import React, { useState, useEffect } from "react";
import { 
  ChevronRight, 
  ChevronDown, 
  CheckSquare, 
  Square,
  Lock,
  Plus,
  Loader2,
  Shield,
  Save,
  Trash2,
  Eye,
  Edit3,
  CheckCircle2
} from "lucide-react";
import { getRoles, getRolePermissionTree, updateRolePermissions } from "../api/api";
import "./RolePermissions.css";

const AdminActions = ["can_view", "can_create", "can_update", "can_delete"];

const PermissionNode = ({ node, level = 0, onUpdate }) => {
  const [isOpen, setIsOpen] = useState(true);
  const hasChildren = node.children && node.children.length > 0;
  
  const toggleOpen = () => setIsOpen(!isOpen);

  const handleActionToggle = (action) => {
    const updatedPerms = { ...node.permissions };
    updatedPerms[action] = !updatedPerms[action];
    onUpdate(node.id, updatedPerms);
  };

  return (
    <div className="permission-node-wrapper">
      <div 
        className={`permission-node level-${level} ${hasChildren ? 'has-children' : ''}`}
        style={{ paddingLeft: `${level * 24 + 1.5 * 16}px` }}
      >
        <div className="node-toggle" onClick={toggleOpen}>
          {hasChildren && (isOpen ? <ChevronDown size={16} /> : <ChevronRight size={16} />)}
        </div>
        
        <div className="node-content">
          <span className="node-name">{node.menu_name || node.name}</span>
          {node.url && <span className="node-url">{node.url}</span>}
        </div>

        <div className="node-actions">
          {AdminActions.map(action => (
            <div 
              key={action} 
              className={`action-checkbox ${node.permissions[action] ? 'checked' : ''} ${action}`}
              onClick={() => handleActionToggle(action)}
            >
              {node.permissions[action] ? <CheckSquare size={16} /> : <Square size={16} />}
              <span>{action.split('_')[1]}</span>
            </div>
          ))}
        </div>
      </div>

      {hasChildren && isOpen && (
        <div className="node-children">
          {node.children.map((child, idx) => (
            <PermissionNode key={idx} node={child} level={level + 1} onUpdate={onUpdate} />
          ))}
        </div>
      )}
    </div>
  );
};

const RolePermissions = () => {
  const [roles, setRoles] = useState([]);
  const [selectedRole, setSelectedRole] = useState(null);
  const [permissionTree, setPermissionTree] = useState([]);
  const [loading, setLoading] = useState(false);
  const [rolesLoading, setRolesLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState(null);

  useEffect(() => {
    fetchRoles();
  }, []);

  const fetchRoles = async () => {
    setRolesLoading(true);
    try {
      const response = await getRoles();
      const rolesList = response.data || [];
      setRoles(rolesList);
      if (rolesList.length > 0) {
        handleRoleSelect(rolesList[0]);
      }
    } catch (err) {
      console.error("Error fetching roles:", err);
    } finally {
      setRolesLoading(false);
    }
  };

  const handleRoleSelect = async (role) => {
    setSelectedRole(role);
    setLoading(true);
    setMessage(null);
    try {
      const tree = await getRolePermissionTree(role.id);
      setPermissionTree(Array.isArray(tree) ? tree : []);
    } catch (err) {
      console.error("Error fetching permission tree:", err);
      setPermissionTree([]);
    } finally {
      setLoading(false);
    }
  };

  const updateNodePermissions = (id, newPerms) => {
    const updateRecursive = (nodes) => {
      return nodes.map(node => {
        if (node.id === id) {
          return { ...node, permissions: newPerms };
        }
        if (node.children) {
          return { ...node, children: updateRecursive(node.children) };
        }
        return node;
      });
    };
    setPermissionTree(prev => updateRecursive(prev));
  };

  const handleSave = async () => {
    if (!selectedRole) return;
    setSaving(true);
    
    // Flatten tree back to map for backend: { "menu_id": { ...perms } }
    const permissionMap = {};
    const flatten = (nodes) => {
      nodes.forEach(node => {
        permissionMap[node.id] = node.permissions;
        if (node.children) flatten(node.children);
      });
    };
    flatten(permissionTree);

    try {
      await updateRolePermissions(selectedRole.id, permissionMap);
      setMessage({ type: 'success', text: 'Permissions saved successfully!' });
      setTimeout(() => setMessage(null), 3000);
    } catch (err) {
      console.error("Error saving permissions:", err);
      setMessage({ type: 'error', text: 'Failed to save permissions.' });
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="role-permissions-page">
      <div className="page-header">
        <div className="title-area">
          <Lock className="header-icon" />
          <div>
            <h1>Role Permissions</h1>
            <p>Define granular access controls for each organizational role</p>
          </div>
        </div>
        <div className="header-buttons">
          {message && (
            <div className={`status-msg ${message.type}`}>
               {message.type === 'success' ? <CheckCircle2 size={16} /> : <Trash2 size={16} />}
               <span>{message.text}</span>
            </div>
          )}
          <button className="primary-btn" onClick={handleSave} disabled={saving || !selectedRole}>
            {saving ? <Loader2 size={18} className="spinner" /> : <Save size={18} />}
            {saving ? 'Saving...' : 'Save Permissions'}
          </button>
        </div>
      </div>

      <div className="permissions-container">
        <div className="role-selector-card">
          <div className="card-header">
            <h3>Roles</h3>
          </div>
          <div className="role-list">
            {rolesLoading ? (
               <div className="loader-box"><Loader2 className="spinner" /></div>
            ) : roles.map((role) => (
              <div 
                key={role.id} 
                className={`role-item ${selectedRole?.id === role.id ? "active" : ""}`}
                onClick={() => handleRoleSelect(role)}
              >
                <Shield size={16} />
                <span>{role.role_name}</span>
                {selectedRole?.id === role.id && <ChevronRight size={16} className="active-chevron" />}
              </div>
            ))}
          </div>
        </div>

        <div className="tree-card">
          <div className="tree-header">
            <h3>Permission Matrix: <span className="role-highlight">{selectedRole?.role_name || '...'}</span></h3>
            <div className="legend">
              <span className="legend-item"><Eye size={12} /> View</span>
              <span className="legend-item"><Plus size={12} /> Create</span>
              <span className="legend-item"><Edit3 size={12} /> Update</span>
              <span className="legend-item"><Trash2 size={12} /> Delete</span>
            </div>
          </div>
          <div className="tree-body">
            {loading ? (
              <div className="tree-loader">
                <Loader2 className="spinner" size={40} />
                <p>Building permission tree...</p>
              </div>
            ) : permissionTree.length === 0 ? (
              <div className="empty-tree">No menus found or no permissions defined yet.</div>
            ) : (
              permissionTree.map((node, idx) => (
                <PermissionNode 
                  key={idx} 
                  node={node} 
                  onUpdate={updateNodePermissions} 
                />
              ))
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

export default RolePermissions;
