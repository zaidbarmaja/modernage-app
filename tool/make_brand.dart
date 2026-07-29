// يولّد ملفات الشعار من brand/logo.template.svg:
//
//   brand/logo.svg          للخلفيات الفاتحة (ورق، مطبوعات، متجر التطبيقات)
//   brand/logo_on_dark.svg  للخلفية الداكنة (داخل التطبيق، خلفية #161911)
//
// يضمّن خط Tajawal Bold داخل كل ملف (base64) فيظهر الاسم بنفس الشكل على أي
// جهاز حتى لو لم يكن الخط منصّباً عليه.
//
// التشغيل من مجلد المشروع:
//     dart run tool/make_brand.dart
import 'dart:convert';
import 'dart:io';

/// لون الخط والاسم في كل نسخة (تدرّج الواجهة نفسه في الاثنتين).
const _variants = <String, String>{
  'brand/logo.svg': '#515E39', // زيتوني داكن
  'brand/logo_on_dark.svg': '#ECEFE1', // كريمي فاتح
};

void main() {
  final template = File('brand/logo.template.svg');
  final font = File('assets/fonts/Tajawal-Bold.ttf');

  if (!template.existsSync()) {
    stderr.writeln('القالب غير موجود: ${template.path}');
    exit(1);
  }
  if (!font.existsSync()) {
    stderr.writeln('الخط غير موجود: ${font.path}');
    exit(1);
  }

  final b64 = base64Encode(font.readAsBytesSync());
  final src = template.readAsStringSync().replaceAll('__FONT_B64__', b64);

  _variants.forEach((path, ink) {
    final out = File(path)..writeAsStringSync(src.replaceAll('__INK__', ink));
    stdout.writeln('تم توليد $path (${(out.lengthSync() / 1024).round()} كيلوبايت)');
  });
}
