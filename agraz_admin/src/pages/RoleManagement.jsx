import React, { useState, useEffect } from 'react';
import { 
  Shield, 
  Search, 
  Plus, 
  Edit, 
  Trash2, 
  X, 
  Loader2,
  FileText,
  Activity,
  CheckCircle2,
  AlertCircle
} from 'lucide-react';
import { getRoles, createRole, updateRole, deleteRole } from '../api/api';
import './RoleManagement.css';

const RoleManagement = () => {
  const [roles, setRoles] = useState([]);
  const [loading, setLoading] = useState(true);
  const [modalOpen, setModalOpen] = useState(false);
  const [selectedRole, setSelectedRole] = useState(null);
  const [formData, setFormData] = useState({
    role_name: '',
    description: '',
    is_active: true
  });

  useEffect(() => {
    fetchRoles();
  }, []);

  const fetchRoles = async () => {
    setLoading(true);
    try {
      const response = await getRoles();
      // Backend returns { data: [...], total: X, ... }
      setRoles(response.data || []);
    } catch (err) {
      console.error("Error fetching roles:", err);
    } finally {
      setLoading(false);
    }
  };

  const openModal = (role = null) => {
    if (role) {
      setSelectedRole(role);
      setFormData({
        role_name: role.role_name || '',
        description: role.description || '',
        is_active: role.is_active ?? true
      });
    } else {
      setSelectedRole(null);
      setFormData({
        role_name: '',
        description: '',
        is_active: true
      });
    }
    setModalOpen(true);
  };

  const closeModal = () => {
    setModalOpen(false);
    setSelectedRole(null);
  };

  const handleInputChange = (e) => {
    const { name, value, type, checked } = e.target;
    setFormData(prev => ({
      ...prev,
      [name]: type === 'checkbox' ? checked : value
    }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      if (selectedRole) {
        await updateRole(selectedRole.id, formData);
      } else {
        await createRole(formData);
      }
      closeModal();
      fetchRoles();
    } catch (err) {
      console.error("Error saving role:", err);
      alert(err.response?.data?.error || "Failed to save role");
    }
  };

  const handleDelete = async (id) => {
    if (window.confirm("Are you sure you want to delete this role? This might affect users assigned to this role.")) {
      try {
        await deleteRole(id);
        fetchRoles();
      } catch (err) {
        console.error("Error deleting role:", err);
      }
    }
  };

  return (
    <div className="role-management-page">
      <div className="page-header">
        <div className="title-area">
          <Shield className="header-icon" />
          <div>
            <h1>Roles & Designations</h1>
            <p>Define and manage security roles for your organization</p>
          </div>
        </div>
        <button className="primary-btn" onClick={() => openModal()}>
          <Plus size={18} />
          Create New Role
        </button>
      </div>

      {loading ? (
        <div className="page-loader">
          <Loader2 className="spinner" size={40} />
          <p>Fetching roles...</p>
        </div>
      ) : (
        <div className="roles-grid">
          {roles.map(role => (
            <div key={role.id} className={`role-card ${!role.is_active ? 'inactive' : ''}`}>
              <div className="role-card-header">
                <div className="role-badge">
                  <Shield size={20} />
                </div>
                <div className="role-actions">
                  <button onClick={() => openModal(role)} title="Edit Role"><Edit size={16} /></button>
                  <button className="del-btn" onClick={() => handleDelete(role.id)} title="Delete Role"><Trash2 size={16} /></button>
                </div>
              </div>
              <div className="role-card-body">
                <h3>{role.role_name}</h3>
                <p>{role.description || "No description provided."}</p>
              </div>
              <div className="role-card-footer">
                <div className={`status-indicator ${role.is_active ? 'active' : 'inactive'}`}>
                  {role.is_active ? <CheckCircle2 size={14} /> : <AlertCircle size={14} />}
                  <span>{role.is_active ? 'Active' : 'Hidden'}</span>
                </div>
                <div className="role-meta">
                  <Activity size={14} />
                  <span>Latest: {new Date(role.updated_at).toLocaleDateString()}</span>
                </div>
              </div>
            </div>
          ))}
          
          <div className="add-role-card" onClick={() => openModal()}>
            <div className="add-icon-circle">
              <Plus size={32} />
            </div>
            <span>Create New Role</span>
          </div>
        </div>
      )}

      {modalOpen && (
        <div className="modal-overlay">
          <div className="modal-content">
            <div className="modal-header">
              <h3>{selectedRole ? 'Modify Role' : 'Initialize New Role'}</h3>
              <button className="close-btn" onClick={closeModal}><X size={20} /></button>
            </div>
            <form onSubmit={handleSubmit} className="role-form">
              <div className="form-group">
                <label>Role Identifier</label>
                <div className="input-icon-wrapper">
                  <Shield size={16} />
                  <input 
                    type="text" 
                    name="role_name" 
                    placeholder="e.g., Marketing Manager"
                    value={formData.role_name} 
                    onChange={handleInputChange} 
                    required 
                  />
                </div>
              </div>
              
              <div className="form-group">
                <label>Description</label>
                <div className="textarea-wrapper">
                  <FileText size={16} />
                  <textarea 
                    name="description" 
                    placeholder="Describe the scope and purpose of this role..."
                    value={formData.description} 
                    onChange={handleInputChange}
                    rows="4"
                  ></textarea>
                </div>
              </div>

              <div className="form-group checkbox-group">
                <label className="switch-label">
                  <input 
                    type="checkbox" 
                    name="is_active" 
                    checked={formData.is_active} 
                    onChange={handleInputChange} 
                  />
                  <span className="slider"></span>
                  <span className="label-text">Set as active role</span>
                </label>
              </div>

              <div className="modal-footer">
                <button type="button" className="secondary-btn" onClick={closeModal}>Discard</button>
                <button type="submit" className="primary-btn">
                  {selectedRole ? 'Save Changes' : 'Confirm Role'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

export default RoleManagement;
