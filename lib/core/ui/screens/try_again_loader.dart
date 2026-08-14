import 'package:flutter/material.dart';
import '../../errors/failures.dart';
import 'failure_page.dart';
import 'loader_page.dart';

class TryAgainLoader extends StatefulWidget {
  const TryAgainLoader({
    super.key,
    this.onRetry,
    this.skeletonCount = 5,
    required this.child,
    required this.isLoading,
    required this.isData,
    required this.failure,
  });
  final Function()? onRetry;
  final bool isLoading;
  final Failure? failure;
  final bool isData;
  final int skeletonCount;
  final Widget child;
  @override
  State<TryAgainLoader> createState() => _TryAgainLoaderState();
}

class _TryAgainLoaderState extends State<TryAgainLoader> {
  @override
  Widget build(BuildContext context) {
    final loadState = widget.isLoading
        ? LoadState.loading
        : widget.isData
        ? LoadState.done
        : LoadState.error;
    if (loadState == LoadState.loading) {
      return loader;
    }
    if (loadState == LoadState.done) {
      return widget.child;
    }
    if (loadState == LoadState.error) {
      return ModernErrorPage(
        error: widget.failure?.message ?? "??",
        onRetry: widget.onRetry,
        isNetworkError: widget.failure is NetworkFailure,
      );
    }
    return Text("un");
  }

  Widget get loader => const ModernPageLoader();
}

enum LoadState { loading, done, error }
