import 'package:accounting_system/core/domain/money.dart';
import 'package:accounting_system/core/currency/currency.dart';
import 'package:accounting_system/core/navigation/app_navigation.dart';
import 'package:accounting_system/core/navigation/app_route.dart';
import 'package:accounting_system/core/providers/accounting_providers.dart';
import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:accounting_system/core/ui/components/blur_appbar.dart';
import 'package:accounting_system/core/ui/components/sync_indicator.dart';
import 'package:accounting_system/core/ui/components/my_scaffold.dart';
import 'package:accounting_system/core/ui/components/premium_ui.dart';
import 'package:accounting_system/core/utils/messges/custom_snackbar.dart';
import 'package:accounting_system/features/reports/models/report_models.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart' show DateFormat;

/// Cerulean Arabic ERP dashboard based on the supplied Stitch direction.
/// Styling stays local to the home screen so the rest of the product is not
/// affected while the design is being evaluated.
class AccountingHome extends ConsumerWidget {
  const AccountingHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(dataRevisionProvider);
    final currency =
        ref.watch(localContextProvider).asData?.value.currencyCode ?? 'USD';
    final compact = showCompactPageAppBar(context);
    if (compact) return const _MobileNavigationHome();
    final repository = ref.read(reportsRepositoryProvider);

    return MyScaffold(
      appBar: compact ? const BlurAppBar(title: Text('لوحة التحكم')) : null,
      body: FutureBuilder<DashboardData>(
        future: repository.dashboardData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _DashboardLoading();
          }
          if (snapshot.hasError) {
            return _DashboardError(message: '${snapshot.error}');
          }
          return CeruleanDashboardView(
            data: snapshot.data!,
            currency: currency,
          );
        },
      ),
    );
  }
}

class _MobileNavigationHome extends ConsumerStatefulWidget {
  const _MobileNavigationHome();

  @override
  ConsumerState<_MobileNavigationHome> createState() =>
      _MobileNavigationHomeState();
}

class _MobileNavigationHomeState extends ConsumerState<_MobileNavigationHome> {
  String? _dollarRate;

  @override
  void initState() {
    super.initState();
    _loadDollarRate();
  }

  Future<void> _loadDollarRate() async {
    final dollar = await ref.read(currencyRepositoryProvider).find('USD');
    if (!mounted) return;
    setState(
      () =>
          _dollarRate =
              dollar == null || dollar.rateMicros <= 0
                  ? null
                  : CurrencyMath.formatRateMicros(dollar.rateMicros),
    );
  }

