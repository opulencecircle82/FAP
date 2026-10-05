/// App distribution settings for the AISAT download hub.
class AppConfig {
  AppConfig._();

  static const version = '2.6';
  static const apkFileName = 'AISAT_FAP_v2.6.apk';

  /// GitHub repository that hosts the releases and the landing page.
  static const repoUrl = 'https://github.com/opulencecircle82/FAP';

  /// Public landing page (GitHub Pages).
  static const landingUrl = 'https://opulencecircle82.github.io/FAP/';

  /// Always points at the APK of the newest GitHub release.
  static const apkUrl = '$repoUrl/releases/latest/download/$apkFileName';
}
