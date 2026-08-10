import React, { useState, useEffect, useCallback } from 'react';
import { 
  Users, 
  Search, 
  Plus, 
  Edit, 
  Trash2, 
  X, 
  ChevronLeft, 
  ChevronRight,
  Loader2,
  Lock,
  Mail,
  User as UserIcon,
  Fingerprint,
  CheckCircle2,
  CircleDashed
} from 'lucide-react';
import { getUsers, createUser, updateUser, deleteUser } from '../api/api';
import './UserList.css';

const UserList = () => {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [modalOpen, setModalOpen] = useState(false);
  const [selectedUser, setSelectedUser] = useState(null);
  const [approvalFilter, setApprovalFilter] = useState('all');
  const [search, setSearch] = useState('');
  const [formData, setFormData] = useState({
    firstname: '',
    lastname: '',
    email: '',
    usercode: '',
    password: '',
    active: true,
    approved: true
  });
  
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const limit = 10;

  const fetchUsers = useCallback(async () => {
    setLoading(true);
    try {
      const data = await getUsers(page, limit, {
        approval: approvalFilter,
        filter: search.trim() || undefined,
      });
      setUsers(data.data || []);
      setTotalPages(Math.ceil(data.total / limit) || 1);
    } catch (err) {
      console.error("Error fetching users:", err);
    } finally {
      setLoading(false);
    }
  }, [page, approvalFilter, search]);

  useEffect(() => {
    fetchUsers();
  }, [fetchUsers]);

  useEffect(() => {
    setPage(1);
  }, [approvalFilter, search]);

  const openModal = (user = null) => {
    if (user) {
      setSelectedUser(user);
      setFormData({
        firstname: user.firstname || '',
        lastname: user.lastname || '',
        email: user.email || '',
        usercode: user.usercode || '',
        password: user.plain_password || '',
        active: user.active ?? true,
        approved: user.approved ?? true
      });
    } else {
      setSelectedUser(null);
      setFormData({
        firstname: '',
        lastname: '',
        email: '',
        usercode: '',
        password: '',
        active: true,
        approved: true
      });
    }
    setModalOpen(true);
  };

  const closeModal = () => {
    setModalOpen(false);
    setSelectedUser(null);
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
      if (selectedUser) {
        await updateUser(selectedUser.id, formData);
      } else {
        await createUser(formData);
      }
      closeModal();
      fetchUsers();
    } catch (err) {
      console.error("Error saving user:", err);
      alert(err.response?.data?.error || "Failed to save user");
    }
  };

  const handleDelete = async (id) => {
    if (window.confirm("Are you sure you want to delete this user?")) {
      try {
        await deleteUser(id);
        fetchUsers();
      } catch (err) {
        console.error("Error deleting user:", err);
        alert(err.response?.data?.error || err.response?.data?.details || "Failed to delete user");
      }
    }
  };

  const handleToggleApprove = async (user) => {
    const next = !user.approved;
    try {
      await updateUser(user.id, { approved: next });
      fetchUsers();
    } catch (err) {
      console.error("Error updating approval:", err);
      alert(err.response?.data?.error || "Failed to update approval");
    }
  };

  const statusLabel = (user) => {
    if (!user.approved) return { text: 'Pending Approval', cls: 'pending' };
    if (!user.active) return { text: 'Inactive', cls: 'inactive' };
    return { text: 'Active', cls: 'active' };
  };

  return (
    <div className="user-list-page">
      <div className="page-header">
        <div className="title-area">
          <Users className="header-icon" />
          <div>
            <h1>User Management</h1>
            <p>Verify new registrations and manage user access</p>
          </div>
        </div>
        <button className="primary-btn" onClick={() => openModal()}>
          <Plus size={18} />
          Add New User
        </button>
      </div>

      <div className="approval-tabs">
        {[
          { key: 'all', label: 'All' },
          { key: 'pending', label: 'Pending Approval' },
          { key: 'approved', label: 'Approved' },
        ].map((tab) => (
          <button
            key={tab.key}
            type="button"
            className={`approval-tab ${approvalFilter === tab.key ? 'active' : ''}`}
            onClick={() => setApprovalFilter(tab.key)}
          >
            {tab.label}
          </button>
        ))}
      </div>

      <div className="list-container">
        <div className="list-header">
          <div className="search-box">
            <Search size={18} />
            <input
              type="text"
              placeholder="Search users by name or email..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>
          <div className="pagination-controls">
            <span>Page {page} of {totalPages}</span>
            <div className="pagination-btns">
              <button disabled={page === 1} onClick={() => setPage(p => p - 1)}>
                <ChevronLeft size={18} />
              </button>
              <button disabled={page === totalPages} onClick={() => setPage(p => p + 1)}>
                <ChevronRight size={18} />
              </button>
            </div>
          </div>
        </div>

        <div className="table-responsive">
          <table className="user-table">
            <thead>
              <tr>
                <th>User Code</th>
                <th>Full Name</th>
                <th>Email Address</th>
                <th>Phone</th>
                <th>Status</th>
                <th>Created At</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan="7" className="loader-cell">
                    <Loader2 className="spinner" size={32} />
                    <p>Loading users...</p>
                  </td>
                </tr>
              ) : users.length === 0 ? (
                <tr>
                  <td colSpan="7" className="empty-cell">No users found.</td>
                </tr>
              ) : (
                users.map(user => {
                  const st = statusLabel(user);
                  return (
                  <tr key={user.id}>
                    <td className="code-cell">
                      <code>{user.usercode || 'N/A'}</code>
                    </td>
                    <td>
                      <div className="user-name-cell">
                        <div className="avatar-sm">{(user.firstname || '?').charAt(0)}{(user.lastname || '').charAt(0)}</div>
                        <span>{user.firstname} {user.lastname}</span>
                      </div>
                    </td>
                    <td>{user.email}</td>
                    <td>{user.mobile_number || '—'}</td>
                    <td>
                      <span className={`status-badge ${st.cls}`}>
                        {st.text}
                      </span>
                    </td>
                    <td>{new Date(user.created_at).toLocaleDateString()}</td>
                    <td className="actions-cell">
                      <button
                        className={`action-btn ${user.approved ? 'unapprove' : 'approve'}`}
                        title={user.approved ? 'Revoke approval' : 'Approve user'}
                        onClick={() => handleToggleApprove(user)}
                      >
                        {user.approved ? <CircleDashed size={16} /> : <CheckCircle2 size={16} />}
                      </button>
                      <button className="action-btn edit" onClick={() => openModal(user)}>
                        <Edit size={16} />
                      </button>
                      <button className="action-btn delete" onClick={() => handleDelete(user.id)}>
                        <Trash2 size={16} />
                      </button>
                    </td>
                  </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>

      {modalOpen && (
        <div className="modal-overlay">
          <div className="modal-content">
            <div className="modal-header">
              <h3>{selectedUser ? 'Edit User' : 'Add New User'}</h3>
              <button className="close-btn" onClick={closeModal}><X size={20} /></button>
            </div>
            <form onSubmit={handleSubmit} className="user-form">
              <div className="form-grid">
                <div className="form-group">
                  <label>First Name</label>
                  <div className="input-icon-wrapper">
                    <UserIcon size={16} />
                    <input 
                      type="text" 
                      name="firstname" 
                      value={formData.firstname} 
                      onChange={handleInputChange} 
                      required 
                    />
                  </div>
                </div>
                <div className="form-group">
                  <label>Last Name</label>
                  <div className="input-icon-wrapper">
                    <UserIcon size={16} />
                    <input 
                      type="text" 
                      name="lastname" 
                      value={formData.lastname} 
                      onChange={handleInputChange} 
                      required 
                    />
                  </div>
                </div>
                <div className="form-group">
                  <label>Email Address</label>
                  <div className="input-icon-wrapper">
                    <Mail size={16} />
                    <input 
                      type="email" 
                      name="email" 
                      value={formData.email} 
                      onChange={handleInputChange} 
                      required 
                    />
                  </div>
                </div>
                <div className="form-group">
                  <label>User Code (Optional)</label>
                  <div className="input-icon-wrapper">
                    <Fingerprint size={16} />
                    <input 
                      type="text" 
                      name="usercode" 
                      value={formData.usercode} 
                      onChange={handleInputChange} 
                    />
                  </div>
                </div>
                <div className="form-group full-width">
                  <label>Password</label>
                  <div className="input-icon-wrapper">
                    <Lock size={16} />
                    <input 
                      type="password" 
                      name="password" 
                      value={formData.password} 
                      onChange={handleInputChange} 
                      required={!selectedUser}
                      placeholder={selectedUser ? "Leave blank to keep current" : ""}
                    />
                  </div>
                </div>
                <div className="form-group checkbox-group">
                  <label className="switch-label">
                    <input 
                      type="checkbox" 
                      name="approved" 
                      checked={formData.approved} 
                      onChange={handleInputChange} 
                    />
                    <span className="slider"></span>
                    <span className="label-text">Approved (can log in to the app)</span>
                  </label>
                </div>
                <div className="form-group checkbox-group">
                  <label className="switch-label">
                    <input 
                      type="checkbox" 
                      name="active" 
                      checked={formData.active} 
                      onChange={handleInputChange} 
                    />
                    <span className="slider"></span>
                    <span className="label-text">Active account</span>
                  </label>
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" className="secondary-btn" onClick={closeModal}>Cancel</button>
                <button type="submit" className="primary-btn">
                  {selectedUser ? 'Update User' : 'Create User'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

export default UserList;