  Future<void> _editDollarRate(String currency) async {
    if (currency.toUpperCase() == 'USD') {
      CustomSnackBar.showWarningSnackbar(
        'الدولار هو عملة المؤسسة الأساسية وسعره يساوي 1',
      );
      return;
    }
    var rateInput = _dollarRate ?? '';
    final value = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('تحديد سعر الدولار'),
            content: TextFormField(
              initialValue: rateInput,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              onChanged: (value) => rateInput = value,
              onFieldSubmitted: (value) => Navigator.pop(dialogContext, value),
              decoration: InputDecoration(
                labelText: 'سعر 1 دولار',
                suffixText: currency,
                hintText: 'مثال: 1500',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, rateInput),
                child: const Text('حفظ'),
              ),
            ],
          ),
    );
    if (value == null || !mounted) return;
    final normalized = value.trim().replaceAll(',', '.');
    int rateMicros;
    try {
      rateMicros = CurrencyMath.parseRateMicros(normalized);
    } catch (_) {
      CustomSnackBar.showWarningSnackbar('أدخل سعر دولار صحيحاً أكبر من صفر');
      return;
    }
    final stored = CurrencyMath.formatRateMicros(rateMicros);
    await ref
        .read(currencyRepositoryProvider)
        .saveCurrency(
          code: 'USD',
          name: 'دولار أمريكي',
          symbol: r'$',
          rateMicros: rateMicros,
        );
    if (!mounted) return;
    setState(() => _dollarRate = stored);
    ref.invalidate(currenciesProvider);
    ref.read(dataRevisionProvider.notifier).state++;
    CustomSnackBar.showSuccessSnackbar('تم حفظ سعر الدولار للمؤسسة');
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(dataRevisionProvider);
    EntityCurrency? configuredDollar;
    for (final item
        in ref.watch(currenciesProvider).asData?.value ??
            const <EntityCurrency>[]) {
      if (item.code == 'USD' && item.rateMicros > 0) {
        configuredDollar = item;
        break;
      }
    }
    final dollarRate =
        configuredDollar == null
            ? _dollarRate
            : CurrencyMath.formatRateMicros(configuredDollar.rateMicros);
    final localContext = ref.watch(localContextProvider).asData?.value;
    final currency = localContext?.currencyCode ?? 'IQD';
    final entityName = localContext?.entityName.trim();
    final repository = ref.read(reportsRepositoryProvider);
    const items = <(String, String, IconData, RouteType)>[
      (
        'فاتورة بيع',
        'بيع سريع وإدارة الفواتير',
        Iconsax.receipt_add,
        RouteType.newSale,
      ),
      ('المبيعات', 'السجل والمرتجعات', Iconsax.receipt_1, RouteType.sales),
      (
        'المشتريات',
        'الفواتير والموردون',
        Iconsax.shopping_cart,
        RouteType.purchases,
      ),
      (
        'الصندوق',
        'الحركة النقدية والدفعات',
        Iconsax.wallet_money,
        RouteType.cashDesk,
      ),
      ('المخزون', 'الأرصدة والتسويات', Iconsax.box_1, RouteType.inventory),
      ('المنتجات', 'المنتجات والتصنيفات', Iconsax.box, RouteType.products),
      ('الأطراف', 'العملاء والموردون', Iconsax.people, RouteType.parties),
      ('التقارير', 'الملخصات وكشوف الحساب', Iconsax.chart_2, RouteType.reports),
      (
        'رأس المال',
        'الشركاء وإيداعات الصناديق',
        Iconsax.wallet_money,
        RouteType.capital,
      ),
      (
        'الحسابات الختامية',
        'المتاجرة والأرباح والميزانية',
        Icons.account_balance_outlined,
        RouteType.closingAccounts,
      ),
      ('المزامنة', 'العمليات وحالة الاتصال', Iconsax.refresh, RouteType.sync),
      (
        'الإعدادات',
        'التفضيلات والاختصارات',
        Iconsax.setting_2,
        RouteType.settings,
      ),
    ];
    return MyScaffold(
      body: PremiumPage(
        maxWidth: 680,
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        child: FutureBuilder<DashboardData>(
          future: repository.dashboardData(),
          builder: (context, snapshot) {
            final cash = snapshot.data?.metrics.cash ?? 0;
            final cashText = Money(cash).format(
              locale: Localizations.localeOf(context).toString(),
              currencyCode: currency,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'نظام المحاسبة',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _MobileWelcomeCard(
                  entityName:
                      entityName == null || entityName.isEmpty
                          ? 'مرحباً بعودتك'
                          : entityName,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MobileBalanceCard(
                        title: 'رصيد الصندوق',
                        value:
                            snapshot.connectionState == ConnectionState.done
                                ? cashText
                                : 'جاري التحميل…',
                        subtitle: 'إجمالي أرصدة الصناديق',
                        icon: Iconsax.wallet_money,
                        color: context.colors.primary,
                        onTap:
                            () => AppNavigation.open(
                              const AppRoute(type: RouteType.cashDesk),
                            ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MobileBalanceCard(
                        title: 'سعر الدولار',
                        value:
                            dollarRate == null
                                ? 'اضغط للإضافة'
                                : '$dollarRate $currency',
                        subtitle: 'إدخال يدوي • 1 USD',
                        icon: Icons.attach_money_rounded,
                        color: context.colors.success,
                        onTap: () => _editDollarRate(currency),
                        editable: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const _MobileSectionTitle('إجراءات سريعة'),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Expanded(
                      child: _MobileQuickAction(
                        label: 'بحث منتج',
                        icon: Iconsax.search_normal,
                        onTap:
                            () => AppNavigation.open(
                              const AppRoute(type: RouteType.products),
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MobileQuickAction(
                        label: 'بيع جديد',
                        icon: Iconsax.receipt_add,
                        onTap:
                            () => AppNavigation.open(
                              const AppRoute(type: RouteType.newSale),
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MobileQuickAction(
                        label: 'شراء',
                        icon: Iconsax.shopping_cart,
                        onTap:
                            () => AppNavigation.open(
                              const AppRoute(type: RouteType.purchases),
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const _MobileSectionTitle('أقسام المحاسبة'),
                const SizedBox(height: 9),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.55,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _MobileNavigationCard(
                      title: item.$1,
                      subtitle: item.$2,
                      icon: item.$3,
                      onTap: () => AppNavigation.open(AppRoute(type: item.$4)),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MobileWelcomeCard extends StatelessWidget {
  const _MobileWelcomeCard({required this.entityName});

  final String entityName;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final date = DateFormat('EEEE، d MMMM y', 'ar').format(DateTime.now());
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.bgElevated.withValues(alpha: .82),
            colors.primary.withValues(alpha: .13),
          ],
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.primary.withValues(alpha: .25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .13),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.primary.withValues(alpha: .28)),
            ),
            child: Icon(Iconsax.building, color: colors.primary, size: 23),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'أهلاً بك',
                  style: TextStyle(color: colors.textDim, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  entityName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  date,
                  style: TextStyle(color: colors.textDim, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const SyncIndicator(),
        ],
      ),
    );
  }
}

class _MobileBalanceCard extends StatelessWidget {
  const _MobileBalanceCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.editable = false,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool editable;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(19),
      child: Container(
        height: 126,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: context.colors.bgElevated.withValues(alpha: .54),
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: color.withValues(alpha: .24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 31,
                  height: 31,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .13),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 17),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.colors.textDim,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (editable) Icon(Icons.edit_rounded, size: 14, color: color),
              ],
            ),
            const Spacer(),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.colors.textDim, fontSize: 9),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MobileSectionTitle extends StatelessWidget {
  const _MobileSectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 3,
        height: 18,
        decoration: BoxDecoration(
          color: context.colors.primary,
          borderRadius: BorderRadius.circular(99),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        title,
        style: TextStyle(
          color: context.colors.textPrimary,
          fontWeight: FontWeight.w900,
          fontSize: 14,
        ),
      ),
    ],
  );
}

class _MobileQuickAction extends StatelessWidget {
  const _MobileQuickAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 7),
        decoration: BoxDecoration(
          color: context.colors.bgElevated.withValues(alpha: .50),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: context.colors.primary.withValues(alpha: .18),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 39,
              height: 39,
              decoration: BoxDecoration(
                color: context.colors.primary.withValues(alpha: .12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: context.colors.primary, size: 19),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MobileNavigationCard extends StatelessWidget {
  const _MobileNavigationCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(19),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: context.colors.bgElevated.withValues(alpha: .42),
          borderRadius: BorderRadius.circular(19),
          border: Border.all(
            color: context.colors.primary.withValues(alpha: .16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .08),
              blurRadius: 16,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: context.colors.primary.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: context.colors.primary, size: 18),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: context.colors.textDim,
                  size: 11,
                ),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 9.5, color: context.colors.textDim),
            ),
          ],
        ),
      ),
    ),
  );
}

class CeruleanDashboardView extends StatelessWidget {
  const CeruleanDashboardView({
    super.key,
    required this.data,
    required this.currency,
    this.fontFamily,
  });

  final DashboardData data;
  final String currency;
  final String? fontFamily;

  String _money(BuildContext context, int value) => Money(value).format(
    locale: Localizations.localeOf(context).toString(),
    currencyCode: currency,
  );

  @override
  Widget build(BuildContext context) {
    final metrics = data.metrics;
    final kpis = [
      _Kpi(
        'مبيعات اليوم',
        _money(context, metrics.salesToday),
        'المبيعات المعتمدة',
        Iconsax.receipt_1,
        _C.positive,
        RouteType.sales,
      ),
      _Kpi(
        'مشتريات اليوم',
        _money(context, metrics.purchasesToday),
        'المشتريات المعتمدة',
        Iconsax.shopping_cart,
        _C.gold,
        RouteType.purchases,
      ),
      _Kpi(
        'ذمم العملاء',
        _money(context, metrics.customerReceivables),
        'مبالغ مستحقة لنا',
        Iconsax.people,
        _C.primary,
        RouteType.customers,
      ),
      _Kpi(
        'ذمم الموردين',
        _money(context, metrics.supplierPayables),
        'مبالغ مستحقة علينا',
        Iconsax.truck_fast,
        _C.error,
        RouteType.suppliers,
      ),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTextStyle.merge(
        style: TextStyle(
          fontFamily: fontFamily,
          fontFamilyFallback: const [
            'IBM Plex Sans Arabic',
            'Segoe UI',
            'Tahoma',
            'Arial',
          ],
          color: _C.text,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final edge = constraints.maxWidth < 560 ? 16.0 : 24.0;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(edge, 34, edge, 40),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _Header(),
                      const SizedBox(height: 20),
                      LayoutBuilder(
                        builder: (context, area) {
                          final overview = _Overview(
                            cash: _money(context, metrics.cash),
                            sales: _money(context, metrics.salesToday),
                            purchases: _money(context, metrics.purchasesToday),
                            pendingSync: metrics.pendingSync,
                            salesTrend: data.trends.sales,
                            purchasesTrend: data.trends.purchases,
                          );
                          final state = _BusinessState(
                            inventory: _money(context, metrics.inventoryValue),
                            lowStock: metrics.lowStock,
                            pendingSync: metrics.pendingSync,
                          );
                          if (area.maxWidth < 980) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                overview,
                                const SizedBox(height: 16),
                                state,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 7, child: overview),
                              const SizedBox(width: 16),
                              Expanded(flex: 4, child: state),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 22),
                      const _Title(
                        'المؤشرات الرئيسية',
                        subtitle: 'ملخص الأرصدة والحركة المالية لليوم',
                      ),
                      const SizedBox(height: 12),
                      _KpiGrid(items: kpis),
                      const SizedBox(height: 24),
                      LayoutBuilder(
                        builder: (context, area) {
                          final activity = _ActivityPanel(
                            rows: data.recentActivity,
                            currency: currency,
                          );
                          final stock = _StockPanel(rows: data.lowStockItems);
                          if (area.maxWidth < 1020) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                activity,
                                const SizedBox(height: 16),
                                stock,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 7, child: activity),
                              const SizedBox(width: 16),
                              Expanded(flex: 4, child: stock),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final heading = const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AccentLine(height: 24),
            SizedBox(width: 10),
            Text(
              'لوحة القيادة المالية',
              style: TextStyle(
                color: _C.text,
                fontSize: 24,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        SizedBox(height: 5),
        Text(
          'نظرة فورية على السيولة، حركة اليوم، والمخزون',
          style: TextStyle(color: _C.muted, fontSize: 13, height: 1.5),
        ),
      ],
    );
    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed:
              () => AppNavigation.open(const AppRoute(type: RouteType.reports)),
          icon: const Icon(Iconsax.chart_2, size: 17),
          label: const Text('التقارير'),
          style: _secondaryButton(context),
        ),
        FilledButton.icon(
          onPressed:
              () => AppNavigation.open(const AppRoute(type: RouteType.newSale)),
          icon: const Icon(Iconsax.receipt_add, size: 17),
          label: const Text('فاتورة بيع جديدة'),
          style: _primaryButton(context),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heading,
              const SizedBox(height: 14),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: actions,
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: heading),
            const SizedBox(width: 18),
            actions,
          ],
        );
      },
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({
    required this.cash,
    required this.sales,
    required this.purchases,
    required this.pendingSync,
    required this.salesTrend,
    required this.purchasesTrend,
  });

  final String cash;
  final String sales;
  final String purchases;
  final int pendingSync;
  final List<int> salesTrend;
  final List<int> purchasesTrend;

  @override
  Widget build(BuildContext context) {
    final balance = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Row(
          children: [
            _IconBox(Iconsax.wallet_money, color: _C.primary, size: 42),
            SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'السيولة المتاحة',
                    style: TextStyle(
                      color: _C.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'إجمالي رصيد جميع الصناديق',
                    style: TextStyle(color: _C.dim, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            cash,
            maxLines: 1,
            style: const TextStyle(
              color: _C.text,
              fontSize: 32,
              height: 1.25,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 15),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _AmountChip('مبيعات', sales, _C.positive, Icons.north_east_rounded),
            _AmountChip(
              'مشتريات',
              purchases,
              _C.gold,
              Icons.south_west_rounded,
            ),
          ],
        ),
        const SizedBox(height: 15),
        _Pill(
          pendingSync == 0
              ? 'محفوظ ومتزامن محلياً'
              : '$pendingSync عملية بانتظار المزامنة',
          color: pendingSync == 0 ? _C.positive : _C.gold,
          icon: pendingSync == 0 ? Iconsax.tick_circle : Iconsax.refresh,
        ),
      ],
    );
    final chart = _TrendSummary(sales: salesTrend, purchases: purchasesTrend);

    return _Panel(
      surface: _C.lowest,
      padding: const EdgeInsets.all(22),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 700) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                balance,
                const SizedBox(height: 22),
                const _Line(),
                const SizedBox(height: 18),
                chart,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 4, child: balance),
              const SizedBox(width: 22),
              Container(width: 1, height: 245, color: _C.outline),
              const SizedBox(width: 22),
              Expanded(flex: 5, child: chart),
            ],
          );
        },
      ),
    );
  }
}

