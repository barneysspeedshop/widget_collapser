import 'package:flutter/widgets.dart';

/// Metadata for a single child managed by [WidgetCollapser].
///
/// Use [Collapsible] to wrap each widget that should participate in the
/// collapse-to-overflow behavior. The lower the [collapsePriority], the sooner
/// the child is moved into the overflow menu when space is constrained.
///
/// {@tool snippet}
/// ```dart
/// WidgetCollapser(
///   children: const [
///     Collapsible(
///       collapsePriority: 10,
///       child: Text('Always try to keep this'),
///     ),
///     Collapsible(
///       collapsePriority: 1,
///       child: Text('Collapse this first'),
///     ),
///   ],
/// )
/// ```
/// {@end-tool}
@immutable
class Collapsible {
  /// The widget to display when this item is not collapsed.
  final Widget child;

  /// Determines the order in which children are collapsed.
  ///
  /// Lower values are collapsed first. Children with the same priority are
  /// collapsed in reverse display order (last displayed collapses first).
  final int collapsePriority;

  /// Forces the size of [child] along the main axis.
  ///
  /// For a horizontal [WidgetCollapser] this is the child's width; for a
  /// vertical one it is the child's height.
  ///
  /// If null, the widget measures [child] during the first frame and uses that
  /// size for collapse calculations. The measured size is refreshed whenever
  /// [WidgetCollapser.remeasureListenable] fires, so children whose size
  /// changes over time (text labels, zoom scaling) stay accurate.
  final double? mainAxisSize;

  /// If non-null, [child] is wrapped in an [Expanded] (horizontal orientation)
  /// or a [Flexible] with [FlexFit.tight] (vertical orientation) and takes the
  /// remaining space along the main axis.
  ///
  /// Flex children do not collapse on their own, but they can be hidden as part
  /// of a [collapseGroup] that contains a non-flex member.
  final int? flex;

  /// An optional group identifier.
  ///
  /// When any non-flex member of a group is collapsed, every other member of
  /// the same group (including flex children such as spacers) is also hidden.
  /// The group's collapse priority is the lowest [collapsePriority] among its
  /// non-flex members.
  final String? collapseGroup;

  /// Creates a collapsible child.
  const Collapsible({
    required this.child,
    this.collapsePriority = 0,
    this.mainAxisSize,
    this.flex,
    this.collapseGroup,
  });

  /// Creates an expanding spacer child.
  ///
  /// The spacer occupies any leftover space along the main axis, pushing other
  /// visible children apart. It is never collapsed unless it shares a
  /// [collapseGroup] with a collapsed non-flex child.
  const Collapsible.spacer({
    this.flex = 1,
    this.collapsePriority = 0,
    this.collapseGroup,
  })  : child = const SizedBox.shrink(),
        mainAxisSize = null;

  /// Whether this child consumes flexible space along the main axis.
  bool get isFlex => flex != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Collapsible &&
          runtimeType == other.runtimeType &&
          child == other.child &&
          collapsePriority == other.collapsePriority &&
          mainAxisSize == other.mainAxisSize &&
          flex == other.flex &&
          collapseGroup == other.collapseGroup;

  @override
  int get hashCode =>
      Object.hash(child, collapsePriority, mainAxisSize, flex, collapseGroup);
}
