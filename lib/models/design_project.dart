import 'package:cloud_firestore/cloud_firestore.dart';

/// مهمة ضمن مشروع تصميم (يضيفها المصمم): عنوان + عدد أيام + حالة الإنجاز.
class ProjectTask {
  final String title;
  final int days;
  final bool done;
  const ProjectTask({required this.title, this.days = 0, this.done = false});

  factory ProjectTask.fromMap(Map<String, dynamic> m) => ProjectTask(
        title: (m['title'] ?? '') as String,
        days: (m['days'] as num?)?.toInt() ?? 0,
        done: (m['done'] as bool?) ?? false,
      );

  Map<String, dynamic> toMap() => {'title': title, 'days': days, 'done': done};

  ProjectTask copyWith({String? title, int? days, bool? done}) => ProjectTask(
        title: title ?? this.title,
        days: days ?? this.days,
        done: done ?? this.done,
      );
}

/// ملاحظة حرة على المشروع — مع كاتبها وختمها الزمني.
class ProjectNote {
  final String text;
  final String author;
  final DateTime? createdAt;
  const ProjectNote({required this.text, this.author = '', this.createdAt});

  factory ProjectNote.fromMap(Map<String, dynamic> m) => ProjectNote(
        text: (m['text'] ?? '') as String,
        author: (m['author'] ?? '') as String,
        createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      );

  Map<String, dynamic> toMap() => {
        'text': text,
        'author': author,
        'createdAt':
            createdAt == null ? null : Timestamp.fromDate(createdAt!),
      };
}

/// مشروع تصميم يُدرج يدوياً من موظف التصميم.
class DesignProject {
  final String id;
  final String ownerName; // اسم صاحب المشروع
  final String details; // تفاصيل المشروع
  final String offerType; // نوع العرض
  final String nextPresentation; // العرض الموالي للزبون (موعد/تفاصيل التسليم القادم)
  final String status; // حالة المشروع (قيد العمل/منجز/معلّق)
  final num totalAmount; // المبلغ الكلي
  final num paidAmount; // المبلغ المدفوع
  final DateTime? deliveryDate; // تاريخ التسليم المتوقع
  final String designerUid;
  final String designerName;
  final String? customerUid; // لربط الزبون بصفحته
  final List<ProjectTask> tasks; // مهام المصمم ضمن المشروع
  final List<ProjectNote> notes; // ملاحظات حرة بختم زمني واسم الكاتب
  final DateTime? createdAt;

  const DesignProject({
    required this.id,
    required this.ownerName,
    required this.details,
    required this.offerType,
    this.nextPresentation = '',
    this.status = 'قيد العمل',
    this.totalAmount = 0,
    this.paidAmount = 0,
    this.deliveryDate,
    required this.designerUid,
    required this.designerName,
    this.customerUid,
    this.tasks = const [],
    this.notes = const [],
    this.createdAt,
  });

  /// المبلغ المتبقي.
  num get remainingAmount => (totalAmount - paidAmount).clamp(0, totalAmount);

  /// الأيام المتبقية حتى التسليم (قد تكون سالبة إذا تأخر).
  int? get remainingDays {
    if (deliveryDate == null) return null;
    final now = DateTime.now();
    final d = DateTime(deliveryDate!.year, deliveryDate!.month, deliveryDate!.day);
    final today = DateTime(now.year, now.month, now.day);
    return d.difference(today).inDays;
  }

  /// إجمالي أيام المهام (للجدول الزمني التلقائي — T-2.6).
  int get totalTaskDays => tasks.fold(0, (acc, t) => acc + t.days);

  /// عدد المهام المنجزة.
  int get doneTasksCount => tasks.where((t) => t.done).length;

  /// إجمالي أيام المهام المنجزة (لنسبة تقدّم الجدول الزمني).
  int get doneTaskDays =>
      tasks.where((t) => t.done).fold(0, (acc, t) => acc + t.days);

  factory DesignProject.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    return DesignProject(
      id: doc.id,
      ownerName: (m['ownerName'] ?? '') as String,
      details: (m['details'] ?? '') as String,
      offerType: (m['offerType'] ?? '') as String,
      nextPresentation: (m['nextPresentation'] ?? '') as String,
      status: (m['status'] ?? 'قيد العمل') as String,
      totalAmount: (m['totalAmount'] as num?) ?? 0,
      paidAmount: (m['paidAmount'] as num?) ?? 0,
      deliveryDate: (m['deliveryDate'] as Timestamp?)?.toDate(),
      designerUid: (m['designerUid'] ?? '') as String,
      designerName: (m['designerName'] ?? '') as String,
      customerUid: m['customerUid'] as String?,
      tasks: ((m['tasks'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => ProjectTask.fromMap(e.cast<String, dynamic>()))
          .toList(),
      notes: ((m['notes'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => ProjectNote.fromMap(e.cast<String, dynamic>()))
          .toList(),
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'ownerName': ownerName,
        'details': details,
        'offerType': offerType,
        'nextPresentation': nextPresentation,
        'status': status,
        'totalAmount': totalAmount,
        'paidAmount': paidAmount,
        'deliveryDate':
            deliveryDate == null ? null : Timestamp.fromDate(deliveryDate!),
        'designerUid': designerUid,
        'designerName': designerName,
        'customerUid': customerUid,
        'tasks': tasks.map((t) => t.toMap()).toList(),
        'notes': notes.map((n) => n.toMap()).toList(),
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
      };
}