class _TrendSummary extends StatelessWidget {
  const _TrendSummary({required this.sales, required this.purchases});

  final List<int> sales;
  final List<int> purchases;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Expanded(
              child: _Title(
                'الحركة خلال 7 أيام',
                subtitle: 'مقارنة المبيعات والمشتريات اليومية',
                compact: true,
              ),
            ),
            _Legend('المبيعات', _C.primary),
            SizedBox(width: 10),
            _Legend('المشتريات', _C.gold),
          ],
        ),
        const SizedBox(height: 14),
        _GroupedBars(sales: sales, purchases: purchases),
      ],
    );
  }
}

class _GroupedBars extends StatelessWidget {
  const _GroupedBars({required this.sales, required this.purchases});

  final List<int> sales;
  final List<int> purchases;

  @override
  Widget build(BuildContext context) {
    final saleValues = _sevenDays(sales);
    final purchaseValues = _sevenDays(purchases);
    final maxValue = [
      ...saleValues,
      ...purchaseValues,
    ].fold<int>(1, (max, value) => value > max ? value : max);
    final maxY = (maxValue * 1.25).ceilToDouble();
    return Container(
      height: 198,
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_C.surfaceLow, _C.surfaceLow.withValues(alpha: .62)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.outline.withValues(alpha: .75)),
      ),
      child: BarChart(
        BarChartData(
          minY: 0,
          maxY: maxY,
          alignment: BarChartAlignment.spaceAround,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine:
                (_) => FlLine(
                  color: _C.outline.withValues(alpha: .24),
                  strokeWidth: 1,
                  dashArray: const [5, 5],
                ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index > 6) return const SizedBox.shrink();
                  final date = DateTime.now().subtract(
                    Duration(days: 6 - index),
                  );
                  final label =
                      index == 6 ? 'اليوم' : '${date.day}/${date.month}';
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(label, style: _caption),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final label = rodIndex == 0 ? 'المبيعات' : 'المشتريات';
                final amount =
                    rodIndex == 0
                        ? saleValues[groupIndex]
                        : purchaseValues[groupIndex];
                return BarTooltipItem(
                  '$label\n$amount',
                  TextStyle(
                    color: rodIndex == 0 ? _C.primary : _C.gold,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                );
              },
            ),
          ),
          barGroups: [
            for (var index = 0; index < 7; index++)
              BarChartGroupData(
                x: index,
                barsSpace: 6,
                barRods: [
                  BarChartRodData(
                    toY:
                        saleValues[index] == 0
                            ? maxY * .025
                            : saleValues[index].toDouble(),
                    width: 10,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(5),
                    ),
                    gradient: LinearGradient(
                      colors: [_C.primary.withValues(alpha: .95), _C.primary],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: maxY,
                      color: _C.primary.withValues(alpha: .075),
                    ),
                  ),
                  BarChartRodData(
                    toY:
                        purchaseValues[index] == 0
                            ? maxY * .025
                            : purchaseValues[index].toDouble(),
                    width: 10,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(5),
                    ),
                    gradient: LinearGradient(
                      colors: [_C.gold.withValues(alpha: .92), _C.gold],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: maxY,
                      color: _C.gold.withValues(alpha: .07),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  List<int> _sevenDays(List<int> values) {
    if (values.length >= 7) return values.sublist(values.length - 7);
    return [...List<int>.filled(7 - values.length, 0), ...values];
  }
}

const _caption = TextStyle(color: _C.dim, fontSize: 9);

class _BusinessState extends StatelessWidget {
  const _BusinessState({
    required this.inventory,
    required this.lowStock,
    required this.pendingSync,
  });

  final String inventory;
  final int lowStock;
  final int pendingSync;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Title(
            'حالة الأعمال',
            subtitle: 'المخزون والمزامنة في لمحة واحدة',
            compact: true,
          ),
          const SizedBox(height: 14),
          _StateRow(
            Iconsax.box_1,
            'قيمة المخزون',
            inventory,
            _C.primary,
            RouteType.inventory,
          ),
          const _Line(),
          _StateRow(
            Iconsax.warning_2,
            'أصناف منخفضة',
            '$lowStock',
            lowStock == 0 ? _C.positive : _C.error,
            RouteType.inventory,
          ),
          const _Line(),
          _StateRow(
            pendingSync == 0 ? Iconsax.tick_circle : Iconsax.refresh,
            'حالة المزامنة',
            pendingSync == 0 ? 'متزامن' : '$pendingSync معلّقة',
            pendingSync == 0 ? _C.positive : _C.gold,
            RouteType.settings,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      () => AppNavigation.open(
                        const AppRoute(type: RouteType.cashboxes),
                      ),
                  icon: const Icon(Iconsax.wallet_money, size: 16),
                  label: const Text('الصناديق'),
                  style: _secondaryButton(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      () => AppNavigation.open(
                        const AppRoute(type: RouteType.inventory),
                      ),
                  icon: const Icon(Iconsax.box, size: 16),
                  label: const Text('المخزون'),
                  style: _secondaryButton(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StateRow extends StatelessWidget {
  const _StateRow(this.icon, this.label, this.value, this.color, this.route);

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final RouteType route;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label: $value',
      child: InkWell(
        onTap: () => AppNavigation.open(AppRoute(type: route)),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              _IconBox(icon, color: color, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: _C.muted, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 5),
              const Icon(Icons.chevron_left_rounded, size: 15, color: _C.dim),
            ],
          ),
        ),
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.items});

  final List<_Kpi> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            constraints.maxWidth >= 1120
                ? 4
                : constraints.maxWidth >= 570
                ? 2
                : 1;
        const gap = 12.0;
        final width = (constraints.maxWidth - (columns - 1) * gap) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(width: width, child: _KpiCard(item)),
          ],
        );
      },
    );
  }
}

