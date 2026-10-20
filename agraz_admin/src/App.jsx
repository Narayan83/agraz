import React from "react";
import { BrowserRouter as Router, Routes, Route, Navigate, useParams } from "react-router-dom";
import Layout from "./components/Layout/Layout";
import Dashboard from "./pages/Dashboard";
import RolePermissions from "./pages/RolePermissions";
import UserList from "./pages/UserList";
import RoleManagement from "./pages/RoleManagement";
import UserRoleMap from "./pages/UserRoleMap";
import MenuManagement from "./pages/MenuManagement";
import ServiceRegistrations from "./pages/ServiceRegistrations";
import VendorDetails from "./pages/VendorDetails";
import VendorProductMapping from "./pages/VendorProductMapping";
import VendorUserMapping from "./pages/VendorUserMapping";
import EcomAdmin from "./pages/EcomAdmin";
import StorefrontHero from "./pages/StorefrontHero";
import GovFacilities from "./pages/GovFacilities";
import MarketReports from "./pages/MarketReports";
import FeedbackAdmin from "./pages/FeedbackAdmin";
import EntryAnalytics from "./pages/EntryAnalytics";
import AppContentAdmin from "./pages/AppContentAdmin";
import OrganizationsAdmin from "./pages/OrganizationsAdmin";
import Login from "./pages/Login";
import PublicServiceRegister from "./pages/PublicServiceRegister";
import RtcEntryAdmin from "./pages/RtcEntryAdmin";
import DairyAdmin from "./pages/DairyAdmin";
import DocumentsAdmin from "./pages/DocumentsAdmin";
import EventsAdmin from "./pages/EventsAdmin";
import AchieversLobbyAdmin from "./pages/AchieversLobbyAdmin";
import TransactionsHub from "./pages/transactions/TransactionsHub";
import IncomeExpenseEntry from "./pages/transactions/IncomeExpenseEntry";
import OrganizationsEntry from "./pages/transactions/OrganizationsEntry";
import LabourEntry from "./pages/transactions/LabourEntry";
import LabourWorkEntry from "./pages/transactions/LabourWorkEntry";
import DairyEntry from "./pages/transactions/DairyEntry";
import DairyOwnerEntry from "./pages/transactions/DairyOwnerEntry";
import NotesEntry from "./pages/transactions/NotesEntry";
import FuturePlansEntry from "./pages/transactions/FuturePlansEntry";
import RtcEntry from "./pages/transactions/RtcEntry";
import DocumentsEntry from "./pages/transactions/DocumentsEntry";
import EventsEntry from "./pages/transactions/EventsEntry";
import ContractManageHub from "./pages/contract/ContractManageHub";
import {
  CmCustomersPage,
  CmDealersPage,
  CmLabourSuppliersPage,
  CmLaboursPage,
  CmMaterialsPage,
  CmAssetsPage,
  CmPurchasesPage,
  CmPaymentsPage,
  CmStockReportPage,
  CmCustomerSummaryPage,
} from "./pages/contract/ContractPages";
import { CmProjectsFullPage, CmProjectLedgerPage, CmAuditPage, CmLabourWorksPage, CmStockIssuesPage } from "./pages/contract/ContractTxnPages";
import { logoutAndRedirect } from "./lib/authStorage";
import "./App.css";

const CmProjectLedgerRoute = () => {
  const { id } = useParams();
  return <CmProjectLedgerPage projectId={id} />;
};

/** Unknown URLs: stay logged-in users on hub; guests go to login (never wipe session). */
const CatchAll = () => {
  const token = localStorage.getItem("token");
  const user = localStorage.getItem("user");
  const loggedIn = token && token !== "undefined" && user && user !== "undefined";
  return <Navigate to={loggedIn ? "/contract-manage" : "/login"} replace />;
};

const routerBasename = (import.meta.env.BASE_URL || "/").replace(/\/$/, "");

const ProtectedRoute = ({ children }) => {
  const token = localStorage.getItem("token");
  const user = localStorage.getItem("user");

  if (!token || token === "undefined" || !user || user === "undefined") {
    return <Navigate to="/login" replace />;
  }

  return <Layout>{children}</Layout>;
};

const Placeholder = ({ title }) => (
  <div className="app-placeholder">
    <h2>{title}</h2>
    <p>This is the {title} page content. More features coming soon!</p>
  </div>
);

