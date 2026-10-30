class RuqyahSheikh {
  final String id;
  final String name;

  /// everyayah.com folder with verse-by-verse audio, if available.
  final String? everyAyahFolder;
  const RuqyahSheikh(this.id, this.name, {this.everyAyahFolder});
}

const List<RuqyahSheikh> ruqyahSheikhs = [
  RuqyahSheikh('maher', 'ماهر المعيقلي',
      everyAyahFolder: 'MaherAlMuaiqly128kbps'),
  RuqyahSheikh('hassan_saleh', 'حسن صالح'),
];

RuqyahSheikh? sheikhById(String? id) {
  for (final s in ruqyahSheikhs) {
    if (s.id == id) return s;
  }
  return null;
}

class AyahRange {
  final String label;
  final int surah;
  final int from;
  final int to;
  const AyahRange(this.label, this.surah, this.from, this.to);

  int get count => to - from + 1;
  Iterable<int> get ayat sync* {
    for (var a = from; a <= to; a++) {
      yield a;
    }
  }
}

/// The verses commonly recited as Ruqyah Shar'iyyah, in order.
const List<AyahRange> ruqyahAyat = [
  AyahRange('الفاتحة', 1, 1, 7),
  AyahRange('أول البقرة', 2, 1, 5),
  AyahRange('البقرة ١٠٢', 2, 102, 102),
  AyahRange('البقرة ١٦٣–١٦٤', 2, 163, 164),
  AyahRange('آية الكرسي', 2, 255, 257),
  AyahRange('خواتيم البقرة', 2, 284, 286),
  AyahRange('آل عمران ١٨–١٩', 3, 18, 19),
  AyahRange('الأعراف ٥٤–٥٦', 7, 54, 56),
  AyahRange('الأعراف ١١٧–١٢٢', 7, 117, 122),
  AyahRange('يونس ٧٩–٨٢', 10, 79, 82),
  AyahRange('طه ٦٥–٧٠', 20, 65, 70),
  AyahRange('المؤمنون ١١٥–١١٨', 23, 115, 118),
  AyahRange('أول الصافات', 37, 1, 10),
  AyahRange('الأحقاف ٢٩–٣٢', 46, 29, 32),
  AyahRange('الرحمن ٣٣–٣٦', 55, 33, 36),
  AyahRange('خواتيم الحشر', 59, 21, 24),
  AyahRange('أول الجن', 72, 1, 9),
  AyahRange('آيات الشفاء', 9, 14, 14),
  AyahRange('آيات الشفاء', 10, 57, 57),
  AyahRange('آيات الشفاء', 16, 69, 69),
  AyahRange('آيات الشفاء', 17, 82, 82),
  AyahRange('آيات الشفاء', 26, 80, 80),
  AyahRange('آيات الشفاء', 41, 44, 44),
  AyahRange('الإخلاص', 112, 1, 4),
  AyahRange('الفلق', 113, 1, 5),
  AyahRange('الناس', 114, 1, 6),
];

int get ruqyahAyatCount =>
    ruqyahAyat.fold(0, (sum, r) => sum + r.count);

String ayahFileName(int surah, int ayah) =>
    '${surah.toString().padLeft(3, '0')}${ayah.toString().padLeft(3, '0')}.mp3';
