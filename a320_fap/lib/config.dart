/// App version and branding.
class AppConfig {
  AppConfig._();

  static const version = '3.4';

  /// School name shown in the app. Build with `--dart-define=BRAND=` for a
  /// neutral, school-free build (used for the generic tutorial video).
  static const brand = String.fromEnvironment('BRAND', defaultValue: 'AISAT');

  static String get appName =>
      brand.isEmpty ? 'A320 FAP Simulator' : '$brand A320 FAP Simulator';
}
