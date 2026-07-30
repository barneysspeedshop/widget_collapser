# widget_collapser

A Flutter package that collapses toolbar children into an overflow widget as the available main-axis space shrinks. Supports both horizontal and vertical toolbars, fully customizable overflow menus, and optional forced child sizes.

## Features

- Collapse children by priority when space is constrained.
- Horizontal and vertical orientations.
- Fully customizable overflow widget (icon, menu implementation, etc.).
- Optional fixed main-axis size per child to skip measurement.
- Expanding spacer children for pushing items apart.

## Getting started

Add `widget_collapser` to your `pubspec.yaml`:

```yaml
dependencies:
  widget_collapser:
    path: ../widget_collapser
```

## Usage

### Horizontal toolbar

```dart
WidgetCollapser(
  spacing: 8,
  children: const [
    Collapsible(
      collapsePriority: 100,
      child: Text('Plan Name'),
    ),
    Collapsible.spacer(flex: 1),
    Collapsible(
      collapsePriority: 10,
      child: Icon(Icons.location_on),
    ),
    Collapsible(
      collapsePriority: 20,
      child: Icon(Icons.qr_code),
    ),
    Collapsible(
      collapsePriority: 1000,
      child: Icon(Icons.add),
    ),
  ],
)
```

Lower `collapsePriority` values are hidden first. In the example above, the location icon would collapse before the QR code, and the plan name / add button are kept visible as long as possible.

### Vertical toolbar

```dart
WidgetCollapser(
  orientation: Axis.vertical,
  spacing: 8,
  children: const [
    Collapsible(
      collapsePriority: 100,
      child: Icon(Icons.home),
    ),
    Collapsible(
      collapsePriority: 50,
      child: Icon(Icons.settings),
    ),
    Collapsible(
      collapsePriority: 1,
      child: Icon(Icons.help),
    ),
  ],
)
```

### Custom overflow widget

The overflow widget is completely customizable. You can use any icon package or menu implementation.

```dart
WidgetCollapser(
  spacing: 8,
  overflowBuilder: (context, hidden) {
    return PopupMenuButton<Collapsible>(
      icon: const FaIcon(FontAwesomeIcons.ellipsisVertical),
      itemBuilder: (context) => hidden
          .map((c) => PopupMenuItem(value: c, child: c.child))
          .toList(),
    );
  },
  children: const [
    // ...
  ],
)
```

You can also integrate with another menu package such as `legacy_context_menu` inside `overflowBuilder`.

### Collapse groups

Use `collapseGroup` to collapse multiple children together. This is useful when a flex spacer should disappear along with the widget it pushes against.

```dart
WidgetCollapser(
  spacing: 8,
  children: const [
    Collapsible(
      collapsePriority: 100,
      collapseGroup: 'plan',
      child: Text('Plan Name'),
    ),
    Collapsible.spacer(flex: 1, collapseGroup: 'plan'),
    Collapsible(
      collapsePriority: 10,
      child: Icon(Icons.location_on),
    ),
    Collapsible(
      collapsePriority: 20,
      child: Icon(Icons.qr_code),
    ),
    Collapsible(
      collapsePriority: 1000,
      child: Icon(Icons.add),
    ),
  ],
)
```

In this example, the spacer is only visible when "Plan Name" is visible. If the plan name collapses, the spacer collapses with it.

### Forced main-axis size

If you already know a child's size, you can skip automatic measurement:

```dart
Collapsible(
  collapsePriority: 10,
  mainAxisSize: 120,
  child: MyCustomButton(),
)
```

For a horizontal `WidgetCollapser`, `mainAxisSize` is the child's width. For a vertical one, it is the child's height.

## Additional information

See the `test/` directory for examples of horizontal collapse, vertical collapse, custom overflow builders, and spacer behavior.
