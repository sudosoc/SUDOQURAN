/// The reciters shown in the Quran section.
///
/// [tokens] are matched (after Arabic normalisation, spaces removed) against
/// reciter names from the mp3quran.net API to find their audio server on the
/// device at runtime. [fallbackServer] is used when the API can't be reached.
class Reciter {
  final String id;
  final String name;
  final String subtitle;
  final List<String> tokens;
  final String prefer; // preferred moshaf keyword, e.g. 'مرتل' / 'مجود'
  final String? fallbackServer;

  const Reciter({
    required this.id,
    required this.name,
    required this.tokens,
    this.subtitle = '',
    this.prefer = 'مرتل',
    this.fallbackServer,
  });

  String get initials {
    final parts = name
        .replaceAll('الشيخ ', '')
        .split(' ')
        .where((p) => p.isNotEmpty && p != 'بن' && p != 'عبد')
        .toList();
    String firstLetter(String w) {
      final s = w.startsWith('ال') && w.length > 2 ? w.substring(2) : w;
      return s.isEmpty ? '' : s.substring(0, 1);
    }

    if (parts.isEmpty) return '';
    if (parts.length == 1) return firstLetter(parts.first);
    return '${firstLetter(parts.first)} ${firstLetter(parts.last)}';
  }
}

const List<Reciter> reciters = [
  Reciter(
    id: 'minshawi',
    name: 'محمد صديق المنشاوي',
    tokens: ['المنشاوي'],
    fallbackServer: 'https://server10.mp3quran.net/minsh/',
  ),
  Reciter(
    id: 'banna',
    name: 'محمود علي البنا',
    tokens: ['محمود', 'البنا'],
    fallbackServer: 'https://server8.mp3quran.net/bna/',
  ),
  Reciter(
    id: 'maher',
    name: 'ماهر المعيقلي',
    tokens: ['المعيقلي'],
    fallbackServer: 'https://server12.mp3quran.net/maher/',
  ),
  Reciter(
    id: 'binhameed',
    name: 'أحمد بن طالب بن حميد',
    tokens: ['طالب', 'حميد'],
  ),
  Reciter(
    id: 'ghamdi',
    name: 'سعد الغامدي',
    tokens: ['سعد', 'الغامدي'],
    fallbackServer: 'https://server7.mp3quran.net/s_gmd/',
  ),
  Reciter(
    id: 'afasy',
    name: 'مشاري راشد العفاسي',
    tokens: ['مشاري'],
    fallbackServer: 'https://server8.mp3quran.net/afs/',
  ),
  Reciter(
    id: 'alhaj',
    name: 'عبد الرحمن الحاج',
    tokens: ['عبدالرحمن', 'الحاج'],
  ),
  Reciter(
    id: 'dawas',
    name: 'ماجد الدعوس',
    tokens: ['الدعوس'],
  ),
  Reciter(
    id: 'islamsobhi',
    name: 'إسلام صبحي',
    tokens: ['اسلام', 'صبحي'],
    fallbackServer:
        'https://server14.mp3quran.net/islam/Rewayat-Hafs-A-n-Assem/',
  ),
  Reciter(
    id: 'shamsan',
    name: 'وليد الشمسان',
    tokens: ['الشمسان'],
  ),
  Reciter(
    id: 'tablawi',
    name: 'محمد محمود الطبلاوي',
    subtitle: 'ترتيل',
    tokens: ['الطبلاوي'],
    fallbackServer: 'https://server12.mp3quran.net/tblawi/',
  ),
  Reciter(
    id: 'nasr',
    name: 'أحمد عبد الرازق نصر',
    tokens: ['احمد', 'نصر'],
  ),
  Reciter(
    id: 'dosari',
    name: 'ياسر الدوسري',
    tokens: ['ياسر', 'الدوسري'],
    fallbackServer: 'https://server11.mp3quran.net/yasser/',
  ),
  Reciter(
    id: 'ghazi',
    name: 'بلال الغازي',
    tokens: ['بلال', 'الغازي'],
  ),
  Reciter(
    id: 'basit',
    name: 'عبد الباسط عبد الصمد',
    tokens: ['عبدالباسط'],
    fallbackServer: 'https://server7.mp3quran.net/basit/',
  ),
  Reciter(
    id: 'omarali',
    name: 'عمر علي',
    tokens: ['عمرعلي'],
  ),
  Reciter(
    id: 'anas',
    name: 'أنس عبد الستار',
    tokens: ['انس', 'عبدالستار'],
  ),
];

Reciter? reciterById(String? id) {
  for (final r in reciters) {
    if (r.id == id) return r;
  }
  return null;
}
