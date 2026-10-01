import 'package:accounting_system/core/navigation/app_navigation.dart';
import 'package:accounting_system/core/navigation/app_route.dart';
import 'package:accounting_system/core/providers/sync_providers.dart';
import 'package:accounting_system/core/sync/sync_models.dart';
import 'package:accounting_system/core/theme/theme_extension.dart';
import 'package:accounting_system/core/utils/messges/custom_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

class SyncIndicator extends ConsumerStatefulWidget {
  const SyncIndicator({super.key});

  @override
  ConsumerState<SyncIndicator> createState() => _SyncIndicatorState();
}

class _SyncIndicatorState extends ConsumerState<SyncIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _success;
  SyncStage _previousStage = SyncStage.idle;

  @override
  void initState() { super.initState(); _success = AnimationController(vsync: this, duration: const Duration(milliseconds: 700)); }
  @override
  void dispose() { _success.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final status = ref
        .watch(syncStatusProvider)
        .when(
          data: (value) => value,
          loading: () => null,
          error: (_, _) => null,
        );
    final stage = ref.watch(syncStageProvider);
    final rejected = status?.rejected ?? 0;
    final conflicts = status?.conflicts ?? 0;
    final failed = status?.failed ?? 0;
    final count = status?.pending ?? 0;
    final syncIsClean = status != null &&
        status.deviceRevoked != true &&
        status.lastError == null &&
        rejected == 0 &&
        conflicts == 0 &&
        failed == 0 &&
        count == 0 &&
        status.initializationComplete;
    if (_previousStage != SyncStage.idle &&
        stage == SyncStage.idle &&
        syncIsClean) {
      _success.forward(from: 0);
    }
    _previousStage = stage;
    final busy = stage != SyncStage.idle;
    final hasIssue = status?.deviceRevoked == true ||
        status?.lastError != null ||
        rejected > 0 ||
        conflicts > 0 ||
        failed > 0;
    final accent = hasIssue
        ? context.colors.error
        : busy
        ? context.colors.primary
        : count > 0
        ? context.colors.secondary
        : context.colors.success;
    final label = status?.deviceRevoked == true
        ? 'الجهاز ملغى'
        : status?.lastError != null
        ? 'خطأ بالمزامنة'
        : rejected > 0
        ? '$rejected مرفوض'
        : conflicts > 0
        ? '$conflicts تعارض'
        : failed > 0
        ? '$failed فاشلة'
        : busy
        ? 'جاري المزامنة'
        : count > 0
        ? '$count معلّقة'
        : 'متزامن';
    return Tooltip(
      message: 'اضغط للمزامنة، واضغط مطولًا للتفاصيل',
      child: GestureDetector(
        onLongPress:
            () => AppNavigation.open(const AppRoute(type: RouteType.sync)),
        onTap: stage == SyncStage.idle ? () => _sync(context, ref) : null,
        child: AnimatedBuilder(
          animation: _success,
          builder: (context, _) => Transform.scale(
            scale: 1 + (_success.value < .5 ? _success.value : 1 - _success.value) * .08,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic, height: 34,
              padding: const EdgeInsetsDirectional.fromSTEB(11, 0, 12, 0),
              decoration: BoxDecoration(color: context.colors.bgDeep.withValues(alpha: .92), borderRadius: BorderRadius.circular(20), border: Border.all(color: accent.withValues(alpha: .42)), boxShadow: [BoxShadow(color: accent.withValues(alpha: _success.value * .42), blurRadius: 18, offset: const Offset(0, 4))]),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                busy ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: accent)) : Icon(_success.value > 0 ? Icons.check_rounded : Iconsax.refresh, color: accent, size: 17),
                const SizedBox(width: 7), Text(_success.value > 0 ? 'اكتملت' : label, style: TextStyle(color: context.colors.textPrimary, fontSize: 11, fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sync(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(syncEngineProvider).syncNow();
    } catch (error) {
      if (context.mounted) CustomSnackBar.showErrorSnackbar('$error');
    } finally {
      ref.invalidate(syncStatusProvider);
      ref.invalidate(syncOperationsProvider);
    }
  }
}
