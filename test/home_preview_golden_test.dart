import 'dart:io';

import 'package:accounting_system/features/accounting/ui/screens/accounting_home.dart';
import 'package:accounting_system/features/reports/models/report_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final arabicFont = File(r'C:\Windows\Fonts\tahoma.ttf');
  final iconsaxFont = File(
    r'C:\Users\Stadia TECH 2\AppData\Local\Pub\Cache\hosted\pub.dev\iconsax-0.0.8\lib\assets\fonts\iconsax.ttf',
  );

  setUpAll(() async {
    if (!arabicFont.existsSync()) return;
    final fontBytes = await arabicFont.readAsBytes();
    final fontLoader = FontLoader('ArabicPreview')
      ..addFont(Future.value(ByteData.sublistView(fontBytes)));
    await fontLoader.load();
    if (iconsaxFont.existsSync()) {
      final iconBytes = await iconsaxFont.readAsBytes();
      final iconLoader = FontLoader('packages/iconsax/iconsax')
        ..addFont(Future.value(ByteData.sublistView(iconBytes)));
      await iconLoader.load();
    }
  });

  testWidgets('renders the Cerulean Arabic ERP home preview', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          fontFamily: 'ArabicPreview',
          filledButtonTheme: _filledButtonTheme,
          outlinedButtonTheme: _outlinedButtonTheme,
          textButtonTheme: _textButtonTheme,
        ),
        home: const Scaffold(
          body: CeruleanDashboardView(
            currency: 'USD',
            fontFamily: 'ArabicPreview',
            data: DashboardData(
              metrics: DashboardMetrics(
                cash: 48500000,
                salesToday: 1245000,
                purchasesToday: 690000,
                customerReceivables: 18200000,
                supplierPayables: 9350000,
                inventoryValue: 67800000,
                lowStock: 3,
                pendingSync: 0,
              ),
              trends: DashboardTrends(
                sales: [
                  520000,
                  680000,
                  610000,
                  930000,
                  820000,
                  1100000,
                  1245000,
                ],
                purchases: [
                  360000,
                  410000,
                  290000,
                  540000,
                  470000,
                  620000,
                  690000,
                ],
              ),
              recentActivity: [
                ActivityItem(
                  kind: 'sale',
                  id: 'sale-1',
                  displayNumber: 'INV-1048',
                  amountMinor: 425000,
                  occurredAt: _previewDate,
                  partyName: 'شركة الأفق للتجارة',
                ),
                ActivityItem(
                  kind: 'purchase',
                  id: 'purchase-1',
                  displayNumber: 'PUR-0321',
                  amountMinor: 286000,
                  occurredAt: _previewDate,
                  partyName: 'مؤسسة الرواد',
                ),
                ActivityItem(
                  kind: 'expense',
                  id: 'expense-1',
                  displayNumber: 'EXP-0086',
                  amountMinor: 54000,
                  occurredAt: _previewDate,
                  partyName: 'مصروفات تشغيلية',
                ),
              ],
              lowStockItems: [
                LowStockItem(
                  productId: 'p-1',
                  productName: 'طابعة فواتير حرارية',
                  warehouseName: 'المستودع الرئيسي',
                  currentQuantity: 2,
                  minQuantity: 8,
                ),
                LowStockItem(
                  productId: 'p-2',
                  productName: 'لفائف ورق حراري',
                  warehouseName: 'فرع المزة',
                  currentQuantity: 6,
                  minQuantity: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('لوحة القيادة المالية'), findsOneWidget);
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    scrollable.position.jumpTo(0);
    await tester.pump();
    await expectLater(
      find.byType(CeruleanDashboardView),
      matchesGoldenFile('goldens/cerulean_home.png'),
    );
  }, skip: !arabicFont.existsSync());
}

const _previewDate = null;

const _filledButtonTheme = FilledButtonThemeData(
  style: ButtonStyle(
    textStyle: WidgetStatePropertyAll(TextStyle(fontFamily: 'ArabicPreview')),
  ),
);

const _outlinedButtonTheme = OutlinedButtonThemeData(
  style: ButtonStyle(
    textStyle: WidgetStatePropertyAll(TextStyle(fontFamily: 'ArabicPreview')),
  ),
);

const _textButtonTheme = TextButtonThemeData(
  style: ButtonStyle(
    textStyle: WidgetStatePropertyAll(TextStyle(fontFamily: 'ArabicPreview')),
  ),
);
