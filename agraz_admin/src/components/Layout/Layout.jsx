import React, { useState, useEffect, useRef } from "react";
import Sidebar from "./Sidebar";
import Header from "./Header";
import "./Layout.css";

const Layout = ({ children }) => {
  const [isMobile, setIsMobile] = useState(
    () => typeof window !== "undefined" && window.innerWidth <= 768
  );
  /** Desktop: true = wide sidebar + main offset; false = icon rail. Never forced true on random resize. */
  const [sidebarOpen, setSidebarOpen] = useState(
    () => typeof window === "undefined" || window.innerWidth > 768
  );
  const [mobileOpen, setMobileOpen] = useState(false);
  const prevIsMobileRef = useRef(null);

  useEffect(() => {
    const handleResize = () => {
      setIsMobile(window.innerWidth <= 768);
    };

    window.addEventListener("resize", handleResize);
    return () => window.removeEventListener("resize", handleResize);
  }, []);

  useEffect(() => {
    const prev = prevIsMobileRef.current;
    if (prev === null) {
      prevIsMobileRef.current = isMobile;
      return;
    }
    if (isMobile && !prev) {
      setSidebarOpen(false);
      setMobileOpen(false);
    } else if (!isMobile && prev) {
      setSidebarOpen(true);
    }
    prevIsMobileRef.current = isMobile;
  }, [isMobile]);

  /** Lets fixed modals (e.g. e-com) inset from the sidebar instead of covering it. */
  useEffect(() => {
    const root = document.documentElement;
    if (isMobile) {
      root.dataset.adminSidebar = "mobile";
    } else {
      root.dataset.adminSidebar = sidebarOpen ? "expanded" : "collapsed";
    }
    return () => {
      delete root.dataset.adminSidebar;
    };
  }, [isMobile, sidebarOpen]);

  const toggleSidebar = () => {
    setSidebarOpen(!sidebarOpen);
  };

  const toggleMobileSidebar = () => {
    setMobileOpen(!mobileOpen);
  };

  return (
    <div className="layout-container">
      <Sidebar 
        isOpen={sidebarOpen} 
        setOpen={setSidebarOpen} 
        isMobile={isMobile} 
        mobileOpen={mobileOpen}
        setMobileOpen={setMobileOpen}
      />
      
      <div 
        className={`main-wrapper ${sidebarOpen ? "expanded" : "collapsed"} ${isMobile ? "mobile" : ""}`}
      >
        <Header 
          toggleSidebar={toggleSidebar} 
          isMobile={isMobile} 
          mobileOpen={mobileOpen}
          toggleMobileSidebar={toggleMobileSidebar}
        />
        
        <main className="content-area">
          <div className="content-container">
            {children}
          </div>
        </main>
      </div>
    </div>
  );
};

export default Layout;
