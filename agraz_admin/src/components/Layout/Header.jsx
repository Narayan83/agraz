import React from "react";
import { Menu as MenuIcon, Bell, Search, User as UserIcon, ChevronDown } from "lucide-react";
import "./Header.css";

const Header = ({ toggleSidebar, isMobile, toggleMobileSidebar }) => {
  const [user, setUser] = React.useState(null);

  React.useEffect(() => {
    const storedUser = localStorage.getItem('user');
    if (storedUser && storedUser !== 'undefined') {
      try {
        setUser(JSON.parse(storedUser));
      } catch (e) {
        console.error("Error parsing user data", e);
      }
    }
  }, []);

  const first = user?.Firstname ?? user?.first_name ?? user?.firstname ?? "";
  const last = user?.Lastname ?? user?.last_name ?? user?.lastname ?? "";
  const userName = (first || last) ? `${first} ${last}`.trim() : "Guest";

  return (
    <header className="header">
      <div className="header-left">
        <button 
          className="sidebar-toggle" 
          onClick={isMobile ? toggleMobileSidebar : toggleSidebar}
        >
          <MenuIcon size={22} strokeWidth={2} />
        </button>
      </div>
      <div className="header-center">
        <div className="search-bar">
          <Search size={16} strokeWidth={2} />
          <input type="text" placeholder="Search anything..." />
        </div>
      </div>
      <div className="header-right">
        <button className="icon-btn">
          <Bell size={18} strokeWidth={1.75} />
          <span className="badge"></span>
        </button>
        
        <div className="user-profile">
          <img 
            src={`https://ui-avatars.com/api/?name=${encodeURIComponent(userName)}&background=008674&color=ffffff&bold=true`} 
            alt="User" 
            className="header-avatar"
          />
          <div className="user-meta">
            <span className="username">{userName}</span>
            <ChevronDown size={14} strokeWidth={2} />
          </div>
        </div>
      </div>
    </header>
  );
};

export default Header;