class _Kpi {
  const _Kpi(
    this.label,
    this.value,
    this.caption,
    this.icon,
    this.color,
    this.route,
  );

  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final Color color;
  final RouteType route;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard(this.item);

  final _Kpi item;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: EdgeInsets.zero,
      child: Semantics(
        button: true,
        label: '${item.label}: ${item.value}',
        child: InkWell(
          onTap: () => _showKpiDialog(context, item),
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 130),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _IconBox(item.icon, color: item.color, size: 38),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _C.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      _AccentLine(height: 24, color: item.color),
                    ],
                  ),
                  const SizedBox(height: 15),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      item.value,
                      style: const TextStyle(
                        color: _C.text,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(item.caption, style: _caption),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _showKpiDialog(BuildContext context, _Kpi item) {
  return showDialog<void>(
    context: context,
    builder:
        (dialogContext) => Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _IconBox(item.icon, color: item.color, size: 46),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.label,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: item.color.withValues(alpha: .25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.caption,
                          style: const TextStyle(color: _C.muted),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.value,
                          style: TextStyle(
                            color: item.color,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'هذه قراءة مختصرة من السجل المحلي المعتمد. لا تحتاج لمغادرة لوحة التحكم لمراجعة الرقم.',
                    style: TextStyle(color: _C.muted, height: 1.5),
                  ),
                  const SizedBox(height: 18),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('تم'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
  );
}

class _ActivityPanel extends StatelessWidget {
  const _ActivityPanel({required this.rows, required this.currency});

  final List<ActivityItem> rows;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: _Title(
              'آخر الحركات',
              subtitle: 'أحدث العمليات المالية المعتمدة محلياً',
              compact: true,
              trailing: TextButton(
                onPressed:
                    () => AppNavigation.open(
                      const AppRoute(type: RouteType.sales),
                    ),
                style: TextButton.styleFrom(
                  foregroundColor: _C.primary,
                  textStyle: TextStyle(
                    fontFamily:
                        Theme.of(context).textTheme.labelLarge?.fontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('عرض السجل'),
              ),
            ),
          ),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 6, 18, 22),
              child: _Empty(
                Iconsax.receipt_1,
                'لا توجد حركات بعد',
                'ستظهر هنا أحدث المبيعات والمشتريات والمصاريف.',
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 620;
                return Column(
                  children: [
                    if (!compact) const _TableHeader(),
                    for (var i = 0; i < rows.length; i++) ...[
                      _ActivityRow(rows[i], currency, compact),
                      if (i != rows.length - 1)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 18),
                          child: _Line(),
                        ),
                    ],
                    const SizedBox(height: 5),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      color: _C.surfaceHigh,
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('العملية', style: _headerCell)),
          Expanded(flex: 2, child: Text('الطرف', style: _headerCell)),
          Expanded(flex: 2, child: Text('التاريخ', style: _headerCell)),
          Expanded(
            flex: 2,
            child: Text('المبلغ', textAlign: TextAlign.end, style: _headerCell),
          ),
        ],
      ),
    );
  }
}

