import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Local, offline persistence: one JSON document written atomically
/// (temp file + rename) plus an images folder. Corrupt files are kept as
/// *.corrupt instead of being silently deleted.
class Store {
  late Directory dir;
  late Directory imagesDir;
  late File file;

  Future<void> init() async {
    dir = await getApplicationDocumentsDirectory();
    imagesDir = Directory('${dir.path}/marker_images');
    if (!await imagesDir.exists()) await imagesDir.create(recursive: true);
    file = File('${dir.path}/marker_creator_db.json');
  }

  Future<Map<String, dynamic>?> read() async {
    if (!await file.exists()) return null;
    try {
      final txt = await file.readAsString();
      return Map<String, dynamic>.from(jsonDecode(txt) as Map);
    } catch (_) {
      try {
        await file.rename('${file.path}.corrupt');
      } catch (_) {}
      return null;
    }
  }

  Future<void> write(Map<String, dynamic> data) async {
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(data), flush: true);
    await tmp.rename(file.path);
  }

  String imagePath(String name) => '${imagesDir.path}/$name';
}
