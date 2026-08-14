<<<<<<< HEAD
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
=======
import 'package:accounting_system/core/domain/money.dart';import 'package:accounting_system/core/navigation/app_navigation.dart';import 'package:accounting_system/core/navigation/app_route.dart';import 'package:accounting_system/core/providers/accounting_providers.dart';import 'package:accounting_system/core/theme/theme_extension.dart';import 'package:flutter/material.dart';import 'package:flutter_riverpod/flutter_riverpod.dart';import 'package:iconsax/iconsax.dart';
class AccountingHome extends ConsumerWidget{const AccountingHome({super.key});@override Widget build(BuildContext context,WidgetRef ref){ref.watch(dataRevisionProvider);final currency=ref.watch(localContextProvider).asData?.value?.currencyCode??'USD';return Scaffold(appBar:AppBar(title:const Text('لوحة التحكم')),body:FutureBuilder(future:ref.read(reportsRepositoryProvider).dashboard(),builder:(c,s){if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());if(s.hasError)return Center(child:Text('${s.error}'));final d=s.data??{};String money(String k)=>Money((d[k]??0) as int).format(locale:Localizations.localeOf(context).toString(),currencyCode:currency);final cards=[('رصيد الصناديق',money('cash'),Iconsax.wallet_money,context.colors.primary,RouteType.cashboxes),('مبيعات اليوم',money('salesToday'),Iconsax.receipt_1,context.colors.success,RouteType.sales),('مشتريات اليوم',money('purchasesToday'),Iconsax.shopping_cart,context.colors.secondary,RouteType.purchases),('ذمم العملاء',money('customerReceivables'),Iconsax.people,context.colors.info,RouteType.customers),('ذمم الموردين',money('supplierPayables'),Iconsax.truck_fast,context.colors.warning,RouteType.suppliers),('قيمة المخزون',money('inventoryValue'),Iconsax.box_1,context.colors.primary,RouteType.inventory),('مخزون منخفض','${d['lowStock']??0}',Iconsax.warning_2,context.colors.error,RouteType.inventory),('بانتظار المزامنة','${d['pendingSync']??0}',Iconsax.refresh,context.colors.textSecondary,RouteType.settings)];return GridView.builder(padding:const EdgeInsets.all(20),gridDelegate:const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent:300,mainAxisExtent:150,crossAxisSpacing:12,mainAxisSpacing:12),itemCount:cards.length+1,itemBuilder:(c,i){if(i==0)return Card(color:context.colors.primary.withValues(alpha:.12),child:InkWell(onTap:()=>AppNavigation.open(const AppRoute(type:RouteType.newSale)),child:const Padding(padding:EdgeInsets.all(20),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(Iconsax.receipt_add,size:38),SizedBox(height:10),Text('فاتورة بيع جديدة',style:TextStyle(fontWeight:FontWeight.bold))]))));final x=cards[i-1];return Card(child:InkWell(onTap:()=>AppNavigation.open(AppRoute(type:x.$5)),child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(x.$3,color:x.$4,size:28),const Spacer(),Text(x.$1,style:Theme.of(context).textTheme.bodyMedium),const SizedBox(height:4),Text(x.$2,style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.bold))]))));});}));}}
>>>>>>> 770ffb670390df62dfe8dc828f6b9370148ffb1e