const _headerCell = TextStyle(
  color: _C.muted,
  fontSize: 10.5,
  fontWeight: FontWeight.w600,
);

class _ActivityRow extends StatelessWidget {
  const _ActivityRow(this.row, this.currency, this.compact);

  final ActivityItem row;
  final String currency;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (icon, color, kind) = switch (row.kind) {
      'sale' => (Iconsax.receipt_1, _C.positive, 'بيع'),
      'purchase' => (Iconsax.shopping_cart, _C.gold, 'شراء'),
      _ => (Iconsax.money_send, _C.error, 'مصروف'),
    };
    final date = row.occurredAt?.toLocal();
    final dateText =
        date == null
            ? '—'
            : '${date.day}/${date.month}  ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    final amount = Money(row.amountMinor).format(
      locale: Localizations.localeOf(context).toString(),
      currencyCode: currency,
    );

    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            _IconBox(icon, color: color, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$kind • ${row.displayNumber}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _C.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${row.partyName ?? 'بدون طرف'} • $dateText',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _caption,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _MoneyText(amount, color: color),
          ],
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                _IconBox(icon, color: color, size: 32),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$kind • ${row.displayNumber}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _C.text,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              row.partyName ?? 'بدون طرف',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _tableCell,
            ),
          ),
          Expanded(flex: 2, child: Text(dateText, style: _tableCell)),
          Expanded(
            flex: 2,
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: _MoneyText(amount, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

const _tableCell = TextStyle(color: _C.muted, fontSize: 11);

class _MoneyText extends StatelessWidget {
  const _MoneyText(this.value, {required this.color});

  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.end,
      style: TextStyle(
        color: color,
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

class _StockPanel extends StatelessWidget {
  const _StockPanel({required this.rows});

  final List<LowStockItem> rows;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Title(
            'تنبيهات المخزون',
            subtitle:
                rows.isEmpty
                    ? 'كل الأصناف أعلى من الحد الأدنى'
                    : 'أصناف تحتاج إلى إعادة طلب',
            compact: true,
            trailing: _Pill(
              rows.isEmpty ? 'المخزون سليم' : '${rows.length} تنبيه',
              color: rows.isEmpty ? _C.positive : _C.error,
              icon: rows.isEmpty ? Iconsax.tick_circle : Iconsax.warning_2,
            ),
          ),
          const SizedBox(height: 14),
          if (rows.isEmpty)
            const _Empty(
              Iconsax.box_1,
              'لا توجد تنبيهات',
              'جميع الكميات الحالية ضمن الحدود المحددة.',
            )
          else
            for (var i = 0; i < rows.length; i++) ...[
              _StockRow(rows[i]),
              if (i != rows.length - 1) const _Line(),
            ],
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed:
                  () => AppNavigation.open(
                    const AppRoute(type: RouteType.inventory),
                  ),
              icon: const Icon(Iconsax.box_1, size: 16),
              label: const Text('فتح إدارة المخزون'),
              style: _secondaryButton(context),
            ),
          ],
        ],
      ),
    );
  }
}

