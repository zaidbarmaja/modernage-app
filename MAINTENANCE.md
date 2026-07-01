# دليل صيانة تطبيق «عصر الحداثة» (ModernAge)

> دليل شامل لفهم المشروع وتعديله مستقبلًا. آخر تحديث: 2026-06-22.
> اقرأ قسم **«الهيكلية والمعمارية»** و**«تحذير: طبقتا بيانات»** قبل أي تعديل.

---

## 1. نظرة عامة

تطبيق Flutter لإدارة مكتب هندسي: مشاريع تصميم وتنفيذ، حضور بالبصمة، تقارير
يومية، وحسابات الزبائن. الواجهة عربية بالكامل (RTL) بثيم أخضر زيتوني داكن.

- **المنصّات:** Android + iOS (+ يعمل على الويب جزئيًا).
- **الخلفية:** Firebase (Auth + Firestore + Storage).
- **مشروع Firebase:** `mohmeed-kadim` — **مشترك** مع تطبيق الويب في مجلد `modage`.
- **اسم الحزمة (Android):** `modernage.online` — **(iOS):** `online.modernage`.

---

## 2. ⚠️ تحذير مهم: المشروع فيه **طبقتا بيانات** منفصلتان

هذا أهم شيء يجب فهمه قبل التعديل. هناك نظامان متوازيان للوصول إلى Firestore:

### أ) الطبقة القديمة `Db` — `lib/services/firebase_service.dart`
- مجموعات: `employees`، `attendance`، `departments`، `design_projects`،
  `execution_projects`، `holidays`، `customers`، `customerTransactions`،
  `attendance_locations`، `receipts`، `daily_reports`، `counters`.
- التواريخ تُخزَّن **نصًا ISO** (`checkIn`/`checkOut`)، والموظف بـ`employeeId`+`code`.
- تستخدمها شاشات: نظام البصمة (`fingerprint_screen.dart`)، `dashboard_screen`،
  `department_admin`، `accountants_screen`، `attendance_viewer`،
  `project_attendance`، **والشاشات الجديدة**: `admin_attendance`، `accounts_screen`،
  `finance_screen`، `departments_screen`.
- **بيانات المحاسبة** (`customers` + `customerTransactions`) **مشتركة مع تطبيق الويب**.

### ب) الطبقة الحديثة `FirestoreService` — `lib/services/firestore_service.dart`
- مجموعات: `users`، `projects`، `sites`، `attendance`(!)، `receipts`،
  `daily_reports`، `execution_reports`، `notifications`، `settings`،
  `credentials`، `expenses`، `site_checkins`.
- التواريخ **Timestamp**، والمستخدم بـ`uid` ودور (`UserRole`).
- تستخدمها: `AdminHome`، `admin_projects`، `admin_reports`، `add_site_form`،
  `design_project_form`، `auth_controller`، إلخ.

### تضاربات يجب الانتباه لها
1. **`employees` مقابل `users`:** البصمة تقرأ الموظفين من `employees` (Db)، بينما
   «إضافة موظف» في لوحة الإدارة تكتب في `users` (FirestoreService). هما **غير
   مرتبطتين**. لو أردت أن يظهر موظف في البصمة يجب أن يكون في `employees`.
2. **`attendance` باسم واحد بمخططين:** Db يكتب `employeeId`/ISO؛ FirestoreService
   يتوقّع `uid`/Timestamp. شاشة البصمة الإدارية الجديدة مبنية على **Db** (الصحيحة
   لبيانات البصمة الفعلية).
3. عند إضافة ميزة: حدّد أولًا أي طبقة بياناتك فيها، والتزم بها.

---

## 3. الهيكلية ومسارات الملفات

