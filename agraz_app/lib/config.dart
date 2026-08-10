// Dashboard backend lives at e.g. /home/narayan/personal/dashboard/backend — that is only
// where you run `go run .`. The Flutter app must use the server's HTTP base URL, not a path.
//
// Set AGRaz_API_BASE to the same host:port the website uses (without trailing slash):
//   - Android emulator on the same PC as the server: http://10.0.2.2:8000
//   - Server on another machine (IITMP, etc.): http://<that-machine-LAN-IP>:8000
//   - Physical phone: http://<PC-or-server-LAN-IP>:8000  (not localhost from the phone)
//   - Backend inside WSL2, app on Windows emulator: often http://<WSL-IP>:8000 not 10.0.2.2
//
// Store (Buy & Sell browse): GET /api/store/products?status=active&limit=50 — public, no JWT.
// Server cart: /api/store/cart — JWT required (see auth_token + login).
//
// **Multi-tenant (same as web `VITE_TENANT_ID` / admin `x_tenant_id`):** backend expects
// header `X-Tenant-ID` on requests. Set at run time:
//   flutter run --dart-define=AGRaz_API_BASE=http://10.0.2.2:8000 --dart-define=AGRaz_TENANT_ID=your-tenant-uuid
//
// Optional single-vendor catalog filter (mirrors storefront `vendor_id`):
//   --dart-define=AGRaz_STORE_VENDOR_ID=123
//
// Example:
//   flutter run --dart-define=AGRaz_API_BASE=http://192.168.1.50:8000

const String BASE_URL = String.fromEnvironment(
  'AGRaz_API_BASE',
  defaultValue: 'https://agrazllp.com',
);

/// Fixed IP for [BASE_URL] host when emulator DNS fails (TCP still works).
/// Override: `--dart-define=AGRaz_API_HOST_IP=88.222.242.192`
const String apiHostIpOverride = String.fromEnvironment(
  'AGRaz_API_HOST_IP',
  defaultValue: '88.222.242.192',
);

/// Mirrors web `VITE_TENANT_ID` — sent as HTTP header `X-Tenant-ID` (marketplace / multi-tenant).
const String TENANT_ID = String.fromEnvironment(
  'AGRaz_TENANT_ID',
  defaultValue: '',
);

/// Optional: limit store catalog to one vendor (`vendor_id` query param).
const String STORE_VENDOR_ID = String.fromEnvironment(
  'AGRaz_STORE_VENDOR_ID',
  defaultValue: '',
);

/// Adds `X-Tenant-ID` when [TENANT_ID] is non-empty (required by many dashboard routes).
void mergeTenantHeaders(Map<String, String> headers) {
  final tid = TENANT_ID.trim();
  if (tid.isNotEmpty) {
    headers['X-Tenant-ID'] = tid;
  }
}

/// Normalized base URL (no trailing slash) for concatenation.
String normalizedBaseUrl() {
  final b = BASE_URL.trim();
  if (b.endsWith('/')) return b.substring(0, b.length - 1);
  return b;
}

/// Turn `/uploads/...` or full URLs into a string [Image.network] can load.
String resolveStoreMediaUrl(String ref) {
  final t = ref.trim();
  if (t.isEmpty) return t;
  if (t.startsWith('http://') || t.startsWith('https://')) return t;
  final base = normalizedBaseUrl();
  if (t.startsWith('/')) return '$base$t';
  return '$base/$t';
}