class _StockRow extends StatelessWidget {
  const _StockRow(this.row);

  final LowStockItem row;

  String _quantity(double value) =>
      value.truncateToDouble() == value
          ? value.toStringAsFixed(0)
          : value.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final ratio =
        row.minQuantity <= 0
            ? 0.0
            : (row.currentQuantity / row.minQuantity).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _IconBox(Iconsax.box, color: _C.error, size: 34),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _C.text,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      row.warehouseName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _Pill(
                '${_quantity(row.currentQuantity)} / ${_quantity(row.minQuantity)}',
                color: _C.error,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 5,
              value: ratio,
              color: _C.error,
              backgroundColor: _C.error.withValues(alpha: .1),
            ),
          ),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(
    this.title, {
    this.subtitle,
    this.trailing,
    this.compact = false,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final block = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: _C.text,
            fontSize: compact ? 14 : 18,
            height: 1.4,
            fontWeight: compact ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: const TextStyle(color: _C.dim, fontSize: 10.5, height: 1.4),
          ),
        ],
      ],
    );
    if (trailing == null) return block;
    return Row(
      children: [
        Expanded(child: block),
        const SizedBox(width: 10),
        Flexible(child: trailing!),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.surface = _C.surface,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color surface;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surface,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: _C.outline),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox(this.icon, {required this.color, required this.size});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: .2)),
      ),
      child: Icon(icon, size: size * .48, color: color),
    );
  }
}

