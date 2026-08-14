import 'package:accounting_system/core/navigation/router.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../core/theme/theme_extension.dart';
import '../../../../core/ui/components/my_scaffold.dart';
import '../components/accounting_header.dart';
import '../components/dashboard_card.dart';

class AccountingHome extends StatelessWidget {
  const AccountingHome({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final items = <_HomeCardData>[
      _HomeCardData(
        icon: Iconsax.receipt_add,
        label: 'فاتورة جديدة',
        subtitle: 'إنشاء فاتورة بيع',
        color: colors.purple,
        onTap: () {},
      ),
      _HomeCardData(
        icon: Iconsax.receipt_1,
        label: 'الفواتير',
        subtitle: '24 اليوم',
        badgeCount: 3,
        color: colors.blue,
        onTap: () {},
      ),
      _HomeCardData(
        icon: Iconsax.rotate_left,
        label: 'المرتجعات',
        subtitle: 'إدارة المرتجعات',
        color: colors.amber,
        onTap: () {},
      ),
      _HomeCardData(
        icon: Iconsax.warning_2,
        label: 'التلف',
        subtitle: 'الأدوية التالفة',
        color: colors.error,
        onTap: () {},
      ),
      _HomeCardData(
        icon: Iconsax.wallet_money,
        label: 'المصروفات',
        subtitle: 'المصاريف اليومية',
        color: colors.errorDark,
        onTap: () {},
      ),
      _HomeCardData(
        icon: Iconsax.people,
        label: 'العملاء',
        subtitle: 'إدارة العملاء',
        color: colors.success,
        onTap: () {},
      ),
      _HomeCardData(
        icon: Iconsax.box_1,
        label: 'المخزون',
        subtitle: 'عرض المخزون',
        color: colors.purpleLight,
        onTap: () {},
      ),
      _HomeCardData(
        icon: Iconsax.truck_fast,
        label: 'الموردين',
        subtitle: 'إدارة الموردين',
        color: colors.blueLight,
        onTap: () {},
      ),
      _HomeCardData(
        icon: Iconsax.grid_5,
        label: 'المزيد',
        subtitle: 'خيارات إضافية',
        color: colors.textSecondary,
        onTap: () {},
      ),
    ];
    final isDesktop = context.isDesktop;

    return MyScaffold(
      body: Center(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(20.0, isDesktop ? 32 : 20, 20.0, 0),
              sliver: const SliverToBoxAdapter(
                child: HomeHeader(balance: 4250000),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            SliverPadding(
              padding: EdgeInsets.fromLTRB(20.0, 0, 20.0, 32),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 250,
                  mainAxisExtent: 190,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),

                delegate: SliverChildBuilderDelegate((context, index) {
                  final item = items[index];

                  return DashboardCard(
                    icon: item.icon,
                    label: item.label,
                    badgeCount: item.badgeCount,
                    color: item.color,
                    onTap: item.onTap,
                  );
                }, childCount: items.length),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeCardData {
  const _HomeCardData({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.subtitle,
    this.badgeCount,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final int? badgeCount;
  final Color color;
  final VoidCallback onTap;
}