```
lib/
├── main.dart                  # نقطة البداية: تهيئة Firebase + التذكيرات + AsrApp
├── firebase_options.dart      # إعداد Firebase (مشروع mohmeed-kadim)
├── theme.dart                 # ثيم قديم (ألوان green*) — يستخدمه نظام Db القديم
├── core/
│   ├── app_login.dart         # ★ اسم الدخول وكلمة المرور للمدير (تتحكّم بهما هنا)
│   ├── theme.dart             # ★ الثيم الأساسي (AppColors الزيتوني + AppTheme.dark)
│   ├── constants.dart         # UserRole, Department, WorkCategory, FsCollections
│   └── format.dart            # Fmt: تنسيق التواريخ والمبالغ (النظام الحديث)
├── models/                    # نماذج البيانات (AppUser, DailyReport, WorkSite, ...)
├── services/
│   ├── firebase_service.dart  # ★ Db: الطبقة القديمة (انظر القسم 2-أ)
│   ├── firestore_service.dart # ★ FirestoreService: الطبقة الحديثة (القسم 2-ب)
│   ├── auth_service.dart      # مصادقة Firebase + دخول المدير الداخلي
│   ├── auth_controller.dart   # ★ حالة الجلسة + دخول مدير الكود (loginCodeAdmin)
│   ├── session.dart           # جلسة محلية (SharedPreferences) لنظام البصمة القديم
│   ├── biometric_service.dart # بصمة الإصبع/الوجه (local_auth)
│   ├── location_service.dart  # GPS (geolocator)
│   ├── reminder_service.dart  # إشعارات الدوام المحلية (flutter_local_notifications)
│   ├── connectivity_service.dart # مراقبة الاتصال
│   ├── storage_service.dart   # رفع الملفات إلى Firebase Storage
│   └── receipt_pdf.dart       # توليد PDF للوصولات
├── utils/time_utils.dart      # WorkTime (حساب الساعات), ArDate (تواريخ عربية)
├── widgets/                   # ودجات مشتركة
│   ├── ui.dart                # ★ StatTile, SectionCard, PageHeader, EmptyState, showSnack
│   ├── common.dart            # ودجات النظام القديم (EmployeeBar, KpiCard, ...)
│   ├── app_actions.dart       # زر الحساب/الخروج (لا تغيير كلمة مرور)
│   ├── app_logo.dart          # عرض الشعار داخل بطاقة بيضاء
│   ├── user_dropdown.dart     # اختيار مستخدم بدور (من users)
│   ├── account_customer_picker.dart # ★ اختيار زبون من حسابات customers
│   └── project_card.dart, site_card.dart, ...
└── screens/
    ├── auth/                  # splash, login_screen, register_screen, auth_gate, role_router
    ├── admin/                 # ★ لوحة الإدارة (انظر القسم 5)
    ├── accounting/, design/, execution/, customer/, client/
    ├── reports/, attendance/, legal/
    └── fingerprint_screen.dart, dashboard_screen.dart, ... (شاشات النظام القديم)
```
الملفات المعلّمة بـ★ هي الأكثر أهمية للتعديلات.

---

## 4. المصادقة وتسجيل الدخول

- **دخول المدير من الكود:** عدّل [lib/core/app_login.dart](lib/core/app_login.dart):
  ```dart
  static const String username = 'mo_3g';        // اسم الدخول
  static const String password = 'YOUR_ADMIN_PASSWORD';   // كلمة المرور
  static const String displayName = 'مدير النظام';
  static const String authEmail = 'mo_3g@asr-app.com'; // حساب Firebase الداخلي
  ```
- التدفّق: المستخدم يكتب الاسم/كلمة المرور في شاشة الدخول → `_login()` يطابقها مع
  `AppLogin` → `AuthController.loginCodeAdmin()` → يدخل بحساب Firebase داخلي ثابت
  (`signInOrCreateInternal`) → `_onAuthChanged` يكتشف البريد `AppLogin.authEmail`
  ويضبط **ملف مدير اصطناعي** (دون الحاجة لوثيقة Firestore).
- **لا يوجد تغيير لكلمة المرور أو اسم المستخدم من التطبيق** (أُزيل من قائمة الحساب).
  التحكّم بهما من `app_login.dart` فقط.
- نفس حساب `authEmail` يستخدمه تطبيق الويب → التطبيقان يشتركان في الهوية والبيانات.

---

## 5. التنقّل ولوحة الإدارة

التدفّق: `main.dart` → `AsrApp` → `ConnectivityGate` → `AuthGate`
(يعرض `SplashScreen` أثناء التحميل) → `RoleRouter` (حسب الدور) → الصفحة المناسبة.

`RoleRouter` ([lib/screens/auth/role_router.dart](lib/screens/auth/role_router.dart)):
admin→`AdminHome` · accounting→`AccountingHome` · designEmployee→`DesignHome` ·
executionEmployee→`ExecutionHome` · customer→`CustomerHome`.

**`AdminHome`** ([lib/screens/admin/admin_home.dart](lib/screens/admin/admin_home.dart))
شريط تنقّل سفلي بخمسة تبويبات (لتغيير تبويب: عدّل قائمة `tabs` و`_titles`
و`destinations` معًا — يجب أن تتطابق المؤشرات):

| # | التبويب | الودجت | مصدر البيانات |
|---|---------|--------|----------------|
| 0 | الحسابات | `CustomerAccountsView` | `customers`+`customerTransactions` (Db) |
| 1 | المشاريع | `AdminProjectsView` | `projects`+`sites` (FirestoreService) |
| 2 | التقارير | `AdminReportsView` | `daily_reports` (FirestoreService) |
| 3 | البصمة | `AdminAttendanceScreen` | `employees`+`attendance` (Db) |
| 4 | الإعدادات | `AdminControlHub` | متعدّد |

**الإعدادات** (`admin_control.dart`) تحوي بطاقات: الزبائن والحسابات، إضافة حساب،
إدارة الحسابات، الإشعارات، إدارة البيانات، إعدادات الشركة.

---

## 6. الميزات الرئيسية وأين تعدّلها

- **الحسابات (أرصدة الزبائن):** `accounts_screen.dart` → `CustomerAccountsView`.
  يحسب لكل زبون: المستلَم − المصروف، مع قاعدة «المجموع اليدوي» (صفوف
  `isManualTotal`)، وفلتر فترة (كل الفترات/هذا الشهر/شهر محدّد).