class _AccentLine extends StatelessWidget {
  const _AccentLine({required this.height, this.color = _C.primary});

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _AmountChip extends StatelessWidget {
  const _AmountChip(this.label, this.value, this.color, this.icon);

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        border: Border.all(color: color.withValues(alpha: .2)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(
            '$label  $value',
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label, {required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: .2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: _C.muted, fontSize: 9.5)),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.icon, this.title, this.subtitle);

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _C.surfaceLow,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _C.outline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _IconBox(icon, color: _C.positive, size: 40),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _C.text,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _C.dim, fontSize: 10.5, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: 1, child: ColoredBox(color: _C.outline));
  }
}

class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: _C.canvas,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                color: _C.primary,
                strokeWidth: 2.5,
              ),
            ),
            SizedBox(height: 14),
            Text(
              'نجهّز الملخص المالي…',
              style: TextStyle(color: _C.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _C.canvas,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: _Panel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _IconBox(Iconsax.warning_2, color: _C.error, size: 48),
                  const SizedBox(height: 14),
                  const Text(
                    'تعذر تحميل لوحة التحكم',
                    style: TextStyle(
                      color: _C.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _C.muted,
                      fontSize: 11,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

ButtonStyle _primaryButton(BuildContext context) => FilledButton.styleFrom(
  minimumSize: const Size(0, 40),
  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
  backgroundColor: _C.primaryContainer,
  foregroundColor: _C.onPrimary,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
  textStyle: TextStyle(
    fontFamily: Theme.of(context).textTheme.labelLarge?.fontFamily,
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
  ),
);

ButtonStyle _secondaryButton(BuildContext context) => OutlinedButton.styleFrom(
  minimumSize: const Size(0, 40),
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  foregroundColor: _C.primary,
  side: const BorderSide(color: _C.primaryContainer),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
  textStyle: TextStyle(
    fontFamily: Theme.of(context).textTheme.labelLarge?.fontFamily,
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
  ),
);

abstract final class _C {
  // Matches the global CustomScaffold palette so the dashboard is no longer
  // a separate blue theme from the rest of the application.
  static const canvas = Color(0x260B1C2C);
  static const lowest = Color(0x85122B42);
  static const surfaceLow = Color(0x80122B42);
  static const surface = Color(0x8A193852);
  static const surfaceHigh = Color(0x961F405B);
  static const outline = Color(0x2EF6F4F0);
  static const text = Color(0xFFF6F4F0);
  static const muted = Color(0xBFF6F4F0);
  static const dim = Color(0x80F6F4F0);
  static const primary = Color(0xFF3D8D95);
  static const primaryContainer = Color(0xFF244F67);
  static const onPrimary = Color(0xFFF6F4F0);
  static const positive = Color(0xFF65BFAE);
  static const gold = Color(0xFFE6C875);
  static const error = Color(0xFFFF7A7A);
}
