import 'dart:io';

import 'config.dart';

/// Android emulators often fail DNS (`Failed host lookup`) while TCP still works.
/// Connect to a fixed IP but keep TLS SNI / cert checks on the real hostname.
class AgrazHttpOverrides extends HttpOverrides {
  AgrazHttpOverrides();

  static final Map<String, String> _hostToIp = {
    'agrazllp.com': apiHostIpOverride,
    'www.agrazllp.com': apiHostIpOverride,
  };

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.connectionFactory = (Uri uri, String? proxyHost, int? proxyPort) async {
      // Leave proxy handling to the default stack.
      if (proxyHost != null) {
        return Socket.startConnect(proxyHost, proxyPort!);
      }

      final mapped = _hostToIp[uri.host.toLowerCase()];
      final Object endpoint =
          (mapped != null && mapped.isNotEmpty)
              ? InternetAddress(mapped)
              : uri.host;

      if (uri.scheme == 'https') {
        // Must negotiate TLS ourselves when connectionFactory is set;
        // a plain Socket to :443 causes nginx "plain HTTP to HTTPS port".
        final raw = await Socket.connect(endpoint, uri.port);
        final secure = await SecureSocket.secure(
          raw,
          context: context,
          host: uri.host,
        );
        return ConnectionTask.fromSocket(
          Future<Socket>.value(secure),
          secure.destroy,
        );
      }

      return Socket.startConnect(endpoint, uri.port);
    };
    return client;
  }
}
