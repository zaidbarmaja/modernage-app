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
  final int workStartMin; // بداية الدوام (دقائق من منتصف الليل) — يحدّدها المدير
  final int workEndMin; // نهاية الدوام (دقائق من منتصف الليل)
  final String contact; // بيانات التواصل (عنوان/هاتف بديل/ملاحظات) — للزبون أساساً
  final bool active; // هل الحساب مفعّل؟ تعطيله يمنع الدخول فوراً
  final DateTime? createdAt;

  const AppUser({
    required this.uid,
    required this.name,
    this.username = '',
    required this.email,
    this.loginNames = const [],
    this.phone = '',
    required this.role,
    this.department = Department.none,
    this.workStartMin = 8 * 60,
    this.workEndMin = 16 * 60,
    this.contact = '',
    this.active = true,
    this.createdAt,
  });

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
      workStartMin: (map['workStartMin'] as num?)?.toInt() ?? 8 * 60,
      workEndMin: (map['workEndMin'] as num?)?.toInt() ?? 16 * 60,
      contact: (map['contact'] ?? '') as String,
      active: (map['active'] as bool?) ?? true,
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
        'workStartMin': workStartMin,
        'workEndMin': workEndMin,
        'contact': contact,
        'active': active,
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
      workStartMin: workStartMin ?? this.workStartMin,
      workEndMin: workEndMin ?? this.workEndMin,
      contact: contact ?? this.contact,
      active: active ?? this.active,
      createdAt: createdAt,
    );
  }
}
