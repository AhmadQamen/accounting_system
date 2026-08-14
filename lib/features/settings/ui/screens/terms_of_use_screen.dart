import 'package:accounting_system/core/theme/app_theme_colors.dart';
import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:accounting_system/core/ui/components/blur_appbar.dart';
import 'package:accounting_system/core/ui/components/my_scaffold.dart';
import 'package:flutter/material.dart';

class TermsOfUseScreen extends StatelessWidget {
  const TermsOfUseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return MyScaffold(
      appBar: BlurAppbar(
        title: const Text('شروط الاستخدام'),
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
                'باستخدامك لتطبيق **Nerd X**، فإنك توافق على الالتزام بشروط الاستخدام التالية. '
                'إذا كنت لا توافق على أي جزء من هذه الشروط، فيرجى عدم استخدام التطبيق.',
          ),
          _buildSection(
            colors,
            title: '1. قبول الشروط',
            body:
                'يعد استخدامك للتطبيق موافقةً منك على هذه الشروط وسياسة الخصوصية، '
                'كما توافق على الالتزام بجميع القوانين والأنظمة المعمول بها.',
          ),
          _buildSection(
            colors,
            title: '2. وصف الخدمة',
            body:
                'يوفر تطبيق **Nerd X** منصة تعليمية تتيح للمستخدمين الوصول إلى المحتوى التعليمي، '
                'مشاهدة الدروس، وإجراء الاختبارات، وتنزيل بعض المحتويات لاستخدامها دون اتصال بالإنترنت، '
                'بالإضافة إلى أي خدمات أخرى يتم إضافتها مستقبلًا.',
          ),
          _buildSection(
            colors,
            title: '3. إنشاء الحساب',
            body:
                'قد يتطلب استخدام بعض خدمات التطبيق إنشاء حساب شخصي.\n\n'
                'يتحمل المستخدم مسؤولية:\n'
                '• الحفاظ على سرية بيانات تسجيل الدخول.\n'
                '• جميع الأنشطة التي تتم باستخدام حسابه.\n'
                '• تقديم معلومات صحيحة ومحدثة.\n\n'
                'يحق لإدارة التطبيق تعليق أو إيقاف أي حساب يخالف هذه الشروط.',
          ),
          _buildSection(
            colors,
            title: '4. استخدام التطبيق',
            body:
                'يوافق المستخدم على استخدام التطبيق للأغراض التعليمية المشروعة فقط، '
                'وعدم القيام بأي من الأفعال التالية:\n\n'
                '• محاولة اختراق التطبيق أو تعطيل عمله.\n'
                '• الوصول غير المصرح به إلى بيانات أو حسابات الآخرين.\n'
                '• استخدام التطبيق بطريقة تضر بالمستخدمين أو بالخدمة.\n'
                '• نسخ أو تعديل أو إعادة نشر محتوى التطبيق دون إذن.',
          ),
          _buildSection(
            colors,
            title: '5. المحتوى التعليمي',
            body:
                'جميع الدروس، الفيديوهات، الملفات، الاختبارات، والتصاميم داخل التطبيق '
                'مملوكة لـ **Nerd X** أو لأصحاب الحقوق الذين منحوا التطبيق حق استخدامها.\n\n'
                'لا يجوز:\n'
                '• إعادة نشر المحتوى.\n'
                '• نسخه أو توزيعه.\n'
                '• بيعه أو تأجيره.\n'
                '• رفعه على منصات أخرى.\n'
                '• استخدامه لأغراض تجارية دون موافقة كتابية مسبقة.',
          ),
          _buildSection(
            colors,
            title: '6. المحتوى المحمل',
            body:
                'قد يتيح التطبيق تنزيل بعض الفيديوهات أو الملفات التعليمية لاستخدامها دون اتصال بالإنترنت.\n\n'
                'يوافق المستخدم على أن:\n'
                '• تكون الملفات للاستخدام الشخصي فقط.\n'
                '• عدم استخراجها أو إعادة توزيعها أو مشاركتها خارج التطبيق.\n'
                '• عدم محاولة تجاوز وسائل الحماية الخاصة بالمحتوى.',
          ),
          _buildSection(
            colors,
            title: '7. الاشتراكات والمدفوعات',
            body:
                'قد تتطلب بعض الخدمات أو المحتويات اشتراكًا أو عملية شراء.\n\n'
                'جميع الأسعار وطرق الدفع وسياسات الاسترداد تخضع لما يتم عرضه داخل التطبيق '
                'أو وفقًا للمنصة التي تم الشراء من خلالها.',
          ),
          _buildSection(
            colors,
            title: '8. التحديثات',
            body:
                'قد نقوم بإضافة أو تعديل أو إزالة بعض الميزات أو المحتويات أو الخدمات في أي وقت بهدف تحسين التطبيق.\n\n'
                'قد يتطلب ذلك تحديث التطبيق إلى أحدث إصدار.',
          ),
          _buildSection(
            colors,
            title: '9. إنهاء الاستخدام',
            body:
                'يحق لإدارة التطبيق تعليق أو إيقاف حساب أي مستخدم في حال:\n\n'
                '• مخالفة شروط الاستخدام.\n'
                '• إساءة استخدام التطبيق.\n'
                '• محاولة الوصول غير المصرح به إلى الأنظمة.\n'
                '• انتهاك حقوق الملكية الفكرية.',
          ),
          _buildSection(
            colors,
            title: '10. إخلاء المسؤولية',
            body:
                'نسعى إلى تقديم خدمة مستقرة وعالية الجودة، إلا أننا لا نضمن أن التطبيق سيعمل دون انقطاع أو دون أخطاء في جميع الأوقات.\n\n'
                'لا تتحمل إدارة التطبيق مسؤولية أي خسائر تنتج عن:\n'
                '• انقطاع الخدمة.\n'
                '• مشاكل الإنترنت.\n'
                '• أعطال الأجهزة.\n'
                '• استخدام التطبيق بطريقة تخالف التعليمات.',
          ),
          _buildSection(
            colors,
            title: '11. حدود المسؤولية',
            body:
                'إلى الحد الذي يسمح به القانون، لا تتحمل إدارة التطبيق أي مسؤولية عن الأضرار المباشرة أو غير المباشرة الناتجة عن استخدام التطبيق أو عدم القدرة على استخدامه.',
          ),
          _buildSection(
            colors,
            title: '12. التعديلات على الشروط',
            body:
                'يجوز لنا تعديل شروط الاستخدام في أي وقت.\n\n'
                'وسيتم نشر النسخة المحدثة داخل التطبيق أو عبر الوسائل الرسمية، '
                'ويعد استمرار استخدام التطبيق بعد نشر التعديلات موافقة عليها.',
          ),
          _buildSection(
            colors,
            title: '13. القانون الواجب التطبيق',
            body:
                'تخضع هذه الشروط وتفسر وفقًا للقوانين المعمول بها في الدولة التي تدير منها إدارة تطبيق **Nerd X** خدماتها، '
                'مع مراعاة الأنظمة المحلية واجبة التطبيق.',
          ),
          _buildSection(
            colors,
            title: '14. التواصل معنا',
            body:
                'إذا كان لديك أي استفسار بخصوص شروط الاستخدام، يمكنك التواصل معنا عبر وسائل التواصل الرسمية الخاصة بتطبيق **Nerd X**.',
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
            child: Icon(
              Icons.description_outlined,
              color: colors.purple,
              size: 26,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'شروط الاستخدام',
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
