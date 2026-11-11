import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

class ImageInfoResult {
  final String? error;
  final String ext;
  final int w;
  final int h;
  final Uint8List bytes;
  ImageInfoResult(this.error, this.ext, this.w, this.h, this.bytes);
}

class ImageService {
  /// Validates JPG/PNG by magic bytes and reads the true pixel size.
  static Future<ImageInfoResult> inspect(String path) async {
    final bytes = await File(path).readAsBytes();
    String? ext;
    if (bytes.length > 4 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      ext = 'jpg';
    } else if (bytes.length > 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      ext = 'png';
    }
    if (ext == null) {
      return ImageInfoResult('Only JPG and PNG images are supported.', '', 0, 0, bytes);
    }
    ui.ImmutableBuffer? buf;
    ui.ImageDescriptor? desc;
    try {
      buf = await ui.ImmutableBuffer.fromUint8List(bytes);
      desc = await ui.ImageDescriptor.encoded(buf);
      return ImageInfoResult(null, ext, desc.width, desc.height, bytes);
    } catch (_) {
      return ImageInfoResult('This image could not be read.', ext, 0, 0, bytes);
    } finally {
      desc?.dispose();
      buf?.dispose();
    }
  }

  /// Decodes the image for display (downscaled to max 2400px on the long side;
  /// the stored original size is still used for calibration maths).
  static Future<ui.Image> load(String path, int w, int h) async {
    final bytes = await File(path).readAsBytes();
    const maxSide = 2400;
    final longSide = math.max(w, h);
    final k = longSide > maxSide ? maxSide / longSide : 1.0;
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: math.max(1, (w * k).round()),
      targetHeight: math.max(1, (h * k).round()),
    );
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }
}
