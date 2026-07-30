import 'package:flutter/material.dart';

import 'collapsible.dart';

/// A toolbar-like widget that collapses its children into an overflow widget as
/// the available main-axis space shrinks.
///
/// Children are displayed in the order supplied. When there is not enough room,
/// children with the lowest [Collapsible.collapsePriority] are hidden first and
/// made available through an overflow widget (by default a popup menu). The
/// overflow widget is fully customizable so you can use any icon package or menu
/// implementation (e.g. `legacy_context_menu`).
///
/// The widget supports both horizontal toolbars ([Axis.horizontal]) and
/// vertical toolbars ([Axis.vertical]).
///
/// {@tool snippet}
/// ```dart
/// WidgetCollapser(
///   orientation: Axis.horizontal,
///   spacing: 8,
///   children: const [
///     Collapsible(
///       collapsePriority: 100,
///       child: Text('Important'),
///     ),
///     Collapsible(
///       collapsePriority: 50,
///       child: Text('Less important'),
///     ),
///     Collapsible(
///       collapsePriority: 1,
///       child: Text('Collapse first'),
///     ),
///   ],
/// )
/// ```
/// {@end-tool}
class WidgetCollapser extends StatefulWidget {
  /// The children that may be collapsed into the overflow widget.
  final List<Collapsible> children;

  /// The axis along which children are laid out and collapsed.
  final Axis orientation;

  /// Space between visible children and the overflow widget.
  final double spacing;

  /// Builder for the overflow widget.
  ///
  /// Receives the list of children that did not fit. The returned widget is
  /// responsible for its own tap handling and menu presentation. If null, a
  /// [PopupMenuButton] with a [Icons.more_vert] icon is used.
  ///
  /// To keep collapse calculations stable, the returned widget should have a
  /// consistent main-axis size regardless of [hiddenChildren]. If that is not
  /// possible, use [overflowMainAxisSize] to pin the size used for layout.
  final Widget Function(BuildContext context, List<Collapsible> hiddenChildren)?
      overflowBuilder;

  /// Forces the main-axis size of [overflowBuilder]'s widget.
  ///
  /// When null, the overflow widget is measured during the first frame. Use
  /// this when the overflow widget's size depends on the hidden children.
  final double? overflowMainAxisSize;

  /// How the visible children should be placed along the main axis.
  final MainAxisAlignment mainAxisAlignment;

  /// How the visible children should be placed along the cross axis.
  final CrossAxisAlignment crossAxisAlignment;

  /// Optional listenable that requests a child re-measure when it fires.
  ///
  /// Children sometimes change size without the [WidgetCollapser] itself
  /// being rebuilt — a label whose text updates through its own listener, or
  /// items that rescale on UI zoom. Because collapse decisions are computed
  /// from measured child sizes, those changes must trigger a re-measure or
  /// the measured sizes go stale and children overflow instead of collapsing.
  ///
  /// Firing this listenable schedules a cheap post-frame re-measure; a new
  /// layout is only produced when a measured size actually changed. Note that
  /// child-driven *growth* beyond the available extent is corrected one frame
  /// later (the new size only exists once the child has rebuilt and laid
  /// out); shrinkage and parent-driven rebuilds (including zoom, see the
  /// [spacing] ratio handling in `didUpdateWidget`) are handled in the same
  /// frame.
  final Listenable? remeasureListenable;

  /// Creates a widget collapser.
  const WidgetCollapser({
    super.key,
    required this.children,
    this.orientation = Axis.horizontal,
    this.spacing = 8.0,
    this.overflowBuilder,
    this.overflowMainAxisSize,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.remeasureListenable,
  });

  @override
  State<WidgetCollapser> createState() => _WidgetCollapserState();
}

class _WidgetCollapserState extends State<WidgetCollapser> {
  final List<GlobalKey> _childKeys = [];
  final GlobalKey _overflowKey = GlobalKey();

  /// Cached child sizes keyed by child index.
  ///
  /// Index-based keys are used so that parent rebuilds creating new
  /// [Collapsible] instances do not invalidate previously measured sizes.
  Map<int, Size>? _childSizes;
  Size? _overflowSize;

  /// Whether a post-frame re-measure should be scheduled.
  bool _needsRemeasure = false;

  /// Whether a re-measure callback from [WidgetCollapser.remeasureListenable]
  /// has already been scheduled for the current frame.
  bool _remeasureScheduled = false;

