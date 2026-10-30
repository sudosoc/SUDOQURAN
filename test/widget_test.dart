import 'package:flutter_test/flutter_test.dart';
import 'package:sudoquran/data/surahs.dart';

void main() {
  test('surah table is complete', () {
    expect(surahs.length, 114);
    expect(surahs.fold<int>(0, (a, s) => a + s.ayahs), 6236);
  });
}
