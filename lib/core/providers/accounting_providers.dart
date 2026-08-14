import 'package:accounting_system/core/db/app_database.dart';
import 'package:accounting_system/core/db/local_context.dart';
import 'package:accounting_system/features/cash/data/cash_repository.dart';
import 'package:accounting_system/features/documents/data/document_repository.dart';
import 'package:accounting_system/features/inventory/data/inventory_repository.dart';
import 'package:accounting_system/features/master_data/data/master_data_repository.dart';
import 'package:accounting_system/features/reports/data/reports_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) => AppDatabase.instance);

final localContextProvider = FutureProvider<LocalContext>((ref) async {
  return LocalContextService.instance.current;
});

final masterDataRepositoryProvider = Provider<MasterDataRepository>((ref) {
  return MasterDataRepository(ref.read(appDatabaseProvider));
});

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(ref.read(appDatabaseProvider));
});

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return DocumentRepository(ref.read(appDatabaseProvider));
});

final cashRepositoryProvider = Provider<CashRepository>((ref) {
  return CashRepository(ref.read(appDatabaseProvider));
});

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(ref.read(appDatabaseProvider));
});

final dataRevisionProvider = StateProvider<int>((ref) => 0);

void invalidateAccountingData(WidgetRef ref) {
  ref.read(dataRevisionProvider.notifier).state++;
}
