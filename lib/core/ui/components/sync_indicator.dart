import 'package:accounting_system/core/navigation/app_navigation.dart';
import 'package:accounting_system/core/navigation/app_route.dart';
import 'package:accounting_system/core/providers/sync_providers.dart';
import 'package:accounting_system/core/sync/sync_models.dart';
import 'package:accounting_system/core/utils/messges/custom_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

class SyncIndicator extends ConsumerWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref
        .watch(syncStatusProvider)
        .when(
          data: (value) => value,
          loading: () => null,
          error: (_, _) => null,
        );
    final stage = ref.watch(syncStageProvider);
    final count = status?.pending ?? 0;
    return Tooltip(
      message: 'اضغط للمزامنة، واضغط مطولًا للتفاصيل',
      child: GestureDetector(
        onLongPress:
            () => AppNavigation.open(const AppRoute(type: RouteType.sync)),
        onTap: stage == SyncStage.idle ? () => _sync(context, ref) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              stage == SyncStage.idle
                  ? const Icon(Iconsax.refresh, size: 21)
                  : const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              if (count > 0)
                PositionedDirectional(
                  top: -7,
                  end: -8,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 17),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sync(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(syncEngineProvider).syncNow();
      ref.invalidate(syncStatusProvider);
      ref.invalidate(syncOperationsProvider);
    } catch (error) {
      if (context.mounted) CustomSnackBar.showErrorSnackbar('$error');
    }
  }
}
