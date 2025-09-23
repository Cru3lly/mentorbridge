import 'package:flutter/material.dart';

/// Global drag lock system to prevent scroll conflicts
/// When any card is being dragged, all parent scrollables are disabled
class DragLock extends InheritedWidget {
  DragLock({super.key, required super.child}) : _activeDrags = ValueNotifier<int>(0);

  final ValueNotifier<int> _activeDrags;

  static DragLock? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<DragLock>();
  }

  static DragLock of(BuildContext context) {
    final DragLock? lock = maybeOf(context);
    assert(lock != null, 'DragLock not found in context');
    return lock!;
  }

  /// Call when a card starts receiving a pointer (down)
  void lock() {
    _activeDrags.value = _activeDrags.value + 1;
    debugPrint('🔒 DragLock LOCKED (${_activeDrags.value} active drags)');
  }

  /// Call when that pointer ends/cancels
  void unlock() {
    final next = _activeDrags.value - 1;
    _activeDrags.value = next < 0 ? 0 : next;
    debugPrint('🔓 DragLock UNLOCKED (${_activeDrags.value} active drags)');
  }

  bool get isLocked => _activeDrags.value > 0;

  @override
  bool updateShouldNotify(DragLock oldWidget) => _activeDrags != oldWidget._activeDrags;

  /// Helper to listen to lock state changes
  static Widget listen({
    required BuildContext context,
    required Widget Function(BuildContext, bool isLocked) builder,
  }) {
    final lock = DragLock.of(context);
    return ValueListenableBuilder<int>(
      valueListenable: lock._activeDrags,
      builder: (ctx, count, _) => builder(ctx, count > 0),
    );
  }
}
