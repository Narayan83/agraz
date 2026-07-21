import React, { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import {
  Users,
  Shield,
  Lock,
  Activity,
  Clock,
  Plus,
  FileText,
  UserPlus,
  List,
  Settings,
  Store,
  Package,
  ExternalLink,
} from "lucide-react";
import { getDashboardStats } from "../api/api";
import "./Dashboard.css";

const StatCard = ({ label, value, hint, hintTone = "positive", icon, color, loading }) => (
  <article className={`stat-card stat-card--${color}`}>
    <div className="stat-card__top">
      <span className="stat-card__label">{label}</span>
      <div className="stat-card__icon" aria-hidden>
        {icon}
      </div>
    </div>
    <p className="stat-card__value">{loading ? "…" : value}</p>
    <p className={`stat-card__hint stat-card__hint--${hintTone}`}>{loading ? "Loading…" : hint}</p>
  </article>
);

const formatCount = (n) => {
  if (n == null || Number.isNaN(n)) return "—";
  return Number(n).toLocaleString();
};

const formatUpdatedAt = (iso) => {
  if (!iso) return "—";
  try {
    return `Updated ${new Date(iso).toLocaleDateString(undefined, {
      month: "short",
      day: "numeric",
      year: "numeric",
    })}`;
  } catch {
    return "—";
  }
};

const formatActivityTime = (iso) => {
  if (!iso) return "";
  try {
    return new Date(iso).toLocaleString(undefined, {
      month: "short",
      day: "numeric",
      hour: "numeric",
      minute: "2-digit",
    });
  } catch {
    return "";
  }
};

const Dashboard = () => {
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const loadStats = async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await getDashboardStats();
      setStats(data);
    } catch (err) {
      const apiMsg = err?.response?.data?.error || err?.response?.data?.message;
      const detail = apiMsg || err?.message || "Could not load dashboard stats.";
      if (err?.response?.status === 401) {
        setError(`${detail} Try logging out and signing in again.`);
      } else {
        setError(detail);
      }
      setStats(null);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadStats();
  }, []);

  const recentActivity = stats?.recent_activity ?? [];
  const isVendorDash = Boolean(stats?.is_vendor_dashboard);

  return (
    <div className="dashboard-page">
      <header className="page-hero dashboard-hero">
        <div className="page-hero__titles">
          <h1>{isVendorDash ? `${stats?.vendor_name || "Vendor"} dashboard` : "Dashboard"}</h1>
          <p className="page-hero__subtitle">
            {isVendorDash
              ? "Your products, inventory, and sales overview."
              : "Welcome back! Here's your workspace overview."}
          </p>
        </div>
        <div className="dashboard-hero__meta">
          <Clock size={14} strokeWidth={2} aria-hidden />
          <span>{loading ? "Loading…" : formatUpdatedAt(stats?.updated_at)}</span>
        </div>
      </header>

      {error && (
        <section className="setup-banner" role="alert">
          <div className="setup-banner__copy">
            <h2>Could not load live data</h2>
            <p>{error}</p>
          </div>
          <button type="button" className="primary-btn setup-banner__btn" onClick={loadStats}>
            Retry
          </button>
        </section>
      )}

      {!isVendorDash && (
      <section className="setup-banner" aria-labelledby="setup-banner-title">
        <div className="setup-banner__copy">
          <h2 id="setup-banner-title">Complete your workspace setup</h2>
          <p>Add branding, invites, and permissions so your team can work smoothly.</p>
        </div>
        <button type="button" className="primary-btn setup-banner__btn">
          Complete setup
        </button>
      </section>
      )}

      {!isVendorDash && (
      <section className="panel commerce-shortcuts" aria-labelledby="commerce-shortcuts-title">
        <div className="panel__head">
          <h2 id="commerce-shortcuts-title">Store &amp; catalog</h2>
        </div>
        <p className="panel__lede">
          Manage products, categories, and images in the admin catalog. The customer storefront runs as a separate app
          (port 5174 in development) and reads the same database through the public API.
        </p>
        <div className="commerce-shortcuts__actions">
          <Link to="/ecom-admin?tab=products" className="primary-btn btn-sm commerce-shortcuts__btn">
            <Package size={16} strokeWidth={1.75} aria-hidden /> Catalog admin
          </Link>
          <Link to="/ecom-admin?tab=categories" className="text-btn commerce-shortcuts__btn">
            <Store size={16} strokeWidth={1.75} aria-hidden /> Categories
          </Link>
          <a
            href="http://localhost:5174/"
            target="_blank"
            rel="noopener noreferrer"
            className="text-btn commerce-shortcuts__btn"
          >
            <ExternalLink size={16} strokeWidth={1.75} aria-hidden /> Open storefront
          </a>
        </div>
      </section>
      )}

      <section className="stats-grid" aria-label="Key metrics">
        {isVendorDash ? (
          <>
            <StatCard
              label="Total products"
              value={formatCount(stats?.products_total)}
              hint="Linked to your vendor account"
              icon={<Package size={18} strokeWidth={1.75} />}
              color="teal"
              loading={loading}
            />
            <StatCard
              label="Inventory units"
              value={formatCount(stats?.inventory_units)}
              hint="Sum of mapped quantities"
              hintTone="neutral"
              icon={<Store size={18} strokeWidth={1.75} />}
              color="indigo"
              loading={loading}
            />
            <StatCard
              label="Total sales"
              value={formatCount(stats?.total_sales)}
              hint="Orders not enabled yet"
              icon={<Activity size={18} strokeWidth={1.75} />}
              color="violet"
              loading={loading}
            />
          </>
        ) : (
          <>
        <StatCard
          label="Total users"
          value={formatCount(stats?.users_total)}
          hint={
            stats?.users_active != null
              ? `${formatCount(stats.users_active)} active`
              : "From database"
          }
          icon={<Users size={18} strokeWidth={1.75} />}
          color="teal"
          loading={loading}
        />
        <StatCard
          label="Active roles"
          value={formatCount(stats?.roles_active)}
          hint="Roles marked active"
          hintTone="neutral"
          icon={<Shield size={18} strokeWidth={1.75} />}
          color="indigo"
          loading={loading}
        />
        <StatCard
          label="Permissions"
          value={formatCount(stats?.permissions_granted)}
          hint="Granted across all roles"
          icon={<Lock size={18} strokeWidth={1.75} />}
          color="violet"
          loading={loading}
        />
        <StatCard
          label="Daily activity"
          value={formatCount(stats?.daily_activity)}
          hint="Record updates today"
          icon={<Activity size={18} strokeWidth={1.75} />}
          color="cyan"
          loading={loading}
        />
          </>
        )}
      </section>

      {!isVendorDash && (
      <section className="panel panel--banner" aria-labelledby="tasks-heading">
        <div className="panel__head">
          <h2 id="tasks-heading">Tasks this week</h2>
          <div className="panel__actions">
            <button type="button" className="text-btn">
              View all
            </button>
            <button type="button" className="primary-btn btn-sm">
              Add task
            </button>
          </div>
        </div>
        <p className="panel__lede">
          Keep onboarding, access reviews, and audits on track from one place.
        </p>
      </section>
      )}

      <div className="dashboard-content">
        <div className="card main-card">
          <div className="card-header">
            <h3>Recent activity</h3>
            <button type="button" className="text-btn" onClick={loadStats} disabled={loading}>
              Refresh
            </button>
          </div>
          <div className="card-body">
            {loading ? (
              <p className="panel__lede">Loading activity…</p>
            ) : recentActivity.length === 0 ? (
              <p className="panel__lede">No recent updates yet.</p>
            ) : (
              <ul className="activity-list">
                {recentActivity.map((item, index) => (
                  <li key={`${item.type}-${item.timestamp}-${index}`}>
                    {item.message}
                    {item.timestamp && (
                      <span className="activity-list__time"> · {formatActivityTime(item.timestamp)}</span>
                    )}
                  </li>
                ))}
              </ul>
            )}
          </div>
        </div>

        <div className="card side-card">
          <div className="card-header">
            <h3>System status</h3>
          </div>
          <div className="card-body">
            <div className="status-item">
              <span>Database</span>
              <span className={`status-badge ${stats ? "online" : loading ? "" : "offline"}`}>
                {loading ? "…" : stats ? "Online" : "Offline"}
              </span>
            </div>
            <div className="status-item">
              <span>Active menus</span>
              <span className="status-badge online">{loading ? "…" : formatCount(stats?.menus_active)}</span>
            </div>
            <div className="status-item">
              <span>API</span>
              <span className={`status-badge ${stats ? "online" : loading ? "" : "offline"}`}>
                {loading ? "…" : stats ? "Online" : "Offline"}
              </span>
            </div>
          </div>
        </div>
      </div>

      {!isVendorDash && (
      <section className="quick-actions" aria-label="Quick actions">
        <button type="button" className="quick-action quick-action--primary">
          <Plus size={17} strokeWidth={2} aria-hidden />
          New report
        </button>
        <button type="button" className="quick-action quick-action--secondary">
          <FileText size={17} strokeWidth={1.75} aria-hidden />
          Audit log
        </button>
        <button type="button" className="quick-action quick-action--secondary">
          <UserPlus size={17} strokeWidth={1.75} aria-hidden />
          Invite user
        </button>
        <button type="button" className="quick-action quick-action--secondary">
          <List size={17} strokeWidth={1.75} aria-hidden />
          Menu manager
        </button>
        <button type="button" className="quick-action quick-action--secondary">
          <Settings size={17} strokeWidth={1.75} aria-hidden />
          Settings
        </button>
      </section>
      )}
    </div>
  );
};

export default Dashboard;
