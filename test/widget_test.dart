import 'package:flutter_test/flutter_test.dart';
import 'package:sudoquran/services/library.dart';

void main() {
  test('detects surah numbers from file names', () {
    expect(Library.detectSurah('001.mp3'), 1);
    expect(Library.detectSurah('018 سورة الكهف.mp3'), 18);
    expect(Library.detectSurah('سورة الكهف - ماهر.mp3'), 18);
    expect(Library.detectSurah('random.mp3'), null);
  });
}
