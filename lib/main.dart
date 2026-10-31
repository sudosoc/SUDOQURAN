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
  AppColors.apply(themeById(Settings.instance.themeId, Settings.instance.customColors));
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

String? _themeSig;

class SudoQuranApp extends StatelessWidget {
  const SudoQuranApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Settings.instance,
      builder: (context, _) {
        final st = Settings.instance;
        final sig = st.themeId == 'custom' ? 'custom-${st.customColors.join('-')}' : st.themeId;
        if (_themeSig != sig) {
          _themeSig = sig;
          AppColors.apply(themeById(st.themeId, st.customColors));
        }
        return MaterialApp(
          // A new key per theme rebuilds every widget with the new palette.
          key: ValueKey(sig),
          builder: (context, child) {
            // Show real errors instead of Flutter's blank grey box.
            ErrorWidget.builder = (d) => Container(
                  padding: const EdgeInsets.all(12),
                  color: const Color(0x33FF4444),
                  child: Text('خطأ: ${d.exceptionAsString()}',
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 13)),
                );
            return child!;
          },
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
      },
    );
  }
}
