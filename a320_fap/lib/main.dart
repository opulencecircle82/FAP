import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'config.dart';
import 'providers/fap_provider.dart';
import 'screens/disclaimer_screen.dart';
import 'screens/fap_simulator_screen.dart';
import 'screens/unlock_screen.dart';
import 'services/access_lock.dart';
import 'theme/fap_theme.dart';
import 'widgets/blink.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    // The FAP is a landscape panel; run full-screen like the real unit.
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  final fap = FapProvider();
  await fap.load();
  final unlocked = await AccessLock.isUnlocked();

  runApp(AisatFapApp(fap: fap, unlocked: unlocked));
}

class AisatFapApp extends StatefulWidget {
  const AisatFapApp({
    super.key,
    required this.fap,
    this.unlocked = true,
    this.showDisclaimer = true,
  });

  final FapProvider fap;

  /// False the first time the app runs on a device: the open code is asked.
  final bool unlocked;

  /// The notice is shown at every start, after the open code.
  final bool showDisclaimer;

  @override
  State<AisatFapApp> createState() => _AisatFapAppState();
}

class _AisatFapAppState extends State<AisatFapApp> {
  // Shared by every route, so a new route (e.g. a web URL change) never
  // shows the lock again once the code has been entered.
  late final _unlocked = ValueNotifier<bool>(widget.unlocked);
  late final _agreed = ValueNotifier<bool>(!widget.showDisclaimer);

  @override
  void dispose() {
    _unlocked.dispose();
    _agreed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Route<void> home() => MaterialPageRoute<void>(
      builder: (_) => ListenableBuilder(
        listenable: Listenable.merge([_unlocked, _agreed]),
        builder: (_, _) {
          if (!_unlocked.value) {
            return UnlockScreen(onUnlocked: () => _unlocked.value = true);
          }
          if (!_agreed.value) {
            return DisclaimerScreen(onAgree: () => _agreed.value = true);
          }
          return const FapSimulatorScreen();
        },
      ),
    );
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.fap),
        ChangeNotifierProvider(create: (_) => Blink()),
      ],
      child: MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        // Any start URL (e.g. the web simulator's #/fap link) opens the same
        // single screen.
        onGenerateInitialRoutes: (_) => [home()],
        onGenerateRoute: (_) => home(),
      ),
    );
  }
}
