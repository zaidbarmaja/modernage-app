import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';

/// مستخدم التطبيق (موظف / إدارة / محاسبة / زبون).
class AppUser {
  final String uid;
  final String name;
  final String username; // اسم الدخول (للموظفين/الإدارة)؛ للزبون = رقم هاتفه
  final String email; // بريد المصادقة الداخلي (الثابت لهذا الحساب)
  final List<String> loginNames; // مفاتيح الدخول المطبّعة (الاسم + الهاتف)
  final String phone;
  final UserRole role;
  final Department department; // قسم/تصنيف (تسمية فقط — الدوام أصبح مخصّصاً)
  // تصنيف موظف التنفيذ: تنفيذ عام / إشراف مسابح / تنفيذ مسابح (لقسم المسابح).
  final WorkCategory workCategory;
  // أوقات الدوام اختيارية (Nullable): قد لا يحدّدها المدير عند الإنشاء (المهمة #4).
  final int? workStartMin; // بداية الدوام (دقائق من منتصف الليل) — null = غير محدّد
  final int? workEndMin; // نهاية الدوام (دقائق من منتصف الليل) — null = غير محدّد
  final String contact; // بيانات التواصل (عنوان/هاتف بديل/ملاحظات) — للزبون أساساً
  final bool active; // هل الحساب مفعّل؟ تعطيله يمنع الدخول فوراً
  // عند true: يُتحقّق من الدخول عبر بيانات اعتماد Firestore (مجموعة credentials
  // المنفصلة) بدل كلمة مرور Firebase Auth. تجزئة كلمة المرور لا تُحفظ هنا أبداً.
  final bool useFirestorePassword;
  final DateTime? createdAt;

  /// قيم الدوام الافتراضية حين لا يحدّدها المدير.
  static const int defaultStartMin = 8 * 60; // 8:00 ص
  static const int defaultEndMin = 16 * 60; // 4:00 م

  const AppUser({
    required this.uid,
    required this.name,
    this.username = '',
    required this.email,
    this.loginNames = const [],
    this.phone = '',
    required this.role,
    this.department = Department.none,
    this.workCategory = WorkCategory.general,
    this.workStartMin,
    this.workEndMin,
    this.contact = '',
    this.active = true,
    this.useFirestorePassword = false,
    this.createdAt,
  });

  /// بداية/نهاية الدوام الفعليتان (تتراجعان للافتراضي عند عدم التحديد).
  int get effectiveStartMin => workStartMin ?? defaultStartMin;
  int get effectiveEndMin => workEndMin ?? defaultEndMin;

  /// هل حُدّد للموظف جدول دوام مخصّص؟
  bool get hasCustomSchedule => workStartMin != null && workEndMin != null;

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    return AppUser(
      uid: uid,
      name: (map['name'] ?? '') as String,
      username: (map['username'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      loginNames: ((map['loginNames'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      phone: (map['phone'] ?? '') as String,
      role: UserRoleX.fromId(map['role'] as String?),
      department: DepartmentX.fromId(map['department'] as String?),
      workCategory: WorkCategoryX.fromId(map['workCategory'] as String?),
      workStartMin: (map['workStartMin'] as num?)?.toInt(),
      workEndMin: (map['workEndMin'] as num?)?.toInt(),
      contact: (map['contact'] ?? '') as String,
      active: (map['active'] as bool?) ?? true,
      useFirestorePassword: (map['useFirestorePassword'] as bool?) ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      AppUser.fromMap(doc.id, doc.data() ?? const {});

  Map<String, dynamic> toMap() => {
        'name': name,
        'username': username,
        'email': email,
        'loginNames': loginNames,
        'phone': phone,
        'role': role.id,
        'department': department.id,
        'workCategory': workCategory.id,
        'workStartMin': workStartMin,
        'workEndMin': workEndMin,
        'contact': contact,
        'active': active,
        'useFirestorePassword': useFirestorePassword,
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
      };

  bool get isEmployee =>
      role == UserRole.designEmployee || role == UserRole.executionEmployee;

  AppUser copyWith({
    String? name,
    String? username,
    String? phone,
    UserRole? role,
    Department? department,
    WorkCategory? workCategory,
    int? workStartMin,
    int? workEndMin,
    String? contact,
    bool? active,
  }) {
    return AppUser(
      uid: uid,
      name: name ?? this.name,
      username: username ?? this.username,
      email: email,
      loginNames: loginNames,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      department: department ?? this.department,
      workCategory: workCategory ?? this.workCategory,
      workStartMin: workStartMin ?? this.workStartMin,
      workEndMin: workEndMin ?? this.workEndMin,
      contact: contact ?? this.contact,
      active: active ?? this.active,
      useFirestorePassword: useFirestorePassword,
      createdAt: createdAt,
    );
  }
}
