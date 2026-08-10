import 'http_setup_stub.dart'
    if (dart.library.io) 'http_setup_io.dart' as http_setup;

void setupAgrazHttpOverrides() => http_setup.setupAgrazHttpOverrides();