  /// Cached result of [_buildFlexWidget] for the current collapse decision.
  ///
  /// Returning the same widget instance from [LayoutBuilder]'s builder lets
  /// Flutter skip rebuilding/re-laying-out the subtree when nothing meaningful
  /// changed (e.g. a resize that does not cross a collapse threshold, or a
  /// parent rebuild with equivalent children). The cache is rebuilt only when
  /// the hidden set actually changes.
  Widget? _cachedLayout;
  List<Collapsible> _cachedHidden = const [];

  @override
  void initState() {
    super.initState();
    _createKeys();
    widget.remeasureListenable?.addListener(_onRemeasureRequested);
  }

  @override
  void dispose() {
    widget.remeasureListenable?.removeListener(_onRemeasureRequested);
    super.dispose();
  }

  /// Schedules a post-frame re-measure in response to
  /// [WidgetCollapser.remeasureListenable].
  ///
  /// The measurement has to happen after the frame completes: children that
  /// rebuild through their own listeners (the ones this listenable exists
  /// for) are laid out with their new sizes during that frame, so only then
  /// can their live sizes be read. If a size actually changed, [_measure]
  /// calls [setState] and the collapse set is re-evaluated on the next frame.
  /// No-op until the initial measurement has completed.
  void _onRemeasureRequested() {
    if (!mounted || _childSizes == null || _remeasureScheduled) return;
    _remeasureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _remeasureScheduled = false;
      _measure();
    });
  }

  @override
  void didUpdateWidget(covariant WidgetCollapser oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.remeasureListenable != widget.remeasureListenable) {
      oldWidget.remeasureListenable?.removeListener(_onRemeasureRequested);
      widget.remeasureListenable?.addListener(_onRemeasureRequested);
    }

    // The parent built a fresh WidgetCollapser, so the child widget instances
    // (and thus the previously cached layout) are no longer current.
    _cachedLayout = null;
    _cachedHidden = const [];

    if (oldWidget.children.length != widget.children.length ||
        oldWidget.orientation != widget.orientation) {
      _createKeys();
      _childSizes = null;
      _overflowSize = null;
      _needsRemeasure = false;
      return;
    }

    // A [spacing] change almost always means a global UI scale factor changed
    // (e.g. `spacing: 8 * scale`), which scales every child by the same
    // ratio. Apply that ratio to the cached sizes so this frame's collapse
    // decision is already (nearly) exact instead of computed from sizes that
    // are one frame stale; the post-frame live re-measure scheduled below
    // confirms the precise sizes.
    final childSizes = _childSizes;
    if (childSizes != null &&
        oldWidget.spacing > 0 &&
        widget.spacing != oldWidget.spacing) {
      final ratio = widget.spacing / oldWidget.spacing;
      Size scaleSize(Size size) => widget.orientation == Axis.horizontal
          ? Size(size.width * ratio, size.height)
          : Size(size.width, size.height * ratio);
      for (final index in childSizes.keys.toList()) {
        childSizes[index] = scaleSize(childSizes[index]!);
      }
      final overflowSize = _overflowSize;
      if (overflowSize != null) _overflowSize = scaleSize(overflowSize);
      _needsRemeasure = true;
    }

    // A pinned overflow size is known exactly; refresh it in place. Only a
    // runtime-measured overflow button needs a re-measure.
    if (oldWidget.overflowMainAxisSize != widget.overflowMainAxisSize) {
      final pinned = widget.overflowMainAxisSize;
      if (pinned != null) {
        _overflowSize = _sizeFromMainAxis(pinned);
      } else {
        _overflowSize = null;
      }
    }

    // Only remeasure for an overflowBuilder change when the overflow size is
    // measured at runtime. If the size is pinned, the builder can change
    // without affecting layout calculations.
    final overflowBuilderChanged = widget.overflowMainAxisSize == null &&
        oldWidget.overflowBuilder != widget.overflowBuilder;

    if (!_childrenConfigsMatch(oldWidget.children, widget.children) ||
        overflowBuilderChanged ||
        _overflowSize == null) {
      _needsRemeasure = true;
    }
  }

  void _createKeys() {
    _childKeys
      ..clear()
      ..addAll(
        List.generate(widget.children.length, (_) => GlobalKey()),
      );
  }

  /// Returns true when every child's collapse metadata and child widget type
  /// are unchanged. This avoids treating routine parent rebuilds as structural
  /// changes.
  bool _childrenConfigsMatch(
    List<Collapsible> oldChildren,
    List<Collapsible> newChildren,
  ) {
    for (var i = 0; i < oldChildren.length; i++) {
      final oldChild = oldChildren[i];
      final newChild = newChildren[i];
      if (oldChild.collapsePriority != newChild.collapsePriority ||
          oldChild.mainAxisSize != newChild.mainAxisSize ||
          oldChild.flex != newChild.flex ||
          oldChild.collapseGroup != newChild.collapseGroup ||
          !Widget.canUpdate(oldChild.child, newChild.child)) {
        return false;
      }
    }
    return true;
  }

  void _measure() {
    if (!mounted) return;

    var changed = false;
    final sizes = <int, Size>{};

    for (var i = 0; i < widget.children.length; i++) {
      final child = widget.children[i];
      if (child.mainAxisSize != null) {
        sizes[i] = _sizeFromMainAxis(child.mainAxisSize!);
      } else if (child.isFlex) {
        sizes[i] = Size.zero;
      } else {
        final renderBox =
            _childKeys[i].currentContext?.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          sizes[i] = renderBox.size;
        } else if (_childSizes != null && _childSizes!.containsKey(i)) {
          // The child is currently hidden; keep its cached size so a parent
          // rebuild does not treat the missing measurement as a change.
          sizes[i] = _childSizes![i]!;
        }
      }

      if (_childSizes == null || _childSizes![i] != sizes[i]) {
        changed = true;
      }
    }

    Size? nextOverflowSize;
    if (widget.overflowMainAxisSize != null) {
      nextOverflowSize = _sizeFromMainAxis(widget.overflowMainAxisSize!);
    } else {
      final renderBox =
          _overflowKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        nextOverflowSize = renderBox.size;
      }
    }

    if (_overflowSize != nextOverflowSize) {
      changed = true;
    }

    if (changed) {
      setState(() {
        _childSizes = sizes;
        _overflowSize = nextOverflowSize;
        _needsRemeasure = false;
      });
    } else {
      _needsRemeasure = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final overflowIsSized = widget.overflowMainAxisSize != null ||
        _overflowSize != null;
    final childrenAreSized = _childSizes != null &&
        _childSizes!.length == widget.children.length;

    if (!childrenAreSized || !overflowIsSized) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
      return _buildMeasurementView(context);
    }

    if (_needsRemeasure) {
      _needsRemeasure = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = _mainAxisExtentFromConstraints(constraints);
        final hidden = _computeHidden(available);

        // Reuse the previously built layout when the collapse decision did not
        // change. Returning the same widget instance lets Flutter skip the
        // downstream rebuild, so a resize that does not cross a threshold (or
        // a keystroke that only moves the cursor) no longer tears down the
        // whole footer. A new layout is only produced when a child's width or
        // the available width actually flips the hidden set.
        //
        // Resizing the spacer still works: the Row element receives new
        // constraints from the LayoutBuilder and re-lays out even when its
        // widget instance is unchanged.
        if (_cachedLayout != null && _hiddenEquals(hidden, _cachedHidden)) {
          return _cachedLayout!;
        }

        final visible =
            widget.children.where((c) => !hidden.contains(c)).toList();
        _cachedLayout = _buildFlexWidget(visible, hidden);
        _cachedHidden = List.unmodifiable(hidden);
        return _cachedLayout!;
      },
    );
  }

  Widget _buildMeasurementView(BuildContext context) {
    final measureChildren = <Widget>[
      for (var i = 0; i < widget.children.length; i++)
        SizedBox(
          key: _childKeys[i],
          child: widget.children[i].isFlex ||
                  widget.children[i].mainAxisSize != null
              ? const SizedBox.shrink()
              : widget.children[i].child,
        ),
      if (widget.overflowMainAxisSize == null)
        SizedBox(
          key: _overflowKey,
          child: _buildOverflowButton(context, const []),
        ),
    ];

    final offscreen = widget.orientation == Axis.horizontal
        ? Row(mainAxisSize: MainAxisSize.min, children: measureChildren)
        : Column(mainAxisSize: MainAxisSize.min, children: measureChildren);

    return Stack(
      children: [
        Positioned(
          left: widget.orientation == Axis.horizontal ? -100000.0 : 0,
          top: widget.orientation == Axis.vertical ? -100000.0 : 0,
          child: offscreen,
        ),
      ],
    );
  }

  List<Collapsible> _computeHidden(double available) {
    if (available.isInfinite) return [];

    final nonFlex = widget.children.where((c) => !c.isFlex).toList();
    if (nonFlex.isEmpty) return [];

    // Build collapse units: grouped children collapse together; ungrouped
    // children collapse individually.
    final units = <_CollapseUnit>[];
    final groups = <String, List<Collapsible>>{};

    for (final child in nonFlex) {
      final group = child.collapseGroup;
      if (group == null) {
        units.add(_CollapseUnit([child]));
      } else {
        groups.putIfAbsent(group, () => []).add(child);
      }
    }
    for (final members in groups.values) {
      units.add(_CollapseUnit(members));
    }

    for (final unit in units) {
      unit.priority = unit.members
          .map((c) => c.collapsePriority)
          .reduce((a, b) => a < b ? a : b);
    }

    // Stable sort: lowest priority first, then later display order first when
    // priorities tie.
    units.sort((a, b) {
      final priorityCompare = a.priority.compareTo(b.priority);
      if (priorityCompare != 0) return priorityCompare;
      return widget.children
          .indexOf(b.members.first)
          .compareTo(widget.children.indexOf(a.members.first));
    });

    double totalExtent(List<_CollapseUnit> visibleUnits,
        {required bool hasOverflow}) {
      final visibleNonFlex =
          visibleUnits.expand<Collapsible>((u) => u.members).toList();
      final visibleGroupNames = visibleNonFlex
          .map((c) => c.collapseGroup)
          .whereType<String>()
          .toSet();
      final visibleFlex = widget.children
          .where((c) =>
              c.isFlex &&
              (c.collapseGroup == null ||
                  visibleGroupNames.contains(c.collapseGroup)))
          .toList();

      // Merge non-flex and flex children in display order.
      final visible = <Collapsible>[];
      for (final child in widget.children) {
        if (visibleNonFlex.contains(child) || visibleFlex.contains(child)) {
          visible.add(child);
        }
      }

      var extent = 0.0;
      for (var i = 0; i < visible.length; i++) {
        final index = widget.children.indexOf(visible[i]);
        final size = _childSizes![index];
        if (size == null) return double.infinity;
        extent += _mainAxisExtent(size);
        if (i < visible.length - 1) extent += widget.spacing;
      }
      if (hasOverflow) {
        final overflowSize = _overflowSize;
        if (overflowSize == null) return double.infinity;
        extent += _mainAxisExtent(overflowSize);
        if (visible.isNotEmpty) extent += widget.spacing;
      }
      return extent;
    }

    if (totalExtent(units, hasOverflow: false) <= available) {
      return [];
    }

    var visibleUnits = [...units];
    while (visibleUnits.isNotEmpty &&
        totalExtent(visibleUnits, hasOverflow: true) > available) {
      // Because of the stable sort, the first unit is the one to collapse.
      visibleUnits.removeAt(0);
    }

    final hiddenNonFlex = nonFlex
        .where((c) => !visibleUnits.any((u) => u.members.contains(c)))
        .toList();

    // Hide flex children that belong to a group with any collapsed non-flex
    // member.
    final collapsedGroups =
        hiddenNonFlex.map((c) => c.collapseGroup).whereType<String>().toSet();
    final hiddenFlex = widget.children
        .where((c) => c.isFlex && collapsedGroups.contains(c.collapseGroup))
        .toList();

    return [...hiddenNonFlex, ...hiddenFlex];
  }

  Widget _buildFlexWidget(List<Collapsible> visible, List<Collapsible> hidden) {
    final children = <Widget>[
      ..._buildVisibleChildren(visible),
      if (hidden.isNotEmpty) ...[
        _spacing(),
        SizedBox(
          key: _overflowKey,
          child: _buildOverflowButton(context, hidden),
        ),
      ],
    ];

    final layout = widget.orientation == Axis.horizontal
        ? Row(
            mainAxisAlignment: widget.mainAxisAlignment,
            crossAxisAlignment: widget.crossAxisAlignment,
            children: children,
          )
        : Column(
            mainAxisAlignment: widget.mainAxisAlignment,
            crossAxisAlignment: widget.crossAxisAlignment,
            children: children,
          );

    // Keep hidden (non-flex) children mounted in an [Offstage] subtree under
    // their measurement keys. Offstage children are laid out (so [_measure]
    // can read their live sizes and they reappear at the correct width), but
    // they are not painted, hit-tested, or exposed to semantics, and finders
    // skip them by default. Because each child's [GlobalKey] appears exactly
    // once — here or in the visible row — moving between the two preserves
    // the child's [State].
    final offstageChildren = <Widget>[
      for (final child in hidden)
        if (!child.isFlex && _indexOfChild(child) != -1)
          KeyedSubtree(
            key: _childKeys[_indexOfChild(child)],
            child: child.child,
          ),
    ];
    if (offstageChildren.isEmpty) return layout;

    final offstageRow = widget.orientation == Axis.horizontal
        ? Row(mainAxisSize: MainAxisSize.min, children: offstageChildren)
        : Column(mainAxisSize: MainAxisSize.min, children: offstageChildren);

    return Stack(
      children: [
        layout,
        Positioned(
          left: 0,
          top: 0,
          child: Offstage(child: UnconstrainedBox(child: offstageRow)),
        ),
      ],
    );
  }

  List<Widget> _buildVisibleChildren(List<Collapsible> visible) {
    final result = <Widget>[];
    for (var i = 0; i < visible.length; i++) {
      final child = visible[i];
      if (child.isFlex) {
        result.add(Expanded(flex: child.flex!, child: child.child));
      } else {
        // Attach the child's measurement key so re-measure passes (see
        // [remeasureListenable]) can read the child's live size. The
        // offscreen measurement view only exists during the first frame, so
        // without the key here, measured sizes could never be refreshed.
        final childIndex = _indexOfChild(child);
        result.add(
          childIndex == -1
              ? child.child
              : KeyedSubtree(key: _childKeys[childIndex], child: child.child),
        );
      }
      if (i < visible.length - 1) {
        result.add(_spacing());
      }
    }
    return result;
  }

  /// Identity-based lookup of [child] in [widget.children].
  ///
  /// [Collapsible] implements value equality, so [List.indexOf] could return
  /// the wrong slot for two equal-by-value children; measurement keys are
  /// index-based and must map to the exact instance.
  int _indexOfChild(Collapsible child) {
    for (var i = 0; i < widget.children.length; i++) {
      if (identical(widget.children[i], child)) return i;
    }
    return -1;
  }

  Widget _buildOverflowButton(BuildContext context, List<Collapsible> hidden) {
    final builder = widget.overflowBuilder ?? _defaultOverflowBuilder;
    return builder(context, hidden);
  }

  Widget _spacing() => widget.orientation == Axis.horizontal
      ? SizedBox(width: widget.spacing)
      : SizedBox(height: widget.spacing);

  double _mainAxisExtent(Size size) => widget.orientation == Axis.horizontal
      ? size.width
      : size.height;

  double _mainAxisExtentFromConstraints(BoxConstraints constraints) =>
      widget.orientation == Axis.horizontal
          ? constraints.maxWidth
          : constraints.maxHeight;

  /// Compares two hidden sets by reference. The Collapsible instances returned
  /// from [_computeHidden] are members of [widget.children], which stay stable
  /// across LayoutBuilder builds that are not preceded by a
  /// [didUpdateWidget]. Reference equality is therefore both correct and cheap
  /// here, and it avoids relying on [Collapsible.operator==] whose `child`
  /// comparison would defeat the purpose of the cache.
  bool _hiddenEquals(List<Collapsible> a, List<Collapsible> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }

  Size _sizeFromMainAxis(double extent) =>
      widget.orientation == Axis.horizontal
          ? Size(extent, 0)
          : Size(0, extent);

  static Widget _defaultOverflowBuilder(
    BuildContext context,
    List<Collapsible> hidden,
  ) {
    return PopupMenuButton<Collapsible>(
      icon: const Icon(Icons.more_vert),
      itemBuilder: (context) => hidden
          .map(
            (c) => PopupMenuItem(value: c, child: c.child),
          )
          .toList(),
    );
  }
}

/// A group of children that collapse together.
class _CollapseUnit {
  final List<Collapsible> members;
  late int priority;

  _CollapseUnit(this.members);
}