function App() {
  return (
    <Router basename={routerBasename && routerBasename !== "/" ? routerBasename : undefined}>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="/register-service" element={<PublicServiceRegister />} />

        <Route path="/" element={<Navigate to="/home" replace />} />

        <Route path="/home" element={<ProtectedRoute><Dashboard /></ProtectedRoute>} />
        <Route path="/users" element={<ProtectedRoute><UserList /></ProtectedRoute>} />
        <Route path="/rolecreation" element={<ProtectedRoute><RoleManagement /></ProtectedRoute>} />
        <Route path="/existingroles" element={<ProtectedRoute><RoleManagement /></ProtectedRoute>} />
        <Route path="/rolemanagement" element={<ProtectedRoute><RolePermissions /></ProtectedRoute>} />
        <Route path="/usermanagement" element={<ProtectedRoute><UserRoleMap /></ProtectedRoute>} />
        <Route path="/menucreation" element={<ProtectedRoute><MenuManagement /></ProtectedRoute>} />
        <Route path="/existingmenus" element={<ProtectedRoute><MenuManagement /></ProtectedRoute>} />
        <Route path="/service-registrations" element={<ProtectedRoute><ServiceRegistrations /></ProtectedRoute>} />
        <Route path="/vendor-details" element={<ProtectedRoute><VendorDetails /></ProtectedRoute>} />
        <Route path="/vendor-product-mapping" element={<ProtectedRoute><VendorProductMapping /></ProtectedRoute>} />
        <Route path="/vendor-user-mapping" element={<ProtectedRoute><VendorUserMapping /></ProtectedRoute>} />
        <Route path="/ecom-admin" element={<ProtectedRoute><EcomAdmin /></ProtectedRoute>} />
        <Route path="/storefront-hero" element={<ProtectedRoute><StorefrontHero /></ProtectedRoute>} />
        <Route path="/gov-facilities" element={<ProtectedRoute><GovFacilities /></ProtectedRoute>} />
        <Route path="/market-reports" element={<ProtectedRoute><MarketReports /></ProtectedRoute>} />
        <Route path="/feedback" element={<ProtectedRoute><FeedbackAdmin /></ProtectedRoute>} />
        <Route path="/entry-analytics" element={<ProtectedRoute><EntryAnalytics /></ProtectedRoute>} />
        <Route path="/organizations" element={<ProtectedRoute><OrganizationsAdmin /></ProtectedRoute>} />
        <Route path="/app-contents" element={<ProtectedRoute><AppContentAdmin /></ProtectedRoute>} />
        <Route path="/rtc-entry" element={<ProtectedRoute><RtcEntryAdmin /></ProtectedRoute>} />
        <Route path="/dairy" element={<ProtectedRoute><DairyAdmin /></ProtectedRoute>} />
        <Route path="/documents" element={<ProtectedRoute><DocumentsAdmin /></ProtectedRoute>} />
        <Route path="/events" element={<ProtectedRoute><EventsAdmin /></ProtectedRoute>} />
        <Route path="/achievers-lobby" element={<ProtectedRoute><AchieversLobbyAdmin /></ProtectedRoute>} />

        <Route path="/transactions" element={<ProtectedRoute><TransactionsHub /></ProtectedRoute>} />
        <Route path="/transactions/income-expense" element={<ProtectedRoute><IncomeExpenseEntry /></ProtectedRoute>} />
        <Route path="/transactions/organizations" element={<ProtectedRoute><OrganizationsEntry /></ProtectedRoute>} />
        <Route path="/transactions/labour" element={<ProtectedRoute><LabourEntry /></ProtectedRoute>} />
        <Route path="/transactions/labour-work" element={<ProtectedRoute><LabourWorkEntry /></ProtectedRoute>} />
        <Route path="/transactions/dairy" element={<ProtectedRoute><DairyEntry /></ProtectedRoute>} />
        <Route path="/transactions/dairy-owner" element={<ProtectedRoute><DairyOwnerEntry /></ProtectedRoute>} />
        <Route path="/transactions/notes" element={<ProtectedRoute><NotesEntry /></ProtectedRoute>} />
        <Route path="/transactions/future-plans" element={<ProtectedRoute><FuturePlansEntry /></ProtectedRoute>} />
        <Route path="/transactions/rtc" element={<ProtectedRoute><RtcEntry /></ProtectedRoute>} />
        <Route path="/transactions/documents" element={<ProtectedRoute><DocumentsEntry /></ProtectedRoute>} />
        <Route path="/transactions/events" element={<ProtectedRoute><EventsEntry /></ProtectedRoute>} />

        <Route path="/contract-manage" element={<ProtectedRoute><ContractManageHub /></ProtectedRoute>} />
        <Route path="/contract-manage/projects" element={<ProtectedRoute><CmProjectsFullPage /></ProtectedRoute>} />
        <Route path="/contract-manage/projects/:id" element={<ProtectedRoute><CmProjectLedgerRoute /></ProtectedRoute>} />
        <Route path="/contract-manage/customers" element={<ProtectedRoute><CmCustomersPage /></ProtectedRoute>} />
        <Route path="/contract-manage/customer-summary" element={<ProtectedRoute><CmCustomerSummaryPage /></ProtectedRoute>} />
        <Route path="/contract-manage/dealers" element={<ProtectedRoute><CmDealersPage /></ProtectedRoute>} />
        <Route path="/contract-manage/labour-suppliers" element={<ProtectedRoute><CmLabourSuppliersPage /></ProtectedRoute>} />
        <Route path="/contract-manage/labours" element={<ProtectedRoute><CmLaboursPage /></ProtectedRoute>} />
        <Route path="/contract-manage/labour-works" element={<ProtectedRoute><CmLabourWorksPage /></ProtectedRoute>} />
        <Route path="/contract-manage/materials" element={<ProtectedRoute><CmMaterialsPage /></ProtectedRoute>} />
        <Route path="/contract-manage/purchases" element={<ProtectedRoute><CmPurchasesPage /></ProtectedRoute>} />
        <Route path="/contract-manage/stock-issues" element={<ProtectedRoute><CmStockIssuesPage /></ProtectedRoute>} />
        <Route path="/contract-manage/stock-report" element={<ProtectedRoute><CmStockReportPage /></ProtectedRoute>} />
        <Route path="/contract-manage/payments" element={<ProtectedRoute><CmPaymentsPage /></ProtectedRoute>} />
        <Route path="/contract-manage/assets" element={<ProtectedRoute><CmAssetsPage /></ProtectedRoute>} />
        <Route path="/contract-manage/audit" element={<ProtectedRoute><CmAuditPage /></ProtectedRoute>} />

        <Route path="/auditlogs" element={<ProtectedRoute><Placeholder title="Audit Logs" /></ProtectedRoute>} />
        <Route path="/profile" element={<ProtectedRoute><Placeholder title="My Profile" /></ProtectedRoute>} />
        <Route path="/logout" element={<LogoutAction />} />
        <Route path="*" element={<CatchAll />} />
      </Routes>
    </Router>
  );
}

const LogoutAction = () => {
  React.useLayoutEffect(() => {
    logoutAndRedirect();
  }, []);
  return null;
};

export default App;
