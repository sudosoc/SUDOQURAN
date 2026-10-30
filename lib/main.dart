import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:permission_handler/permission_handler.dart';

import 'services/library.dart';
import 'services/player.dart';
import 'services/settings.dart';
import 'services/sources.dart';
import 'ui/glass.dart';
import 'ui/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Background playback + media session (steering-wheel buttons, notification).
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.sudosoc.sudoquran.audio',
    androidNotificationChannelName: 'تلاوة القرآن',
    androidNotificationOngoing: true,
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  await Settings.instance.load();
  await Library.instance.init();
  await Sources.instance.load();
  // Don't block first frame on the notification permission dialog.
  Permission.notification.request().ignore();
  await Player.instance.init();

  // Pull the latest verified links, then resume pending downloads.
  Sources.instance.refresh().whenComplete(() {
    if (Settings.instance.autoDownload) Library.instance.downloadEverything();
  });

  runApp(const SudoQuranApp());
}

class SudoQuranApp extends StatelessWidget {
  const SudoQuranApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'القرآن الكريم',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HomeShell(),
    );
  }
}
