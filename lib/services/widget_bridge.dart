import 'package:home_widget/home_widget.dart';

/// Pushes "now playing" to the Android home-screen widget.
class HomeWidgetBridge {
  static String _last = '';

  static Future<void> update(String title, String subtitle, bool playing) async {
    final sig = '$title|$subtitle|$playing';
    if (sig == _last) return;
    _last = sig;
    try {
      await HomeWidget.saveWidgetData<String>('title', title.isEmpty ? 'القرآن الكريم' : title);
      await HomeWidget.saveWidgetData<String>('subtitle', subtitle.isEmpty ? 'اضغط للتشغيل' : subtitle);
      await HomeWidget.saveWidgetData<bool>('playing', playing);
      await HomeWidget.updateWidget(
        qualifiedAndroidName: 'com.sudosoc.sudoquran.QuranWidgetProvider',
      );
    } catch (_) {}
  }
}
