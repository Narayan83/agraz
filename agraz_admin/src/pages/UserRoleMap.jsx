import React, { useState, useEffect } from 'react';
import { 
  Link as LinkIcon, 
  Search, 
  User as UserIcon, 
  Shield, 
  ChevronRight, 
  CheckCircle2, 
  Loader2,
  Save,
  AlertCircle
} from 'lucide-react';
import { getUsers, getRoles, getUserRoles, updateUserRoles } from '../api/api';
import './UserRoleMap.css';

const UserRoleMap = () => {
  const [users, setUsers] = useState([]);
  const [roles, setRoles] = useState([]);
  const [selectedUser, setSelectedUser] = useState(null);
  const [selectedRoleIds, setSelectedRoleIds] = useState([]);
  const [loading, setLoading] = useState(true);
  const [rolesLoading, setRolesLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');
  const [message, setMessage] = useState(null);

  useEffect(() => {
    fetchInitialData();
  }, []);

  const fetchInitialData = async () => {
    setLoading(true);
    try {
      const [usersResponse, rolesResponse] = await Promise.all([
        getUsers(1, 100), // Fetch a larger batch for mapping
        getRoles()
      ]);
      setUsers(usersResponse.data || []);
      setRoles(rolesResponse.data || []);
      
      if (usersResponse.data && usersResponse.data.length > 0) {
        handleUserSelect(usersResponse.data[0]);
      }
    } catch (err) {
      console.error("Error fetching initial data:", err);
    } finally {
      setLoading(false);
    }
  };

  const handleUserSelect = async (user) => {
    setSelectedUser(user);
    setRolesLoading(true);
    setMessage(null);
    try {
      const userRoles = await getUserRoles(user.id);
      // Backend likely returns objects, we need IDs
      const roleIds = (userRoles || []).map(r => r.id || r.role_id);
      setSelectedRoleIds(roleIds);
    } catch (err) {
      console.error("Error fetching user roles:", err);
      setSelectedRoleIds([]);
    } finally {
      setRolesLoading(false);
    }
  };

  const toggleRole = (roleId) => {
    setSelectedRoleIds(prev => 
      prev.includes(roleId) 
        ? prev.filter(id => id !== roleId) 
        : [...prev, roleId]
    );
  };

  const handleSave = async () => {
    if (!selectedUser) return;
    setSaving(true);
    try {
      await updateUserRoles(selectedUser.id, selectedRoleIds);
      setMessage({ type: 'success', text: 'Assignments updated successfully!' });
      setTimeout(() => setMessage(null), 3000);
    } catch (err) {
      console.error("Error updating assignments:", err);
      setMessage({ type: 'error', text: 'Failed to update assignments.' });
    } finally {
      setSaving(false);
    }
  };

  const filteredUsers = users.filter(user => 
    `${user.firstname} ${user.lastname}`.toLowerCase().includes(searchTerm.toLowerCase()) ||
    user.email.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <div className="user-role-map-page">
      <div className="page-header">
        <div className="title-area">
          <LinkIcon className="header-icon" />
          <div>
            <h1>User-Role Mapping</h1>
            <p>Assign and manage organizational roles for each user</p>
          </div>
        </div>
        <div className="header-actions">
           {message && (
             <div className={`status-msg ${message.type}`}>
               {message.type === 'success' ? <CheckCircle2 size={16} /> : <AlertCircle size={16} />}
               <span>{message.text}</span>
             </div>
           )}
           <button 
             className="primary-btn" 
             onClick={handleSave} 
             disabled={saving || !selectedUser}
           >
             {saving ? <Loader2 size={18} className="spinner" /> : <Save size={18} />}
             Save Changes
           </button>
        </div>
      </div>

      <div className="mapping-container">
        {/* Left Side: User List */}
        <div className="user-selection-panel">
          <div className="search-box">
            <Search size={18} />
            <input 
              type="text" 
              placeholder="Filter users..." 
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>
          <div className="user-scroll-list">
            {loading ? (
              <div className="panel-loader"><Loader2 className="spinner" /></div>
            ) : filteredUsers.length === 0 ? (
              <div className="empty-panel">No users matching search.</div>
            ) : (
              filteredUsers.map(user => (
                <div 
                  key={user.id} 
                  className={`user-list-item ${selectedUser?.id === user.id ? 'active' : ''}`}
                  onClick={() => handleUserSelect(user)}
                >
                  <div className="user-avatar">
                    {user.firstname.charAt(0)}{user.lastname.charAt(0)}
                  </div>
                  <div className="user-details">
                    <span className="name">{user.firstname} {user.lastname}</span>
                    <span className="email">{user.email}</span>
                  </div>
                  <ChevronRight size={16} className="chevron" />
                </div>
              ))
            )}
          </div>
        </div>

        {/* Right Side: Role Assignment */}
        <div className="role-assignment-panel">
          <div className="panel-header">
            <h3>Assign Roles to: <span className="highlight">{selectedUser ? `${selectedUser.firstname} ${selectedUser.lastname}` : '...'}</span></h3>
            <p className="subtitle">Select the roles this user should possess</p>
          </div>

          <div className="roles-checklist">
            {rolesLoading ? (
              <div className="panel-loader"><Loader2 className="spinner" size={32} /></div>
            ) : roles.length === 0 ? (
              <div className="empty-panel">No roles defined in the system.</div>
            ) : (
              <div className="roles-grid">
                {roles.map(role => (
                  <div 
                    key={role.id} 
                    className={`role-check-card ${selectedRoleIds.includes(role.id) ? 'checked' : ''}`}
                    onClick={() => toggleRole(role.id)}
                  >
                    <div className="check-indicator">
                      <Shield size={20} />
                      {selectedRoleIds.includes(role.id) && (
                        <div className="check-mark">
                          <CheckCircle2 size={16} />
                        </div>
                      )}
                    </div>
                    <div className="role-info">
                      <h4>{role.role_name}</h4>
                      <p>{role.description || "No description provided."}</p>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

export default UserRoleMap;