- **البصمة وحساب الساعات الإضافية:** `admin_attendance.dart`. الإضافي يُحسب عبر
  `WorkTime.stats(record).overtime`. فلتر التاريخ من/إلى. تعديل دخول/خروج يدوي عبر
  `Db.attendance` (إضافة) و`Db.updateAttendanceRecord` (تعديل).
- **التقارير:** `admin_reports.dart` — قائمة موظفين → تقاريره الأحدث + فلتر تاريخ.
- **ربط المشروع بزبون:** `account_customer_picker.dart` في نموذجي
  `add_site_form.dart` و`design_project_form.dart` (يملأ اسم صاحب المشروع من
  مجموعة `customers`).
- **إدارة البيانات:** `admin_control.dart` → `DataManagementScreen` — حذف
  المشاريع/المواقع/الوصولات/**البصمات** (`Db.attendance`)/**التقارير**
  (`daily_reports`). ⚠️ اكتشاف «قسم التنفيذ» (للساعات الإضافية في البصمة) يعتمد
  على احتواء اسم القسم على كلمة «تنفيذ».

---

## 7. الثيم والشعار والأيقونات

- **الثيم الأساسي:** [lib/core/theme.dart](lib/core/theme.dart) — `AppColors`
  (زيتوني) و`AppTheme.dark`. تغيير لون واحد يُحدّث كل الشاشات الحديثة تلقائيًا.
- **ثيم ثانٍ قديم:** [lib/theme.dart](lib/theme.dart) (`green*`/`cream*`) يستخدمه
  نظام Db القديم (`fingerprint_screen`, `dashboard_screen`, `department_admin`).
  لو غيّرت الألوان، غيّر **كلا الملفين** للاتساق.
- **الشعار داخل التطبيق:** `assets/images/logo.png` (يُعرض داخل بطاقة بيضاء عبر
  `AppLogo` لأنه مصمَّم لخلفية بيضاء).
- **أيقونة التطبيق الخارجية:** مصدرها `assets/images/logo_icon.png` (مربّعة 1024).
  بعد تغييرها شغّل: `dart run flutter_launcher_icons` (الإعداد في `pubspec.yaml`).

---

## 8. إعداد المتاجر والتوقيع

- **توقيع Android (سرّي، مستبعد من Git):** `android/key.properties` +
  `android/app/upload-keystore.jks`. يقرأها `android/app/build.gradle.kts`.
  **خذ نسخة احتياطية منهما** — فقدانهما يمنع تحديث التطبيق على Play للأبد.
- **iOS:** مُعرّف الحزمة `online.modernage`، أوصاف الأذونات في
  `ios/Runner/Info.plist`، وملف `ios/Runner/PrivacyInfo.xcprivacy`. (بناء iOS
  يتطلّب جهاز Mac.)
- **سياسة الخصوصية:** داخل التطبيق `lib/screens/legal/privacy_policy_screen.dart` —
  ويجب أيضًا استضافتها على رابط عام وإدخاله في لوحتي المتجرين.

---

## 9. ⚠️ قواعد أمان Firestore (مطلوبة لعمل البيانات)

- `firestore.rules` (جذر المشروع) = قواعد مجموعات التطبيق الحديثة.
- `modage/firestore.rules` = قواعد مجموعات الويب (`customers`, `departments`,
  `customerTransactions`, ...).
- التطبيقان على **نفس المشروع** `mohmeed-kadim`، فالقواعد المنشورة يجب أن **تدمج
  مجموعات الطرفين**. حاليًا: `customers`/`customerTransactions` مسموحة (الحسابات
  تعمل)، لكن `employees`/`attendance`/`departments` قد تُرفض حتى تُضاف قواعدها.
- النشر: `firebase deploy --only firestore:rules`.

---

## 10. أوامر شائعة

```bash
flutter pub get                      # جلب الحزم
flutter analyze                      # فحص الأخطاء (يجب أن يكون "No issues found!")
flutter run                          # تشغيل على جهاز/محاكي
dart run flutter_launcher_icons      # إعادة توليد أيقونات التطبيق
flutter build appbundle --release    # حزمة Google Play (.aab)
flutter build apk --release          # APK مباشر
```
بيئة التطوير: Flutter SDK، JDK من Android Studio (`...\Android Studio\jbr`).

---

## 11. عند إضافة ميزة جديدة — قائمة تحقّق

1. حدّد طبقة البيانات (Db القديمة أم FirestoreService الحديثة) والتزم بها.
2. استخدم ودجات `widgets/ui.dart` و`AppColors` من `core/theme.dart` للاتساق.
3. لإضافة تبويب في الإدارة: حدّث `tabs` + `_titles` + `destinations` في
   `admin_home.dart` (نفس الترتيب).
4. شغّل `flutter analyze` ثم `flutter build appbundle --release` للتأكد.
5. أي مجموعة Firestore جديدة → أضف قاعدة أمان لها قبل النشر.
6. لا تكتب كلمة مرور المدير إلا في `app_login.dart`.
```
