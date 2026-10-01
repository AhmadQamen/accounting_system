import 'package:accounting_system/core/navigation/app_navigation.dart';
import 'package:accounting_system/core/navigation/app_route.dart';
import 'package:flutter/material.dart';

class MobileAppDrawer extends StatelessWidget {
  const MobileAppDrawer({super.key});
  static const _items = <(String, IconData, RouteType)>[
    ('الرئيسية', Icons.home_outlined, RouteType.dashboard),
    ('فاتورة بيع', Icons.receipt_long_outlined, RouteType.newSale),
    ('المبيعات', Icons.sell_outlined, RouteType.sales),
    ('المشتريات', Icons.shopping_cart_outlined, RouteType.purchases),
    ('الصندوق', Icons.account_balance_wallet_outlined, RouteType.cashDesk),
    ('المخزون', Icons.inventory_2_outlined, RouteType.inventory),
    ('المنتجات', Icons.category_outlined, RouteType.products),
    ('الأطراف', Icons.people_outline, RouteType.parties),
    ('التقارير', Icons.bar_chart_outlined, RouteType.reports),
    ('المحاسبة العامة', Icons.account_tree_outlined, RouteType.generalLedger),
    (
      'الحسابات الختامية',
      Icons.account_balance_outlined,
      RouteType.closingAccounts,
    ),
    ('اختصارات الكيبورد', Icons.keyboard_outlined, RouteType.keyboardShortcuts),
    ('الإعدادات', Icons.settings_outlined, RouteType.settings),
  ];
  @override
  Widget build(BuildContext context) => Drawer(
    child: SafeArea(
      child: Column(
        children: [
          const ListTile(
            leading: Icon(Icons.account_balance_outlined),
            title: Text(
              'نظام المحاسبة',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('التنقل بين الواجهات'),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              children:
                  _items
                      .map(
                        (item) => ListTile(
                          leading: Icon(item.$2),
                          title: Text(item.$1),
                          onTap: () {
                            Navigator.pop(context);
                            AppNavigation.openReplacement(
                              AppRoute(type: item.$3),
                            );
                          },
                        ),
                      )
                      .toList(),
            ),
          ),
        ],
      ),
    ),
  );
}
