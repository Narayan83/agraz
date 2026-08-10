import 'dart:io';

import 'agraz_http_overrides.dart';

void setupAgrazHttpOverrides() {
  HttpOverrides.global = AgrazHttpOverrides();
}
