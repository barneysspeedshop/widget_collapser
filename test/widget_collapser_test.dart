import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widget_collapser/widget_collapser.dart';

void main() {
  group('WidgetCollapser horizontal', () {
    testWidgets('shows all children when they fit', (tester) async {
      await tester.pumpWidget(
        _TestApp(
          child: SizedBox(
            width: 300,
            height: 50,
            child: WidgetCollapser(
              spacing: 10,
              overflowMainAxisSize: 20,
              children: [
                _box(key: const Key('a'), width: 50, priority: 1),
                _box(key: const Key('b'), width: 50, priority: 2),
                _box(key: const Key('c'), width: 50, priority: 3),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('a')), findsOneWidget);
      expect(find.byKey(const Key('b')), findsOneWidget);
      expect(find.byKey(const Key('c')), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsNothing);
    });

    testWidgets('collapses lowest priority children first', (tester) async {
      await tester.pumpWidget(
        _TestApp(
          child: SizedBox(
            width: 150,
            height: 50,
            child: WidgetCollapser(
              spacing: 10,
              overflowMainAxisSize: 20,
              overflowBuilder: _smallOverflow,
              children: [
                _box(key: const Key('a'), width: 50, priority: 1),
                _box(key: const Key('b'), width: 50, priority: 2),
                _box(key: const Key('c'), width: 50, priority: 3),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // a (priority 1) is the only one that needs to be hidden.
      // b+c+spacing+overflow = 50 + 10 + 50 + 10 + 20 = 140 <= 150.
      expect(find.byKey(const Key('a')), findsNothing);
      expect(find.byKey(const Key('b')), findsOneWidget);
      expect(find.byKey(const Key('c')), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('custom overflow builder receives hidden children',
        (tester) async {
      List<Collapsible>? receivedHidden;

      await tester.pumpWidget(
        _TestApp(
          child: SizedBox(
            width: 80,
            height: 50,
            child: WidgetCollapser(
              spacing: 10,
              overflowMainAxisSize: 20,
              overflowBuilder: (context, hidden) {
                receivedHidden = hidden;
                return _smallOverflow(context, hidden);
              },
              children: [
                _box(key: const Key('a'), width: 50, priority: 1),
                _box(key: const Key('b'), width: 50, priority: 2),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.more_vert), findsOneWidget);
      expect(receivedHidden, isNotNull);
      expect(receivedHidden!.length, 1);
      expect((receivedHidden!.first.child as Container).key, const Key('a'));
    });

    testWidgets('spacer pushes visible children apart', (tester) async {
      await tester.pumpWidget(
        _TestApp(
          child: SizedBox(
            width: 300,
            height: 50,
            child: WidgetCollapser(
              spacing: 10,
              children: [
                _box(key: const Key('a'), width: 50, priority: 1),
                const Collapsible.spacer(flex: 1),
                _box(key: const Key('b'), width: 50, priority: 2),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('a')), findsOneWidget);
      expect(find.byKey(const Key('b')), findsOneWidget);

      final aRect = tester.getRect(find.byKey(const Key('a')));
      final bRect = tester.getRect(find.byKey(const Key('b')));
      // a should be on the left, b on the right.
      expect(aRect.left < bRect.left, isTrue);
    });
  });

  group('WidgetCollapser vertical', () {
    testWidgets('shows all children when they fit', (tester) async {
      await tester.pumpWidget(
        _TestApp(
          child: SizedBox(
            width: 50,
            height: 300,
            child: WidgetCollapser(
              orientation: Axis.vertical,
              spacing: 10,
              overflowMainAxisSize: 20,
              children: [
                _box(key: const Key('a'), height: 50, priority: 1),
                _box(key: const Key('b'), height: 50, priority: 2),
                _box(key: const Key('c'), height: 50, priority: 3),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('a')), findsOneWidget);
      expect(find.byKey(const Key('b')), findsOneWidget);
      expect(find.byKey(const Key('c')), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsNothing);
    });

    testWidgets('collapses lowest priority children first', (tester) async {
      await tester.pumpWidget(
        _TestApp(
          child: SizedBox(
            width: 50,
            height: 150,
            child: WidgetCollapser(
              orientation: Axis.vertical,
              spacing: 10,
              overflowMainAxisSize: 20,
              overflowBuilder: _smallOverflow,
              children: [
                _box(key: const Key('a'), height: 50, priority: 1),
                _box(key: const Key('b'), height: 50, priority: 2),
                _box(key: const Key('c'), height: 50, priority: 3),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('a')), findsNothing);
      expect(find.byKey(const Key('b')), findsOneWidget);
      expect(find.byKey(const Key('c')), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });
  });

  group('WidgetCollapser priority ties', () {
    testWidgets('collapses later children first when priorities tie',
        (tester) async {
      await tester.pumpWidget(
        _TestApp(
          child: SizedBox(
            width: 80,
            height: 50,
            child: WidgetCollapser(
              spacing: 10,
              overflowMainAxisSize: 20,
              overflowBuilder: _smallOverflow,
              children: [
                _box(key: const Key('a'), width: 50, priority: 1),
                _box(key: const Key('b'), width: 50, priority: 1),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // b appears later, so it collapses first.
      expect(find.byKey(const Key('a')), findsOneWidget);
      expect(find.byKey(const Key('b')), findsNothing);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });
  });

  group('WidgetCollapser measurement stability', () {
    testWidgets('keeps cached sizes when parent rebuilds with equivalent children',
        (tester) async {
      Widget buildWithKey(Key key) {
        return _TestApp(
          child: SizedBox(
            width: 300,
            height: 50,
            child: WidgetCollapser(
              spacing: 10,
              overflowMainAxisSize: 20,
              children: [
                _box(key: key, width: 50, priority: 1),
                _box(key: const Key('b'), width: 50, priority: 2),
                _box(key: const Key('c'), width: 50, priority: 3),
              ],
            ),
          ),
        );
      }

      final collapserFinder = find.byType(WidgetCollapser);
      final measurementViewFinder = find.descendant(
        of: collapserFinder,
        matching: find.byType(Stack),
      );

      await tester.pumpWidget(buildWithKey(const Key('a')));
      await tester.pumpAndSettle();

      // After settling, the real layout (not the off-screen measurement view)
      // should be visible.
      expect(measurementViewFinder, findsNothing);
      expect(find.byKey(const Key('a')), findsOneWidget);

      // Rebuild with a new Collapsible/Container instance but the same
      // configuration. The measurement view should not reappear.
      await tester.pumpWidget(buildWithKey(const Key('a')));
      await tester.pumpAndSettle();
      expect(measurementViewFinder, findsNothing);
      expect(find.byKey(const Key('a')), findsOneWidget);
      expect(find.byKey(const Key('b')), findsOneWidget);
      expect(find.byKey(const Key('c')), findsOneWidget);
    });

    testWidgets(
        'does not trigger extra rebuilds when parent rebuilds with hidden children',
        (tester) async {
      var bBuildCount = 0;

      Widget buildCollapser() {
        return _TestApp(
          child: SizedBox(
            width: 150,
            height: 50,
            child: WidgetCollapser(
              spacing: 10,
              overflowBuilder: (context, hidden) =>
                  _smallOverflow(context, hidden),
              children: [
                _box(key: const Key('a'), width: 50, priority: 1),
                Collapsible(
                  collapsePriority: 2,
                  child: _CountedBuild(
                    key: const Key('b'),
                    width: 50,
                    height: 50,
                    onBuild: () => bBuildCount++,
                  ),
                ),
                _box(key: const Key('c'), width: 50, priority: 3),
              ],
            ),
          ),
        );
      }

      await tester.pumpWidget(buildCollapser());
      await tester.pumpAndSettle();

      // a is hidden because a+b+c+2*spacing+overflow ≈ 190 > 150.
      expect(find.byKey(const Key('a')), findsNothing);
      expect(find.byKey(const Key('b')), findsOneWidget);
      expect(find.byKey(const Key('c')), findsOneWidget);

      final countAfterInitial = bBuildCount;
      expect(countAfterInitial, greaterThan(0));

      // Simulate a parent rebuild (e.g. typing in another field) with new
      // widget instances but equivalent configuration.
      await tester.pumpWidget(buildCollapser());
      await tester.pumpAndSettle();

      // b should rebuild exactly once for the parent rebuild, not again due to
      // an unnecessary post-frame setState from the hidden child measurement.
      expect(bBuildCount, countAfterInitial + 1);
    });

    testWidgets('uses cached sizes on resize and restores hidden children',
        (tester) async {
      Widget buildWithWidth(double width) {
        return _TestApp(
          child: SizedBox(
            width: width,
            height: 50,
            child: WidgetCollapser(
              spacing: 10,
              overflowMainAxisSize: 20,
              overflowBuilder: _smallOverflow,
              children: [
                _box(key: const Key('a'), width: 50, priority: 1),
                _box(key: const Key('b'), width: 50, priority: 2),
              ],
            ),
          ),
        );
      }

      // Width 120: a+b+spacing = 110 <= 120, both visible.
      await tester.pumpWidget(buildWithWidth(120));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('a')), findsOneWidget);
      expect(find.byKey(const Key('b')), findsOneWidget);

      // Width 100: a+b+spacing = 110 > 100, a (lower priority) collapses.
      await tester.pumpWidget(buildWithWidth(100));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('a')), findsNothing);
      expect(find.byKey(const Key('b')), findsOneWidget);

      // Width 120 again: cached size for a lets the collapser restore it.
      await tester.pumpWidget(buildWithWidth(120));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('a')), findsOneWidget);
      expect(find.byKey(const Key('b')), findsOneWidget);
    });
  });

  group('WidgetCollapser layout stability', () {
    testWidgets(
        'does not rebuild children on resize that keeps the hidden set',
        (tester) async {
      var aBuildCount = 0;
      var bBuildCount = 0;

      // Build the collapser once so the same widget instance is reused across
      // resizes. This mirrors the real-world case where a parent that does not
      // rebuild (e.g. a footer driven by a structural ListenableBuilder that
      // does not fire on resize) leaves the WidgetCollapser element untouched,
      // so only the inner LayoutBuilder re-runs with new constraints.
      final collapser = WidgetCollapser(
        spacing: 10,
        overflowMainAxisSize: 20,
        children: [
          Collapsible(
            collapsePriority: 1,
            child: _CountedBuild(
              key: const Key('a'),
              width: 50,
              height: 50,
              onBuild: () => aBuildCount++,
            ),
          ),
          Collapsible(
            collapsePriority: 2,
            child: _CountedBuild(
              key: const Key('b'),
              width: 50,
              height: 50,
              onBuild: () => bBuildCount++,
            ),
          ),
        ],
      );

      Widget buildWithWidth(double width) {
        return _TestApp(
          child: SizedBox(width: width, height: 50, child: collapser),
        );
      }

      // Width 120: a+b+spacing = 110 <= 120, both visible.
      await tester.pumpWidget(buildWithWidth(120));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('a')), findsOneWidget);
      expect(find.byKey(const Key('b')), findsOneWidget);

      final aAfterInitial = aBuildCount;
      final bAfterInitial = bBuildCount;

      // Resize within the range that does not change the collapse decision.
      // Only the LayoutBuilder should run; the visible child widgets should
      // not be rebuilt.
      await tester.pumpWidget(buildWithWidth(116));
      await tester.pumpAndSettle();
      await tester.pumpWidget(buildWithWidth(119));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('a')), findsOneWidget);
      expect(find.byKey(const Key('b')), findsOneWidget);
      expect(aBuildCount, aAfterInitial);
      expect(bBuildCount, bAfterInitial);
    });

    // Crossing a collapse threshold is already covered by the
    // "uses cached sizes on resize and restores hidden children" test above.
  });

  group('WidgetCollapser collapse groups', () {
    testWidgets('hides grouped flex spacer when non-flex member collapses',
        (tester) async {
      await tester.pumpWidget(
        _TestApp(
          child: SizedBox(
            width: 120,
            height: 50,
            child: WidgetCollapser(
              spacing: 10,
              overflowMainAxisSize: 20,
              overflowBuilder: _smallOverflow,
              children: [
                _box(
                  key: const Key('plan'),
                  width: 80,
                  priority: 100,
                  group: 'plan',
                ),
                const Collapsible.spacer(flex: 1, collapseGroup: 'plan'),
                _box(
                  key: const Key('loc'),
                  width: 50,
                  priority: 1,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The plan group is higher priority than location, so location collapses.
      // The spacer in the 'plan' group stays visible because plan is visible.
      expect(find.byKey(const Key('plan')), findsOneWidget);
      expect(find.byKey(const Key('loc')), findsNothing);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('collapses entire group together', (tester) async {
      await tester.pumpWidget(
        _TestApp(
          child: SizedBox(
            width: 100,
            height: 50,
            child: WidgetCollapser(
              spacing: 10,
              overflowMainAxisSize: 20,
              overflowBuilder: _smallOverflow,
              children: [
                _box(
                  key: const Key('plan'),
                  width: 80,
                  priority: 1,
                  group: 'plan',
                ),
                const Collapsible.spacer(flex: 1, collapseGroup: 'plan'),
                _box(
                  key: const Key('loc'),
                  width: 50,
                  priority: 100,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The plan group has lower priority, so the whole group (including its
      // flex spacer) collapses together. loc + overflow + spacing = 80 <= 100.
      expect(find.byKey(const Key('plan')), findsNothing);
      expect(find.byKey(const Key('loc')), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('collapses lower priority group first', (tester) async {
      await tester.pumpWidget(
        _TestApp(
          child: SizedBox(
            width: 140,
            height: 50,
            child: WidgetCollapser(
              spacing: 10,
              overflowMainAxisSize: 20,
              overflowBuilder: _smallOverflow,
              children: [
                _box(
                  key: const Key('a1'),
                  width: 50,
                  priority: 10,
                  group: 'a',
                ),
                _box(
                  key: const Key('a2'),
                  width: 50,
                  priority: 10,
                  group: 'a',
                ),
                _box(
                  key: const Key('b1'),
                  width: 50,
                  priority: 5,
                  group: 'b',
                ),
                _box(
                  key: const Key('b2'),
                  width: 50,
                  priority: 5,
                  group: 'b',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Group 'b' has lower priority, so it collapses first.
      expect(find.byKey(const Key('a1')), findsOneWidget);
      expect(find.byKey(const Key('a2')), findsOneWidget);
      expect(find.byKey(const Key('b1')), findsNothing);
      expect(find.byKey(const Key('b2')), findsNothing);
    });

    testWidgets('overflow builder receives all group members', (tester) async {
      List<Collapsible>? receivedHidden;

      await tester.pumpWidget(
        _TestApp(
          child: SizedBox(
            width: 100,
            height: 50,
            child: WidgetCollapser(
              spacing: 10,
              overflowMainAxisSize: 20,
              overflowBuilder: (context, hidden) {
                receivedHidden = hidden;
                return _smallOverflow(context, hidden);
              },
              children: [
                _box(
                  key: const Key('plan'),
                  width: 80,
                  priority: 1,
                  group: 'plan',
                ),
                const Collapsible.spacer(flex: 1, collapseGroup: 'plan'),
                _box(
                  key: const Key('loc'),
                  width: 50,
                  priority: 100,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The plan group collapses, so both plan and its spacer are hidden.
      expect(receivedHidden, isNotNull);
      expect(receivedHidden!.length, 2);
      expect(
        receivedHidden!.any((c) => (c.child as Container).key == const Key('plan')),
        isTrue,
      );
      expect(
        receivedHidden!.any((c) => c.isFlex),
        isTrue,
      );
    });
  });

  group('WidgetCollapser remeasure', () {
    testWidgets(
      'remeasureListenable re-evaluates the collapse set when a child '
      'resizes through its own listener',
      (tester) async {
        final width = ValueNotifier<double>(80);
        final remeasure = ChangeNotifier();
        addTearDown(width.dispose);
        addTearDown(remeasure.dispose);

        Collapsible child() => Collapsible(
          collapsePriority: 1,
          child: ValueListenableBuilder<double>(
            valueListenable: width,
            builder: (context, w, _) => Container(
              key: const Key('a'),
              width: w,
              height: 50,
              color: Colors.red,
            ),
          ),
        );

        await tester.pumpWidget(
          _TestApp(
            child: SizedBox(
              width: 170,
              height: 50,
              child: WidgetCollapser(
                spacing: 10,
                overflowMainAxisSize: 20,
                overflowBuilder: _smallOverflow,
                remeasureListenable: remeasure,
                children: [
                  child(),
                  _box(key: const Key('b'), width: 50, priority: 2),
                  _box(key: const Key('c'), width: 50, priority: 3),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 80+10+50+10+50 = 200 > 170, so 'a' (priority 1) is hidden from the
        // start: b+c+overflow = 50+10+50+10+20 = 140 <= 170.
        expect(find.byKey(const Key('a')), findsNothing);
        expect(find.byIcon(Icons.more_vert), findsOneWidget);

        // Shrink 'a' through its own listenable and request a re-measure:
        // 50+10+50+10+50 = 170 <= 170, so 'a' reappears.
        width.value = 50;
        remeasure.notifyListeners();
        await tester.pump();
        await tester.pump();
        expect(find.byKey(const Key('a')), findsOneWidget);
        expect(find.byIcon(Icons.more_vert), findsNothing);

        // Grow it back. The growth frame itself may overflow (the child's new
        // size only exists once it has rebuilt and laid out — a limitation of
        // widget-level collapse); the re-measure corrects the set one frame
        // later.
        width.value = 80;
        remeasure.notifyListeners();
        await tester.pump();
        tester.takeException(); // transient RenderFlex overflow, if reported
        await tester.pump();

        expect(find.byKey(const Key('a')), findsNothing);
        expect(find.byKey(const Key('b')), findsOneWidget);
        expect(find.byKey(const Key('c')), findsOneWidget);
        expect(find.byIcon(Icons.more_vert), findsOneWidget);
      },
    );

    testWidgets(
      'a spacing change ratio-scales cached sizes so a zoom-like rebuild '
      'collapses in the same frame',
      (tester) async {
        Widget buildApp({required double spacing, required double w}) {
          return _TestApp(
            child: SizedBox(
              width: 170,
              height: 50,
              child: WidgetCollapser(
                spacing: spacing,
                overflowMainAxisSize: 20,
                overflowBuilder: _smallOverflow,
                children: [
                  _box(key: const Key('a'), width: w, priority: 1),
                  _box(key: const Key('b'), width: w, priority: 2),
                  _box(key: const Key('c'), width: w, priority: 3),
                ],
              ),
            ),
          );
        }

        await tester.pumpWidget(buildApp(spacing: 10, w: 50));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.more_vert), findsNothing);

        // Simulate a UI zoom x2: spacing and children double, width stays.
        // Cached sizes must scale by the spacing ratio so the collapse set is
        // correct immediately (100+20+100+20+100 = 340 > 170; after hiding a
        // and b: c+overflow = 100+20+20 = 140 <= 170).
        await tester.pumpWidget(buildApp(spacing: 20, w: 100));
        await tester.pump();

        expect(find.byKey(const Key('a')), findsNothing);
        expect(find.byKey(const Key('b')), findsNothing);
        expect(find.byKey(const Key('c')), findsOneWidget);
        expect(find.byIcon(Icons.more_vert), findsOneWidget);
      },
    );
  });
}

Collapsible _box({
  required Key key,
  double? width,
  double? height,
  required int priority,
  String? group,
}) {
  return Collapsible(
    collapsePriority: priority,
    collapseGroup: group,
    child: Container(key: key, width: width, height: height, color: Colors.red),
  );
}

Widget _smallOverflow(BuildContext context, List<Collapsible> hidden) {
  return const SizedBox(
    width: 20,
    height: 20,
    child: Icon(Icons.more_vert),
  );
}

class _CountedBuild extends StatelessWidget {
  final double? width;
  final double? height;
  final VoidCallback onBuild;

  const _CountedBuild({
    required super.key,
    this.width,
    this.height,
    required this.onBuild,
  });

  @override
  Widget build(BuildContext context) {
    onBuild();
    return Container(
      width: width,
      height: height,
      color: Colors.red,
    );
  }
}

class _TestApp extends StatelessWidget {
  final Widget child;

  const _TestApp({required this.child});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(child: child),
      ),
    );
  }
}
