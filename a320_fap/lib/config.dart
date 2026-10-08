/// App version and branding.
class AppConfig {
  AppConfig._();

  static const version = '3.7';

  /// Optional school name shown in the app (`--dart-define=BRAND=...`).
  /// The released app is school-free: "A320 FAP Simulator".
  static const brand = String.fromEnvironment('BRAND');

  static String get appName =>
      brand.isEmpty ? 'A320 FAP Simulator' : '$brand A320 FAP Simulator';
}
