import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';

class NoScrollGlowBehavior extends CupertinoScrollBehavior {
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };
  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // يمنع رسم أي Scrollbar
    return child;
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // يمنع تأثير اللمعة/الوهج عند السحب الزائد
    return child;
  }
}
