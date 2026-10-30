import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/owners.dart';
import '../data/reciters.dart';
import '../data/ruqyah.dart';
import '../services/library.dart';
import 'glass.dart';

Future<void> pickPhotoFor(BuildContext context, String id) async {
  final img = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 600, imageQuality: 90);
  if (img == null) return;
  await Library.instance.setPhoto(id, img.path);
  if (context.mounted) toast(context, 'اتحطت صورة ${ownerName(id)} ✓');
}

/// Lets the user set a real photo for every sheikh (tap = choose, long-press = remove).
class PhotosCard extends StatelessWidget {
  const PhotosCard({super.key});

  @override
  Widget build(BuildContext context) {
    final ids = [
      for (final r in reciters) r.id,
      for (final s in ruqyahSheikhs)
        if (reciterById(s.id) == null) s.id,
    ];
    return Glass(
      radius: 26,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(Icons.photo_library_rounded, color: AppColors.gold, size: 30),
            const SizedBox(width: 12),
            const Text('صور الشيوخ', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 4),
          Text('دوس على الشيخ واختار صورته من الجهاز · ضغطة طويلة تشيلها',
              style: TextStyle(color: AppColors.muted, fontSize: 15)),
          const SizedBox(height: 14),
          ListenableBuilder(
            listenable: Library.instance,
            builder: (context, _) => Wrap(
              spacing: 18,
              runSpacing: 16,
              children: [
                for (final id in ids)
                  InkWell(
                    borderRadius: BorderRadius.circular(60),
                    onTap: () => pickPhotoFor(context, id),
                    onLongPress: () => Library.instance.removePhoto(id),
                    child: SizedBox(
                      width: 104,
                      child: Column(children: [
                        ReciterAvatar(ownerInitials(id), photoId: id, size: 76),
                        const SizedBox(height: 6),
                        Text(ownerName(id),
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14, height: 1.2)),
                      ]),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
