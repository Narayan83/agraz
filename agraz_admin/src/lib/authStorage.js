/** Clear all client-side auth state (call before navigating to /login). */
export function clearAuthStorage() {
  localStorage.removeItem("token");
  localStorage.removeItem("user");
  localStorage.removeItem("x_tenant_id");
}

/** Full-page redirect to login (works with Vite base path e.g. /agraz_admin/). */
export function logoutAndRedirect() {
  clearAuthStorage();
  const base = import.meta.env.BASE_URL || "/";
  const loginPath = `${base}${base.endsWith("/") ? "" : "/"}login`;
  window.location.replace(loginPath);
}

export function getStoredUser() {
  const raw = localStorage.getItem("user");
  if (!raw || raw === "undefined") return null;
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

export function isVendorUser() {
  return Boolean(getStoredUser()?.is_vendor_user);
}
