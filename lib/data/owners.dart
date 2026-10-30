import 'reciters.dart';
import 'ruqyah.dart';

/// Display name for a reciter id or a ruqyah sheikh id.
String ownerName(String id) =>
    reciterById(id)?.name ?? sheikhById(id)?.name ?? id;

String ownerInitials(String id) {
  final r = reciterById(id);
  if (r != null) return r.initials;
  final s = sheikhById(id);
  if (s == null) return '۞';
  return Reciter(id: s.id, name: s.name, tokens: const []).initials;
}
