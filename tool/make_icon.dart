// سكربت لمرّة واحدة: يبني أيقونة التطبيق من الشعار القديم (logo.png):
// يقصّ الهوامش البيضاء حول الشعار ثم يكبّره على خلفية بيضاء نظيفة (بلا صندوق
// ملوّن)، فيظهر الشعار كبيرًا وواضحًا.
//   • app_icon.png    : 1024×1024، خلفية بيضاء + الشعار مقصوصًا بنسبة ~%94.
//   • app_icon_fg.png : 1024×1024، خلفية شفّافة + الشعار بنسبة ~%74 (طبقة
//                       أمامية تكيّفية ضمن المنطقة الآمنة على أندرويد).
import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  final bytes = File('assets/images/logo.png').readAsBytesSync();
  final src = img.decodeImage(bytes);
  if (src == null) {
    stderr.writeln('تعذّر قراءة logo.png');
    exit(1);
  }
  final logo = _trimWhite(src); // الشعار مقصوصًا من الهوامش البيضاء

  _make(logo, 1024, 0.94, true, 'assets/images/app_icon.png');
  _make(logo, 1024, 0.74, false, 'assets/images/app_icon_fg.png');

  stdout.writeln('تم توليد app_icon.png و app_icon_fg.png من logo.png');
}

/// يقصّ الهوامش شبه البيضاء حول الشعار (أي بكسل قناته الدنيا ≥ 245 يُعتبر خلفية).
img.Image _trimWhite(img.Image src) {
  int minX = src.width, minY = src.height, maxX = -1, maxY = -1;
  for (var y = 0; y < src.height; y++) {
    for (var x = 0; x < src.width; x++) {
      final p = src.getPixel(x, y);
      final r = p.r.toInt(), g = p.g.toInt(), b = p.b.toInt();
      final mn = r < g ? (r < b ? r : b) : (g < b ? g : b);
      if (mn < 245) {
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }
  }
  if (maxX < minX || maxY < minY) return src; // لا شيء غير أبيض
  // هامش صغير حول الشعار.
  const pad = 12;
  minX = (minX - pad).clamp(0, src.width - 1);
  minY = (minY - pad).clamp(0, src.height - 1);
  maxX = (maxX + pad).clamp(0, src.width - 1);
  maxY = (maxY + pad).clamp(0, src.height - 1);
  return img.copyCrop(src,
      x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1);
}

void _make(img.Image logo, int size, double scale, bool whiteBg, String outPath) {
  final canvas = img.Image(width: size, height: size, numChannels: 4);
  img.fill(canvas,
      color: whiteBg
          ? img.ColorRgba8(255, 255, 255, 255)
          : img.ColorRgba8(0, 0, 0, 0));

  final box = size * scale;
  final ratio = logo.width / logo.height;
  int w, h;
  if (logo.width >= logo.height) {
    w = box.round();
    h = (box / ratio).round();
  } else {
    h = box.round();
    w = (box * ratio).round();
  }
  final resized = img.copyResize(logo,
      width: w, height: h, interpolation: img.Interpolation.cubic);
  final dx = ((size - w) / 2).round();
  final dy = ((size - h) / 2).round();
  img.compositeImage(canvas, resized, dstX: dx, dstY: dy);

  File(outPath).writeAsBytesSync(img.encodePng(canvas));
}
