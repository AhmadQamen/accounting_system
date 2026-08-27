import 'dart:io';

import 'package:accounting_system/core/db/app_database.dart';
import 'package:accounting_system/core/db/local_context.dart';
import 'package:accounting_system/core/providers/accounting_providers.dart';
import 'package:accounting_system/core/theme/app_theme.dart';
import 'package:accounting_system/features/cash/models/cash_models.dart';
import 'package:accounting_system/features/documents/ui/new_document_screen.dart';
import 'package:accounting_system/features/inventory/data/inventory_repository.dart';
import 'package:accounting_system/features/inventory/models/inventory_models.dart';
import 'package:accounting_system/features/master_data/data/master_data_repository.dart';
import 'package:accounting_system/features/master_data/models/master_data_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final arabicFont = File(r'C:\Windows\Fonts\tahoma.ttf');
  final iconsaxFont = File(
    r'C:\Users\Stadia TECH 2\AppData\Local\Pub\Cache\hosted\pub.dev\iconsax-0.0.8\lib\assets\fonts\iconsax.ttf',
  );
  final materialIconsFont = File(
    r'C:\dev\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf',
  );

  setUpAll(() async {
    if (!arabicFont.existsSync()) return;
    final fontLoader = FontLoader('ArabicPreview')..addFont(
      Future.value(ByteData.sublistView(await arabicFont.readAsBytes())),
    );
    await fontLoader.load();
    if (iconsaxFont.existsSync()) {
      final iconLoader = FontLoader('packages/iconsax/iconsax')..addFont(
        Future.value(ByteData.sublistView(await iconsaxFont.readAsBytes())),
      );
      await iconLoader.load();
    }
    if (materialIconsFont.existsSync()) {
      final iconLoader = FontLoader('MaterialIcons')..addFont(
        Future.value(
          ByteData.sublistView(await materialIconsFont.readAsBytes()),
        ),
      );
      await iconLoader.load();
    }
  });

  testWidgets(
    'renders the professional multi-invoice workspace',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final baseTheme = AppTheme.dark;
      final theme = baseTheme.copyWith(
        textTheme: baseTheme.textTheme.apply(fontFamily: 'ArabicPreview'),
        primaryTextTheme: baseTheme.primaryTextTheme.apply(
          fontFamily: 'ArabicPreview',
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: baseTheme.filledButtonTheme.style?.copyWith(
            textStyle: const WidgetStatePropertyAll(
              TextStyle(
                fontFamily: 'ArabicPreview',
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: baseTheme.outlinedButtonTheme.style?.copyWith(
            textStyle: const WidgetStatePropertyAll(
              TextStyle(
                fontFamily: 'ArabicPreview',
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: baseTheme.textButtonTheme.style?.copyWith(
            textStyle: const WidgetStatePropertyAll(
              TextStyle(
                fontFamily: 'ArabicPreview',
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            masterDataRepositoryProvider.overrideWithValue(
              _PreviewMasterData(),
            ),
            inventoryRepositoryProvider.overrideWithValue(_PreviewInventory()),
            localContextProvider.overrideWith(
              (ref) async => const LocalContext(
                entityId: 'entity-preview',
                userId: 'user-preview',
                deviceId: 'device-preview',
                financialYearId: 'year-preview',
                defaultWarehouseId: 'warehouse-main',
                defaultCashboxId: 'cashbox-main',
                currencyCode: 'ر.س',
              ),
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: const Directionality(
              textDirection: TextDirection.rtl,
              child: NewDocumentScreen(kind: DocumentKind.sale),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 900));

      await tester.tap(find.text('إضافة بند').first);
      await tester.pump(const Duration(milliseconds: 350));
      final priceField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'سعر الوحدة',
      );
      await tester.enterText(priceField, '8100');
      await tester.tap(find.widgetWithText(FilledButton, 'إضافة'));
      await tester.pump(const Duration(milliseconds: 500));

      final paidField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'المقبوض من العميل',
      );
      await tester.enterText(paidField, '5000');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('ملخص الفاتورة'), findsOneWidget);
      expect(find.text('حاسب محمول احترافي'), findsOneWidget);
      await expectLater(
        find.byType(NewDocumentScreen),
        matchesGoldenFile('goldens/professional_invoice_workspace.png'),
      );
    },
    skip: !arabicFont.existsSync(),
  );
}

class _PreviewMasterData extends MasterDataRepository {
  _PreviewMasterData() : super(AppDatabase.instance);

  @override
  Future<List<Warehouse>> listWarehouses() async => const [
    Warehouse(id: 'warehouse-main', name: 'المستودع الرئيسي'),
    Warehouse(id: 'warehouse-branch', name: 'مستودع الفرع'),
  ];

  @override
  Future<List<Party>> listParties({
    String? type,
    String search = '',
  }) async => const [
    Party(id: 'customer-1', name: 'شركة التقنية المتقدمة', type: 'customer'),
  ];

  @override
  Future<List<Cashbox>> listCashboxes() async => const [
    Cashbox(id: 'cashbox-main', name: 'صندوق المعرض الرئيسي'),
  ];

  @override
  Future<List<ProductUnit>> listProductUnits(String productId) async => const [
    ProductUnit(
      id: 'unit-piece',
      productId: 'product-laptop',
      name: 'قطعة',
      isPrimary: true,
    ),
  ];
}

class _PreviewInventory extends InventoryRepository {
  _PreviewInventory() : super(AppDatabase.instance);

  @override
  Future<List<SellableProduct>> listSellableProducts({
    String search = '',
    String? warehouseId,
  }) async => const [
    SellableProduct(
      productId: 'product-laptop',
      productName: 'حاسب محمول احترافي',
      productUnitId: 'unit-piece',
      unitName: 'قطعة',
      inventoryItemId: 'inventory-laptop',
      currentQuantity: 13,
    ),
  ];
}
