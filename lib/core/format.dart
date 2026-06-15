import 'package:intl/intl.dart';

/// دوال مساعدة لتنسيق التاريخ والوقت والمبالغ بشكل موحّد في كامل التطبيق.
class Fmt {
  Fmt._();

  static final DateFormat _date = DateFormat('yyyy/MM/dd');
  static final DateFormat _time = DateFormat('hh:mm a');
  static final DateFormat _dateTime = DateFormat('yyyy/MM/dd  hh:mm a');
  static final NumberFormat _money = NumberFormat('#,##0', 'en');

  static String date(DateTime? d) => d == null ? '—' : _date.format(d);

  static String time(DateTime? d) => d == null ? '—' : _time.format(d);

  static String dateTime(DateTime? d) => d == null ? '—' : _dateTime.format(d);

  /// مبلغ مالي بصيغة مفصولة بفواصل + العملة.
  static String money(num? value, {String currency = 'د.ع'}) {
    if (value == null) return '—';
    return '${_money.format(value)} $currency';
  }

  /// تحويل عدد دقائق إلى نص "س ساعة و د دقيقة".
  static String duration(int minutes) {
    if (minutes <= 0) return '0 دقيقة';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m دقيقة';
    if (m == 0) return '$h ساعة';
    return '$h ساعة و $m دقيقة';
  }

  /// نص مختصر بالساعات بصيغة عشرية (مثلاً 7.5 ساعة).
  static String hours(int minutes) {
    final h = minutes / 60.0;
    return '${h.toStringAsFixed(1)} ساعة';
  }
}
