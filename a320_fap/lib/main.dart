import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'providers/fap_provider.dart';
import 'screens/fap_simulator_screen.dart';
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

  runApp(AisatFapApp(fap: fap));
}

class AisatFapApp extends StatelessWidget {
  const AisatFapApp({super.key, required this.fap});

  final FapProvider fap;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: fap),
        ChangeNotifierProvider(create: (_) => Blink()),
      ],
      child: MaterialApp(
        title: 'AISAT A320 FAP Simulator',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        initialRoute: FapSimulatorScreen.route,
        routes: {FapSimulatorScreen.route: (_) => const FapSimulatorScreen()},
      ),
    );
  }
}
