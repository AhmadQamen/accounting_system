import 'package:accounting_system/core/theme/app_theme_colors.dart';
import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:accounting_system/core/ui/components/blur_appbar.dart';
import 'package:accounting_system/core/ui/components/my_scaffold.dart';
import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return MyScaffold(
      appBar: BlurAppbar(
        title: const Text('سياسة الخصوصية'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
        children: [
          _buildHeader(colors),
          const SizedBox(height: 24),
          _buildSection(
            colors,
            title: null,
            body:
                'نحن في Nerd X نولي خصوصية مستخدمينا أهمية كبيرة، ونلتزم بحماية بياناتهم الشخصية واستخدامها بمسؤولية وشفافية. توضح هذه السياسة كيفية جمع المعلومات واستخدامها وحمايتها عند استخدام تطبيقنا.',
          ),
          _buildSection(
            colors,
            title: 'المعلومات التي نجمعها',
            body:
                'قد نقوم بجمع بعض المعلومات الضرورية لتقديم خدمات التطبيق، مثل:\n\n'
                '• معلومات الحساب (مثل الاسم أو البريد الإلكتروني عند تسجيل الدخول).\n'
                '• بيانات تقدمك في الدراسة، مثل الدروس التي شاهدتها والاختبارات التي أنهيتها.\n'
                '• الملفات التعليمية التي قمت بتنزيلها للاستخدام دون اتصال بالإنترنت.\n'
                '• معلومات تقنية عن الجهاز، مثل نوع الجهاز، نظام التشغيل، إصدار التطبيق، وسجلات الأعطال لتحسين الأداء.',
          ),
          _buildSection(
            colors,
            title: 'كيفية استخدام المعلومات',
            body:
                'نستخدم المعلومات من أجل:\n\n'
                '• إنشاء وإدارة حساب المستخدم.\n'
                '• توفير المحتوى التعليمي.\n'
                '• حفظ تقدمك الدراسي ومزامنته بين الأجهزة.\n'
                '• تمكين تحميل الفيديوهات والملفات للاستخدام دون اتصال.\n'
                '• تحسين أداء التطبيق وتجربة المستخدم.\n'
                '• إصلاح الأخطاء والمشكلات التقنية.\n'
                '• حماية التطبيق ومنع إساءة الاستخدام.',
          ),
          _buildSection(
            colors,
            title: 'الملفات التي يتم تنزيلها',
            body:
                'يمكن للمستخدم تنزيل بعض الفيديوهات والملفات التعليمية لاستخدامها دون اتصال بالإنترنت.\n\n'
                'يتم تخزين هذه الملفات داخل مساحة تخزين التطبيق، ولا يتم استخدامها إلا من خلال التطبيق.',
          ),
          _buildSection(
            colors,
            title: 'مشاركة المعلومات',
            body:
                'لا نقوم ببيع أو تأجير أو مشاركة بيانات المستخدمين مع أي جهة خارجية لأغراض تسويقية.\n\n'
                'قد تتم مشاركة بعض البيانات فقط في الحالات التالية:\n'
                '• عند الحاجة لتشغيل الخدمات الأساسية للتطبيق.\n'
                '• إذا تطلب القانون ذلك.\n'
                '• لحماية حقوق المستخدمين أو حماية التطبيق من الاستخدام غير المشروع.',
          ),
          _buildSection(
            colors,
            title: 'أمان البيانات',
            body:
                'نتخذ إجراءات تقنية وإدارية مناسبة للمساعدة في حماية بيانات المستخدمين من الوصول غير المصرح به أو التعديل أو الإفصاح أو الحذف.\n\n'
                'ورغم ذلك، لا يمكن ضمان أمان أي نظام إلكتروني بنسبة 100%.',
          ),
          _buildSection(
            colors,
            title: 'الصلاحيات',
            body:
                'قد يطلب التطبيق بعض الصلاحيات اللازمة لعمله، مثل:\n\n'
                '• الاتصال بالإنترنت للوصول إلى المحتوى.\n'
                '• مساحة التخزين لحفظ الملفات التعليمية.\n'
                '• الإشعارات لإبلاغ المستخدم بالتحديثات أو التنزيلات.\n'
                '• أي صلاحيات أخرى يتم طلبها فقط عند الحاجة إلى ميزة محددة داخل التطبيق.',
          ),
          _buildSection(
            colors,
            title: 'خدمات الجهات الخارجية',
            body:
                'قد يستخدم التطبيق خدمات مقدمة من جهات خارجية لتحسين الأداء أو توفير بعض الوظائف، '
                'مثل خدمات Google أو Firebase، وتخضع هذه الخدمات لسياسات الخصوصية الخاصة بها.',
          ),
          _buildSection(
            colors,
            title: 'حقوق المستخدم',
            body:
                'يحق للمستخدم، وفقًا للقوانين المعمول بها:\n\n'
                '• الاطلاع على بياناته.\n'
                '• تعديل بياناته.\n'
                '• طلب حذف حسابه وبياناته عند توفر هذه الخدمة.\n'
                '• التواصل معنا للاستفسار عن كيفية معالجة بياناته.',
          ),
          _buildSection(
            colors,
            title: 'التعديلات على سياسة الخصوصية',
            body:
                'قد نقوم بتحديث سياسة الخصوصية من وقت لآخر بما يتوافق مع تطوير التطبيق أو المتطلبات القانونية.\n\n'
                'وسيتم نشر أي تحديث داخل التطبيق أو عبر الوسائل الرسمية.',
          ),
          _buildSection(
            colors,
            title: 'التواصل معنا',
            body:
                'إذا كان لديك أي استفسار أو ملاحظة تتعلق بسياسة الخصوصية أو بكيفية التعامل مع بياناتك، '
                'يمكنك التواصل معنا من خلال وسائل التواصل الرسمية الخاصة بتطبيق **Nerd X**.',
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AppThemeColors colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.purple.withValues(alpha: 0.12), colors.purpleTint],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.purple.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.purple.withValues(alpha: 0.15),
            ),
            child: Icon(Icons.shield_outlined, color: colors.purple, size: 26),
          ),
          const SizedBox(height: 12),
          Text(
            'سياسة الخصوصية',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'آخر تحديث: 27 يوليو 2026',
            style: TextStyle(fontSize: 12, color: colors.textDim),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    AppThemeColors colors, {
    String? title,
    required String body,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            body,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.7,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
