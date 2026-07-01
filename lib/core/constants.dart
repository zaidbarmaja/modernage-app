import 'package:flutter/material.dart';

/// أدوار المستخدمين في النظام.
enum UserRole {
  admin, // الإدارة
  accounting, // المحاسبة
  designEmployee, // موظف التصميم
  executionEmployee, // موظف التنفيذ
  customer, // الزبون
}

extension UserRoleX on UserRole {
  String get id => name;

  String get labelAr {
    switch (this) {
      case UserRole.admin:
        return 'الإدارة';
      case UserRole.accounting:
        return 'المحاسبة';
      case UserRole.designEmployee:
        return 'موظف التصميم';
      case UserRole.executionEmployee:
        return 'موظف التنفيذ';
      case UserRole.customer:
        return 'الزبون';
    }
  }

  IconData get icon {
    switch (this) {
      case UserRole.admin:
        return Icons.admin_panel_settings;
      case UserRole.accounting:
        return Icons.calculate;
      case UserRole.designEmployee:
        return Icons.architecture;
      case UserRole.executionEmployee:
        return Icons.engineering;
      case UserRole.customer:
        return Icons.person;
    }
  }

  static UserRole fromId(String? value) {
    return UserRole.values.firstWhere(
      (r) => r.name == value,
      orElse: () => UserRole.customer,
    );
  }
}

/// القسم الوظيفي — يحدد جدول الدوام للبصمة.
enum Department {
  civil, // المدني  : 7 ص - 3 م
  architectural, // المعماري : 10 ص - 6 م
  none, // لمن لا ينطبق عليه دوام (محاسبة/إدارة/زبون مثلاً)
}

extension DepartmentX on Department {
  String get id => name;

  String get labelAr {
    switch (this) {
      case Department.civil:
        return 'المدني';
      case Department.architectural:
        return 'المعماري';
      case Department.none:
        return 'بدون قسم';
    }
  }

  /// ساعة بدء الدوام (24h).
  int get startHour {
    switch (this) {
      case Department.civil:
        return 7;
      case Department.architectural:
        return 10;
      case Department.none:
        return 0;
    }
  }

  /// ساعة انتهاء الدوام (24h).
  int get endHour {
    switch (this) {
      case Department.civil:
        return 15; // 3 مساءً
      case Department.architectural:
        return 18; // 6 مساءً
      case Department.none:
        return 0;
    }
  }

  /// عدد ساعات الدوام القياسية في اليوم.
  int get standardHours =>
      this == Department.none ? 0 : endHour - startHour; // 8 ساعات

  String get scheduleLabel {
    switch (this) {
      case Department.civil:
        return 'من 7 صباحاً إلى 3 عصراً';
      case Department.architectural:
        return 'من 10 صباحاً إلى 6 مساءً';
      case Department.none:
        return 'لا يوجد دوام محدد';
    }
  }

  static Department fromId(String? value) {
    return Department.values.firstWhere(
      (d) => d.name == value,
      orElse: () => Department.none,
    );
  }
}

/// أسماء مجموعات Firestore (collections) في مكان واحد لتفادي الأخطاء.
class FsCollections {
  FsCollections._();
  static const users = 'users';
  static const attendance = 'attendance';
  static const projects = 'projects'; // مشاريع التصميم
  static const sites = 'sites'; // مواقع العمل للتنفيذ
  static const executionReports = 'execution_reports';
  static const dailyReports = 'daily_reports'; // التقرير اليومي للموظف
  static const siteCheckins = 'site_checkins';
  static const expenses = 'expenses'; // السلف والصرفيات
  static const receipts = 'receipts'; // الوصولات الإلكترونية (المدفوعات)
  static const notifications = 'notifications';
  static const settings = 'settings'; // إعدادات الشركة (مستند company)
  // التنبيهات اليومية المجدولة التي يتحكّم بها المدير من الداشبورد؛ يقرأها
  // التطبيق ويجدول إشعارات محلية للموظفين (تذكير بالدخول/الخروج… إلخ).
  static const scheduledReminders = 'scheduled_reminders';
  // بيانات اعتماد كلمة المرور (تجزئة + ملح) — منفصلة عن ملف المستخدم كي لا
  // يقرأها الطاقم؛ لا تُحمَّل في نموذج AppUser إطلاقاً.
  static const credentials = 'credentials';
}

/// يوم العطلة الأسبوعية (الجمعة) — DateTime.friday == 5.
const int weekendDay = DateTime.friday;

/// أنواع العروض المتاحة لمشروع التصميم.
const List<String> kOfferTypes = [
  'تصميم معماري',
  'تصميم داخلي',
  'إشراف هندسي',
  'تصميم وتنفيذ',
  'استشارة هندسية',
  'أخرى',
];

/// حالات مشروع التصميم.
const List<String> kProjectStatuses = [
  'قيد العمل',
  'منجز',
  'معلّق',
];

/// تصنيف عمل التنفيذ: تنفيذ عام، أو أحد قسمي المسابح (إشراف/تنفيذ).
/// يُسنَد للموظف وللموقع لتنظيم قسم تنفيذ المسابح ضمن وحدة التنفيذ.
enum WorkCategory {
  general, // تنفيذ عام
  poolsSupervision, // إشراف مسابح
  poolsExecution, // تنفيذ مسابح
}

extension WorkCategoryX on WorkCategory {
  String get id => name;

  String get labelAr {
    switch (this) {
      case WorkCategory.general:
        return 'تنفيذ عام';
      case WorkCategory.poolsSupervision:
        return 'إشراف مسابح';
      case WorkCategory.poolsExecution:
        return 'تنفيذ مسابح';
    }
  }

  /// هل التصنيف ضمن قسم المسابح؟
  bool get isPools => this != WorkCategory.general;

  IconData get icon {
    switch (this) {
      case WorkCategory.general:
        return Icons.engineering;
      case WorkCategory.poolsSupervision:
        return Icons.visibility;
      case WorkCategory.poolsExecution:
        return Icons.pool;
    }
  }

  static WorkCategory fromId(String? value) => WorkCategory.values.firstWhere(
        (c) => c.name == value,
        orElse: () => WorkCategory.general,
      );
}

/// أقسام المسابح فقط (للاختيار حين يكون العمل ضمن المسابح).
const List<WorkCategory> kPoolsCategories = [
  WorkCategory.poolsSupervision,
  WorkCategory.poolsExecution,
];
