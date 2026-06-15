import 'package:intl/intl.dart';

/// نقل أمين لمنطق الوقت والساعات من script.js.
/// الدوام الرسمي: 8:00 صباحًا — 4:00 مساءً.
class WorkTime {
  static const int workStartMin = 8 * 60; // 480
  static const int workEndMin = 16 * 60; // 960

  /// "0 دقيقة" / "X ساعة" / "X ساعة وY دقيقة"
  static String minutesToText(int minutes) {
    if (minutes <= 0) return '0 دقيقة';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0 && mins > 0) return '$hours ساعة و$mins دقيقة';
    if (hours > 0) return '$hours ساعة';
    return '$mins دقيقة';
  }

  static DateTime? _parse(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  /// مفتاح التاريخ المحلي YYYY-MM-DD (يطابق منطق العطل).
  static String dateKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  /// مفتاح تاريخ سجل البصمة من checkIn.
  static String attendanceDateKey(Map<String, dynamic> data) {
    final ci = _parse(data['checkIn']);
    if (ci == null) return '';
    return dateKey(ci);
  }

  /// عدد الأيام الكاملة بين مفتاحَي تاريخ.
  static int daysBetween(String fromKey, String toKey) {
    final from = DateTime.tryParse(fromKey);
    final to = DateTime.tryParse(toKey);
    if (from == null || to == null) return 0;
    return to.difference(from).inDays;
  }

  static int workedMinutes(Map<String, dynamic> data) {
    final ci = _parse(data['checkIn']);
    final co = _parse(data['checkOut']);
    if (ci == null || co == null) return 0;
    final m = (co.difference(ci).inSeconds / 60).round();
    return m > 0 ? m : 0;
  }

  /// موعد بداية الدوام لهذا السجل (بالدقائق من منتصف الليل) — من السجل أو الافتراضي.
  static int scheduleStart(Map<String, dynamic> data) {
    final v = data['workStart'];
    return (v is num) ? v.toInt() : workStartMin;
  }

  /// موعد نهاية الدوام لهذا السجل (بالدقائق من منتصف الليل) — من السجل أو الافتراضي.
  static int scheduleEnd(Map<String, dynamic> data) {
    final v = data['workEnd'];
    return (v is num) ? v.toInt() : workEndMin;
  }

  /// التأخير/الإضافي/العمل لسجل واحد نسبةً لمواعيد الدوام المحفوظة بالسجل
  /// (أو 8:00–4:00 افتراضيًا للسجلات القديمة).
  static AttendanceStats stats(Map<String, dynamic> data) {
    final ci = _parse(data['checkIn']);
    final open = data['checkOut'] == null ||
        (data['checkOut'] is String && (data['checkOut'] as String).isEmpty);
    if (ci == null) {
      return AttendanceStats(open: open, late: 0, overtime: 0, worked: 0);
    }

    final ws = scheduleStart(data);
    final we = scheduleEnd(data);
    final dayStart = DateTime(ci.year, ci.month, ci.day, ws ~/ 60, ws % 60);
    final dayEnd = DateTime(ci.year, ci.month, ci.day, we ~/ 60, we % 60);

    final late =
        (ci.difference(dayStart).inSeconds / 60).round().clamp(0, 1 << 30);

    if (open) {
      return AttendanceStats(open: true, late: late, overtime: 0, worked: 0);
    }

    final co = _parse(data['checkOut']);
    final overtime = co == null
        ? 0
        : (co.difference(dayEnd).inSeconds / 60).round().clamp(0, 1 << 30);
    return AttendanceStats(
      open: false,
      late: late,
      overtime: overtime,
      worked: workedMinutes(data),
    );
  }
}

class AttendanceStats {
  final bool open;
  final int late;
  final int overtime;
  final int worked;
  const AttendanceStats({
    required this.open,
    required this.late,
    required this.overtime,
    required this.worked,
  });
}

/// تنسيق التاريخ والوقت بالعربية (تقويم ميلادي، صيغة 12 ساعة).
class ArDate {
  static final _dateFmt = DateFormat('d MMMM y', 'ar');
  static final _timeFmt = DateFormat('h:mm a', 'ar');

  static String dateOnly(dynamic value) {
    final d = value is DateTime ? value : DateTime.tryParse('$value');
    if (d == null) return '—';
    return _dateFmt.format(d);
  }

  static String timeOnly(dynamic value) {
    final d = value is DateTime ? value : DateTime.tryParse('$value');
    if (d == null) return '—';
    return _timeFmt.format(d);
  }

  static String fullArabicDate(DateTime d) => _dateFmt.format(d);

  /// تحويل دقائق من منتصف الليل إلى وقت عربي 12 ساعة (مثل: ٨:٠٠ صباحًا).
  static String clockLabel(int minutes) {
    final h = (minutes ~/ 60) % 24;
    final m = minutes % 60;
    return _timeFmt.format(DateTime(2020, 1, 1, h, m));
  }
}

/// تنسيق الأرقام بالعربية (للمصروفات والتكاليف).
String arNumber(num value) {
  final f = NumberFormat.decimalPattern('ar');
  return f.format(value);
}

const Map<int, String> _arWeekdayNames = {
  7: 'الأحد',
  1: 'الإثنين',
  2: 'الثلاثاء',
  3: 'الأربعاء',
  4: 'الخميس',
  5: 'الجمعة',
  6: 'السبت',
};

/// اسم اليوم العربي من ترقيم DateTime.weekday (الإثنين=1..الأحد=7).
String arWeekday(int wd) => _arWeekdayNames[wd] ?? '';

/// اسم العملة: IQD → دينار عراقي، USD → دولار.
String currencyName(String c) => c == 'USD' ? 'دولار' : 'دينار عراقي';

/// رمز العملة المختصر.
String currencySymbol(String c) => c == 'USD' ? '\$' : 'د.ع';

/// تنسيق مبلغ مالي مع رمز العملة (مثل: ١٢٬٥٠٠ د.ع).
String moneyLabel(num amount, String currency) =>
    '${arNumber(amount)} ${currencySymbol(currency)}';

/// قائمة أيام مرتّبة بالترتيب العربي (الأحد أولًا) كنص مفصول بفواصل.
String arWeekdaysLabel(List<int> days) {
  const order = [7, 1, 2, 3, 4, 5, 6];
  final set = days.toSet();
  final names = [
    for (final wd in order)
      if (set.contains(wd)) _arWeekdayNames[wd]!
  ];
  return names.isEmpty ? '—' : names.join('، ');
}
