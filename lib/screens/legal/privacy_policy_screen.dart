import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// صفحة سياسة الخصوصية داخل التطبيق (T-Legal) — تشرح ما يجمعه التطبيق وكيف
/// يُستخدم ويُحفظ، بما يلبّي متطلبات Google Play و Apple App Store.
///
/// مهم: عند النشر يجب أيضًا توفير نفس النص على رابط عام (URL) وإدخاله في حقل
/// «رابط سياسة الخصوصية» في لوحتي المتجرين — لا يكفي وجوده داخل التطبيق فقط.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  /// بريد التواصل المعتمد للخصوصية — غيّره إلى بريدك الرسمي قبل النشر.
  static const String contactEmail = 'support@modernage.online';

  /// رابط سياسة الخصوصية المنشور على الاستضافة (نفس صفحة مجلد DASHBORD/privacy).
  /// يُفتح في المتصفّح عند الضغط على «سياسة الخصوصية» في شاشة الدخول، وهو نفسه
  /// الرابط الذي يوضع في متجرَي Google Play و App Store.
  static const String publicUrl =
      'https://modernage.online/accounts/DASHBORD/privacy/';

  /// تاريخ آخر تحديث للسياسة.
  static const String lastUpdated = '1 يوليو 2026';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سياسة الخصوصية')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          children: [
            const Text(
              'سياسة الخصوصية – تطبيق «عصر الحداثة»',
              style: TextStyle(
                color: AppColors.cream,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'آخر تحديث: $lastUpdated',
              style: const TextStyle(color: AppColors.creamDim, fontSize: 13),
            ),
            const SizedBox(height: 18),
            const _Paragraph(
              'تحترم إدارة تطبيق «عصر الحداثة» خصوصية مستخدميها وتلتزم بحماية '
              'بياناتهم الشخصية. توضّح هذه السياسة أنواع البيانات التي نجمعها، '
              'وكيف نستخدمها ونحفظها ونشاركها، وحقوقك تجاهها. باستخدامك التطبيق '
              'فإنك توافق على ما ورد في هذه السياسة.',
            ),
            _Section(
              title: '1. البيانات التي نجمعها',
              bullets: const [
                'بيانات الحساب: الاسم ورقم الهاتف والدور الوظيفي وكلمة المرور '
                    '(تُحفظ مشفّرة).',
                'الموقع الجغرافي: يُقرأ موقعك «أثناء الاستخدام» فقط ولحظة ضغطك '
                    'على زر تسجيل الحضور أو الانصراف، للتأكّد من وجودك في موقع '
                    'العمل المعتمد. لا نتتبّع موقعك في الخلفية إطلاقًا، ولا '
                    'يُستخدم لأي أغراض إعلانية أو تسويقية.',
                'الصور والملفات: الصور التي تلتقطها أو تختارها لإرفاق الإيصالات '
                    'والتقارير، والمستندات التي ترفعها.',
                'بيانات التشغيل: سجلّات الحضور والمهام والتقارير والإشعارات '
                    'المرتبطة بحسابك.',
              ],
            ),
            _Section(
              title: '2. كيف نستخدم بياناتك',
              bullets: const [
                'تشغيل الميزات الأساسية: تسجيل الدخول، الحضور، المهام، التقارير، '
                    'والإشعارات.',
                'التحقق من الهوية وحماية الحساب.',
                'إرسال إشعارات تأكيد تسجيل الحضور/الانصراف والتنبيهات المهمّة.',
                'تحسين أداء التطبيق ومعالجة الأعطال.',
              ],
            ),
            _Section(
              title: '3. تسجيل الحضور بالموقع',
              bullets: const [
                'يُسجّل الموظف حضوره وانصرافه يدويًا بالضغط على زر «تسجيل الحضور» '
                    'أو «تسجيل الانصراف».',
                'عند الضغط فقط، يطلب التطبيق إذن الموقع «أثناء الاستخدام» ويقرأ '
                    'موقعك في تلك اللحظة للتأكّد من وجودك في نطاق موقع العمل، ثم '
                    'يسجّل الوقت والموقع مع بصمتك.',
                'لا يوجد أي تتبّع للموقع في الخلفية أو عند إغلاق التطبيق. يمكنك '
                    'رفض إذن الموقع أو سحبه من إعدادات جهازك في أي وقت، ولن '
                    'يُستخدم موقعك لأي غرض آخر ولا يُشارك مع معلنين.',
              ],
            ),
            _Section(
              title: '4. التخزين والأمان',
              bullets: const [
                'تُحفظ البيانات على خدمات Google Firebase (المصادقة، قاعدة '
                    'البيانات Firestore، التخزين Storage) بحماية وتشفير أثناء '
                    'النقل.',
                'نتّبع إجراءات تقنية وتنظيمية معقولة لحماية بياناتك من الوصول '
                    'غير المصرّح به.',
              ],
            ),
            _Section(
              title: '5. مشاركة البيانات',
              bullets: const [
                'لا نبيع بياناتك الشخصية ولا نؤجّرها لأي طرف.',
                'نشاركها فقط مع مزوّد البنية التحتية Google Firebase لتشغيل '
                    'التطبيق، ووفق سياسات خصوصيته.',
                'قد نفصح عنها إذا فرض ذلك القانون أو جهة قضائية مختصّة.',
              ],
            ),
            _Section(
              title: '6. أذونات التطبيق',
              bullets: const [
                'الكاميرا والصور: لالتقاط وإرفاق صور الإيصالات والتقارير.',
                'الموقع (أثناء الاستخدام فقط): يُطلب لحظة ضغطك على زر تسجيل '
                    'الحضور/الانصراف للتحقّق من موقع العمل. لا يوجد وصول للموقع '
                    'في الخلفية.',
                'البصمة / Face ID: للتحقّق من هويتك قبل تسجيل الحضور أو الانصراف. '
                    'تتم المصادقة بالكامل على جهازك عبر نظام التشغيل — لا نطّلع '
                    'على بياناتك الحيوية ولا نخزّنها.',
                'الإشعارات: لتأكيد تسجيل الحضور، ولتذكيرك اليومي بتسجيل الدخول '
                    'والخروج في أوقات الدوام، والتنبيهات المهمّة.',
                'يمكنك إدارة هذه الأذونات أو إيقافها من إعدادات جهازك في أي وقت.',
              ],
            ),
            _Section(
              title: '7. مدّة الاحتفاظ بالبيانات',
              bullets: const [
                'نحتفظ ببياناتك طوال فترة استخدامك للتطبيق ولِما تتطلّبه الأغراض '
                    'التشغيلية والقانونية.',
                'عند حذف حسابك تُحذف بياناتك المرتبطة به خلال مدة معقولة، عدا ما '
                    'يلزم الاحتفاظ به نظامًا.',
              ],
            ),
            _Section(
              title: '8. حقوقك',
              bullets: const [
                'الوصول إلى بياناتك وطلب تصحيحها.',
                'طلب حذف حسابك وبياناتك.',
                'سحب الموافقة على أذونات معيّنة من إعدادات الجهاز.',
                'لتنفيذ أي من هذه الحقوق تواصل معنا عبر البريد أدناه.',
              ],
            ),
            _Section(
              title: '9. خصوصية الأطفال',
              bullets: const [
                'التطبيق موجّه للاستخدام المؤسسي/الوظيفي وليس للأطفال دون 13 '
                    'عامًا، ولا نجمع بياناتهم عمدًا.',
              ],
            ),
            _Section(
              title: '10. التعديلات على هذه السياسة',
              bullets: const [
                'قد نُحدّث هذه السياسة من حين لآخر، وسننشر النسخة المحدّثة داخل '
                    'التطبيق مع تحديث تاريخ «آخر تحديث» أعلاه.',
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x33ECEFE1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '11. التواصل معنا',
                    style: TextStyle(
                      color: AppColors.cream,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'لأي استفسار حول الخصوصية أو لطلب الوصول إلى بياناتك أو '
                    'حذفها، تواصل معنا على:',
                    style: TextStyle(
                      color: AppColors.creamDim,
                      height: 1.7,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.email_outlined,
                          color: AppColors.oliveBright, size: 18),
                      const SizedBox(width: 8),
                      SelectableText(
                        contactEmail,
                        style: const TextStyle(
                          color: AppColors.oliveBright,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// فقرة نصّية عادية بتباعد مريح.
class _Paragraph extends StatelessWidget {
  final String text;
  const _Paragraph(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.creamDim,
        height: 1.8,
        fontSize: 14.5,
      ),
    );
  }
}

/// قسم بعنوان وقائمة نقاط.
class _Section extends StatelessWidget {
  final String title;
  final List<String> bullets;
  const _Section({required this.title, required this.bullets});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.cream,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          for (final b in bullets)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 7),
                    child: Icon(Icons.circle,
                        size: 6, color: AppColors.oliveBright),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      b,
                      style: const TextStyle(
                        color: AppColors.creamDim,
                        height: 1.7,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
